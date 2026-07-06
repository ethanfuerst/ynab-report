MODEL (
  name combined.paystubs,
  kind FULL,
  grain file_name,
  description 'Paystub facts with positive money semantics. Deduction and tax costs use *_spend, savings contributions use *_saved, and dashboard signs are applied only in the dashboard layer.'
);

select
    file_name  -- Source paystub filename
    , pay_date  -- Pay date
    , round(earnings_custom_calc_usd, 2) as earnings_actual  -- Gross earnings used for reporting, positive USD
    , round(pre_tax_deductions_spend_usd, 2) as pre_tax_deductions_spend  -- FSA and medical pre-tax deductions, positive USD spend
    , round(taxes_spend_usd, 2) as taxes_spend  -- Paycheck taxes, positive USD spend
    , round(retirement_fund_saved_usd, 2) as retirement_fund_saved  -- 401(k) and related retirement contributions, positive USD saved
    , round(hsa_saved_usd, 2) as hsa_saved  -- HSA contributions, positive USD saved
    , round(post_tax_deductions_spend_usd, 2) as post_tax_deductions_spend  -- Insurance post-tax deductions, positive USD spend
    , round(paycheck_withheld_usd, 2) as paycheck_withheld  -- Total amount withheld from gross pay, positive USD
    , round(net_pay_custom_calc_usd, 2) as net_pay  -- Net pay excluding reimbursements, positive USD
    , round(earnings_expense_reimbursement_usd, 2) as reimbursement_income  -- Non-taxable reimbursement income, positive USD
    , round(earnings_salary_usd, 2) as salary  -- Salary earnings, positive USD
    , round(bonus_custom_calc_usd, 2) as bonus  -- Bonus, PTO payout, and severance earnings, positive USD
from cleaned.paystubs
order by pay_date desc
