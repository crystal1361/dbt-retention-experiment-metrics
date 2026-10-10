-- Experiment readout: retention_offer_2025q2
--
-- The semantic layer serves the point estimate (retention_lift_d90_pp).
-- This analysis adds what a decision needs on top of it:
--   1. ITT lift with a 95% confidence interval (unpooled two-proportion z)
--   2. CUPED-adjusted lift, using pre-period transaction count as covariate
--   3. CACE (complier average causal effect): ITT / take-up rate. Control
--      cannot accept, so the Wald estimator reduces to lift / acceptance rate.
--   4. Minimum detectable effect at 80% power, given the realized SE
--
-- Compile with `dbt compile -s experiment_readout` and run the SQL in
-- target/compiled/..., or run `make readout`.

with units as (
    select
        variant,
        case when is_retained_d90 then 1.0 else 0.0 end as y,
        case when is_accepted then 1.0 else 0.0 end      as accepted,
        cast(pre_period_txn_count as double)               as x
    from {{ ref('fct_experiment_outcomes') }}
    where experiment_id = 'retention_offer_2025q2'
),

-- CUPED: theta = cov(Y, X) / var(X), estimated on the pooled sample.
-- X is measured before assignment, so the adjustment cannot bias the lift.
theta as (
    select
        covar_samp(y, x) / var_samp(x) as theta,
        avg(x)                          as x_bar,
        corr(y, x)                      as corr_y_x
    from units
),

adjusted as (
    select
        u.variant,
        u.y,
        u.accepted,
        u.y - t.theta * (u.x - t.x_bar) as y_cuped
    from units as u
    cross join theta as t
),

arms as (
    select
        variant,
        count(*)            as n,
        avg(y)              as rate,
        var_samp(y)         as var_y,
        avg(y_cuped)        as rate_cuped,
        var_samp(y_cuped)   as var_y_cuped,
        avg(accepted)       as take_up
    from adjusted
    group by variant
),

lift as (
    select
        t.n                                                     as n_treatment,
        c.n                                                     as n_control,
        t.rate                                                  as rate_treatment,
        c.rate                                                  as rate_control,
        t.rate - c.rate                                         as lift,
        sqrt(t.var_y / t.n + c.var_y / c.n)                     as se,
        t.rate_cuped - c.rate_cuped                             as lift_cuped,
        sqrt(t.var_y_cuped / t.n + c.var_y_cuped / c.n)         as se_cuped,
        t.take_up - c.take_up                                   as take_up
    from arms as t
    cross join arms as c
    where t.variant = 'treatment' and c.variant = 'control'
)

select
    n_treatment,
    n_control,
    round(rate_treatment * 100, 2)                      as retention_treatment_pct,
    round(rate_control * 100, 2)                        as retention_control_pct,
    round(lift * 100, 2)                                as lift_pp,
    round((lift - 1.96 * se) * 100, 2)                  as lift_ci95_low_pp,
    round((lift + 1.96 * se) * 100, 2)                  as lift_ci95_high_pp,
    round(lift / se, 2)                                 as z,
    round(lift_cuped * 100, 2)                          as lift_cuped_pp,
    round((lift_cuped - 1.96 * se_cuped) * 100, 2)      as lift_cuped_ci95_low_pp,
    round((lift_cuped + 1.96 * se_cuped) * 100, 2)      as lift_cuped_ci95_high_pp,
    round(1 - power(se_cuped / se, 2), 3)               as variance_reduction,
    round(take_up * 100, 1)                             as take_up_pct,
    round(lift / take_up * 100, 1)                      as cace_pp,
    round((1.96 + 0.84) * se * 100, 2)                  as mde_80pct_power_pp,
    round((select corr_y_x from theta), 3)              as corr_outcome_covariate
from lift
