.PHONY: setup data build metrics readout docs all clean

setup:
	pip install -r requirements.txt

data:
	python scripts/generate_data.py

build:
	dbt build

metrics:
	mf validate-configs
	mf query --metrics retention_rate_d90,experiment_units --group-by experiment_unit__variant
	mf query --metrics retention_lift_d90_pp
	mf query --metrics offer_acceptance_rate_14d
	mf query --metrics monthly_churn_rate --group-by metric_time__quarter,customer__segment --order metric_time__quarter

readout:
	python scripts/run_analysis.py experiment_readout

docs:
	dbt docs generate --static
	@echo "Open target/static_index.html in a browser"

all: data build metrics readout

clean:
	dbt clean
	rm -f northwind.duckdb northwind.duckdb.wal data/raw/*.csv
