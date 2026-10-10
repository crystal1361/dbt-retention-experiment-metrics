with source as (
    select * from {{ source('bank', 'experiment_assignments') }}
)

select
    cast(experiment_id as varchar)  as experiment_id,
    cast(customer_id as varchar)    as customer_id,
    cast(variant as varchar)        as variant,
    cast(assigned_at as date)       as assigned_date
from source
