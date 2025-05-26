MODEL (
  name combined.paystubs,
  kind FULL,
  grain pay_date
);

select
    pay_date
    , round(earnings_actual, 2) as earnings_actual
    , round(pre_tax_deductions, 2) as pre_tax_deductions
    , round(retirement_fund, 2) as retirement_fund
    , round(hsa, 2) as hsa
    , round(taxes, 2) as taxes
    , round(post_tax_deductions, 2) as post_tax_deductions
    , round(deductions, 2) as deductions
    , round(earnings_actual + deductions, 2) as net_pay
    , round(income_for_reimbursements, 2) as income_for_reimbursements
from cleaned.paystubs
order by pay_date desc
