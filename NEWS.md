# OECDscaleup (development version)

## Verified against Stata

Outputs were compared with the original Stata code (package version 1.3)
run in Stata 19.5, on 9 synthetic scenarios built to hit every branch and on
one full national firm-level dataset (confidential). All 9 output tables
match in every scenario (rows, keys, labels and counts exact; other values
within a relative 1e-4). The R code now reproduces the Stata code
*including its known bugs* (git tag `stata-parity-v1_3`); fixing those is a
separate step, see "Known issues inherited from the Stata code" below.
Two Stata crashes are not reproduced: R completes where Stata stops (S13,
S14). Translation errors found and corrected:

- Stata arithmetic: `x/0`, `ln(0)` and `0/0` are missing in Stata, not
  `Inf`/`NaN`. This changed HG flags (turnover 0 at t-3), the p1/p99
  trimming of growth rates and labour productivity, MFP, the acquisition
  flag and the financial-dependency ratios.
- Stata storage: `gen` stores `float`. Reproduced (`stata_float()`) where it
  decides a threshold, e.g. `8/10 > 0.8` is true in Stata.
- Stata's `x^y` is `exp(y * ln(x))`: firms growing at exactly 10%/20% a year
  are not high-growth firms in Stata (`stata_pow()`).
- The HG pool no longer requires the growth ratio to exist.
- `"."` in `sector_1d`/`region_2d` is missing, and never forms a `._<sector>`
  region-sector pair; the `".."` TL3 typology is kept as its own category.
- `L3age` is created (it was missing, so `median_L3age` was absent).
- `log_added_value_emp` is renamed to `labour_prod` as in Stata; the Solow
  intermediates `va sl k slk l sll` are kept.
- Region aggregation reproduces Stata's `share_small > 0.5` with a missing
  share counting as true (Stata bug, reproduced on purpose).
- Approximate medians of growth rates were means: `summarise()` evaluated
  the means first and overwrote the columns (characteristics and
  desc_predictors).
- Transitions/evolutions/desc_predictors write value labels (`FOLLOW`,
  `LEAD`, `type`) as Stata's `export delimited` does; desc_predictors labels
  ALL as "Total".
- Evolutions: `entry_year`/`exit_year` are missing where `entry`/`exit` is.
- Contribution: the p2 table for `exiting` is written once (Stata skips the
  aggregate block when the detail block is empty).
- Regressions: replaced `fixest` with an emulation of `regress, robust`
  (`stata_regress_robust()`): Stata's term names (`0b.L3size_cat`,
  `3.L3region_2d`, `o.x`, `_cons`), base and omitted rows, left-to-right
  collinearity handling, HC1 errors, no regression with fewer than 2
  observations, dominance shares rounded to 4 decimals. Previously any
  warning dropped the model.
- `accounts_indicators_<CT>.dta` is written with Stata's labelled numeric
  categories and `encode` codes (byte order; `typology_UR` extends the label
  that comes with `tl3_typology.dta`).
- `fixest` is no longer a dependency.

## Known issues inherited from the Stata code

Reproduced on purpose at `stata-parity-v1_3`, to be fixed on the
`FixStataBugs` branch. Items marked *(method)* change what a result means
and are decided one by one before they are changed.

- S1 Jump filter: in a 20-200-20 spike the year after the spike is blanked,
  not the spike.
- S2 `ind_a38`: `D68T82` is assigned after `D69T71`, `D72`, `D73T75`, so
  divisions 69-76 all end up in `D68T82`; `D77T82` overlaps likewise.
- S3 Region aggregation: a missing small-region share counts as above 0.5,
  so large TL1 regions are aggregated too.
- S4 Predictor types 9 ("missing info") and 50 ("<50 N") are overwritten
  by types 5/6.
- S5 Contribution: years are hard-coded (2014, 2017, 2019-2021); the
  computed first/last years are unused.
- S6 *(method)* Regression samples include firms that are not eligible to
  scale (fewer than 10 employees at t-3, or 250+).
- S7 *(method)* Regions with TL3 typology ".." form their own category.
- S8 A user-supplied `age_cat` together with `birth_year` fails in Stata
  (`gen birth_year` on an existing variable).
- S9 *(method)* Fractional FTE between 9 and 10 at t-3: such a firm can be a
  micro scaler but is never in the micro comparison pool.
- S10 *(documentation)* Output file names differ from the documentation.
- S11 *(documentation)* The documentation calls MFP "productivity growth";
  the code reports the MFP level.
- S12 *(method)* Labour share is labour costs over turnover, not value
  added; the MFP < 0 floor can never apply.
- S13 Stata crashes when `age_cat` is supplied without value labels
  (R does not).
- S14 Stata crashes when no regression can run, losing desc_predictors too
  (R does not).
- S15 `tech_grad`: divisions 58-60 (except 582), 63, 77, 90-94 and 96 get no
  group.
- S16 Rescaling to thousands (PT, ES, RO, SI, HU) leaves out `cash_flow`, so
  financial-dependency ratio 4 mixes thousands with units.

# OECDscaleup 0.1.0

Initial release: a behaviour-preserving translation of the OECD Scale Up
project's "Second Package" Stata pipeline (`MASTER_OECD_p2.do` and its 5
worker `.do` files, version 1.0, `scaleup@oecd.org`) into R.

## What this release contains

- `config_scaleup()` — replaces the Stata global macros set in
  `MASTER_OECD_p2.do`.
- `build_accounts_indicators()` — translates `n0_1_accounts_indicators_v2.do`.
- `compute_characteristics()` — translates `n1_3_characteristics.do`.
- `compute_persistence()` — translates `n1_3_persistence.do` (transitions +
  evolutions).
- `compute_contribution()` — translates `n1_3_contribution.do`.
- `compute_predictors()` — translates `n1_3_predictors.do`.
- `run_scaleup_pipeline()` — file-I/O orchestrator mirroring
  `MASTER_OECD_p2.do`'s role; every function above it is a pure,
  independently-testable data transformation.
- Bundled reference data `tl3_typology` and `exchange_rates`, carried over
  as-is from the OECD-supplied `.dta` files.
- A documented `country_patches` lookup table replacing the 3 hardcoded
  country-list branches in the original `n0_1_accounts_indicators_v2.do`.

## Translation notes

- Ported from `Pseudocode/*.md` (a structure-preserving intermediate
  representation of the original Stata source), not directly from the `.do`
  files — see that directory for the line-by-line correspondence.
- Several Stata/R semantic gaps were identified and deliberately corrected
  for, each with a dedicated regression test: Stata's non-propagating
  missing-value comparisons (`stata_num()`), `replace ... if` semantics
  under an unresolved condition (`stata_replace()`), Stata's round-half-away-
  from-zero convention (`round_half_up()`), and Stata's percentile algorithm
  (`percentile_stata()`, confirmed equivalent to R's `quantile(type = 2)`).
- The original has no automated test suite; the one existing behavioural
  spec (the confidentiality worked example in the source PDF, §4) informed
  this package's dominance-share tests. Everything else is covered by new
  unit and integration tests built from synthetic fixtures, since the real
  firm microdata this pipeline processes is confidential and never ships
  with the package (see `Analysis/stata.md` and `variable_dictionary_v1.xlsx`
  for the input schema fixtures are built against).
- No `.dlg` dialog files exist in the source package, so no Shiny GUI was
  built (there was nothing to recreate).
- Known residual approximations, not exact-match verified against a live
  Stata run at the time: `statar::xtile()`'s tie-breaking at quartile
  boundaries, and `fixest`'s robust-standard-error small-sample adjustment
  (both since verified or replaced, see the development version above).
