MODEL (
  name cleaned.paystubs,
  kind FULL,
  grain (file_name, pay_period_start_date)
);

select
    pay_date
    , round(
        earnings_salary
        + earnings_bonus
        + earnings_pto_payout
        + earnings_severance
        , 2
    ) as earnings_actual
    , -1 * round(pre_tax_fsa + pre_tax_medical, 2) as pre_tax_deductions
    , -1 * round(post_tax_roth + pre_tax_401k, 2) as retirement_fund
    , -1 * round(pre_tax_hsa, 2) as hsa
    , -1
    * round(
        taxes_medicare
        + taxes_federal
        + taxes_state
        + taxes_city
        + taxes_nypfl
        + taxes_disability
        + taxes_social_security
        , 2
    ) as taxes
    , -1
    * round(
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
from raw.paystubs
