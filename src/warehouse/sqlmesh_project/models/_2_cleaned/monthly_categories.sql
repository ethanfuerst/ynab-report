MODEL (
  name cleaned.monthly_categories,
  kind FULL,
  grain id
);

select
    id
    , category_group_id
    , name
    , make_date(year, month, 1) as budget_month
    , budgeted / 1000 as budgeted
    , balance / 1000 as balance
    , activity / 1000 as activity
from raw.monthly_categories
