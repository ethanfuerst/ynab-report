MODEL (
  name cleaned.category_groups,
  kind FULL,
  grain id
);

select
    id
    , name
    , split(name, ' - ')[2] as subcategory_group_name
    , split(name, ' - ')[1] as category_group_name_mapping
from raw.category_groups
