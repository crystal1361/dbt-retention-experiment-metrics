-- Customer x month fact for retention reporting.
-- The first `dormancy_days` of history are dropped: without 90 days of
-- look-back, every customer looks "new" and churn is undefined.

select
    customer_id || '|' || strftime(month_start, '%Y-%m')  as customer_month_id,
    customer_id,
    month_start,
    month_end,
    customer_txn_count,
    deposit_amount,
    spend_amount,
    has_direct_deposit,
    days_since_last_txn,
    is_active,
    is_active_at_start,
    is_churned_in_month
from {{ ref('int_customer_monthly_status') }}
where month_start >= cast('{{ var("analysis_start_date") }}' as date)
                     + to_days({{ var('dormancy_days') }})
