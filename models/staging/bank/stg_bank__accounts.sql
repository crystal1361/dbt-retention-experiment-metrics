with source as (
    select * from {{ source('bank', 'accounts') }}
)

select
    cast(account_id as varchar)    as account_id,
    cast(customer_id as varchar)   as customer_id,
    cast(account_type as varchar)  as account_type,
    cast(opened_at as date)        as opened_date,
    cast(closed_at as date)        as closed_date,
    closed_at is not null          as is_closed
from source
