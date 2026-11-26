# Collapse transaction-level trade data to a firm-year panel

The raw trade file has one row per firm, year, flow (`trade_type` 1 =
import, 2 = export), destination country and CN8 product. The result has
one row per firm-year with, for each flow, the total value, the number
of distinct 6-digit products and the largest product's share; for
exports also the number of destination countries (all and EU). Imports
have no partner country in the data, so their partner counts are
dropped.

## Usage

``` r
build_trade_panel(config, trade_raw, storage_types = NULL)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- trade_raw:

  Data frame with `idf, year, trade_type, trade_value` (numeric) and
  `code_destin, prod_code` (string), as in the `trade_RAW` rows of
  [variable_dictionary](https://amannj.github.io/OECDscaleup/reference/variable_dictionary.md)
  ([`vignette("input-trade-data")`](https://amannj.github.io/OECDscaleup/articles/input-trade-data.md)).

- storage_types:

  Optional storage types of `trade_raw`'s columns (see
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md));
  used for the PT/HU rescaling.

## Value

A data frame, one row per `(idf, year)` present in `trade_raw`.

## Details

Values are stored as in the original routines (`float` totals, `double`
sums); products whose 6-digit total is below 1 (thousand EUR) are
blanked before the counts; a flow whose values were all missing stays
missing after the collapse (which would sum them to 0); a flow that is
entirely absent stays missing for every firm.
