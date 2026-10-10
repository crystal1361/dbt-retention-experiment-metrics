-- One row per customer per calendar month from signup month to the end of
-- the analysis window, with whether they held an open checking account at
-- month end. Months with no activity must still exist, or dormancy is invisible.

with months as (
    select cast(month_ts as date) as month_start
    from range(
        timestamp '{{ var("analysis_start_date") }}',
        timestamp '{{ var("analysis_end_date") }}' + interval 1 day,
        interval 1 month
    ) as t(month_ts)
),

customers as (
    select customer_id, signup_date
    from {{ ref('stg_bank__customers') }}
),

checking_accounts as (
    select customer_id, opened_date, closed_date
    from {{ ref('stg_bank__accounts') }}
    where account_type = 'checking'
),

spine as (
    select
        c.customer_id,
        m.month_start,
        last_day(m.month_start) as month_end
    from customers as c
    inner join months as m
        on m.month_start >= date_trunc('month', c.signup_date)
)

select
    s.customer_id,
    s.month_start,
    s.month_end,
    coalesce(
        bool_or(a.opened_date <= s.month_end
                and (a.closed_date is null or a.closed_date > s.month_end)),
        false
    ) as has_open_checking
from spine as s
left join checking_accounts as a
    on a.customer_id = s.customer_id
group by all
