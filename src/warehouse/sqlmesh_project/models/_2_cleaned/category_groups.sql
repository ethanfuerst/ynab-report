MODEL (
  name cleaned.category_groups,
  kind FULL,
  grain id
);

select
    id
    , name
    , case
        when name like 'Needs%'
            then 'Needs'
        when name like 'Wants%'
            then 'Wants'
        when name = 'Internal Master Category'
            then 'Income'
        else name
    end as category_group_name_mapping
    , split(name, ' - ')[2] as subcategory_group_name
from raw.category_groups
