MODEL (
  name raw.transactions,
  kind FULL,
  grain id
);

select
    id
    , date
    , amount
    , memo
    , cleared
    , approved
    , flag_color
    , account_id
    , payee_id
    , category_id
    , transfer_account_id
    , transfer_transaction_id
    , matched_transaction_id
    , import_id
    , import_payee_name
    , import_payee_name_original
    , debt_transaction_type
    , deleted
from @get_s3_parquet_path('transactions')
