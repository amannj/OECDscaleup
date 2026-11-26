# Variable dictionary of the input data

The input variables the OECD Scale Up project asks for, one row per
variable of each input file: the firm-level panel `base_financials`, the
optional establishment file `plants_RAW` and, for the trade package, the
transaction-level `trade_RAW`. It carries the OECD variable dictionary
(definitions, formats, codings, sources, priorities and notes) and adds
what this package does with each variable.
[`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md)
and
[`vignette("input-trade-data")`](https://amannj.github.io/OECDscaleup/articles/input-trade-data.md)
are built from it.

## Usage

``` r
variable_dictionary
```

## Format

A data frame with one row per dataset and variable:

- dataset:

  `"base_financials"`, `"plants_RAW"` or `"trade_RAW"`.

- file:

  File name the pipeline reads from `input_dir`; `<CT>` is the
  two-letter country code of
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- variable:

  Variable name, as the pipeline expects it.

- definition:

  What the variable measures.

- format:

  `"numeric"` or `"string"`.

- coding:

  Values of an indicator or code variable.

- source:

  Usual statistical source: BR (business register), BD (business
  demography), SBS (structural business statistics), ITGS / ITSS
  (international trade in goods / services statistics), IFATS (inward
  foreign affiliates statistics), EuroGroups register.

- sbs_code:

  SBS variable code, where there is one.

- priority:

  The OECD request: `"must-have"`, `"nice-to-have, first order"` or
  `"nice-to-have, second order"`.

- notes:

  Further notes of the OECD dictionary.

- package_requirement:

  What the package needs: `"required"` (the build stops without it),
  `"required unless age_cat is supplied"`,
  `"required (if the file is supplied)"`, `"optional"` (used when
  present) or `"not used"`.

- package_use:

  What the package does with the variable.

- money:

  `TRUE` for money variables, expected in EUR thousand and divided by
  1000 when `financials_unit = "EUR"` (for `trade_value`:
  `trade_value_unit = "EUR"`).

- negatives_missing:

  `TRUE` if the build sets negative values to missing.

## Source

OECD Scale Up project variable dictionary (Phase 3); the package columns
from this package's code. Built by `data-raw/variable_dictionary.R`.
