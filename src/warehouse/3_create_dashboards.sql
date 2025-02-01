create or replace table monthly_level_dashboard as (
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
            coalesce(income_for_reimbursements, 0)
            + coalesce(net_pay, 0)
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
    from monthly_transactions
    left join monthly_paystubs
        on
            monthly_transactions.budget_month = monthly_paystubs.pay_month
    order by monthly_transactions.budget_month desc
);

create or replace table yearly_level_dashboard as (
    select
        date_trunc('year', monthly_level_dashboard.budget_month) as budget_year
        , sum(monthly_level_dashboard.earnings_actual) as earnings_actual
        , sum(monthly_level_dashboard.pre_tax_deductions) as pre_tax_deductions
        , sum(monthly_level_dashboard.taxes) as taxes
        , sum(monthly_level_dashboard.retirement_fund) as retirement_fund
        , sum(monthly_level_dashboard.hsa) as hsa
        , sum(monthly_level_dashboard.post_tax_deductions)
            as post_tax_deductions
        , sum(monthly_level_dashboard.total_deductions) as total_deductions
        , sum(monthly_level_dashboard.net_pay) as net_pay
        , sum(monthly_level_dashboard.income_for_reimbursements)
            as income_for_reimbursements
        , sum(monthly_level_dashboard.misc_income) as misc_income
        , sum(monthly_level_dashboard.total_income) as total_income
        , sum(monthly_level_dashboard.needs_spend) as needs_spend
        , sum(monthly_level_dashboard.wants_spend) as wants_spend
        , sum(monthly_level_dashboard.savings_spend) as savings_spend
        , sum(monthly_level_dashboard.emergency_fund_spend)
            as emergency_fund_spend
        , sum(monthly_level_dashboard.savings_saved) as savings_saved
        , sum(monthly_level_dashboard.emergency_fund_saved)
            as emergency_fund_saved
        , sum(monthly_level_dashboard.investments_saved) as investments_saved
        , sum(monthly_level_dashboard.emergency_fund_in_hsa)
            as emergency_fund_in_hsa
        , sum(monthly_level_dashboard.spent) as spent
        , sum(monthly_level_dashboard.difference) as difference
    from monthly_level_dashboard
    group by budget_year
    order by budget_year desc
);

create or replace table yearly_category_level_dashboard as (
    select
        category_name
        , category_group_name_mapping as category_group
        , date_trunc('year', budget_month) as budget_year
        , sum(activity) as spend
        , sum(budgeted) as assigned
    from monthly_level
    group by category_name, category_group_name_mapping, budget_year
    order by budget_year desc, category_group_name_mapping asc
);
