with source as (
    select * from {{ source('bank', 'transactions') }}
)

select
    cast(transaction_id as varchar)        as transaction_id,
    cast(account_id as varchar)            as account_id,
    cast(transaction_date as date)         as transaction_date,
    cast(amount as decimal(18, 2))         as amount,
    cast(direction as varchar)             as direction,
    cast(channel as varchar)               as channel,
    -- Fees and interest are posted by the bank, not by the customer.
    -- They must never count as engagement, or dormant accounts look alive.
    channel <> 'system'                    as is_customer_initiated
from source
