# Run the trade package, reading and writing files on disk

Reads `base_financials_<country>.dta`, `trade_RAW_<country>.dta` and (if
present) `plants_RAW_<country>.dta`, `exchange_rates.dta` and
`tl3_typology.dta` from `config$input_dir`; runs
[`build_trade_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_trade_accounts_indicators.md)
and
[`compute_trade_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_trade_characteristics.md);
writes `trade_accounts_indicators_<country>.dta` to `config$input_dir`
and `n16_trade_characteristics_p1_<country>.csv` / `..._p2_...` to
`config$output_dir`. The second package
([`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md))
is not needed first: the trade package builds its own panel.

## Usage

``` r
run_trade_pipeline(config)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

## Value

Invisibly, a list with the `p1` and `p2` tables.
