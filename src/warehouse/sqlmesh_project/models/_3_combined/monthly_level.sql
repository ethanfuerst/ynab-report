MODEL (
  name combined.monthly_level,
  kind FULL,
  grain (budget_month, category_id)
);

with all_transactions as (
    select
        transactions.id
        , coalesce(subtransactions.category_id, transactions.category_id)
            as category_id
        , coalesce(subtransactions.amount, transactions.amount) as amount
        , coalesce(subtransactions.memo, transactions.memo) as memo
        , subtransactions.id as subtransaction_id
        , transactions.transaction_date
        , date_trunc('month', transactions.transaction_date)
            as transaction_month
    from cleaned.transactions as transactions
    left outer join cleaned.sub_transactions as subtransactions
        on transactions.id = subtransactions.transaction_id
)

, transactions_with_categories as (
    select
        all_transactions.id
        , all_transactions.category_id
        , categories.name as category_name
        , category_groups.category_group_name_mapping
        , all_transactions.amount
        , all_transactions.memo
        , all_transactions.transaction_date
        , all_transactions.transaction_month
    from all_transactions
    left join cleaned.categories as categories
        on all_transactions.category_id = categories.id
    left join cleaned.category_groups as category_groups
        on categories.category_group_id = category_groups.id
)

, monthly_transactions as (
    select
        transaction_month
        , category_id
        , round(
            sum(
                case
                    when
                        category_group_name_mapping = 'Income'
                        then amount
                    else 0
                end
            )
            , 2
        ) as income
        , round(
            sum(
                case
                    when
                        category_name like '%HSA%'
                        then -1 * amount
                    else 0
                end
            )
            , 2
        ) as emergency_fund_in_hsa
        , round(
            sum(
                case
                    when
                        category_group_name_mapping = 'Needs'
                        then amount
                    else 0
                end
            )
            , 2
        ) as needs_spend
        , round(
            sum(
                case
                    when
                        category_group_name_mapping = 'Wants'
                        then amount
                    else 0
                end
            )
            , 2
        ) as wants_spend
        , round(
            sum(
                case
                    when
                        category_group_name_mapping = 'Savings'
                        then amount
                    else 0
                end
            )
            , 2
        ) as savings_spend
        , round(
            sum(
                case
                    when
                        category_group_name_mapping = 'Emergency Fund'
                        and memo not like '%(to be reimbursed by HSA)%'
                        then amount
                    else 0
                end
            )
            , 2
        ) as emergency_fund_spend
    from transactions_with_categories
    group by
        transaction_month
        , category_id
)

, monthly_budgeted as (
    select
        budget_month
        , category_id
        , sum(budgeted) as budgeted
        , sum(activity) as activity
        , sum(
            case
                when
                    category_group_name_mapping = 'Emergency Fund'
                    then budgeted
                else 0
            end
        ) as emergency_fund_assigned
        , sum(
            case
                when
                    category_group_name_mapping = 'Savings'
                    then budgeted
                else 0
            end
        ) as savings_assigned
        , sum(
            case
                when
                    category_group_name_mapping = 'Investments'
                    then budgeted
                else 0
            end
        ) as investments_assigned
        , sum(
            case
                when
                    category_group_name_mapping = 'Emergency Fund'
                    then balance
                else 0
            end
        ) as emergency_fund_balance
        , sum(
            case
                when
                    category_group_name_mapping = 'Savings'
                    then balance
                else 0
            end
        ) as savings_balance
        , sum(
            case
                when
                    category_group_name_mapping = 'Investments'
                    then balance
                else 0
            end
        ) as investments_balance
        , sum(
            case
                when
                    category_group_name_mapping = 'Net Zero Expenses'
                    then balance
                else 0
            end
        ) as net_zero_balance
    from combined.monthly_category_groups as final_monthly_category_groups
    group by
        budget_month
        , category_id
)

, category_monthly_spine as (
    select
        months.generate_series as budget_month
        , categories.id as category_id
        , categories.name as category_name
        , category_groups.category_group_name_mapping
    from
        generate_series(
            (
                select
                    min(
                        date_trunc(
                            'month', transactions.transaction_date
                        )
                    )
                from cleaned.transactions as transactions
            )::date
            , current_date::date
            , interval '1 month'
        ) as months
    cross join cleaned.categories as categories
    left join cleaned.category_groups as category_groups
        on categories.category_group_id = category_groups.id
)

select
    category_monthly_spine.budget_month
    , category_monthly_spine.category_id
    , category_monthly_spine.category_name
    , category_monthly_spine.category_group_name_mapping
    , coalesce(monthly_transactions.income, 0) as income
    , coalesce(monthly_transactions.emergency_fund_in_hsa, 0)
        as emergency_fund_in_hsa
    , coalesce(monthly_transactions.needs_spend, 0) as needs_spend
    , coalesce(monthly_transactions.wants_spend, 0) as wants_spend
    , coalesce(monthly_transactions.savings_spend, 0) as savings_spend
    , coalesce(monthly_transactions.emergency_fund_spend, 0)
        as emergency_fund_spend
    , coalesce(monthly_budgeted.budgeted, 0) as budgeted
    , coalesce(monthly_budgeted.activity, 0) as activity
    , coalesce(monthly_budgeted.emergency_fund_assigned, 0)
        as emergency_fund_assigned
    , coalesce(monthly_budgeted.savings_assigned, 0) as savings_assigned
    , coalesce(monthly_budgeted.investments_assigned, 0)
        as investments_assigned
    , coalesce(monthly_budgeted.emergency_fund_balance, 0)
        as emergency_fund_balance
    , coalesce(monthly_budgeted.savings_balance, 0) as savings_balance
    , coalesce(monthly_budgeted.investments_balance, 0)
        as investments_balance
    , coalesce(monthly_budgeted.net_zero_balance, 0) as net_zero_balance
from category_monthly_spine
left join monthly_transactions
    on
        category_monthly_spine.category_id
        = monthly_transactions.category_id
        and category_monthly_spine.budget_month
        = monthly_transactions.transaction_month
left join monthly_budgeted
    on
        category_monthly_spine.budget_month = monthly_budgeted.budget_month
        and category_monthly_spine.category_id
        = monthly_budgeted.category_id
order by
    category_monthly_spine.budget_month desc
    , category_monthly_spine.category_id desc
