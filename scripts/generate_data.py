"""
Generate synthetic raw data for a fictional retail bank ("Northwind Bank").

Scenario
--------
* Customers open a checking account (and sometimes a savings account).
* Customers transact monthly; some eventually go dormant (churn) and a
  share of churners later close their accounts.
* System postings (monthly fees / interest) keep hitting open accounts even
  after a customer stops using them -- so "any transaction" is NOT a valid
  activity signal. The dbt models have to exclude these.
* On 2025-04-01 the bank ran a randomized retention experiment
  (``retention_offer_2025q2``) on at-risk customers: treatment customers were
  shown a fee-waiver offer, control customers were not.

Because the true treatment effect is planted by this script, the metrics built
in dbt can be checked against a known answer.

Output: CSV files in ``data/raw/`` (git-ignored, fully reproducible via --seed).
"""
from __future__ import annotations

import argparse
import calendar
import csv
from datetime import date, timedelta
from pathlib import Path

import numpy as np

SIM_START = date(2024, 1, 1)
SIM_END = date(2025, 12, 31)
EXPERIMENT_ID = "retention_offer_2025q2"
EXPERIMENT_START = date(2025, 4, 1)
EXPERIMENT_MONTHS = 3  # treatment effect applies to Apr-Jun 2025

SEGMENTS = ["mass_market", "affluent", "small_business"]
SEGMENT_P = [0.70, 0.20, 0.10]
SEGMENT_TXN_RATE = {"mass_market": 6.0, "affluent": 9.0, "small_business": 14.0}
SEGMENT_HAZARD_MULT = {"mass_market": 1.0, "affluent": 0.8, "small_business": 0.7}

REGIONS = ["Central", "Mountain", "Plains", "Southwest"]
CHANNELS = ["branch", "digital", "referral"]
CHANNEL_P = [0.40, 0.45, 0.15]
CHANNEL_HAZARD = {"branch": 0.012, "digital": 0.022, "referral": 0.010}
AGE_BANDS = ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"]
AGE_P = [0.10, 0.24, 0.22, 0.18, 0.14, 0.12]

DEBIT_CHANNELS = ["card", "ach", "atm", "transfer", "check"]
DEBIT_P = [0.55, 0.15, 0.10, 0.12, 0.08]
CREDIT_CHANNELS = ["transfer", "mobile_deposit"]


def month_starts(start: date, end: date) -> list[date]:
    out, d = [], date(start.year, start.month, 1)
    while d <= end:
        out.append(d)
        d = date(d.year + (d.month == 12), d.month % 12 + 1, 1)
    return out


def month_end(d: date) -> date:
    return date(d.year, d.month, calendar.monthrange(d.year, d.month)[1])


def rand_day(rng: np.random.Generator, start: date, end: date) -> date:
    return start + timedelta(days=int(rng.integers(0, (end - start).days + 1)))


