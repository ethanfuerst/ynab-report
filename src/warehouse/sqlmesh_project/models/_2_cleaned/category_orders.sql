MODEL (
  name cleaned.category_orders,
  kind FULL,
  grain id
);

select
    row_number() over () as id
    , needs
    , wants
    , other
    , category_groups
    , paycheck
from raw.category_orders
