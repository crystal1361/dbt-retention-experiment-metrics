-- Sample Ratio Mismatch (SRM) check.
--
-- Assignment was designed as 50/50. If the observed split deviates more than
-- chance allows, randomization or logging is broken and the experiment result
-- cannot be trusted -- no matter how good the lift looks.
--
-- Chi-square goodness-of-fit, 1 degree of freedom. Fails when p < 0.001
-- (chi-square > 10.828), the conventional SRM alerting threshold.

with counts as (
    select experiment_id, variant, count(*) as n
    from {{ ref('fct_experiment_outcomes') }}
    group by all
),

expected as (
    select experiment_id, variant, n, sum(n) over (partition by experiment_id) / 2.0 as expected_n
    from counts
)

select
    experiment_id,
    sum(power(n - expected_n, 2) / expected_n) as chi_square
from expected
group by experiment_id
having sum(power(n - expected_n, 2) / expected_n) > 10.828
