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
    from combined.monthly_level
    group by category_name, category_group_name_mapping, budget_year
)

, paycheck_level as (
    select
        budget_year
        , column_name as paycheck_col
        , amount as paycheck_value
    from dashboards.yearly_paychecks as yearly_paycheck_data
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
