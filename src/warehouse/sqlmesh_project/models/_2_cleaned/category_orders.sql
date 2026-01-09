MODEL (
  name cleaned.category_orders,
  kind FULL,
  grain order_id
);

select
    id as order_id
    , category_group
    , subcategory_group
    , category_name
from raw.category_orders
order by order_id
