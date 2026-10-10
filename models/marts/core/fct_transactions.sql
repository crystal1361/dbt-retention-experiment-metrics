select
    t.transaction_id,
    a.customer_id,
    t.account_id,
    a.account_type,
    t.transaction_date,
    t.amount,
    t.direction,
    t.channel,
    t.is_customer_initiated
from {{ ref('stg_bank__transactions') }} as t
inner join {{ ref('stg_bank__accounts') }} as a
    on a.account_id = t.account_id
