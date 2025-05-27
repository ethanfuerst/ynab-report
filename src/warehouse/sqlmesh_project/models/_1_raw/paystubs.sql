MODEL (
  name raw.paystubs,
  kind FULL,
  grain (file_name, pay_period_start_date)
);

select
    file_name
    , employer
    , pay_period_start_date
    , pay_period_end_date
    , pay_date
    , net_pay
    , earnings_total
    , pre_tax_deductions
    , taxes
    , post_tax_deductions
    , earnings_salary
    , earnings_bonus
    , earnings_meal_allowance
    , earnings_pto_payout
    , earnings_severance
    , earnings_misc
    , earnings_expense_reimbursement
    , earnings_nyc_citi_bike
    , pre_tax_401k
    , pre_tax_hsa
    , pre_tax_fsa
    , pre_tax_medical
    , taxes_medicare
    , taxes_federal
    , taxes_state
    , taxes_city
    , taxes_nypfl
    , taxes_disability
    , taxes_social_security
    , post_tax_meal_allowance_offset
    , post_tax_roth
    , post_tax_critical_illness
    , post_tax_ad_d
    , post_tax_long_term_disability
    , post_tax_citi_bike
from @get_s3_parquet_path('raw-paystubs')
