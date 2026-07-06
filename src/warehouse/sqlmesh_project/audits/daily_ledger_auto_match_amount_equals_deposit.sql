AUDIT (
  name daily_ledger_auto_match_amount_equals_deposit
);

SELECT
  transaction_id,
  paystub_file_name,
  ledger_date,
  transaction_inflow_usd,
  net_pay,
  reimbursement_income,
  round(
    transaction_inflow_usd - (coalesce(net_pay, 0) + coalesce(reimbursement_income, 0)),
    2
  ) AS diff
FROM @this_model
WHERE paystub_link_source = 'auto'
  AND round(transaction_inflow_usd, 2)
      != round(coalesce(net_pay, 0) + coalesce(reimbursement_income, 0), 2);
