# OECD regional typology of small (TL3) regions

The OECD territorial classification of small (TL3) regions, with their
typologies.
[`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
joins it to `region_3d` to give the urban/rural breakdown `typology_UR`
(from the access-to-cities typology), for the classification declared in
`config_scaleup(tl_classification = )`: `"TL2024"` (the default; NUTS
2024 for EU countries) or `"TL2021"` (NUTS 2021).

## Usage

``` r
tl3_typology
```

## Format

A data frame, one row per classification and TL3 region:

- classification:

  `"TL2024"` or `"TL2021"`.

- iso3:

  3-letter ISO country code.

- region_3d:

  TL3 region code (the NUTS 3 code for EU countries): the key joined to
  `region_3d`.

- region_name:

  Region name (English).

- tl3c_id:

  TL2024 only: the aggregated metropolitan region (TL3C) the region
  belongs to; the OECD advises aggregating to it when several TL3
  regions form one metropolitan region.

- typology_access_level1:

  Access to cities, level 1: `MR` (metropolitan region) or `NM`
  (non-metropolitan).

- typology_access_cities:

  Access to cities, level 2: `MR_L` (metropolitan, functional urban area
  above 1.5 million inhabitants), `MR_M` (metropolitan, 250,000 to 1.5
  million), `NMR_M` (near a functional urban area above 250,000),
  `NMR_S` (near a functional urban area of 50,000 to 250,000), `NMR_R`
  (remote); `..` not available. The column the package uses.

- typology_rural_urban:

  The earlier rural/urban typology: `3_PU` predominantly urban, `3_IN`
  intermediate, `3_PR` predominantly rural.

- typology_rural_urban_extended:

  TL2024 only: the extended rural/urban typology (close to a city or
  remote), for some countries.

## Source

OECD territorial correspondence table TL2024 (version of 20 November
2026), OECD geographical definitions,
<https://www.oecd.org/en/data/datasets/oecd-geographical-definitions.html>
(<http://oe.cd/geostats>). Built by `data-raw/prepare-reference-data.R`.

## Details

**Version.** Package version 0.2.0.9000 ships the OECD territorial
correspondence table TL2024, version of **20 November 2026**: its TL2024
regions (2,628 TL3 regions in 49 countries) and its TL2021 regions
(2,598 regions in 44 countries). The OECD revises the typologies in this
table: the access-to-cities typology of non-metropolitan regions in EU
countries and of non-EU countries was still being updated in that
version, and Türkiye has no access-to-cities typology in TL2024
(commuting data are not available). Version 0.1.0 shipped the TL2021
table of the earlier routines (the same 2,598 regions and typology). See
[`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md)
for the versions by package version.

Between TL2021 and TL2024 the TL3 codes changed in Germany, Finland, the
United Kingdom, Latvia, the Netherlands, Norway and Portugal, and the
access-to-cities typology of about 200 regions changed (most in Germany
and Türkiye).
[`check_inputs()`](https://amannj.github.io/OECDscaleup/reference/check_inputs.md)
reports how many region codes of the data match each classification.

A `tl3_typology.dta` in the input folder replaces this table in
[`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)
and
[`run_trade_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_trade_pipeline.md);
a table without a `classification` column is used as it is.
