# Run the scaler analysis (top scalers, scalers to mid-caps) from files

New analysis, after
[`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)
(or
[`run_trade_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_trade_pipeline.md)):
reads the indicators panel those write to `config$input_dir`, preferring
`trade_accounts_indicators_<country>.dta` (it adds exporter status as a
breakdown) over `accounts_indicators_<country>.dta`, runs
[`compute_top_scalers()`](https://amannj.github.io/OECDscaleup/reference/compute_top_scalers.md)
twice (without and with `joint_growth`) and
[`compute_midcap_transitions()`](https://amannj.github.io/OECDscaleup/reference/compute_midcap_transitions.md),
and writes to `config$output_dir`:

- `sa_top_scalers_<country>.csv` (both versions, column `joint_growth`);

- `sa_midcap_incidence_<country>.csv`, `sa_midcap_entry_<country>.csv`,
  `sa_midcap_by_year_<country>.csv`, `sa_midcap_coverage_<country>.csv`,
  `sa_midcap_hazard_<country>.csv`.

## Usage

``` r
run_scaler_analysis(config)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

## Value

Invisibly, a list of the tables written.

## Details

The money variables of the indicators panel are in EUR thousand (the
build rescales them, see `financials_unit` in
[`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md)),
as the mid-cap thresholds need;
[`compute_midcap_transitions()`](https://amannj.github.io/OECDscaleup/reference/compute_midcap_transitions.md)
stops if they look like euros.
