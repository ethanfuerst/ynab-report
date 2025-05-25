MODEL (
  name cleaned.transactions,
  kind FULL,
  grain id
);

select
    id
    , category_id
    , strptime(transaction_date, '%Y-%m-%d') as transaction_date
    , amount
    , memo
    , import_payee_name as payee_name
    , flag_color
from raw.transactions
where category_id is not null
