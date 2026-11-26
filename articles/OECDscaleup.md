# Getting Started with OECDscaleup

``` r

library(OECDscaleup)
```

## Installation

The package is not on CRAN. Install it from GitHub with `devtools`:

``` r

# install.packages("devtools")
devtools::install_github("amannj/OECDscaleup", build_vignettes = TRUE)
```

This installs the default branch of the repository
(<https://github.com/amannj/OECDscaleup>); `ref = "<branch or tag>"`
installs another version, for example `ref = "stata-parity-v1_3-1"` for
the version that reproduces the Stata code bug for bug.

## What this package does

This package builds the firm-level “high-growth firm” (HGF) / scale-up
indicators used in the OECD Scale Up project, and produces the
disclosure-checked aggregate tables shared back with the OECD. It
translates the OECD’s original Stata packages: the “Second Package”
(`MASTER_OECD_p2.do` and 5 worker `.do` files, version 1.3) and the
trade package (`MASTER_OECD_trade.do`, version 1.0). The translation was
verified table by table against the Stata code; the
[changelog](https://amannj.github.io/OECDscaleup/news/index.html) lists
every departure from the Stata code since then (bug fixes, the declared
NACE revision and money unit) and why.

Firm-level microdata is confidential and never leaves the country whose
national statistical institute holds it, so **no real data ships with
this package**. Every example below uses small, fabricated data purely
to demonstrate the interface — the actual numbers are meaningless. The
input data are described in
[`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md)
and
[`vignette("input-trade-data")`](https://amannj.github.io/OECDscaleup/articles/input-trade-data.md).

## The pipeline at a glance

Five pipeline functions, matching the five original `.do` files
one-to-one:

1.  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
    — cleans raw firm-level data and constructs every derived indicator
    (growth rates, HGF flags, categories, multi-factor productivity, …).
    Every other stage depends on its output.
2.  [`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md)
    — descriptive statistics of scaler populations.
3.  [`compute_persistence()`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md)
    — growth trajectories before/after a scaling event (“transitions”
    and “evolutions”).
4.  [`compute_contribution()`](https://amannj.github.io/OECDscaleup/reference/compute_contribution.md)
    — job/turnover creation-vs-destruction accounting.
5.  [`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md)
    — classifies scalers by pre-period predictor quartile and regresses
    scaling on those predictors.

Stages 2-5 are independent of each other and only depend on stage 1’s
output. All five are **pure functions** — data frames in, data frames
out — so they can be tested and used without touching the filesystem.

[`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)
performs the file I/O: it reads the raw `.dta` inputs, calls the five
functions above in order, and writes every output as a CSV — mirroring
`MASTER_OECD_p2.do`’s role in the original package.

The trade package works the same way:
[`build_trade_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_trade_accounts_indicators.md)
(the panel with the firm-year trade variables merged in) and
[`compute_trade_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_trade_characteristics.md),
run from files by
[`run_trade_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_trade_pipeline.md).
[`check_inputs()`](https://amannj.github.io/OECDscaleup/reference/check_inputs.md)
checks the input files of both before a run.

The scaler analysis is new, not part of the Stata packages. It works on
the indicators panel these pipelines write:
[`compute_top_scalers()`](https://amannj.github.io/OECDscaleup/reference/compute_top_scalers.md)
ranks the fastest growers among the scalers (top 50, top 1, 5, 10 and 25
%, on three growth indices), and
[`compute_midcap_transitions()`](https://amannj.github.io/OECDscaleup/reference/compute_midcap_transitions.md)
follows scalers and non-scalers into mid-cap status under three
definitions (EU small mid-cap, leaving the EU SME category, 250+
employees), with exit as a competing outcome and coverage diagnostics.
[`run_scaler_analysis()`](https://amannj.github.io/OECDscaleup/reference/run_scaler_analysis.md)
runs both from files. Every variant is written, so the choice among them
is left to the analysis.

## Configuration

Every stage takes a `scaleup_config`, built with
[`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).
This replaces the Stata global macros (`$country`, `$inputdir`, …) set
once in `MASTER_OECD_p2.do`:

``` r

cfg <- config_scaleup(
  country = "FR",
  input_dir = "V:/SCALE_UP/DTA/",
  output_dir = "V:/SCALE_UP/TMP/",
  nace_revision = "2", # the NACE revision of the sector codes: "2" or "2.1"
  # nace_rev21_from = 2025, # for a panel in Rev. 2 up to 2024 and Rev. 2.1 after
  # financials_unit = "EUR", # if the money variables are in euros, not EUR thousand
  dominance = FALSE # set TRUE (with dom_vars/dom_num) if your country
  # requires dominance-rule confidentiality statistics
)
```

`nace_revision` is required: the pipeline’s sector rules are written for
NACE Rev. 2, and Rev. 2.1 codes (used from reference year 2025) are
converted to Rev. 2 first. The build stops if the codes do not match the
declared revision, and if turnover per employee does not fit EUR
thousand after `financials_unit` is applied.

## Running the full pipeline from files

If you have `base_financials_<CT>.dta` (and optionally
`plants_RAW_<CT>.dta`) prepared as described in
[`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md),
alongside this package’s own `tl3_typology`/`exchange_rates` reference
data saved as `.dta` files in the same input folder (exactly as the
original PDF instructions describe):

``` r

cfg <- config_scaleup(nace_revision = "2",
  country = "FR",
  input_dir = "path/to/input",
  output_dir = "path/to/output"
)
check_inputs(cfg) # errors, warnings and notes on the input files (counts only)
outputs <- run_scaleup_pipeline(cfg)
```

This writes `n13_characteristics_FR.csv`, `n13_transitions_FR.csv`, and
so on to `output_dir`, plus the intermediate
`accounts_indicators_FR.dta` back to `input_dir` (used for the manual
confidentiality-check procedure described below). It also returns every
output table as an R list, for programmatic use.

## Running the pure functions directly

If you already have data loaded in R — for instance because you’re
testing, or piping in data from elsewhere in an R workflow — call the
five functions directly instead. Here’s a small synthetic example:

``` r

set.seed(1)
years <- 2010:2018
base_financials <- data.frame(
  idf = rep(1:20, each = length(years)),
  year = rep(years, times = 20),
  sector_1d = "C",
  sector_2d = 26,
  sector_3d = 262,
  region_2d = "FR10",
  birth_year = 2000,
  employment = as.vector(sapply(1:20, function(i) {
    pmax(10, round(stats::rlnorm(1, log(30), 0.3) * (1 + stats::rnorm(1, 0.02, 0.1))^(seq_along(years) - 1)))
  })),
  stringsAsFactors = FALSE
)
base_financials$turnover <- base_financials$employment * 100

cfg <- config_scaleup(nace_revision = "2",
  country = "FR",
  input_dir = tempdir(), # unused by the pure functions themselves
  output_dir = tempdir()
)

accounts_indicators <- build_accounts_indicators(cfg, base_financials)
characteristics <- compute_characteristics(cfg, accounts_indicators)
head(characteristics)
#> # A tibble: 6 × 20
#>    year sample category group       firm_count median_L3age median_L3employment
#>   <dbl> <chr>  <chr>    <chr>            <int>        <dbl>               <dbl>
#> 1  2013 HGE10  ALL      full sample          2           10                26.5
#> 2  2014 HGE10  ALL      full sample          2           11                30.5
#> 3  2015 HGE10  ALL      full sample          2           12                34.5
#> 4  2016 HGE10  ALL      full sample          2           13                39.5
#> 5  2017 HGE10  ALL      full sample          3           14                49.3
#> 6  2018 HGE10  ALL      full sample          3           15                55.7
#> # ℹ 13 more variables: median_L3turnover <dbl>, median_employment <dbl>,
#> #   median_turnover <dbl>, median_employment_growth3y <dbl>,
#> #   median_turnover_growth3y <dbl>, median_employment_futgrowth <dbl>,
#> #   median_turnover_futgrowth <dbl>, mean_employment_growth3y <dbl>,
#> #   mean_turnover_growth3y <dbl>, mean_employment_futgrowth <dbl>,
#> #   mean_turnover_futgrowth <dbl>, share_acquisition <dbl>, L3share_young <dbl>
```

[`compute_persistence()`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md)
returns a named list (`transitions`, `evolutions_p1`, `evolutions_p2`)
since a country’s panel may be too short to produce all three;
[`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md)
similarly returns [`list()`](https://rdrr.io/r/base/list.html) entirely
if `added_value`, `tangible_fixed_assets`, or `labour_costs` aren’t
present in the input data.

``` r

persistence <- compute_persistence(cfg, accounts_indicators)
names(persistence)
#> NULL
```

`persistence` has no elements here — this random 9-year panel doesn’t
happen to contain a firm that scales specifically within the 2014-2016
window (`transitions`) or a panel reaching 2020 (`evolutions`), and
neither is an error. Real country panels spanning more years, with
genuine scaling firms, will populate one or more of `transitions`,
`evolutions_p1`, `evolutions_p2`.

## Disclosure control

Every output table can include `dom_<var>` dominance-concentration
columns — the share of a group’s total held by its largest `dom_num`
firms — when `config$dominance` is `TRUE`. This package’s own
[`dominance_share()`](https://amannj.github.io/OECDscaleup/reference/dominance_share.md)
function implements that statistic and is directly usable to
independently verify a value, the same way the original PDF’s
confidentiality-check worked example describes doing by hand in Stata:

``` r

cfg_dom <- config_scaleup(nace_revision = "2",
  country = "FR", input_dir = tempdir(), output_dir = tempdir(),
  dominance = TRUE, dom_vars = c("employment", "turnover"), dom_num = 2
)
characteristics_dom <- compute_characteristics(cfg_dom, accounts_indicators)
characteristics_dom[1:3, c("category", "group", "sample", "dom_employment")]
#> # A tibble: 3 × 4
#>   category group       sample dom_employment
#>   <chr>    <chr>       <chr>           <dbl>
#> 1 ALL      full sample HGE10               1
#> 2 ALL      full sample HGE10               1
#> 3 ALL      full sample HGE10               1
```

**Cells are not automatically blanked.** As with the original Stata
pipeline, the decision on which cells to suppress before sharing results
externally rests with the analyst / national statistical institute —
this package reports the statistics needed to make that decision, it
does not make it for you.

## Where to look next

- [`?config_scaleup`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md),
  [`?build_accounts_indicators`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md),
  [`?compute_characteristics`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md),
  [`?compute_persistence`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md),
  [`?compute_contribution`](https://amannj.github.io/OECDscaleup/reference/compute_contribution.md),
  [`?compute_predictors`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md),
  [`?run_scaleup_pipeline`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md),
  [`?run_trade_pipeline`](https://amannj.github.io/OECDscaleup/reference/run_trade_pipeline.md),
  [`?check_inputs`](https://amannj.github.io/OECDscaleup/reference/check_inputs.md)
  for full argument/return documentation.
- [`?country_patches`](https://amannj.github.io/OECDscaleup/reference/country_patches.md)
  for the 3 country-specific data patches carried over from the original
  Stata source.
- [`?tl3_typology`](https://amannj.github.io/OECDscaleup/reference/tl3_typology.md),
  [`?exchange_rates`](https://amannj.github.io/OECDscaleup/reference/exchange_rates.md)
  for the bundled OECD reference data.
- [`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md)
  and
  [`vignette("input-trade-data")`](https://amannj.github.io/OECDscaleup/articles/input-trade-data.md)
  for every input variable (also as the dataset `variable_dictionary`).
