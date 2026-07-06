AUDIT (
  name daily_ledger_manual_link_amounts_sum_to_deposit
);

WITH manual_sums AS (
  SELECT
    paystub_file_name,
    SUM(transaction_inflow_usd) AS total_transaction_inflow,
    MAX(COALESCE(net_pay, 0) + COALESCE(reimbursement_income, 0)) AS paystub_deposit
  FROM @this_model
  WHERE paystub_link_source = 'manual'
  GROUP BY 1
)
SELECT
  paystub_file_name,
  total_transaction_inflow,
  paystub_deposit,
  ROUND(total_transaction_inflow - paystub_deposit, 2) AS diff
FROM manual_sums
WHERE ROUND(total_transaction_inflow, 2) != ROUND(paystub_deposit, 2);
