MODEL (
  name combined.monthly_category_groups,
  kind FULL,
  grain (budget_month, category_id)
);

select
    monthly_categories.budget_month
    , monthly_categories.id as category_id
    , category_groups.category_group_name_mapping
    , monthly_categories.budgeted
    , monthly_categories.balance
    , monthly_categories.activity
from cleaned.monthly_categories as monthly_categories
left join cleaned.category_groups as category_groups
    on monthly_categories.category_group_id = category_groups.id
