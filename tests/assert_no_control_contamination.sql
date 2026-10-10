-- Control customers must never see the offer. Any row here means the
-- treatment leaked into control, which biases the measured lift toward zero.

select *
from {{ ref('fct_experiment_outcomes') }}
where variant = 'control'
  and (is_exposed or is_accepted)
