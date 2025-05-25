MODEL (
  name raw.subtransactions,
  kind FULL,
  grain id
);

select
    id
    , transaction_id
    , amount
    , memo
    , payee_id
    , category_id
    , transfer_account_id
    , deleted
from @get_s3_table_path('subtransactions')
