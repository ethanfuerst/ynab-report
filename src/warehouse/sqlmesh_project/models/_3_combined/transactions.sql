MODEL (
  name combined.transactions,
  kind FULL,
  grain id,
  description 'Transactions enriched with category and account dimensions. Money values are positive inflow/outflow columns; dashboard signs are applied only in the dashboard layer.'
);

with all_transactions as (
    select
        transactions.id
        , transactions.account_id
        , transactions.category_id
        , transactions.transaction_amount_usd
        , transactions.transaction_inflow_usd
        , transactions.transaction_outflow_usd
        , transactions.memo
        , transactions.paystub_file_name
        , subtransactions.id as subtransaction_id
        , subtransactions.category_id as sub_category_id
        , subtransactions.subtransaction_amount_usd
        , subtransactions.subtransaction_inflow_usd
        , subtransactions.subtransaction_outflow_usd
        , subtransactions.memo as subtransaction_memo
        , transactions.transaction_date
    from cleaned.transactions as transactions
    left outer join cleaned.sub_transactions as subtransactions
        on transactions.id = subtransactions.transaction_id
)

, transactions_int as (
    select
        id
        , account_id
        , coalesce(sub_category_id, category_id) as category_id
        , coalesce(subtransaction_amount_usd, transaction_amount_usd) as transaction_amount
        , coalesce(subtransaction_inflow_usd, transaction_inflow_usd) as transaction_inflow
        , coalesce(subtransaction_outflow_usd, transaction_outflow_usd) as transaction_outflow
        , coalesce(subtransaction_memo, memo) as memo
        , paystub_file_name
        , transaction_date
    from all_transactions
)

select
    transactions_int.id
    , transactions_int.transaction_date
    , categories.id as category_id
    , categories.category_group_id
    , categories.category_name
    , category_groups.category_group_name_mapping
    , category_groups.subcategory_group_name
    , transactions_int.transaction_amount  -- Absolute transaction or split amount, positive USD
    , transactions_int.transaction_inflow  -- Positive inflow amount, USD
    , transactions_int.transaction_outflow  -- Positive outflow amount, USD
    , transactions_int.memo
    , transactions_int.paystub_file_name
    , accounts.name as account_name
    , accounts.type as account_type
from transactions_int as transactions_int
left join cleaned.categories as categories
    on transactions_int.category_id = categories.id
left join cleaned.category_groups as category_groups
    on categories.category_group_id = category_groups.id
left join cleaned.accounts as accounts
    on transactions_int.account_id = accounts.id
order by transactions_int.transaction_date desc
