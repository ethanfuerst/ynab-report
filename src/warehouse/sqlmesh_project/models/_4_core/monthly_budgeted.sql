MODEL (
  name core.monthly_budgeted,
  kind FULL,
  grain budget_month,
  description 'Monthly-grain rollup of combined.monthly_budgeted. Saved columns are positive USD amounts; dashboard signs are applied only in the dashboard layer.'
);

select
    budget_month  -- First day of the budget month
    , sum(savings_saved) as savings_saved  -- Amount assigned to Savings categories, positive USD
    , sum(emergency_fund_saved) as emergency_fund_saved  -- Amount assigned to Emergency Fund categories, positive USD
    , sum(investments_saved) as investments_saved  -- Amount assigned to Investments categories, positive USD
    , sum(savings_balance) as savings_balance  -- Savings category balance, USD
    , sum(emergency_fund_balance) as emergency_fund_balance  -- Emergency Fund category balance, USD
    , sum(investments_balance) as investments_balance  -- Investments category balance, USD
    , sum(net_zero_balance) as net_zero_balance  -- Net Zero Expenses category balance, USD
from combined.monthly_budgeted
group by 1
order by budget_month desc
