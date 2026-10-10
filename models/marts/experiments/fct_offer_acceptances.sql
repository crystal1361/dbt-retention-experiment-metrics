-- One row per offer acceptance (see fct_offer_exposures for why these are split).
select offer_event_id, customer_id, experiment_id, variant, event_date as accepted_date
from {{ ref('fct_offer_events') }}
where event_type = 'offer_accepted'
