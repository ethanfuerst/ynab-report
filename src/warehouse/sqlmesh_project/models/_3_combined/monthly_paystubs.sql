MODEL (
  name combined.monthly_paystubs,
  kind FULL,
  grain pay_month
);

select
    date_trunc('month', pay_date) as pay_month
    , sum(round(earnings_actual, 2)) as earnings_actual
    , sum(round(pre_tax_deductions, 2)) as pre_tax_deductions
    , sum(round(retirement_fund, 2)) as retirement_fund
    , sum(round(hsa, 2)) as hsa
    , sum(round(taxes, 2)) as taxes
    , sum(round(post_tax_deductions, 2)) as post_tax_deductions
    , sum(round(deductions, 2)) as deductions
    , sum(round(earnings_actual + deductions, 2)) as net_pay
    , sum(round(income_for_reimbursements, 2)) as income_for_reimbursements
from cleaned.paystubs
group by pay_month
