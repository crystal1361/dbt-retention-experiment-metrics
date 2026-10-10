-- One row per offer exposure. Kept separate from acceptances on purpose:
-- a conversion metric whose base and conversion events live in the same
-- semantic model lets a conversion event match itself as its own base.
select offer_event_id, customer_id, experiment_id, variant, event_date as exposed_date
from {{ ref('fct_offer_events') }}
where event_type = 'offer_exposed'
