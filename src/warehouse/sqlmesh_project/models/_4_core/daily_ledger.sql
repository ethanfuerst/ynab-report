MODEL (
  name core.daily_ledger,
  kind FULL,
  audits (
    daily_ledger_auto_match_amount_equals_deposit,
    daily_ledger_manual_link_amounts_sum_to_deposit,
    daily_ledger_manual_paystub_file_name_resolves
  ),
  description 'Flat ledger combining YNAB transactions with paystubs. Transaction money is positive inflow/outflow, paystub costs use *_spend, and savings contributions use *_saved. Linking is hybrid: manual memo links (combined.transactions.paystub_file_name) take precedence; remaining transactions auto-match to a paystub when the inflow equals net_pay + reimbursement_income and transaction_date is within 7 days of pay_date. Dashboard signs are applied only in the dashboard layer.'
);

/*
    Step 1: collect every transaction that already carries an explicit paystub
    file_name in its memo (e.g. "<source> Paycheck - <paystub file_name>").
    These manual links are the source of truth — they win over any
    auto-matching below.
*/
with manual_links as (
    select
        id as transaction_id
        , paystub_file_name
    from combined.transactions
    where paystub_file_name is not null
)

/*
    Step 2: find candidate (transaction, paystub) pairs to auto-match. A pair
    is a candidate if the transaction inflow equals the paystub deposit
    (net_pay + reimbursement_income, since combined.paystubs.net_pay
    excludes reimbursements but the bank deposit includes them) and the
    transaction_date is within 7 days of pay_date in either direction.
    Already-manual transactions and already-manually-claimed paystubs are
    excluded so manual links can't be overridden or duplicated.
*/
, auto_match_candidates as (
    select
        transactions.id as transaction_id
        , paystubs.file_name as paystub_file_name
        , abs(transactions.transaction_date::date - paystubs.pay_date::date) as date_diff
    from combined.transactions as transactions
    join combined.paystubs as paystubs
        on round(transactions.transaction_inflow, 2) = round(
            coalesce(paystubs.net_pay, 0) + coalesce(paystubs.reimbursement_income, 0),
            2
        )
        and abs(transactions.transaction_date::date - paystubs.pay_date::date) <= 7
    where transactions.paystub_file_name is null
        and paystubs.file_name not in (select paystub_file_name from manual_links)
)

/*
    Step 3: collapse candidates to a 1:1 link by keeping only pairs that are
    the closest match for both sides. txn_rank picks the closest paystub for
    each transaction; ps_rank picks the closest transaction for each paystub.
    Requiring both ranks = 1 prevents double-counting when amounts coincide
    across multiple pay periods.
*/
, auto_links as (
    select
        transaction_id
        , paystub_file_name
    from (
        select
            transaction_id
            , paystub_file_name
            , row_number() over (partition by transaction_id order by date_diff, paystub_file_name) as txn_rank
            , row_number() over (partition by paystub_file_name order by date_diff, transaction_id) as ps_rank
        from auto_match_candidates
    ) ranked
    where txn_rank = 1 and ps_rank = 1
)

/*
    Step 4: union manual and auto links into a single lookup, tagged so
    downstream consumers can tell which path each link came from.
*/
, all_links as (
    select transaction_id, paystub_file_name, 'manual' as paystub_link_source from manual_links
    union all
    select transaction_id, paystub_file_name, 'auto' as paystub_link_source from auto_links
)

/*
    Step 5a: every transaction becomes a ledger row, joined to its paystub
    when a link exists. paystub_row_rank ranks transactions sharing the same
    paystub_file_name (e.g. a paycheck split across two deposits) so we can
    keep only one copy of the paystub-side fields in the next step.
*/
, transactions_with_paystub_rank as (
    select
        transactions.transaction_date::date as ledger_date
        , transactions.id as transaction_id
        , links.paystub_file_name
        , links.paystub_link_source
        , transactions.transaction_amount as transaction_amount_usd
        , transactions.transaction_inflow as transaction_inflow_usd
        , transactions.transaction_outflow as transaction_outflow_usd
        , transactions.category_id
        , transactions.category_name
        , transactions.category_group_name_mapping
        , transactions.subcategory_group_name
        , transactions.account_name
        , transactions.account_type
        , transactions.memo
        , paystubs.earnings_actual
        , paystubs.salary
        , paystubs.bonus
        , paystubs.pre_tax_deductions_spend
        , paystubs.taxes_spend
        , paystubs.retirement_fund_saved
        , paystubs.hsa_saved
        , paystubs.post_tax_deductions_spend
        , paystubs.paycheck_withheld
        , paystubs.net_pay
        , paystubs.reimbursement_income
        , row_number() over (
            partition by links.paystub_file_name
            order by transactions.transaction_date, transactions.transaction_amount desc
        ) as paystub_row_rank
    from combined.transactions as transactions
    left join all_links as links
        on transactions.id = links.transaction_id
    left join combined.paystubs as paystubs
        on links.paystub_file_name = paystubs.file_name
)

