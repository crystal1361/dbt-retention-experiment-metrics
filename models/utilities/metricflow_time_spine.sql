-- Daily calendar required by MetricFlow for time-based joins,
-- cumulative windows and conversion metrics.
select cast(day_ts as date) as date_day
from range(timestamp '2023-01-01', timestamp '2027-01-01', interval 1 day) as t(day_ts)
