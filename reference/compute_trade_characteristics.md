# Characteristics of exporting and non-exporting scalers (trade package)

A variant of
[`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md):

## Usage

``` r
compute_trade_characteristics(config, trade_accounts_indicators)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- trade_accounts_indicators:

  The output of
  [`build_trade_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_trade_accounts_indicators.md).

## Value

A list with data frames `p1` and `p2`, matching
`trade_characteristics_p1_<country>.csv` and `..._p2_...`.

## Details

- **p1**: scalers, non-scalers and heavy/light exporting turnover
  scalers (`HGX`/`HGNX`) by exporter status, size-age group, sector
  group x exporter and digital intensity (all at t-3). The second
  package's statistics plus medians of export value, products and
  partners, the mean share of the core product, and the shares of
  first-time exporters and importers. `HGX`/`HGNX` samples are not
  broken down by size-age or digital intensity.

- **p2**: exporting scalers only (exporter at t), by the second
  package's breakdowns, trade statistics only plus the share of heavy
  exporters.
