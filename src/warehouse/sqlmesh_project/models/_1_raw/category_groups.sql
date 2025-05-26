MODEL (
  name raw.category_groups,
  kind FULL,
  grain id
);

select
    id
    , name
    , hidden
    , deleted
from @get_s3_parquet_path('category-groups')
