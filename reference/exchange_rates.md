# Annual average Eurostat exchange rates

Annual average EUR exchange rates for the 5 non-Euro countries this
project covers, 2008-2022. Supplied by the OECD alongside the original
Stata package (`Stata/exchange_rates.dta`); bundled here as-is because
it is small, non-confidential reference data. Used by
[`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
to convert `turnover` to national currency for the countries in
`country_patches$non_euro`.

## Usage

``` r
exchange_rates
```

## Format

A data frame with 75 rows and 4 columns:

- currency:

  3-letter currency code (e.g. `"HRK"`).

- year:

  Calendar year.

- rate:

  Annual average units of national currency per EUR.

- country:

  2-letter country code — the join key used by
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md),
  alongside `year`.

## Source

Eurostat, via the OECD Scale Up project's `exchange_rates.dta` (`Stata/`
in the original package). See
<https://ec.europa.eu/eurostat/databrowser/view/ERT_BIL_EUR_A/default/table?lang=en>.
