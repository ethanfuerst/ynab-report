MODEL (
  name combined.monthly_transactions,
  kind FULL,
  grain budget_month
);

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
from combined.monthly_level
group by budget_month
order by budget_month desc
