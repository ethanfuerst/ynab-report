MODEL (
  name cleaned.sub_transactions,
  kind FULL,
  grain id
);

select
    id
    , transaction_id
    , category_id
    , amount / 1000 as amount
    , memo
from raw.subtransactions
