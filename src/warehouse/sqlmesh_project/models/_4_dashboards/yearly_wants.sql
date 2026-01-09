MODEL (
  name dashboards.yearly_wants,
  kind FULL,
  grain (category_name, budget_year)
);

select
    order_id
    , category_name
    , budget_year
    , category_group
    , category_group_name_mapping
    , subcategory_group
    , assigned
    , spend
from combined.yearly_budgeted
where category_group = 'Wants'
order by budget_year, order_id
