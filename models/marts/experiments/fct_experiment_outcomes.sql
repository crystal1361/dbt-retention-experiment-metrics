with assignments as (
    select * from {{ ref('stg_bank__experiment_assignments') }}
),

offer_events as (
    select
        experiment_id,
        customer_id,
        min(event_date) filter (where event_type = 'offer_exposed')  as first_exposed_date,
        min(event_date) filter (where event_type = 'offer_accepted') as first_accepted_date
    from {{ ref('stg_bank__offer_events') }}
    group by all
),

customer_txns as (
    select customer_id, transaction_date
    from {{ ref('fct_transactions') }}
    where is_customer_initiated
),

txn_windows as (
    select
        a.experiment_id,
        a.customer_id,
        -- pre-period covariate for CUPED: [-90, 0)
        count(*) filter (where t.transaction_date >= a.assigned_date - interval 90 day
                           and t.transaction_date <  a.assigned_date)        as pre_period_txn_count,
        -- engagement during the test: [0, 90]
        count(*) filter (where t.transaction_date >= a.assigned_date
                           and t.transaction_date <= a.assigned_date + interval 90 day)
                                                                             as post_period_txn_count,
        -- primary outcome window: (60, 90]
        count(*) filter (where t.transaction_date >  a.assigned_date + to_days({{ var('retention_window_start_day') }})
                           and t.transaction_date <= a.assigned_date + to_days({{ var('retention_window_end_day') }}))
                                                                             as outcome_window_txn_count
    from assignments as a
    left join customer_txns as t
        on t.customer_id = a.customer_id
    group by all
)

select
    a.experiment_id || '|' || a.customer_id                       as experiment_unit_id,
    a.experiment_id,
    a.customer_id,
    a.variant,
    a.assigned_date,
    c.segment,
    c.acquisition_channel,
    o.first_exposed_date is not null                              as is_exposed,
    o.first_accepted_date is not null                             as is_accepted,
    o.first_exposed_date,
    o.first_accepted_date,
    cast(w.pre_period_txn_count as integer)                       as pre_period_txn_count,
    cast(w.post_period_txn_count as integer)                      as post_period_txn_count,
    w.outcome_window_txn_count > 0                                as is_retained_d90
from assignments as a
inner join {{ ref('dim_customers') }} as c using (customer_id)
left join offer_events as o using (experiment_id, customer_id)
left join txn_windows as w using (experiment_id, customer_id)
