MODEL (
  name raw.monthly_categories,
  kind FULL,
  grain id
);

select
    id
    , category_group_id
    , name
    , hidden
    , original_category_group_id
    , note
    , budgeted
    , activity
    , balance
    , goal_type
    , goal_needs_whole_amount
    , goal_day
    , goal_cadence
    , goal_cadence_frequency
    , goal_creation_month
    , goal_target
    , goal_target_month
    , goal_percentage_complete
    , goal_months_to_budget
    , goal_under_funded
    , goal_overall_funded
    , goal_overall_left
    , deleted
    , month
    , year
from @get_s3_parquet_path('monthly-categories')
