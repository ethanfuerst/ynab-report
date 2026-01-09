MODEL (
  name combined.yearly_budgeted,
  kind FULL,
  grain (order_id, budget_year)
);

with order_spine as (
    select
        category_group
        , subcategory_group
        , category_name
        , order_id
    from cleaned.category_orders
)

, aggs as (
    select
        year(budget_month) as budget_year
        , category_group_name_mapping
        , subcategory_group_name as subcategory_group
        , category_name
        , sum(activity) as spend
        , sum(budgeted) as assigned
    from combined.budgeted
    where budget_year <= (select max(budget_year) from dashboards.yearly_level)
    and category_group_name_mapping not in ('Credit Card Payments', 'Income')
    group by
        1
        , 2
        , 3
        , 4
)

select
    order_spine.order_id
    , aggs.budget_year
    , order_spine.category_group
    , aggs.category_group_name_mapping
    , aggs.subcategory_group
    , aggs.category_name
    , aggs.spend
    , aggs.assigned
from aggs
left join order_spine
  on aggs.category_name = order_spine.category_name
order by aggs.budget_year, order_spine.order_id
