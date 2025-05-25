MODEL (
  name combined.transactions,
  kind FULL,
  grain id
);

with all_transactions as (
    select
        transactions.id
        , transactions.category_id
        , transactions.amount
        , transactions.memo
        , subtransactions.id as subtransaction_id
        , subtransactions.category_id as sub_category_id
        , subtransactions.amount as subtransaction_amount
        , subtransactions.memo as subtransaction_memo
        , transactions.transaction_date
    from cleaned.transactions as transactions
    left outer join cleaned.sub_transactions as subtransactions
        on transactions.id = subtransactions.transaction_id
)

, transactions_int as (
    select
        id
        , coalesce(sub_category_id, category_id) as category_id
        , coalesce(subtransaction_amount, amount) as amount
        , coalesce(subtransaction_memo, memo) as memo
        , transaction_date
    from all_transactions
)

select
    transactions_int.id
    , categories.id as category_id
    , categories.category_group_id
    , categories.name as category_name
    , transactions_int.amount
    , transactions_int.transaction_date
    , category_groups.category_group_name_mapping
    , transactions_int.memo
from transactions_int as transactions_int
left join cleaned.categories as categories
    on transactions_int.category_id = categories.id
left join cleaned.category_groups as category_groups
    on categories.category_group_id = category_groups.id
order by transactions_int.transaction_date desc