/*
    Step 5b: non-primary transactions for a shared paystub keep their own
    transaction-side fields (amount, category, memo) but get NULL paystub
    fields. This prevents monthly aggregations from double-counting salary,
    taxes, etc. when one paystub is deposited as multiple transactions.
*/
, transactions_with_paystubs as (
    select
        ledger_date
        , transaction_id
        , paystub_file_name
        , paystub_link_source
        , transaction_amount_usd
        , transaction_inflow_usd
        , transaction_outflow_usd
        , category_id
        , category_name
        , category_group_name_mapping
        , subcategory_group_name
        , account_name
        , account_type
        , memo
        , case when paystub_row_rank = 1 then earnings_actual end as earnings_actual
        , case when paystub_row_rank = 1 then salary end as salary
        , case when paystub_row_rank = 1 then bonus end as bonus
        , case when paystub_row_rank = 1 then pre_tax_deductions_spend end as pre_tax_deductions_spend
        , case when paystub_row_rank = 1 then taxes_spend end as taxes_spend
        , case when paystub_row_rank = 1 then retirement_fund_saved end as retirement_fund_saved
        , case when paystub_row_rank = 1 then hsa_saved end as hsa_saved
        , case when paystub_row_rank = 1 then post_tax_deductions_spend end as post_tax_deductions_spend
        , case when paystub_row_rank = 1 then paycheck_withheld end as paycheck_withheld
        , case when paystub_row_rank = 1 then net_pay end as net_pay
        , case when paystub_row_rank = 1 then reimbursement_income end as reimbursement_income
    from transactions_with_paystub_rank
)

/*
    Step 6: surface paystubs that didn't match any transaction as standalone
    ledger rows so monthly aggregations include their earnings/taxes/etc.
    Transaction-side columns are NULL on these rows; they're identifiable
    via paystub_link_source = 'orphan'.
*/
, orphan_paystubs as (
    select
        paystubs.pay_date::date as ledger_date
        , cast(null as varchar) as transaction_id
        , paystubs.file_name as paystub_file_name
        , 'orphan' as paystub_link_source
        , cast(null as decimal) as transaction_amount_usd
        , cast(null as decimal) as transaction_inflow_usd
        , cast(null as decimal) as transaction_outflow_usd
        , cast(null as varchar) as category_id
        , cast(null as varchar) as category_name
        , cast(null as varchar) as category_group_name_mapping
        , cast(null as varchar) as subcategory_group_name
        , cast(null as varchar) as account_name
        , cast(null as varchar) as account_type
        , cast(null as varchar) as memo
        , paystubs.earnings_actual
        , paystubs.salary
        , paystubs.bonus
        , paystubs.pre_tax_deductions_spend
        , paystubs.taxes_spend
        , paystubs.retirement_fund_saved
        , paystubs.hsa_saved
        , paystubs.post_tax_deductions_spend
        , paystubs.paycheck_withheld
        , paystubs.net_pay
        , paystubs.reimbursement_income
    from combined.paystubs as paystubs
    where paystubs.file_name not in (
        select paystub_file_name from all_links where paystub_file_name is not null
    )
)

/*
    Step 7: combine the two row sources. All transactions (linked or not)
    plus all unmatched paystubs.
*/
select
    ledger_date
    , transaction_id
    , paystub_file_name
    , paystub_link_source
    , transaction_amount_usd
    , transaction_inflow_usd
    , transaction_outflow_usd
    , category_id
    , category_name
    , category_group_name_mapping
    , subcategory_group_name
    , account_name
    , account_type
    , memo
    , earnings_actual
    , salary
    , bonus
    , pre_tax_deductions_spend
    , taxes_spend
    , retirement_fund_saved
    , hsa_saved
    , post_tax_deductions_spend
    , paycheck_withheld
    , net_pay
    , reimbursement_income
from transactions_with_paystubs
union all
select
    ledger_date
    , transaction_id
    , paystub_file_name
    , paystub_link_source
    , transaction_amount_usd
    , transaction_inflow_usd
    , transaction_outflow_usd
    , category_id
    , category_name
    , category_group_name_mapping
    , subcategory_group_name
    , account_name
    , account_type
    , memo
    , earnings_actual
    , salary
    , bonus
    , pre_tax_deductions_spend
    , taxes_spend
    , retirement_fund_saved
    , hsa_saved
    , post_tax_deductions_spend
    , paycheck_withheld
    , net_pay
    , reimbursement_income
from orphan_paystubs
