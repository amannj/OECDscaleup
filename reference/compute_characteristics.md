# Descriptive characteristics of scaler and non-scaler populations

Translates `n1_3_characteristics.do`. For every combination of 24 firm
samples (each HGF definition, its "eligible non-scaler" complement,
micro/non-micro) and up to 12 category breakdowns (age, size, sector,
region, ownership, ...), reports firm counts, mean growth rates, the
disclosure-safe
[`approx_median()`](https://amannj.github.io/OECDscaleup/reference/approx_median.md)
of size/age/productivity/financial variables, and (optionally)
[`dominance_share()`](https://amannj.github.io/OECDscaleup/reference/dominance_share.md)
concentration statistics.

## Usage

``` r
compute_characteristics(config, accounts_indicators)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- accounts_indicators:

  The output of
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md).

## Value

A data frame, one row per `(sample, category, group, year)` cell,
matching the column contract of `n13_characteristics_<country>.csv` (PDF
Table 3.3).
