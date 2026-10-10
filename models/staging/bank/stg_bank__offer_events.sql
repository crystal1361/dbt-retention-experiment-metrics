with source as (
    select * from {{ source('bank', 'offer_events') }}
)

select
    md5(customer_id || '|' || experiment_id || '|' || event_type || '|' || cast(event_at as varchar))
                                    as offer_event_id,
    cast(customer_id as varchar)    as customer_id,
    cast(experiment_id as varchar)  as experiment_id,
    cast(event_type as varchar)     as event_type,
    cast(event_at as date)          as event_date
from source
