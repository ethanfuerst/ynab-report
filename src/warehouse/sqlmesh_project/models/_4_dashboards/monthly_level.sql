MODEL (
  name dashboards.monthly_level,
  kind FULL,
  grain budget_month
);

select
    monthly_transactions.budget_month
    , coalesce(monthly_paystubs.earnings_actual, 0) as earnings_actual
    , coalesce(monthly_paystubs.pre_tax_deductions, 0) as pre_tax_deductions
    , coalesce(monthly_paystubs.taxes, 0) as taxes
    , coalesce(monthly_paystubs.retirement_fund, 0) as retirement_fund
    , coalesce(monthly_paystubs.hsa, 0) as hsa
    , coalesce(monthly_paystubs.post_tax_deductions, 0)
        as post_tax_deductions
    , coalesce(monthly_paystubs.deductions, 0) as total_deductions
    , coalesce(monthly_paystubs.net_pay, 0) as net_pay
    , coalesce(monthly_paystubs.income_for_reimbursements, 0)
        as income_for_reimbursements
    , coalesce(
        coalesce(monthly_transactions.income, 0)
        - coalesce(monthly_paystubs.net_pay, 0)
        , 0
    ) as misc_income
    , coalesce(
        coalesce(net_pay, 0)
        + coalesce(misc_income, 0)
        , 0
    ) as total_income
    , coalesce(monthly_transactions.needs_spend, 0) as needs_spend
    , coalesce(monthly_transactions.wants_spend, 0) as wants_spend
    , coalesce(monthly_transactions.savings_spend, 0) as savings_spend
    , coalesce(monthly_transactions.emergency_fund_spend, 0)
        as emergency_fund_spend
    , coalesce(monthly_transactions.savings_assigned, 0) as savings_saved
    , coalesce(monthly_transactions.emergency_fund_assigned, 0)
        as emergency_fund_saved
    , coalesce(monthly_transactions.investments_assigned, 0)
        as investments_saved
    , coalesce(monthly_transactions.emergency_fund_in_hsa, 0)
        as emergency_fund_in_hsa
    , coalesce(
        monthly_transactions.needs_spend
        + monthly_transactions.wants_spend
        + monthly_transactions.savings_spend
        + monthly_transactions.emergency_fund_spend
        , 0
    ) as spent
    , round(coalesce(total_income, 0) + coalesce(spent, 0), 2) as difference
from combined.monthly_transactions as monthly_transactions
left join combined.monthly_paystubs as monthly_paystubs
    on
        monthly_transactions.budget_month = monthly_paystubs.pay_month
order by monthly_transactions.budget_month desc
