MODEL (
  name dashboards.yearly_paychecks,
  kind FULL,
  grain (budget_year, paycheck_column)
);

with base as (
    select
        budget_year
        , earnings_actual
        , salary
        , bonus
        , pre_tax_deductions
        , taxes
        , retirement_fund
        , hsa
        , post_tax_deductions
        , total_deductions
        , net_pay
        , income_for_reimbursements
        , misc_income
        , total_income
        , spent
        , difference
    from dashboards.yearly_level
)

, yearly_paychecks as (
    select
        budget_year
        , unnest([
            'Pre-Tax Earnings'
            , 'Salary'
            , 'Bonus'
            , 'Pre-Tax Deductions'
            , 'Taxes'
            , 'Retirement Fund Contribution'
            , 'HSA Contribution'
            , 'Post-Tax Deductions'
            , 'Total Deductions'
            , 'Net Pay'
            , 'Reimbursed Income'
            , 'Miscellaneous Income'
            , 'Total Income (Net to Account)'
            , 'Total Spend'
            , 'Net Income'
        ]) as paycheck_column
        , unnest([
            earnings_actual
            , salary
            , bonus
            , pre_tax_deductions
            , taxes
            , retirement_fund
            , hsa
            , post_tax_deductions
            , total_deductions
            , net_pay
            , income_for_reimbursements
            , misc_income
            , total_income
            , spent
            , difference
        ]) as paycheck_value
    from base
)

, orders as (
    select
        category_name
        , order_id
    from cleaned.category_orders
    where category_group = 'Paycheck'
)

select
    yearly_paychecks.budget_year
    , yearly_paychecks.paycheck_column
    , yearly_paychecks.paycheck_value
    , orders.order_id
from yearly_paychecks
left join orders
    on yearly_paychecks.paycheck_column = orders.category_name
order by yearly_paychecks.budget_year, orders.order_id
