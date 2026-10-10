{% docs churn_definition %}
Customer x month status. **This model is the single source of truth for churn.**

- **Active**: holds an open checking account at month end *and* made at least
  one customer-initiated transaction in the trailing 90 days
  (`days_since_last_txn < var('dormancy_days')`).
- **Churned in month**: active at the end of the prior month, not active at
  the end of this month.
- System postings (fees, interest) never count as activity.

Why dormancy rather than account closure: most customers who leave a bank
stop using the account long before they close it, if they close it at all.
A closure-only definition undercounts churn and detects it months late.

Trade-off: a 90-day dormancy rule detects churn ~3 months after the customer's
last transaction. Monthly churn is therefore a *lagging* indicator, and the
first 3 months of history are a warm-up period (see `fct_customer_monthly`).
{% enddocs %}

{% docs experiment_outcome_definition %}
One row per customer assigned to an experiment.

**Primary outcome — `is_retained_d90`**: the customer made at least one
customer-initiated transaction in days (60, 90] after assignment.

Why this window and not "active at day 90" under the 90-day dormancy rule:
dormancy at day 90 would count anyone who transacted on day 1 as retained,
which tells us nothing about the offer. Requiring activity in the third month
measures whether the customer is *still* using the account.

**Covariate — `pre_period_txn_count`**: customer-initiated transactions in the
90 days before assignment. Not affected by treatment, so it can be used for
CUPED / regression adjustment to tighten confidence intervals.

**Analysis unit = randomization unit = customer.** Metrics must be computed
as ratios of sums across customers (never averages of per-segment rates).
{% enddocs %}
