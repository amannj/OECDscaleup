# OECDscaleup 0.1.0

The translation to R of the OECD Scale Up routines written in Stata (the
"Second Package", version 1.3): `build_accounts_indicators()`,
`compute_characteristics()`, `compute_persistence()`,
`compute_contribution()` and `compute_predictors()`, run from files by
`run_scaleup_pipeline()`, with the configuration in `config_scaleup()` and
the reference data `tl3_typology` and `exchange_rates`.

The results were compared table by table with those of the original
routines (run in Stata 19.5), on 9 synthetic scenarios built to reach every
branch and on national firm-level panels (confidential): rows, keys, labels
and counts match exactly, other values within a relative 1e-4.

This version is kept on the branch `Stata-to-R`. The development version is
on the default branch, `ScalerAnalysis`.
