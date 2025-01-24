create or replace table monthly_level_dashboard as (
    select
        budget_month
        , sum(income) as income
        , sum(needs_spend) as needs_spend
        , sum(wants_spend) as wants_spend
        , sum(savings_spend) as savings_spend
        , sum(emergency_fund_spend) as emergency_fund_spend
        , sum(savings_assigned) as savings_assigned
        , sum(emergency_fund_assigned) as emergency_fund_assigned
        , sum(investments_assigned) as investments_assigned
        , sum(emergency_fund_in_hsa) as emergency_fund_in_hsa
        , sum(needs_spend + wants_spend + savings_spend + emergency_fund_spend)
            as spent
        , round(sum(income) + spent, 2) as difference
    from monthly_level
    group by budget_month
    order by budget_month desc
);

create or replace table yearly_level_dashboard as (
    select
        date_trunc('year', budget_month) as budget_year
        , sum(income) as income
        , sum(needs_spend) as needs_spend
        , sum(wants_spend) as wants_spend
        , sum(savings_spend) as savings_spend
        , sum(emergency_fund_spend) as emergency_fund_spend
        , sum(savings_assigned) as savings_assigned
        , sum(emergency_fund_assigned) as emergency_fund_assigned
        , sum(investments_assigned) as investments_assigned
        , sum(emergency_fund_in_hsa) as emergency_fund_in_hsa
        , sum(needs_spend + wants_spend + savings_spend + emergency_fund_spend)
            as spent
        , round(sum(income) + spent, 2) as difference
    from monthly_level
    group by budget_year
    order by budget_year desc
);

create or replace table category_level_dashboard as (
    with pre_ordered as (
        select
            category_name
            , category_group_name_mapping
            , budget_month
            , activity as spend
            , budgeted as assigned
        from monthly_level
        where category_group_name_mapping != 'Emergency Fund'

        union all

        select
            category_name
            , category_group_name_mapping
            , budget_month
            , activity + emergency_fund_in_hsa as spend
            , budgeted as assigned
        from monthly_level
        where category_group_name_mapping = 'Emergency Fund'

        union all

        select
            'HSA amount for reimbursement' as category_name
            , category_group_name_mapping
            , budget_month
            , -1 * emergency_fund_in_hsa as spend
            , null as assigned
        from monthly_level
        where category_group_name_mapping = 'Emergency Fund'
    )

    select
        category_name
        , category_group_name_mapping
        , budget_month
        , spend
        , assigned
    from pre_ordered
    order by budget_month desc, category_group_name_mapping asc
);
