# Run the full Scale-Up pipeline, reading and writing files on disk

Reads the raw inputs from `config$input_dir`, runs
[`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
followed by the four independent downstream stages
([`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md),
[`compute_persistence()`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md),
[`compute_contribution()`](https://amannj.github.io/OECDscaleup/reference/compute_contribution.md),
[`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md)),
and writes every output CSV to `config$output_dir` plus the intermediate
`accounts_indicators_<country>.dta` back to `config$input_dir` (as the
source PDF documents it - used for the manual confidentiality-check
worked example).

## Usage

``` r
run_scaleup_pipeline(config)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

## Value

Invisibly, a named list of every non-`NULL` output table produced (the
same tables written to `config$output_dir`).

## Details

This is the only function in the package that performs file I/O; every
`compute_*()`/`build_*()` function is a pure, directly-testable
data-frame-in-data-frame-out transformation. Call the pure functions
directly if you already have the inputs loaded in R.

The regional typology and the exchange rates are the package's
[tl3_typology](https://amannj.github.io/OECDscaleup/reference/tl3_typology.md)
(for `config$tl_classification`) and
[exchange_rates](https://amannj.github.io/OECDscaleup/reference/exchange_rates.md),
unless `tl3_typology.dta` or `exchange_rates.dta` is in
`config$input_dir`.
