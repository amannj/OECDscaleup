# Changelog

## OECDscaleup 0.2.0.9000 (development version)

The development version, on the default branch `ScalerAnalysis`.

- **One package for the routines that were separate before.** The trade
  package (firm-level trade in goods: exporters, importers and exporting
  scalers) runs from the same package and the same configuration
  ([`run_trade_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_trade_pipeline.md)).
- **New scaler analysis.** The fastest-growing scalers
  ([`compute_top_scalers()`](https://amannj.github.io/OECDscaleup/reference/compute_top_scalers.md))
  and scalers growing into mid-caps
  ([`compute_midcap_transitions()`](https://amannj.github.io/OECDscaleup/reference/compute_midcap_transitions.md)),
  run from files by
  [`run_scaler_analysis()`](https://amannj.github.io/OECDscaleup/reference/run_scaler_analysis.md).
- **Documentation.** The variable dictionary of the input data as a
  dataset (`variable_dictionary`) and two articles on the input
  variables;
  [`check_inputs()`](https://amannj.github.io/OECDscaleup/reference/check_inputs.md)
  checks a country’s files before a run; a step-by-step walkthrough of
  the whole analysis on simulated data
  ([`example_scaleup_data()`](https://amannj.github.io/OECDscaleup/reference/example_scaleup_data.md)).
- **Reference data.** The OECD regional typology of the TL2024
  territorial classification (version of 20 November 2026), with TL2021
  still available (`config_scaleup(tl_classification = "TL2021")`), and
  euro exchange rates for 2008-2025 ship with the package and are used
  unless files in the input folder replace them. See the versions in
  [`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md).
- **Performance.** A panel of 8 million firm-years runs in about 15
  minutes with under 20 GB of memory.
- [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md)
  now requires `nace_revision`, the NACE revision of the sector codes
  (`"2"` or `"2.1"`).
- Some indicator computations were revised, so results can differ from
  version 0.1.0.

## OECDscaleup 0.1.0

The translation to R of the OECD Scale Up routines written in Stata (the
“Second Package”, version 1.3):
[`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md),
[`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md),
[`compute_persistence()`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md),
[`compute_contribution()`](https://amannj.github.io/OECDscaleup/reference/compute_contribution.md)
and
[`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md),
run from files by
[`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md).
The results were checked table by table against those of the original
routines. This version is kept on the branch `Stata-to-R`.
