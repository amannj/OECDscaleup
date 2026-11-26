# Country-specific data patches

Three country-list rules of the build work around idiosyncrasies of
specific national data sources — these are data-source patches, not
general econometric rules (steps 6, 8 and 17 of
[`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)).
They are kept here as one explicit, documented table instead of
scattered `if (country %in% c(...))` chains, so extending them as more
countries join the project only requires editing this table.

## Usage

``` r
country_patches
```

## Format

A named list with three character vectors:

- rescale_to_thousands:

  Countries whose raw financial variables are supplied in EUR and
  divided by 1000, unless the configuration says otherwise
  ([`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md)'s
  `financials_unit`): `PT, ES, RO, SI, HU`.

- non_euro:

  Countries whose `turnover` needs converting to national currency via
  `exchange_rates.dta` (used to detect the "20-200-20"
  employment/turnover jump pattern in national-currency terms):
  `DK, HU, RO, CA, HR`.

- aggregate_small_regions:

  Countries where TL2 regions with a thin count of HGET10 scalers get
  coarsened up to the TL1 level: `AT, CA, HU, IT, NL, ES, RO`.

- trade_values_in_eur:

  Trade package: countries whose `trade_value` is supplied in EUR and
  divided by 1000, unless the configuration says otherwise
  ([`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md)'s
  `trade_value_unit`): `PT, HU`.
