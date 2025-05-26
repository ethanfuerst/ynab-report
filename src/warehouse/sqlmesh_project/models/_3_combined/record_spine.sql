MODEL (
  name combined.record_spine,
  kind FULL,
  grain (budget_month, category_id)
);

select
    months.generate_series as budget_month
    , categories.id as category_id
    , categories.name as category_name
    , category_groups.category_group_name_mapping
from
    generate_series(
        (select min(date_trunc('month', transaction_date)) from cleaned.transactions)::date
        , current_date::date
        , interval '1 month'
    ) as months
cross join cleaned.categories as categories
left join cleaned.category_groups as category_groups
    on categories.category_group_id = category_groups.id
