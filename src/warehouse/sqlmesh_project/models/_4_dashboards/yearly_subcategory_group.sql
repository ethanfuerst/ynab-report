MODEL (
  name dashboards.yearly_subcategory_group,
  kind FULL,
  grain (subcategory_group, budget_year)
);

select
    subcategory_group
    , budget_year
    , min(order_id) as order_id
    , sum(spend) as spend
    , sum(assigned) as assigned
from combined.yearly_budgeted
where subcategory_group is not null
group by subcategory_group, budget_year
order by budget_year, order_id
