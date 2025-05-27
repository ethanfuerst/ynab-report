MODEL (
  name dashboards.monthly_level,
  kind FULL,
  grain budget_month
);

with monthly_transactions as (
    select
        date_trunc('month', transaction_date) as transaction_month
        , category_id
        , sum(if(category_group_name_mapping = 'Income', amount, 0)) as income
        , sum(if(category_name like '%HSA%', -1 * amount, 0)) as emergency_fund_in_hsa
        , sum(if(category_group_name_mapping = 'Needs', amount, 0)) as needs_spend
        , sum(if(category_group_name_mapping = 'Wants', amount, 0)) as wants_spend
        , sum(if(category_group_name_mapping = 'Savings', amount, 0)) as savings_spend
        , sum(if(category_group_name_mapping = 'Emergency Fund', amount, 0)) as emergency_fund_spend
    from combined.transactions
    group by
        1
        , 2
)

, monthly_budgeted as (
    select
        budget_month
        , category_id
        , sum(budgeted) as budgeted
        , sum(activity) as activity
        , sum(emergency_fund_assigned) as emergency_fund_assigned
        , sum(savings_assigned) as savings_assigned
        , sum(investments_assigned) as investments_assigned
        , sum(emergency_fund_balance) as emergency_fund_balance
        , sum(savings_balance) as savings_balance
        , sum(investments_balance) as investments_balance
        , sum(net_zero_balance) as net_zero_balance
    from combined.budgeted
    group by
        1
        , 2
)

, monthly_paystubs as (
    select
        date_trunc('month', pay_date) as pay_month
        , sum(earnings_actual) as earnings_actual
        , sum(salary) as salary
        , sum(bonus) as bonus
        , sum(pre_tax_deductions) as pre_tax_deductions
        , sum(retirement_fund) as retirement_fund
        , sum(hsa) as hsa
        , sum(taxes) as taxes
        , sum(post_tax_deductions) as post_tax_deductions
        , sum(deductions) as deductions
        , sum(net_pay) as net_pay
        , sum(income_for_reimbursements) as income_for_reimbursements
    from combined.paystubs
    group by 1
)

, monthly_transactions_and_budgeted as (
    select
        category_monthly_spine.budget_month
        , sum(monthly_transactions.income) as income
        , sum(monthly_transactions.needs_spend) as needs_spend
        , sum(monthly_transactions.wants_spend) as wants_spend
        , sum(monthly_transactions.savings_spend) as savings_spend
        , sum(monthly_transactions.emergency_fund_spend) as emergency_fund_spend
        , sum(monthly_budgeted.savings_assigned) as savings_assigned
        , sum(monthly_budgeted.emergency_fund_assigned) as emergency_fund_assigned
        , sum(monthly_budgeted.investments_assigned) as investments_assigned
        , sum(monthly_transactions.emergency_fund_in_hsa) as emergency_fund_in_hsa
        , sum(monthly_transactions.needs_spend + monthly_transactions.wants_spend + monthly_transactions.savings_spend + monthly_transactions.emergency_fund_spend) as spent
    from combined.record_spine as category_monthly_spine
    left join monthly_transactions
        on category_monthly_spine.category_id = monthly_transactions.category_id
        and category_monthly_spine.budget_month = monthly_transactions.transaction_month
    left join monthly_budgeted
        on category_monthly_spine.budget_month = monthly_budgeted.budget_month
        and category_monthly_spine.category_id = monthly_budgeted.category_id
    group by 1
)

select
    monthly_transactions.budget_month
    , coalesce(monthly_paystubs.earnings_actual, 0) as earnings_actual
    , coalesce(monthly_paystubs.salary, 0) as salary
    , coalesce(monthly_paystubs.bonus, 0) as bonus
    , coalesce(monthly_paystubs.pre_tax_deductions, 0) as pre_tax_deductions
    , coalesce(monthly_paystubs.taxes, 0) as taxes
    , coalesce(monthly_paystubs.retirement_fund, 0) as retirement_fund
    , coalesce(monthly_paystubs.hsa, 0) as hsa
    , coalesce(monthly_paystubs.post_tax_deductions, 0) as post_tax_deductions
    , coalesce(monthly_paystubs.deductions, 0) as total_deductions
    , coalesce(monthly_paystubs.net_pay, 0) as net_pay
    , coalesce(monthly_paystubs.income_for_reimbursements, 0) as income_for_reimbursements
    , coalesce(coalesce(monthly_transactions.income, 0) - coalesce(monthly_paystubs.net_pay, 0), 0) as misc_income
    , coalesce(coalesce(net_pay, 0) + coalesce(misc_income, 0), 0) as total_income
    , coalesce(monthly_transactions.needs_spend, 0) as needs_spend
    , coalesce(monthly_transactions.wants_spend, 0) as wants_spend
    , coalesce(monthly_transactions.savings_spend, 0) as savings_spend
    , coalesce(monthly_transactions.emergency_fund_spend, 0) as emergency_fund_spend
    , coalesce(monthly_transactions.savings_assigned, 0) as savings_saved
    , coalesce(monthly_transactions.emergency_fund_assigned, 0) as emergency_fund_saved
    , coalesce(monthly_transactions.investments_assigned, 0) as investments_saved
    , coalesce(monthly_transactions.emergency_fund_in_hsa, 0) as emergency_fund_in_hsa
    , coalesce(needs_spend + wants_spend + savings_spend + emergency_fund_spend, 0) as spent
    , round(coalesce(total_income, 0) + coalesce(spent, 0), 2) as difference
from monthly_transactions_and_budgeted as monthly_transactions
left join monthly_paystubs
    on monthly_transactions.budget_month = monthly_paystubs.pay_month
order by monthly_transactions.budget_month desc
