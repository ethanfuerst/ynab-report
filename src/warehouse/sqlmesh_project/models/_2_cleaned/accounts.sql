MODEL (
  name cleaned.accounts,
  kind FULL,
  grain id
);

select
    id
    , name
    , type
    , on_budget as is_on_budget
    , closed as is_closed
    , note
    , balance / 1000 as balance
    , cleared_balance / 1000 as cleared_balance
    , uncleared_balance / 1000 as uncleared_balance
    , transfer_payee_id
    , last_reconciled_at
from raw.accounts
