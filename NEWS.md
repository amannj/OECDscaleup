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
  Stata run: `statar::xtile()`'s tie-breaking at quartile boundaries, and
  `fixest`'s robust-standard-error small-sample adjustment. Both are flagged
  in the relevant function's documentation.
