MODEL (
  name cleaned.paystubs,
  kind FULL,
  grain (file_name, pay_period_start_date)
);

with cleaned_paystubs_int as (
    select
        file_name
        , employer
        , @try_strip_date(pay_period_start_date) as pay_period_start_date
        , @try_strip_date(pay_period_end_date) as pay_period_end_date
        , @try_strip_date(pay_date) as pay_date
        , @try_cast_to_float(net_pay) as net_pay_on_sheet_calc
        , @try_cast_to_float(earnings_total) as earnings_total_on_sheet_calc
        , @try_cast_to_float(pre_tax_deductions) as pre_tax_deductions_on_sheet_calc
        , @try_cast_to_float(taxes) as taxes_on_sheet_calc
        , @try_cast_to_float(post_tax_deductions) as post_tax_deductions_on_sheet_calc
        , @try_cast_to_float(earnings_salary) as earnings_salary
        , @try_cast_to_float(earnings_bonus) as earnings_bonus
        , @try_cast_to_float(earnings_meal_allowance) as earnings_meal_allowance
        , @try_cast_to_float(earnings_pto_payout) as earnings_pto_payout
        , @try_cast_to_float(earnings_severance) as earnings_severance
        , @try_cast_to_float(earnings_misc) as earnings_misc
        , @try_cast_to_float(earnings_expense_reimbursement) as earnings_expense_reimbursement
        , @try_cast_to_float(earnings_nyc_citi_bike) as earnings_nyc_citi_bike
        , @try_cast_to_float(pre_tax_401k) as pre_tax_401k
        , @try_cast_to_float(pre_tax_hsa) as pre_tax_hsa
        , @try_cast_to_float(pre_tax_fsa) as pre_tax_fsa
        , @try_cast_to_float(pre_tax_medical) as pre_tax_medical
        , @try_cast_to_float(taxes_medicare) as taxes_medicare
        , @try_cast_to_float(taxes_federal) as taxes_federal
        , @try_cast_to_float(taxes_state) as taxes_state
        , @try_cast_to_float(taxes_city) as taxes_city
        , @try_cast_to_float(taxes_nypfl) as taxes_nypfl
        , @try_cast_to_float(taxes_disability) as taxes_disability
        , @try_cast_to_float(taxes_social_security) as taxes_social_security
        , @try_cast_to_float(post_tax_meal_allowance_offset) as post_tax_meal_allowance_offset
        , @try_cast_to_float(post_tax_roth) as post_tax_roth
        , @try_cast_to_float(post_tax_critical_illness) as post_tax_critical_illness
        , @try_cast_to_float(post_tax_ad_d) as post_tax_ad_d
        , @try_cast_to_float(post_tax_long_term_disability) as post_tax_long_term_disability
        , @try_cast_to_float(post_tax_citi_bike) as post_tax_citi_bike
    from raw.paystubs
)

select
    pay_date
    , employer
    , round(
        earnings_salary
        + earnings_bonus
        + earnings_pto_payout
        + earnings_severance
        , 2
    ) as earnings_actual
    , round(earnings_salary, 2) as salary
    , round(earnings_bonus + earnings_pto_payout + earnings_severance, 2) as bonus
    , -1 * round(pre_tax_fsa + pre_tax_medical, 2) as pre_tax_deductions
    , -1 * round(post_tax_roth + pre_tax_401k, 2) as retirement_fund
    , -1 * round(pre_tax_hsa, 2) as hsa
    , -1 * round(
        taxes_medicare
        + taxes_federal
        + taxes_state
        + taxes_city
        + taxes_nypfl
        + taxes_disability
        + taxes_social_security
        , 2
    ) as taxes
    , -1 * round(
        post_tax_critical_illness
        + post_tax_ad_d
        + post_tax_long_term_disability
        , 2
    ) as post_tax_deductions
    , round(
        pre_tax_deductions
        + retirement_fund
        + hsa
        + taxes
        + post_tax_deductions
        , 2
    ) as deductions
    , round(earnings_expense_reimbursement, 2) as income_for_reimbursements
from cleaned_paystubs_int
order by pay_date desc
