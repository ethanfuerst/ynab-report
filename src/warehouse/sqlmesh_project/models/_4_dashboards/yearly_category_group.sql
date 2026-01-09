MODEL (
  name dashboards.yearly_category_group,
  kind FULL,
  grain (category_group_name_mapping, budget_year)
);

select
    category_group_name_mapping
    , budget_year
    , min(order_id) as order_id
    , sum(spend) as spend
    , sum(assigned) as assigned
from combined.yearly_budgeted
group by 1, 2
order by 2, 3
