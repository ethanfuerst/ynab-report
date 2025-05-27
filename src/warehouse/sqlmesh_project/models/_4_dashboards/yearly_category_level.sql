MODEL (
  name dashboards.yearly_category_level,
  kind FULL,
  grain (budget_year, category_name)
);

with category_level as (
    select
        category_name
        , category_group_name_mapping as category_group
        , date_trunc('year', budget_month) as budget_year
        , sum(activity) as spend
        , sum(budgeted) as assigned
    from combined.budgeted
    group by
        1
        , 2
        , 3
)

, pre_un_pivot as (
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
    from dashboards.yearly_level
)

, yearly_paychecks_pivot as (
    select budget_year, 'earnings_actual' as column_name, earnings_actual as amount from pre_un_pivot
    union all
    select budget_year, 'salary', salary from pre_un_pivot
    union all
    select budget_year, 'bonus', bonus from pre_un_pivot
    union all
    select budget_year, 'pre_tax_deductions', pre_tax_deductions from pre_un_pivot
    union all
    select budget_year, 'taxes', taxes from pre_un_pivot
    union all
    select budget_year, 'retirement_fund', retirement_fund from pre_un_pivot
    union all
    select budget_year, 'hsa', hsa from pre_un_pivot
    union all
    select budget_year, 'post_tax_deductions', post_tax_deductions from pre_un_pivot
    union all
    select budget_year, 'total_deductions', total_deductions from pre_un_pivot
    union all
    select budget_year, 'net_pay', net_pay from pre_un_pivot
    union all
    select budget_year, 'income_for_reimbursements', income_for_reimbursements from pre_un_pivot
    union all
    select budget_year, 'misc_income', misc_income from pre_un_pivot
    union all
    select budget_year, 'total_income', total_income from pre_un_pivot
)

, paycheck_level as (
    select
        budget_year
        , column_name as paycheck_col
        , amount as paycheck_value
    from yearly_paychecks_pivot
)

select
    category_name
    , category_group
    , budget_year
    , spend
    , assigned
    , null as paycheck_col
    , null as paycheck_value
from category_level

union all

select
    null as category_name
    , null as category_group
    , budget_year
    , null as spend
    , null as assigned
    , paycheck_col
    , paycheck_value
from paycheck_level

union all

select
    null as category_name
    , null as category_group
    , budget_year
    , null as spend
    , null as assigned
    , 'total_spend' as paycheck_col
    , spent as paycheck_value
from dashboards.yearly_level

union all

select
    null as category_name
    , null as category_group
    , budget_year
    , null as spend
    , null as assigned
    , 'net_income' as paycheck_col
    , difference as paycheck_value
from dashboards.yearly_level
