"""Compile a dbt analysis and run it against the local DuckDB warehouse.

Usage: python scripts/run_analysis.py experiment_readout
"""
import subprocess
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]


def main(name: str) -> None:
    subprocess.run(["dbt", "compile", "-s", name, "-q"], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    compiled = next((ROOT / "target" / "compiled").rglob(f"analyses/{name}.sql"))
    con = duckdb.connect(str(ROOT / "northwind.duckdb"), read_only=True)
    rel = con.sql(compiled.read_text())
    rows = rel.fetchall()
    if len(rows) == 1:  # one-row readout: print vertically
        width = max(len(c) for c in rel.columns)
        for col, val in zip(rel.columns, rows[0]):
            print(f"{col:<{width}}  {val}")
    else:
        rel.show()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "experiment_readout")