def main(n_customers: int, seed: int, out_dir: Path) -> None:
    rng = np.random.default_rng(seed)
    out_dir.mkdir(parents=True, exist_ok=True)
    months = month_starts(SIM_START, SIM_END)

    customers, accounts, txns, assignments, offer_events = [], [], [], [], []
    account_seq = 0
    txn_seq = 0

    for i in range(1, n_customers + 1):
        cid = f"C{i:06d}"
        segment = rng.choice(SEGMENTS, p=SEGMENT_P)
        channel = rng.choice(CHANNELS, p=CHANNEL_P)
        signup = rand_day(rng, date(2023, 1, 1), date(2025, 6, 30))
        has_dd = rng.random() < 0.55  # direct deposit set up
        high_risk = rng.random() < 0.35  # latent; never written to the data
        customers.append(
            dict(
                customer_id=cid,
                signup_date=signup,
                segment=segment,
                region=rng.choice(REGIONS),
                age_band=rng.choice(AGE_BANDS, p=AGE_P),
                acquisition_channel=channel,
            )
        )

        # ---- accounts -------------------------------------------------------
        account_seq += 1
        checking = dict(account_id=f"A{account_seq:07d}", customer_id=cid,
                        account_type="checking", opened_at=signup, closed_at=None)
        accts = [checking]
        if rng.random() < 0.40:
            account_seq += 1
            accts.append(dict(account_id=f"A{account_seq:07d}", customer_id=cid,
                              account_type="savings",
                              opened_at=signup + timedelta(days=int(rng.integers(0, 120))),
                              closed_at=None))

        # ---- pass 1: simulate churn month (with experiment effect) ----------
        base_hazard = CHANNEL_HAZARD[channel] * SEGMENT_HAZARD_MULT[segment]
        base_hazard *= 0.5 if has_dd else 1.0
        base_hazard *= 2.5 if high_risk else 1.0

        first_month = max(date(signup.year, signup.month, 1), months[0])
        active_months = [m for m in months if m >= first_month]
        churn_month = None
        variant = None
        exp_mult = 1.0
        for m in active_months:
            if m == EXPERIMENT_START:
                eligible = high_risk and signup < date(2025, 1, 1)
                if eligible:
                    variant = "treatment" if rng.random() < 0.5 else "control"
                    assigned_at = EXPERIMENT_START + timedelta(days=int(rng.integers(0, 3)))
                    assignments.append(dict(experiment_id=EXPERIMENT_ID, customer_id=cid,
                                            variant=variant, assigned_at=assigned_at))
                    if variant == "treatment" and rng.random() < 0.85:
                        exposed_at = assigned_at + timedelta(days=int(rng.integers(0, 7)))
                        offer_events.append(dict(customer_id=cid, experiment_id=EXPERIMENT_ID,
                                                 event_type="offer_exposed", event_at=exposed_at))
                        exp_mult = 0.9
                        if rng.random() < 0.35:
                            accepted_at = exposed_at + timedelta(days=int(rng.integers(0, 21)))
                            offer_events.append(dict(customer_id=cid, experiment_id=EXPERIMENT_ID,
                                                     event_type="offer_accepted", event_at=accepted_at))
                            exp_mult = 0.4
            in_window = variant is not None and EXPERIMENT_START <= m < months[
                months.index(EXPERIMENT_START) + EXPERIMENT_MONTHS]
            tenure_m = (m.year - signup.year) * 12 + m.month - signup.month
            h = base_hazard * (1.6 if tenure_m < 6 else 1.0)
            if in_window:
                h = 0.08 * exp_mult  # at-risk population during the test window
            if rng.random() < h:
                churn_month = m
                break

        # churned customers sometimes close accounts 1-4 months later
        if churn_month is not None and rng.random() < 0.45:
            close_at = month_end(churn_month) + timedelta(days=int(rng.integers(30, 120)))
            if close_at <= SIM_END:
                for a in accts:
                    a["closed_at"] = close_at
        accounts.extend(accts)

        # ---- pass 2: transactions ------------------------------------------
        rate = SEGMENT_TXN_RATE[segment] * rng.lognormal(0, 0.3)
        for m in active_months:
            m_end = month_end(m)
            for a in accts:
                if a["opened_at"] > m_end or (a["closed_at"] and a["closed_at"] <= m_end):
                    continue
                # system postings hit every open account, even dormant ones
                txn_seq += 1
                if a["account_type"] == "checking":
                    txns.append((f"T{txn_seq:09d}", a["account_id"], m_end, -12.00, "debit", "system"))
                else:
                    txns.append((f"T{txn_seq:09d}", a["account_id"], m_end,
                                 round(float(rng.uniform(0.5, 25)), 2), "credit", "system"))

            if churn_month is not None and m > churn_month:
                continue  # dormant: no customer-initiated activity
            lam = rate
            last_day = m_end
            if churn_month is not None and m == churn_month:
                lam *= 0.35
                last_day = m + timedelta(days=13)
            elif churn_month is not None and m == date(churn_month.year - (churn_month.month == 1),
                                                         (churn_month.month - 2) % 12 + 1, 1):
                lam *= 0.6  # visible decline the month before going dormant
            start_day = max(m, checking["opened_at"])
            if start_day > last_day:
                continue
            for _ in range(rng.poisson(lam)):
                txn_seq += 1
                d = rand_day(rng, start_day, last_day)
                if rng.random() < 0.8:
                    amt = -round(float(rng.lognormal(3.6, 0.9)), 2)
                    txns.append((f"T{txn_seq:09d}", checking["account_id"], d, amt, "debit",
                                 rng.choice(DEBIT_CHANNELS, p=DEBIT_P)))
                else:
                    amt = round(float(rng.lognormal(5.0, 0.8)), 2)
                    txns.append((f"T{txn_seq:09d}", checking["account_id"], d, amt, "credit",
                                 rng.choice(CREDIT_CHANNELS)))
            if has_dd and (churn_month is None or m < churn_month):
                pay = round(float(rng.normal(2400 if segment != "affluent" else 5200, 300)), 2)
                for day in (1, 15):
                    d = date(m.year, m.month, day)
                    if d >= checking["opened_at"]:
                        txn_seq += 1
                        txns.append((f"T{txn_seq:09d}", checking["account_id"], d, pay / 2,
                                     "credit", "direct_deposit"))

    # ---- write --------------------------------------------------------------
    def write(name: str, rows: list, header: list[str]) -> None:
        with open(out_dir / f"{name}.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(header)
            for r in rows:
                w.writerow([r[h] for h in header] if isinstance(r, dict) else r)
        print(f"{name:<24}{len(rows):>10,} rows")

    write("customers", customers,
          ["customer_id", "signup_date", "segment", "region", "age_band", "acquisition_channel"])
    write("accounts", accounts, ["account_id", "customer_id", "account_type", "opened_at", "closed_at"])
    txns.sort(key=lambda t: (t[2], t[0]))
    write("transactions", txns,
          ["transaction_id", "account_id", "transaction_date", "amount", "direction", "channel"])
    write("experiment_assignments", assignments, ["experiment_id", "customer_id", "variant", "assigned_at"])
    write("offer_events", offer_events, ["customer_id", "experiment_id", "event_type", "event_at"])


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--customers", type=int, default=10000)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", type=Path, default=Path(__file__).resolve().parents[1] / "data" / "raw")
    a = p.parse_args()
    main(a.customers, a.seed, a.out)
