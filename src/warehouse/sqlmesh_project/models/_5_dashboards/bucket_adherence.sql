MODEL (
  name dashboards.bucket_adherence,
  kind FULL,
  grain (year, bucket),
  audits (
    not_null(columns := (year, bucket)),
    unique_combination_of_columns(columns := (year, bucket))
  ),
  description 'Tab 2 (ETH-472): bucket adherence, one row per (year, bucket). Unions Needs/Wants (core.yearly_bucket_adherence) + Savings (core.yearly_savings_adherence). on_plan_flag already encodes polarity (Needs/Wants less-is-good, Savings more-is-good).'
);

with needs_wants as (
    select year, bucket, target, projected, overage_pct, on_plan_flag, is_extrapolated
    from core.yearly_bucket_adherence
)

, savings as (
    select year, bucket, target, projected, overage_pct, on_plan_flag, is_extrapolated
    from core.yearly_savings_adherence
)

, unioned as (
    select * from needs_wants
    union all select * from savings
)

select
    year
    , bucket
    , target
    , projected
    , overage_pct
    , on_plan_flag
    , is_extrapolated
from unioned
order by
    year desc
    , case bucket when 'Needs' then 1 when 'Wants' then 2
                  when 'Savings' then 3 else 4 end
