# Build the firm-year analytical panel and its derived indicators

Translates `n0_1_accounts_indicators_v2.do`. Cleans the raw firm-level
panel, optionally folds in establishment-level plant data, and
constructs every derived variable the other 4 pipeline stages depend on:
growth rates, high-growth-firm (HGF) flags, age/size/sector/region
categories, the TL3 urbanisation typology, labour productivity,
multi-factor productivity (Solow residual), and the acquisition
indicator.

## Usage

``` r
build_accounts_indicators(
  config,
  base_financials,
  plants_raw = NULL,
  exchange_rates = NULL,
  tl3_typology = NULL,
  storage_types = NULL
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

  Optional named character vector giving the Stata storage type
  (`"byte"`, `"int"`, `"long"`, `"float"`, `"double"`) of the columns of
  `base_financials`, as stored in its `.dta` file.
  [`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)
  reads it from the file header. Where Stata rescales a `float` (or
  `byte`/`int`) variable in place, the result is stored in single
  precision, and R rounds it the same way. `NULL` (the default) treats
  every column as `double`.

## Value

A data frame, one row per `(idf, year)`, ready to be passed to
[`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md),
[`compute_persistence()`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md),
[`compute_contribution()`](https://amannj.github.io/OECDscaleup/reference/compute_contribution.md),
and
[`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md).

## Details

Unlike the source `.do` file, this is a pure function: it takes
already-loaded data frames and returns the built panel, rather than
reading/writing `.dta` files itself (that I/O now lives in
[`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md),
mirroring `MASTER_OECD_p2.do`'s role). This also means the
row-order-dependent `sort idf year` step in the source is unnecessary
here: every lag/lead below is computed via
[`panel_lag()`](https://amannj.github.io/OECDscaleup/reference/panel_lag.md)
/
[`panel_lead()`](https://amannj.github.io/OECDscaleup/reference/panel_lead.md),
which key off `(idf, year)` values directly rather than physical row
position.
