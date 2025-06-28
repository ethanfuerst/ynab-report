MODEL (
  name raw.accounts,
  kind FULL,
  grain id
);

select
    id
    , name
    , type
    , on_budget
    , closed
    , note
    , balance
    , cleared_balance
    , uncleared_balance
    , transfer_payee_id
    , last_reconciled_at
from @get_s3_parquet_path('accounts')
