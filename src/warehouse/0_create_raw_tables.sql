create or replace table raw_category_groups as (
    select
        id
        , name
        , hidden
        , deleted
    from
        read_parquet(
            's3://$bucket_name/category-groups.parquet'
        )
);

create or replace table raw_monthly_categories as (
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
    from
        read_parquet(
            's3://$bucket_name/monthly-categories.parquet'
        )
);

create or replace table raw_transactions as (
    select
        id
        , date as transaction_date
        , amount / 1000 as amount
        , memo
        , cleared
        , approved
        , flag_color
        , account_id
        , payee_id
        , category_id
        , transfer_account_id
        , transfer_transaction_id
        , matched_transaction_id
        , import_id
        , import_payee_name
        , import_payee_name_original
        , debt_transaction_type
        , deleted
    from
        read_parquet(
            's3://$bucket_name/transactions.parquet'
        )
);

create or replace table raw_subtransactions as (
    select
        id
        , transaction_id
        , amount
        , memo
        , payee_id
        , category_id
        , transfer_account_id
        , deleted
    from
        read_parquet(
            's3://$bucket_name/subtransactions.parquet'
        )
);

create or replace table raw_paystubs as (
    select
        file_name
        , strptime(
            if(pay_period_start_date = '', null, pay_period_start_date)
            , '%m/%d/%Y'
        ) as pay_period_start_date
        , strptime(
            if(pay_period_end_date = '', null, pay_period_end_date), '%m/%d/%Y'
        ) as pay_period_end_date
        , strptime(if(pay_date = '', null, pay_date), '%m/%d/%Y') as pay_date
        , coalesce(round(try_cast(net_pay as float), 2), 0)
            as net_pay_on_sheet_calc
        , coalesce(round(try_cast(earnings_total as float), 2), 0)
            as earnings_total_on_sheet_calc
        , coalesce(round(try_cast(pre_tax_deductions as float), 2), 0)
            as pre_tax_deductions_on_sheet_calc
        , coalesce(round(try_cast(taxes as float), 2), 0) as taxes_on_sheet_calc
        , coalesce(round(try_cast(post_tax_deductions as float), 2), 0)
            as post_tax_deductions_on_sheet_calc
        , coalesce(round(try_cast(earnings_salary as float), 2), 0)
            as earnings_salary
        , coalesce(round(try_cast(earnings_bonus as float), 2), 0)
            as earnings_bonus
        , coalesce(round(try_cast(earnings_meal_allowance as float), 2), 0)
            as earnings_meal_allowance
        , coalesce(round(try_cast(earnings_pto_payout as float), 2), 0)
            as earnings_pto_payout
        , coalesce(round(try_cast(earnings_severance as float), 2), 0)
            as earnings_severance
        , coalesce(round(try_cast(earnings_misc as float), 2), 0)
            as earnings_misc
        , coalesce(
            round(try_cast(earnings_expense_reimbursement as float), 2), 0
        ) as earnings_expense_reimbursement
        , coalesce(round(try_cast(earnings_nyc_citi_bike as float), 2), 0)
            as earnings_nyc_citi_bike
        , coalesce(round(try_cast(pre_tax_401k as float), 2), 0) as pre_tax_401k
        , coalesce(round(try_cast(pre_tax_hsa as float), 2), 0) as pre_tax_hsa
        , coalesce(round(try_cast(pre_tax_fsa as float), 2), 0) as pre_tax_fsa
        , coalesce(round(try_cast(pre_tax_medical as float), 2), 0)
            as pre_tax_medical
        , coalesce(round(try_cast(taxes_medicare as float), 2), 0)
            as taxes_medicare
        , coalesce(round(try_cast(taxes_federal as float), 2), 0)
            as taxes_federal
        , coalesce(round(try_cast(taxes_state as float), 2), 0) as taxes_state
        , coalesce(round(try_cast(taxes_city as float), 2), 0) as taxes_city
        , coalesce(round(try_cast(taxes_nypfl as float), 2), 0) as taxes_nypfl
        , coalesce(round(try_cast(taxes_disability as float), 2), 0)
            as taxes_disability
        , coalesce(round(try_cast(taxes_social_security as float), 2), 0)
            as taxes_social_security
        , coalesce(
            round(try_cast(post_tax_meal_allowance_offset as float), 2), 0
        ) as post_tax_meal_allowance_offset
        , coalesce(round(try_cast(post_tax_roth as float), 2), 0)
            as post_tax_roth
        , coalesce(round(try_cast(post_tax_critical_illness as float), 2), 0)
            as post_tax_critical_illness
        , coalesce(round(try_cast(post_tax_ad_d as float), 2), 0)
            as post_tax_ad_d
        , coalesce(
            round(try_cast(post_tax_long_term_disability as float), 2), 0
        ) as post_tax_long_term_disability
        , coalesce(round(try_cast(post_tax_citi_bike as float), 2), 0)
            as post_tax_citi_bike
    from
        read_parquet(
            's3://$bucket_name/raw-paystubs.parquet'
        )
);
