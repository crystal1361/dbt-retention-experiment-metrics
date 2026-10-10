with customers as (
    select * from {{ ref('stg_bank__customers') }}
),

accounts as (
    select
        customer_id,
        count(*)                                          as n_accounts,
        bool_or(account_type = 'savings')                 as has_savings,
        min(opened_date) filter (where account_type = 'checking') as checking_opened_date
    from {{ ref('stg_bank__accounts') }}
    group by customer_id
),

latest_status as (
    select customer_id, is_active, last_txn_date
    from {{ ref('int_customer_monthly_status') }}
    qualify row_number() over (partition by customer_id order by month_start desc) = 1
)

select
    c.customer_id,
    c.signup_date,
    c.segment,
    c.region,
    c.age_band,
    c.acquisition_channel,
    a.n_accounts,
    a.has_savings,
    a.checking_opened_date,
    s.last_txn_date,
    coalesce(s.is_active, false) as is_currently_active
from customers as c
left join accounts as a using (customer_id)
left join latest_status as s using (customer_id)
