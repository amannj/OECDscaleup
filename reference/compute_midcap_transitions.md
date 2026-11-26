# Scalers to mid-caps: crossings into mid-cap status

New analysis (not part of the original Stata package). Follows firms
from the start of the 3-year window that first makes them a scaler (or a
non-scaler of the pool) and records when they cross into mid-cap status,
with firm exit as a competing event.

## Usage

``` r
compute_midcap_transitions(
  config,
  accounts_indicators,
  money_unit = c("EUR thousand", "EUR"),
  top_cutoffs = c(top50 = 50, p1 = 0.01, p5 = 0.05, p10 = 0.1, p25 = 0.25)
)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- accounts_indicators:

  The output of
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md);
  needs `employment`, and for the first two definitions `turnover` and
  `total_assets`.

- money_unit:

  Unit of `turnover` and `total_assets` in `accounts_indicators`:
  `"EUR thousand"` (what
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
  produces, see `financials_unit` in
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md))
  or `"EUR"` (for an indicators panel built in euros by an earlier
  version of the package). As a check, the function stops if firms with
  10-49 employees have a median turnover per employee above 5,000 when
  `"EUR thousand"` is declared (EUR 5 m per person: euros, not
  thousands).

- top_cutoffs:

  Cut-offs of
  [`compute_top_scalers()`](https://amannj.github.io/OECDscaleup/reference/compute_top_scalers.md):
  each top-scaler sample (e.g. `HGE20_rel_p10`) is also followed, from
  t-3 of its first year in the sample, category `ALL` only, so its
  crossings compare with those of all scalers (the link between the two
  analyses). `NULL` skips them.

## Value

A list of tibbles:

- `incidence`: by definition, sample, category, group (at entry) and
  step: firms at risk, crossings to `mid` and to `large`, exits,
  censored, and the cumulative incidence of each (Aalen-Johansen);

- `entry`: per definition, sample, category and group, the firms
  entering the risk set and those not followed, by reason;

- `by_year`: per definition, sample, category, group and calendar year,
  firms at risk, crossings, exits and `status_missing`: at-risk
  firm-years without a status (no row that year, or values that cannot
  decide it), where a crossing could neither start nor be confirmed;

- `coverage`: per year, firm-years with 100+ employees and how many of
  them have both turnover and total assets (the financial coverage
  behind the first two definitions);

- `hazard`: discrete-time logit of a crossing (to `mid` or `large`) in
  year t, one per definition and scaler type, on scalers and their pool
  non-scalers together (`scaler` = 1 for the scalers' spells).
  Covariates at t-1: log employment, 1-year employment growth, log
  turnover per employee and, where present, independence and exporter
  status; plus a young-firm dummy (age class 0-5 at t-1), years since
  entry and its square, and a linear calendar trend. Firm-clustered
  standard errors (CR1, as Stata's `vce(cluster idf)`); `ame_scaler` is
  the average change in the yearly crossing probability when `scaler`
  goes from 0 to 1. Exits count as no crossing in their year (a
  cause-specific hazard). Two models each (`window`): `from_t-3`, every
  step; `after_window`, only the years after the growth window (step 4 =
  t + 1 on) of firms that had not crossed by t, so the scaler effect is
  net of the growth that defines a scaler.

## Details

**Status** per firm-year, three definitions (`definition` column):

- `small_midcap`: EU small mid-cap (Recommendation (EU) 2025/1099). A
  firm leaves the SME category (Recommendation 2003/361/EC) with 250+
  persons, or with turnover above EUR 50 m *and* balance sheet above EUR
  43 m. It is a small mid-cap if it then has fewer than 750 persons and
  turnover of at most EUR 150 m *or* a balance sheet of at most EUR 129
  m; above those ceilings it is `large`.

- `sme_exit`: leaving the SME category; `large` from 3,000 employees
  (the EIB mid-cap bound).

- `employment_250`: 250+ employees; `large` from 3,000 employees. The
  reference series (no balance sheet, no inflation).

Money in EUR thousand, nominal (thresholds 50,000 / 43,000 / 150,000 /
129,000); balance sheet = `total_assets`. Firm-level figures (the legal
definition adds up linked enterprises; use the `independent` breakdown).
Nothing is imputed: a status is missing when the available values cannot
decide it (e.g. turnover above EUR 50 m, under 250 employees, no balance
sheet). Where `consolidation_code` exists, only unconsolidated accounts
(`U1`, `U2`) get a status.

**Crossing.** The first year after entry into the risk set in which the
firm is above SME status (`mid` or `large`) and is so again in the next
calendar year. A missing year or an exit before the confirmation year is
not a crossing. The crossing's type is the status in the crossing year:
`mid` or `large` (the firm jumped past the mid-cap band).

**Risk set.** A firm's sample year t is its first year as a scaler
(`HGE20` / `HGT20`), as a non-scaler of the pool (`HGE20_nonscaler_pool`
/ `HGT20_nonscaler_pool`, as in
[`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md);
firms that scale later stay in it) or as a top scaler (see
`top_cutoffs`), with 10 to fewer than 250 employees at t-3, from the
fourth panel year. The firm enters the risk set at **t-3**, the start of
that growth window, so a crossing during the growth spell itself counts.
Scalers and pool firms are both observed at t-3 and t, so both groups
survive the first three steps by construction. Entry needs SME status at
t-3: firms already above it, or without a status, are counted
(`n_above_at_entry`, `n_status_missing_at_entry`) and not followed.
Breakdowns are the categories at t-3 (`L3size_cat`, `L3age_cat`, ...).

**Time** is years since entry (step 1 = t-2). A firm that crosses at
step k has its event at k; a firm whose last year L is before the
panel's last year exits at step L - entry (competing event); other firms
are censored at the last step whose crossing could still be confirmed
(panel end - 1 - entry). Firms with no step left are counted
(`n_no_followup`).
