# Build a Scale-Up pipeline configuration

Constructs and validates the configuration shared by every pipeline
stage, passed to every function of the package.

## Usage

``` r
config_scaleup(
  country,
  input_dir,
  output_dir,
  nace_revision,
  nace_rev21_from = NULL,
  dominance = FALSE,
  dom_vars = c("employment", "turnover"),
  dom_num = 2,
  financials_unit = NULL,
  trade_value_unit = NULL
)
```

## Arguments

- country:

  2-letter ISO country code (e.g. `"FR"`). Drives output file naming and
  several country-specific data patches inside
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
  (see `country_patches`).

- input_dir:

  Folder holding `base_financials_<country>.dta` (and
  `plants_RAW_<country>.dta` if available), `exchange_rates.dta`, and
  `tl3_typology.dta`. Must already exist.

- output_dir:

  Folder the final CSV outputs and logs are written to. Must already
  exist.

- nace_revision:

  Required. The NACE revision of the sector codes (`sector_1d`,
  `sector_2d`, `sector_3d`) in `base_financials`: `"2"` (NACE Rev. 2) or
  `"2.1"` (NACE Rev. 2.1, used for statistics from reference year 2025).
  The pipeline's sector rules are written for Rev. 2; Rev. 2.1 codes are
  converted to Rev. 2 first. The build stops if the codes do not match
  the declared revision (a section letter that does not belong to its
  division, division 45 in Rev. 2.1, section V in Rev. 2).

- nace_rev21_from:

  For a panel coded in Rev. 2 up to some year and in Rev. 2.1 after: the
  first year in Rev. 2.1 (with `nace_revision = "2"`). `NULL` (the
  default): one revision for every year.

- dominance:

  Logical; if `TRUE`, every output table gains `dom_<var>`
  disclosure-control columns for each variable in `dom_vars`. Default
  `FALSE`.

- dom_vars:

  Character vector of variables the dominance ratio is computed on (only
  used if `dominance = TRUE`). Default `c("employment", "turnover")`.

- dom_num:

  Number of top units defining the dominance ratio (e.g. `2` means
  "share held by the 2 largest firms"). Default `2`.

- financials_unit:

  The unit of the money variables in `base_financials`: `"EUR thousand"`
  (as the variable dictionary asks) or `"EUR"` (divided by 1000 on
  input). `NULL` (the default) follows the original package: EUR for the
  countries in `country_patches$rescale_to_thousands`, EUR thousand
  otherwise. The build stops when turnover per employee does not fit EUR
  thousand after this step.

- trade_value_unit:

  Trade package only: the unit of `trade_value` in
  `trade_RAW_<country>.dta`, `"EUR"` (divided by 1000) or
  `"EUR thousand"`. `NULL` (the default) follows the trade package: EUR
  for PT and HU, EUR thousand otherwise
  (`country_patches$trade_values_in_eur`).

## Value

An object of class `scaleup_config`.

## Examples

``` r
if (FALSE) { # \dontrun{
cfg <- config_scaleup(
  country = "FR",
  input_dir = "V:/SCALE_UP/DTA/",
  output_dir = "V:/SCALE_UP/TMP/",
  nace_revision = "2",
  dominance = FALSE
)
} # }
```
