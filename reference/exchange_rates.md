# Annual average euro exchange rates

Annual averages of the euro exchange rate (units of national currency
per euro) for the non-euro countries in `country_patches$non_euro`:
Canada (CAD), Denmark (DKK), Croatia (HRK), Hungary (HUF) and Romania
(RON).
[`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
converts `turnover` to national currency with them before computing
turnover growth, so that growth rates are not moved by the exchange
rate. Without a rate for a year, the turnover growth of that year is
missing;
[`check_inputs()`](https://amannj.github.io/OECDscaleup/reference/check_inputs.md)
reports such years.

## Usage

``` r
exchange_rates
```

## Format

A data frame with one row per currency and year:

- currency:

  3-letter currency code (e.g. `"HUF"`).

- year:

  Calendar year.

- rate:

  Annual average, units of national currency per euro.

- country:

  2-letter country code, joined with `year` to the data.

## Source

Eurostat, `ert_bil_eur_a`,
<https://ec.europa.eu/eurostat/databrowser/view/ERT_BIL_EUR_A/default/table?lang=en>;
ECB, <https://data.ecb.europa.eu/data/datasets/EXR>. Built by
`data-raw/prepare-reference-data.R`.

## Details

**Version.** Package version 0.2.0.9000 covers **2008-2025**:

- CAD, DKK, HUF, RON: Eurostat `ert_bil_eur_a`, as extracted from the
  update of 8 July 2026;

- HRK: Croatia adopted the euro on 1 January 2023, and Eurostat no
  longer publishes the kuna series. 2008-2022: the ECB annual averages
  (series `EXR.A.HRK.EUR.SP00.A`, the source of the Eurostat series),
  rounded to 4 decimals; from 2023: the fixed conversion rate 7.53450,
  so that turnover growth over windows ending in 2023 or later equals
  growth in euros.

Version 0.1.0 shipped the rates of the earlier routines, 2008-2022 (the
same Eurostat values for CAD, DKK, HUF and RON; for HRK values within
0.02 % of the ECB averages). See
[`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md)
for the versions by package version.

An `exchange_rates.dta` in the input folder replaces this table in
[`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)
and
[`run_trade_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_trade_pipeline.md).
