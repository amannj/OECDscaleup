# Build a Scale-Up pipeline configuration

Constructs and validates the configuration shared by every pipeline
stage, replacing the Stata global macros (`$country`, `$inputdir`,
`$outputdir`, `$dominance`, `$domvars`, `$dom_num`) set once in
`MASTER_OECD_p2.do` and read implicitly by every downstream `.do` file.
See `Pseudocode/00_conventions.md`'s `CONFIG` primitive and
`Pseudocode/MASTER_OECD_p2.md`.

## Usage

``` r
config_scaleup(
  country,
  input_dir,
  output_dir,
  dominance = FALSE,
  dom_vars = c("employment", "turnover"),
  dom_num = 2
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

## Value

An object of class `scaleup_config`.

## Examples

``` r
if (FALSE) { # \dontrun{
cfg <- config_scaleup(
  country = "FR",
  input_dir = "V:/SCALE_UP/DTA/",
  output_dir = "V:/SCALE_UP/TMP/",
  dominance = FALSE
)
} # }
```
