# Package index

## Configuration and input checks

- [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md)
  : Build a Scale-Up pipeline configuration
- [`check_inputs()`](https://amannj.github.io/OECDscaleup/reference/check_inputs.md)
  : Check the input data against the variable dictionary
- [`country_patches`](https://amannj.github.io/OECDscaleup/reference/country_patches.md)
  : Country-specific data patches

## Scale-up pipeline

The baseline indicators, from files or step by step.

- [`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)
  : Run the full Scale-Up pipeline, reading and writing files on disk
- [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
  : Build the firm-year analytical panel and its derived indicators
- [`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md)
  : Descriptive characteristics of scaler and non-scaler populations
- [`compute_persistence()`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md)
  : Growth trajectories before/after a scaling event ("transitions" and
  "evolutions")
- [`compute_contribution()`](https://amannj.github.io/OECDscaleup/reference/compute_contribution.md)
  : Job/turnover creation-destruction accounting by firm sample
- [`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md)
  : Classify scalers by pre-period predictor quartile and regress
  scaling on them

## Scaler analysis

The fastest-growing scalers and scalers growing into mid-caps.

- [`run_scaler_analysis()`](https://amannj.github.io/OECDscaleup/reference/run_scaler_analysis.md)
  : Run the scaler analysis (top scalers, scalers to mid-caps) from
  files
- [`compute_top_scalers()`](https://amannj.github.io/OECDscaleup/reference/compute_top_scalers.md)
  : Top scalers: the fastest-growing high-growth firms
- [`compute_midcap_transitions()`](https://amannj.github.io/OECDscaleup/reference/compute_midcap_transitions.md)
  : Scalers to mid-caps: crossings into mid-cap status

## Trade (optional)

Firm-level international trade in goods.

- [`run_trade_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_trade_pipeline.md)
  : Run the trade package, reading and writing files on disk

- [`build_trade_panel()`](https://amannj.github.io/OECDscaleup/reference/build_trade_panel.md)
  : Collapse transaction-level trade data to a firm-year panel

- [`build_trade_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_trade_accounts_indicators.md)
  :

  Build the trade package's firm-year panel
  (`trade_accounts_indicators`)

- [`compute_trade_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_trade_characteristics.md)
  : Characteristics of exporting and non-exporting scalers (trade
  package)

## Confidentiality statistics

- [`dominance_share()`](https://amannj.github.io/OECDscaleup/reference/dominance_share.md)
  : Dominance-rule concentration share (disclosure-control statistic)
- [`approx_median()`](https://amannj.github.io/OECDscaleup/reference/approx_median.md)
  : Disclosure-safe "approximate median" (average of 5 central sorted
  values)

## Data

- [`variable_dictionary`](https://amannj.github.io/OECDscaleup/reference/variable_dictionary.md)
  : Variable dictionary of the input data
- [`example_scaleup_data()`](https://amannj.github.io/OECDscaleup/reference/example_scaleup_data.md)
  : Simulate example input data
- [`tl3_typology`](https://amannj.github.io/OECDscaleup/reference/tl3_typology.md)
  : TL3/NUTS3 region urbanisation typology
- [`exchange_rates`](https://amannj.github.io/OECDscaleup/reference/exchange_rates.md)
  : Annual average Eurostat exchange rates
