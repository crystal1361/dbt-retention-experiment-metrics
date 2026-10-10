-- The churn definition lives here, and only here.
--
--   active   = holds an open checking account at month end AND made a
--              customer-initiated transaction within the trailing
--              `dormancy_days` days (days_since_last_txn < dormancy_days)
--   churned  = active at the end of the prior month, not active at the end
--              of this month
--
-- Unit tests in _int__models.yml pin the 89-vs-90-day boundary.

with spine as (
    select * from {{ ref('int_customer_month_spine') }}
),

activity as (
    select * from {{ ref('int_customer_monthly_activity') }}
),

joined as (
    select
        s.customer_id,
        s.month_start,
        s.month_end,
        s.has_open_checking,
        coalesce(a.customer_txn_count, 0)    as customer_txn_count,
        coalesce(a.deposit_amount, 0)        as deposit_amount,
        coalesce(a.spend_amount, 0)          as spend_amount,
        coalesce(a.has_direct_deposit, false) as has_direct_deposit,
        a.last_txn_date_in_month
    from spine as s
    left join activity as a
        on  a.customer_id = s.customer_id
        and a.activity_month = s.month_start
),

with_recency as (
    select
        *,
        -- max() ignores nulls, so this carries the last activity date forward
        max(last_txn_date_in_month) over (
            partition by customer_id
            order by month_start
            rows between unbounded preceding and current row
        ) as last_txn_date
    from joined
),

with_status as (
    select
        *,
        date_diff('day', last_txn_date, month_end) as days_since_last_txn,
        coalesce(
            has_open_checking
            and date_diff('day', last_txn_date, month_end) < {{ var('dormancy_days') }},
            false
        ) as is_active
    from with_recency
)

select
    customer_id,
    month_start,
    month_end,
    has_open_checking,
    customer_txn_count,
    deposit_amount,
    spend_amount,
    has_direct_deposit,
    last_txn_date,
    days_since_last_txn,
    is_active,
    coalesce(
        lag(is_active) over (partition by customer_id order by month_start),
        false
    ) as is_active_at_start,
    coalesce(
        lag(is_active) over (partition by customer_id order by month_start),
        false
    ) and not is_active as is_churned_in_month
from with_status
