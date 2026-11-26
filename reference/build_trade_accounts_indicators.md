# Build the trade package's firm-year panel (`trade_accounts_indicators`)

The panel of
[`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
with the firm-year trade panel
([`build_trade_panel()`](https://amannj.github.io/OECDscaleup/reference/build_trade_panel.md))
merged in, and exporter/importer flags, first-time exporters
(`y4_exporter`), heavy/light exporting turnover scalers (`HGX10/20`,
`HGNX10/20`), `sector_exporter` and `digit_sect` added. Regions are not
aggregated and there is no `reg_techgrad`.

## Usage

``` r
build_trade_accounts_indicators(
  config,
  base_financials,
  trade_raw,
  plants_raw = NULL,
  exchange_rates = NULL,
  tl3_typology = NULL,
  storage_types = NULL,
  trade_storage_types = NULL
)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- base_financials:

  A data frame of raw firm-level financials, as described in
  [variable_dictionary](https://amannj.github.io/OECDscaleup/reference/variable_dictionary.md)
  and
  [`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md).
  Must contain
  `idf, year, sector_1d, sector_2d, sector_3d, employment, turnover, region_2d`;
  every other column is optional and used only if present.

- trade_raw:

  The transaction-level trade data (see
  [`build_trade_panel()`](https://amannj.github.io/OECDscaleup/reference/build_trade_panel.md)).

- plants_raw:

  Optional data frame of establishment-level data (`plants_RAW` in
  [variable_dictionary](https://amannj.github.io/OECDscaleup/reference/variable_dictionary.md)),
  with columns `idf, idp, year`. If `NULL` (the default), no
  `multiplant` indicator is produced.

- exchange_rates:

  Optional data frame with columns `year, country, rate` (as shipped in
  this package's `exchange_rates` dataset). Required only for the
  non-Euro countries listed in `country_patches$non_euro`.

- tl3_typology:

  Optional data frame with columns `region_3d, typology_access_cities`
  (as shipped in this package's `tl3_typology` dataset). Required only
  if `base_financials` has a `region_3d` column.

- storage_types:

  Optional named character vector giving the storage type (`"byte"`,
  `"int"`, `"long"`, `"float"`, `"double"`) of the columns of
  `base_financials`, as stored in its `.dta` file.
  [`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)
  reads it from the file header. A `float` (or `byte`/`int`) variable
  rescaled to EUR thousand is rounded to single precision, as the file
  stores it. `NULL` (the default) treats every column as `double`.

- trade_storage_types:

  Optional storage types of `trade_raw`.

## Value

A data frame, one row per `(idf, year)` of `base_financials`, ready for
[`compute_trade_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_trade_characteristics.md).
