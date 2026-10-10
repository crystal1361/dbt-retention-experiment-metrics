select
    e.offer_event_id,
    e.customer_id,
    e.experiment_id,
    a.variant,
    e.event_type,
    e.event_date
from {{ ref('stg_bank__offer_events') }} as e
left join {{ ref('stg_bank__experiment_assignments') }} as a
    using (experiment_id, customer_id)
