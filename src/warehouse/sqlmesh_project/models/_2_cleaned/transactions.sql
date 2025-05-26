MODEL (
  name cleaned.transactions,
  kind FULL,
  grain id
);

select
    id
    , category_id
    , strptime(date, '%Y-%m-%d') as transaction_date
    , amount / 1000 as amount
    , memo
    , import_payee_name as payee_name
    , flag_color
from raw.transactions
where category_id is not null
order by
    transaction_date desc
    , amount desc
