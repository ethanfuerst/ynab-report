create or replace table raw_category_groups as (
    select
        id
        , name
        , hidden
        , deleted
        , filename
        , month
        , year
    from
        read_parquet(
            's3://$bucket_name/category-groups/**/*.parquet', filename = true
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
        , filename
        , month
        , year
    from
        read_parquet(
            's3://$bucket_name/monthly-categories/**/*.parquet', filename = true
        )
);

create or replace table raw_transactions as (
    select
        id
        , date
        , amount
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
        , filename
        , month
        , year
    from
        read_parquet(
            's3://$bucket_name/transactions/**/*.parquet', filename = true
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
        , filename
        , month
        , year
    from
        read_parquet(
            's3://$bucket_name/subtransactions/**/*.parquet', filename = true
        )
);
