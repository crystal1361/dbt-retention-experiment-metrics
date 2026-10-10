-- Customer-initiated activity rolled up to customer x month.
-- System postings (fees, interest) are excluded on purpose.

with transactions as (
    select * from {{ ref('stg_bank__transactions') }}
    where is_customer_initiated
),

accounts as (
    select account_id, customer_id from {{ ref('stg_bank__accounts') }}
)

select
    a.customer_id,
    cast(date_trunc('month', t.transaction_date) as date)              as activity_month,
    count(*)                                                           as customer_txn_count,
    max(t.transaction_date)                                            as last_txn_date_in_month,
    sum(case when t.direction = 'credit' then t.amount else 0 end)     as deposit_amount,
    sum(case when t.direction = 'debit' then -t.amount else 0 end)     as spend_amount,
    bool_or(t.channel = 'direct_deposit')                              as has_direct_deposit
from transactions as t
inner join accounts as a
    on a.account_id = t.account_id
group by all
