# Input data for the trade package: trade_RAW

OECD project on SME scaling up. For information: <scaleup@oecd.org>,
<juergen.amann@oecd.org>.

The trade package
([`run_trade_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_trade_pipeline.md))
adds firm-level international trade in goods to the scale-up indicators.
It reads the same `base_financials_<CT>.dta` (and, if present,
`plants_RAW_<CT>.dta`, `tl3_typology.dta`, `exchange_rates.dta`) as the
scale-up pipeline, described in
[`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md),
plus one trade file. The same information is in the package dataset
`variable_dictionary`
([`?variable_dictionary`](https://amannj.github.io/OECDscaleup/reference/variable_dictionary.md)).
`check_inputs(cfg)` also checks `trade_RAW_<CT>.dta` when it is in
`input_dir`.

## File

`trade_RAW_<CT>.dta` in `config$input_dir`, where `<CT>` is the
two-letter country code given to
[`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).
It holds transaction-level international trade in goods statistics
(ITGS): one row per firm, year, flow (import or export), destination
country and 8-digit CN product.

## General rules

1.  **Missing values** are coded `.` in numeric variables and `"."` in
    string variables. The package also reads an empty string as missing.
2.  **`trade_value` is in EUR thousand.** Values in euros are declared
    with `config_scaleup(trade_value_unit = "EUR")`, and the build
    divides them by
    1000. (For PT and HU, which delivered euros in earlier rounds,
          `"EUR"` is the default.)
3.  Definitions follow the Eurostat (2022) *European business statistics
    compilers’ manual for international trade in goods statistics,
    detailed data*:
    <https://ec.europa.eu/eurostat/web/products-manuals-and-guidelines/-/ks-gq-22-008>.

## Priorities

All the variables of `trade_RAW` are must-have: the trade build stops if
one is missing.

## What to supply

| Variable | Priority | Definition | Format and coding | Source | Notes |
|:---|:---|:---|:---|:---|:---|
| `idf` | must-have | unique firm-level identifier | numeric |  | Allows the data to be joined with base_financials. |
| `year` | must-have | calendar year | numeric |  |  |
| `trade_type` | must-have | indicator of import or export | numeric; 1 = import; 2 = export |  |  |
| `trade_value` | must-have | statistical value, in EUR thousand | numeric | ITGS | See 8.7.1.2 of the ITGS compilers’ manual. |
| `code_destin` | must-have | the last country to which it is known, at the time of export, that the goods are to be exported | string; two-letter country code, e.g. SE for Sweden | ITGS | See 8.5.3.1 and 8.5.2.1 of the ITGS compilers’ manual. Non-missing for trade_type == 2. |
| `prod_code` | must-have | goods code at CN level (8 digits) | string | ITGS | See 8.4.1 of the ITGS compilers’ manual. |

## What the package does with it

| Variable | The package needs it | What the package does with it |
|:---|:---|:---|
| `idf` | required | Links the trade records to base_financials. Firm-years of base_financials without trade records are non-traders (value 0); trade records of firms not in base_financials are dropped. |
| `year` | required | Trade is summed per firm and year. |
| `trade_type` | required | Splits the flows into imports (imp\_*) and exports (exp\_*). A missing trade_type stops the build. A file with only one flow gives missing values for the other. |
| `trade_value` | required | Summed to exp_value / imp_value per firm-year (exporter, importer, heavy and light exporting scalers HGX / HGNX). Products whose 6-digit total is below 1 (EUR thousand) are left out. Declare config_scaleup(trade_value_unit = “EUR”) for values in euros. |
| `code_destin` | required | Number of export destinations (exp_all_partners) and of EU destinations (exp_eu_partners, EU membership of the year). |
| `prod_code` | required | Cut to its first 6 characters (HS6): number of products (exp_products, imp_products) and the share of the largest product (exp_core_prod, imp_core_prod). |

The trade build
([`build_trade_panel()`](https://amannj.github.io/OECDscaleup/reference/build_trade_panel.md)
and
[`build_trade_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_trade_accounts_indicators.md))
collapses the transactions to one row per firm and year and merges them
onto `base_financials`:

- `exp_value`, `imp_value`: total exports and imports (EUR thousand);
  `exporter`, `importer`: 1 for a positive value;
- `exp_all_partners`, `exp_eu_partners`: number of export destinations,
  all and in the EU;
- `exp_products`, `imp_products`: number of 6-digit products;
  `exp_core_prod`, `imp_core_prod`: share of the largest product;
- `y4_exporter`: first-time exporters over t-3 to t;
- `HGX10`, `HGX20`, `HGNX10`, `HGNX20`: turnover scalers whose export
  growth is at least (heavy exporting) or less than (light exporting)
  half the turnover growth that makes a high-growth firm;
- `sector_exporter`, `digit_sect`: sector group by export status, and by
  the digital intensity of the industry.

Import partner countries are not part of the data, so there are no
import partner counts.
