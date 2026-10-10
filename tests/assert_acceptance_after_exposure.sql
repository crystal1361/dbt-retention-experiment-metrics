-- A customer cannot accept an offer before (or without) seeing it.

select *
from {{ ref('fct_experiment_outcomes') }}
where is_accepted
  and (first_exposed_date is null or first_accepted_date < first_exposed_date)
