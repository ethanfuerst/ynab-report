MODEL (
  name cleaned.sub_transactions,
  kind FULL,
  grain id,
  description 'Cleaned YNAB sub-transactions. YNAB signs are normalized into positive inflow/outflow columns; dashboard signs are applied only in the dashboard layer.'
);

select
    /* Primary key */
    id  -- YNAB sub-transaction UUID

    /* Foreign keys */
    , transaction_id  -- Parent transaction UUID
    , payee_id  -- Payee UUID (nullable)
    , category_id  -- Category UUID (nullable)
    , transfer_account_id  -- Account UUID this split transfers to (nullable)

    /* Status and properties */
    , memo  -- Free-form memo (nullable)
    , deleted  -- Whether the sub-transaction has been deleted

    /* Money */
    , amount as ynab_amount_milliunits  -- Raw YNAB split amount in milliunits (positive = inflow, negative = outflow)
    , abs(amount) / 10 as subtransaction_amount_cents  -- Absolute split amount in cents
    , abs(amount) / 1000 as subtransaction_amount_usd  -- Absolute split amount in USD
    , greatest(amount, 0) / 1000 as subtransaction_inflow_usd  -- Positive split inflow amount in USD
    , abs(least(amount, 0)) / 1000 as subtransaction_outflow_usd  -- Positive split outflow amount in USD
from raw.subtransactions
