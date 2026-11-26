# TL3/NUTS3 region urbanisation typology

Classifies TL3 (NUTS3-equivalent) regions by their access to cities, per
the OECD regional urban/rural typology. Supplied by the OECD alongside
the original Stata package (`Stata/tl3_typology.dta`); bundled here
as-is because it is small, non-confidential reference data (not firm
microdata). Used by
[`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
to derive `typology_UR` when the raw input data has a `region_3d`
column.

## Usage

``` r
tl3_typology
```

## Format

A data frame with 2,598 rows and 8 columns:

- iso3:

  3-letter ISO country code.

- region_3d:

  TL3/NUTS3 region code — the join key used by
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md).

- classificationlatesttl2021:

  TL classification vintage.

- tl:

  Territorial level (always `"3"` in this table).

- regionalnameeng:

  Region name (English).

- regionalnamepublicationeng:

  Region name with country/state suffix.

- typology_access_cities:

  5-letter urbanisation code (`MR-L`, `MR-M`, `NMR-M`, `NMR-S`, `NMR-R`)
  — the column
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
  actually reads and remaps to readable labels.

- typology_UR:

  An OECD-supplied labelled urban/rural code, unused by this package
  (which derives its own `typology_UR` from `typology_access_cities`
  instead, step 18 of
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)).

## Source

OECD Scale Up project, `tl3_typology.dta` (`Stata/` in the original
package).
