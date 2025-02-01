create or replace table category_groups as (
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
    from raw_category_groups
);

create or replace table monthly_categories as (
    select
        id
        , category_group_id
        , name
        , make_date(year, month, 1) as budget_month
        , budgeted / 1000 as budgeted
        , balance / 1000 as balance
        , activity / 1000 as activity
    from raw_monthly_categories
);

create or replace table categories as (
    select
        id
        , category_group_id
        , name
        , hidden as is_hidden
    from raw_monthly_categories
    qualify
        row_number() over (
            partition by id
            order by month desc, year desc
        ) = 1
);

create or replace table transactions as (
    select
        id
        , category_id
        , transaction_date
        , amount
        , memo
        , import_payee_name as payee_name
        , flag_color
    from raw_transactions
    where category_id is not null
);

create or replace table subtransactions as (
    select
        id
        , transaction_id
        , category_id
        , amount / 1000 as amount
        , memo
    from raw_subtransactions
);

create or replace table paystubs as (
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
    from raw_paystubs
);
