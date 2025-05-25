MODEL (
  name dashboards.yearly_paychecks,
  kind FULL,
  grain (budget_year, column_name)
);

with pre_un_pivot as (
    select
        budget_year
        , earnings_actual
        , pre_tax_deductions
        , taxes
        , retirement_fund
        , hsa
        , post_tax_deductions
        , total_deductions
        , net_pay
        , income_for_reimbursements
        , misc_income
        , total_income
    from dashboards.yearly_level
)

select budget_year, 'earnings_actual' as column_name, earnings_actual as amount from pre_un_pivot
union all
select budget_year, 'pre_tax_deductions', pre_tax_deductions from pre_un_pivot
union all
select budget_year, 'taxes', taxes from pre_un_pivot
union all
select budget_year, 'retirement_fund', retirement_fund from pre_un_pivot
union all
select budget_year, 'hsa', hsa from pre_un_pivot
union all
select budget_year, 'post_tax_deductions', post_tax_deductions from pre_un_pivot
union all
select budget_year, 'total_deductions', total_deductions from pre_un_pivot
union all
select budget_year, 'net_pay', net_pay from pre_un_pivot
union all
select budget_year, 'income_for_reimbursements', income_for_reimbursements from pre_un_pivot
union all
select budget_year, 'misc_income', misc_income from pre_un_pivot
union all
select budget_year, 'total_income', total_income from pre_un_pivot
