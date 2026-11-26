# OECDscaleup 0.2.0.9000 (development version)

The development version, on the default branch `ScalerAnalysis`.

- **One package for the routines that were separate before.** The trade
  package (firm-level trade in goods: exporters, importers and exporting
  scalers) runs from the same package and the same configuration
  (`run_trade_pipeline()`).
- **New scaler analysis.** The fastest-growing scalers
  (`compute_top_scalers()`) and scalers growing into mid-caps
  (`compute_midcap_transitions()`), run from files by
  `run_scaler_analysis()`.
- **Documentation.** The variable dictionary of the input data as a dataset
  (`variable_dictionary`) and two articles on the input variables;
  `check_inputs()` checks a country's files before a run; a step-by-step
  walkthrough of the whole analysis on simulated data
  (`example_scaleup_data()`).
- **Performance.** A panel of 8 million firm-years runs in about 15 minutes
  with under 20 GB of memory.
- `config_scaleup()` now requires `nace_revision`, the NACE revision of the
  sector codes (`"2"` or `"2.1"`).
- Some indicator computations were revised, so results can differ from
  version 0.1.0.

# OECDscaleup 0.1.0

The translation to R of the OECD Scale Up routines written in Stata (the
"Second Package", version 1.3): `build_accounts_indicators()`,
`compute_characteristics()`, `compute_persistence()`,
`compute_contribution()` and `compute_predictors()`, run from files by
`run_scaleup_pipeline()`. The results were checked table by table against
those of the original routines. This version is kept on the branch
`Stata-to-R`.
