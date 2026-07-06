MODEL (
  name combined.monthly_budgeted,
  kind FULL,
  grain (budget_month, category_id),
  description 'Monthly budget category facts with positive saved/spend fields. Dashboard signs are applied only in the dashboard layer.'
);

select
    monthly_categories.id as category_id
    , category_groups.id as category_group_id
    , monthly_categories.budget_month
    , monthly_categories.category_name
    , category_groups.name as category_group_name
    , category_groups.subcategory_group_name
    , category_groups.category_group_name_mapping
    , monthly_categories.assigned_usd as assigned
    , monthly_categories.activity_inflow_usd as activity_inflow
    , monthly_categories.activity_outflow_usd as activity_outflow
    , monthly_categories.activity_outflow_usd - monthly_categories.activity_inflow_usd as net_spend
    , monthly_categories.balance_usd as balance
    , if(category_groups.category_group_name_mapping = 'Emergency Fund', monthly_categories.assigned_usd, 0) as emergency_fund_saved
    , if(category_groups.category_group_name_mapping = 'Savings', monthly_categories.assigned_usd, 0) as savings_saved
    , if(category_groups.category_group_name_mapping = 'Investments', monthly_categories.assigned_usd, 0) as investments_saved
    , if(category_groups.category_group_name_mapping = 'Emergency Fund', monthly_categories.balance_usd, 0) as emergency_fund_balance
    , if(category_groups.category_group_name_mapping = 'Savings', monthly_categories.balance_usd, 0) as savings_balance
    , if(category_groups.category_group_name_mapping = 'Investments', monthly_categories.balance_usd, 0) as investments_balance
    , if(category_groups.category_group_name_mapping = 'Net Zero Expenses', monthly_categories.balance_usd, 0) as net_zero_balance
from cleaned.monthly_categories as monthly_categories
left join cleaned.category_groups as category_groups
    on monthly_categories.category_group_id = category_groups.id
order by
  budget_month desc
  , category_id desc
