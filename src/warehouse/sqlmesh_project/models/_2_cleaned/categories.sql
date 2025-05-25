MODEL (
  name cleaned.categories,
  kind FULL,
  grain id
);

select
    id
    , category_group_id
    , name
    , hidden as is_hidden
from raw.monthly_categories
qualify row_number() over (partition by id order by month desc, year desc) = 1
