# Check the input data against the variable dictionary

Run before
[`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)
or
[`run_trade_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_trade_pipeline.md):
checks the input files of a country against
[variable_dictionary](https://amannj.github.io/OECDscaleup/reference/variable_dictionary.md)
and the rules of the build, and lists what would stop the build
(errors), what looks wrong or will be lost (warnings) and what the build
will do to the data (notes). The data are not changed.

## Usage

``` r
check_inputs(
  config,
  base_financials = NULL,
  plants_raw = NULL,
  trade_raw = NULL,
  tl3_typology = NULL,
  exchange_rates = NULL
)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- base_financials, plants_raw, trade_raw:

  Data frames to check; `NULL` reads them from `config$input_dir`
  (`plants_raw` and `trade_raw` only when `base_financials` is `NULL`
  too).

- tl3_typology, exchange_rates:

  Reference data for the data frames given (as the package datasets
  [tl3_typology](https://amannj.github.io/OECDscaleup/reference/tl3_typology.md),
  [exchange_rates](https://amannj.github.io/OECDscaleup/reference/exchange_rates.md));
  read from `config$input_dir` when the files are read.

## Value

Invisibly, a data frame of class `scaleup_input_check` with one row per
check: `dataset`, `variable` (`""` for checks of a whole file),
`priority` (of the dictionary), `check`, `result` (`"error"`,
`"warning"`, `"note"` or `"ok"`) and `detail`. Printing it lists the
errors, warnings and notes.

## Details

The report holds counts, shares and years only, never firm records or
values, so it can be shared, e.g. with the OECD team.

With `base_financials = NULL` (the default) the files are read from
`config$input_dir`, as the pipelines read them:
`base_financials_<CT>.dta` and, where they exist, `plants_RAW_<CT>.dta`,
`trade_RAW_<CT>.dta`, `tl3_typology.dta` and `exchange_rates.dta` (only
the columns the checks need). Otherwise the data frames given are
checked, as the pure functions
([`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md),
[`build_trade_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_trade_accounts_indicators.md))
take them.

Checks:

- every variable of the dictionary: present, of the right type, not all
  missing; share missing; negative values of the variables the build
  sets to missing; values of the 0/1 indicators and of `trade_type`; the
  form of the country, region and product codes;

- `base_financials`: duplicate firm-years; sector codes (NACE divisions,
  groups within their division, section letters against the declared
  `nace_revision`, the sectors the analysis leaves out); `birth_year`
  after `year`; the money unit (turnover per employee, after
  `financials_unit`); the reference files the build needs
  (`tl3_typology` for `region_3d`, `exchange_rates` for the years of a
  non-euro country);

- `plants_RAW` and `trade_RAW`: firms not in `base_financials`; for
  trade, whether exports fit EUR thousand next to turnover (after
  `trade_value_unit`).

## Examples

``` r
cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(),
                      nace_revision = "2")
bf <- data.frame(idf = 1:3, year = 2020, sector_1d = "C", sector_2d = 26, sector_3d = 262,
                 region_2d = "FR10", employment = c(10, 20, 30), turnover = c(1000, 2500, 4000),
                 birth_year = 2010)
check_inputs(cfg, bf)
#> Input check for FR: 0 error(s), 0 warning(s), 28 note(s); 11 check(s) ok.
#> 
#> Notes:
#>   base_financials$age                      absent (nice-to-have, second order; package: optional).
#>   base_financials$exit                     absent (nice-to-have, second order; package: optional).
#>   base_financials$exit_acq                 absent (nice-to-have, first order; package: optional).
#>   base_financials$exit_close               absent (nice-to-have, first order; package: not used).
#>   base_financials$region_3d                absent (nice-to-have, first order; package: optional).
#>   base_financials$exp_revenues_goods       absent (nice-to-have, second order; package: not used).
#>   base_financials$exp_revenues_services    absent (nice-to-have, second order; package: not used).
#>   base_financials$labour_costs             absent (nice-to-have, first order; package: optional).
#>   base_financials$operating_costs          absent (nice-to-have, second order; package: not used).
#>   base_financials$services_costs           absent (nice-to-have, first order; package: not used).
#>   base_financials$depr_amort               absent (nice-to-have, first order; package: optional).
#>   base_financials$interest_costs           absent (nice-to-have, first order; package: optional).
#>   base_financials$intangible_fixed_assets  absent (nice-to-have, second order; package: not used).
#>   base_financials$tangible_fixed_assets    absent (nice-to-have, first order; package: optional).
#>   base_financials$fixed_assets             absent (nice-to-have, second order; package: not used).
#>   base_financials$current_assets           absent (nice-to-have, first order; package: optional).
#>   base_financials$total_assets             absent (nice-to-have, first order; package: optional).
#>   base_financials$loans                    absent (nice-to-have, first order; package: not used).
#>   base_financials$total_liabilities        absent (nice-to-have, first order; package: optional).
#>   base_financials$gross_profit             absent (nice-to-have, second order; package: not used).
#>   base_financials$profit_after_tax         absent (nice-to-have, second order; package: not used).
#>   base_financials$added_value              absent (nice-to-have, first order; package: optional).
#>   base_financials$cash_flow                absent (nice-to-have, second order; package: optional).
#>   base_financials$independent              absent (nice-to-have, first order; package: optional).
#>   base_financials$uco                      absent (nice-to-have, first order; package: optional).
#>   base_financials                          3 firm-years of 3 firms, years 2020 to 2020.
#>   base_financials                          0 of 3 (0.0 %) firm-years in sectors the analysis leaves out (agriculture, finance, public administration, households, extraterritorial).
#>   base_financials$turnover                 too few firm-years with 10-49 employees to check the money unit (financials_unit = "EUR thousand" (the default for this country)).
```
