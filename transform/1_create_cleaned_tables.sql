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
        , epoch_ms(date) as transation_date
        , amount / 1000 as amount
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
