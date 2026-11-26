# Get started

> **Development version.** OECDscaleup is under active development, so
> functions and outputs may still change. Please report problems and
> suggestions as an [issue on
> GitHub](https://github.com/amannj/OECDscaleup/issues) or to
> <scaleup@oecd.org>. Use synthetic data in a report (for example from
> [`example_scaleup_data()`](https://amannj.github.io/OECDscaleup/reference/example_scaleup_data.md)),
> never confidential firm data.

## What OECDscaleup does

OECDscaleup computes indicators on high-growth firms (“scalers”) from
national firm-level microdata, for the OECD Scale Up project, part of
the OECD’s work to understand SMEs and their potential to scale up (see
[Helping SMEs scale
up](https://www.oecd.org/en/about/programmes/helping-smes-scale-up.html)).
It builds on previous OECD routines written in Stata. The firm-level
data never leave the national statistical institute that holds them: the
package produces aggregate tables, with the statistics needed to check
them for confidentiality before they are shared.

It has three parts:

- **the baseline**: a firm-year panel of indicators, and from it tables
  on the characteristics of scalers, what happens before and after
  scaling, their contribution to job and turnover creation, and the
  predictors of scaling;
- **the scaler analysis**: the fastest-growing scalers, and scalers that
  grow into mid-caps;
- **trade** (optional): exporters, importers and exporting scalers, from
  firm-level trade in goods.

## Installation

The package is not on CRAN. Install it from GitHub with `devtools`:

``` r

# install.packages("devtools")
devtools::install_github("amannj/OECDscaleup", build_vignettes = TRUE)
```

``` r

library(OECDscaleup)
```

## The workflow at a glance

This article goes through the whole analysis on fabricated data:

1.  [Example data](#step-1-example-data)
2.  [Configuration](#step-2-configuration)
3.  [Check the inputs](#step-3-check-the-inputs)
4.  [The indicator panel](#step-4-the-indicator-panel)
5.  [Characteristics of scalers](#step-5-characteristics-of-scalers)
6.  [Before and after scaling](#step-6-before-and-after-scaling)
7.  [Contribution to job and turnover
    creation](#step-7-contribution-to-job-and-turnover-creation)
8.  [Predictors of scaling](#step-8-predictors-of-scaling)
9.  [The scaler analysis](#step-9-the-scaler-analysis)
10. [Confidentiality](#step-10-confidentiality)
11. [Running everything from
    files](#step-11-running-everything-from-files)
12. [Optional: trade](#optional-trade)

Steps 4 to 9 are functions that take data frames and return data frames.
In production a country runs them from its files in one go (step 11).
The input variables are described in
[`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md)
and
[`vignette("input-trade-data")`](https://amannj.github.io/OECDscaleup/articles/input-trade-data.md).

## Step 1: Example data

[`example_scaleup_data()`](https://amannj.github.io/OECDscaleup/reference/example_scaleup_data.md)
simulates the input files: a panel of firms with entries, exits,
high-growth episodes and a few firms that grow past 250 employees, plus
plants and trade flows. **The data are random: none of the numbers below
mean anything.**

``` r

ex <- example_scaleup_data(n_firms = 3000, years = 2010:2022, seed = 1)
sapply(ex, nrow)
#> base_financials      plants_raw       trade_raw 
#>           25182           34335           43198
head(ex$base_financials[, 1:10])
#>   idf year birth_year sector_1d sector_2d sector_3d region_2d region_3d employment turnover
#> 1   1 2010       2009         C        26       261      FRB0     FRB06        2.7    250.6
#> 2   1 2011       2009         C        26       261      FRB0     FRB06        2.6    254.4
#> 3   2 2010       2007         C        25       251      FRB0     FRB04       10.2   1497.5
#> 4   2 2011       2007         C        25       251      FRB0     FRB04       10.4   1664.6
#> 5   2 2012       2007         C        25       251      FRB0     FRB04       10.7   1824.6
#> 6   2 2013       2007         C        25       251      FRB0     FRB04       10.7   1649.4
```

`base_financials` is the firm-level panel (one row per firm and year);
`plants_raw` lists each firm’s plants, and `trade_raw` its trade flows
(used in the optional trade part). Money is in EUR thousand.

## Step 2: Configuration

Every function takes a configuration from
[`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md):

``` r

cfg <- config_scaleup(
  country = "FR",
  input_dir = tempdir(),  # where the input files are (used in step 11)
  output_dir = tempdir(), # where the output tables go
  nace_revision = "2"     # NACE revision of the sector codes: "2" or "2.1"
)
```

- `nace_revision` is required. A panel that switches from NACE Rev. 2 to
  Rev. 2.1 also gives `nace_rev21_from`, the first Rev. 2.1 year.
- `financials_unit = "EUR"` declares money variables in euros instead of
  EUR thousand; the build then divides them by 1000.
- `dominance = TRUE` adds the dominance statistics for the
  confidentiality checks (step 10).

## Step 3: Check the inputs

[`check_inputs()`](https://amannj.github.io/OECDscaleup/reference/check_inputs.md)
compares the data with the variable dictionary before anything is
computed. It lists errors (what would stop the build), warnings (what
looks wrong or will be lost) and notes (what the build will do to the
data). The report holds counts and shares only, so it can be shared.

``` r

chk <- check_inputs(cfg, ex$base_financials, ex$plants_raw, ex$trade_raw,
                    tl3_typology = tl3_typology)
#> Input check for FR: 0 error(s), 0 warning(s), 24 note(s); 31 check(s) ok.
#> 
#> Notes:
#>   base_financials$age                      absent (nice-to-have, second order; package: optional).
#>   base_financials$exit                     absent (nice-to-have, second order; package: optional).
#>   base_financials$exit_close               absent (nice-to-have, first order; package: not used).
#>   base_financials$exp_revenues_goods       absent (nice-to-have, second order; package: not used).
#>   base_financials$exp_revenues_services    absent (nice-to-have, second order; package: not used).
#>   base_financials$labour_costs             missing in 1,250 of 25,182 (5.0 %) rows.
#>   base_financials$operating_costs          absent (nice-to-have, second order; package: not used).
#>   base_financials$services_costs           absent (nice-to-have, first order; package: not used).
#>   base_financials$depr_amort               missing in 1,312 of 25,182 (5.2 %) rows.
#>   base_financials$intangible_fixed_assets  absent (nice-to-have, second order; package: not used).
#>   base_financials$tangible_fixed_assets    missing in 1,301 of 25,182 (5.2 %) rows.
#>   base_financials$fixed_assets             absent (nice-to-have, second order; package: not used).
#>   base_financials$total_assets             missing in 1,287 of 25,182 (5.1 %) rows.
#>   base_financials$loans                    absent (nice-to-have, first order; package: not used).
#>   base_financials$gross_profit             absent (nice-to-have, second order; package: not used).
#>   base_financials$profit_after_tax         absent (nice-to-have, second order; package: not used).
#>   base_financials$added_value              missing in 1,268 of 25,182 (5.0 %) rows.
#>   base_financials$cash_flow                missing in 1,300 of 25,182 (5.2 %) rows.
#>   base_financials$uco                      missing in 459 of 25,182 (1.8 %) rows.
#>   base_financials                          25,182 firm-years of 3,000 firms, years 2010 to 2022.
#>   base_financials                          569 of 25,182 (2.3 %) firm-years in sectors the analysis leaves out (agriculture, finance, public administration, households, extraterritorial).
#>   plants_RAW$p_region_2d                   absent (nice-to-have, second order; package: not used).
#>   plants_RAW$p_region_3d                   absent (nice-to-have, second order; package: not used).
#>   plants_RAW$hq                            absent (nice-to-have, second order; package: not used).
```

No errors or warnings here. The notes list the optional variables the
example does not have, and the firms in agriculture and finance, which
the analysis leaves out.

## Step 4: The indicator panel

[`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
cleans the panel and derives every indicator the tables use: growth
rates, the scaler flags, size, age and sector classes, productivity and
financial ratios.

``` r

ai <- build_accounts_indicators(cfg, ex$base_financials, ex$plants_raw,
                                tl3_typology = tl3_typology)
dim(ai)
#> [1] 24613    98
```

The scaler flags compare year *t* with year *t-3*:

| Flag | A firm with at least 10 employees at t-3 whose … |
|----|----|
| `HGE20`, `HGE10` | employment grew by more than 20 % (10 %) a year on average from t-3 to t |
| `HGT20`, `HGT10` | turnover grew by more than 20 % (10 %) a year on average |
| `HGB20`, `HGB10` | employment and turnover both did |
| `HGET20`, `HGET10` | employment or turnover did |
| `MHGE20`, `MHGT20` | the same, for micro firms (fewer than 10 employees at t-3) |

Each flag is compared with its pool (`HGE_pool`, `HGT_pool`, …): the
firms with at least 10 employees at t-3 whose growth is known.
Breakdowns use the firm’s situation at t-3 (variables starting with
`L3`): size class, age class, sector group, region, urban or rural
region, independence, multi-plant and foreign ownership.

The share of employment scalers among the firms that could have scaled:

``` r

pool <- ai[ai$HGE_pool %in% 1, ]
round(100 * tapply(pool$HGE20, pool$year, mean), 1)
#> 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 
#>  2.3  4.3  4.1  3.7  3.6  3.7  4.7  4.8  4.5  4.4
```

## Step 5: Characteristics of scalers

[`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md)
describes the scalers and the non-scalers of their pool, by year and
breakdown: the number of firms, medians and means of size, growth,
productivity and financial ratios at t-3 and at t, and shares (young,
independent, multi-plant, foreign-owned).

``` r

ch <- compute_characteristics(cfg, ai)
x <- ch[ch$year == 2019 & ch$category == "ALL" &
          ch$sample %in% c("HGE20", "HGE20_nonscaler_pool"),
        c("sample", "firm_count", "median_L3employment", "median_employment",
          "median_employment_growth3y", "L3share_young")]
knitr::kable(x, digits = 2)
```

| sample | firm_count | median_L3employment | median_employment | median_employment_growth3y | L3share_young |
|:---|---:|---:|---:|---:|---:|
| HGE20 | 39 | 28.88 | 58.74 | 0.97 | 0.08 |
| HGE20_nonscaler_pool | 785 | 23.68 | 24.14 | 0.03 | 0.09 |

Rows are cells: `sample` is the group of firms, `category` and `group`
the breakdown (`ALL` for all firms; for example `L3size_cat` and a size
class). The medians are approximate medians, the average of the five
central values, so that no single firm’s value is published.

## Step 6: Before and after scaling

[`compute_persistence()`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md)
follows scalers over time:

- **transitions**: firms that scaled in 2014-2016, classified by what
  happened in the three years after (`FOLLOW`: high growth again,
  growing, stable, partial or full reversal, acquisition, missing
  information);
- **evolutions**: firms that scaled in 2017, classified by the three
  years before (`LEAD`) and after.

``` r

pe <- compute_persistence(cfg, ai)
names(pe)
#> [1] "transitions"   "evolutions_p1" "evolutions_p2"
tr <- pe$transitions
x <- tr[tr$hg == "HGE20" & tr$category == "ALL" & tr$year == 2014 &
          !is.na(tr$FOLLOW) & is.na(tr$FOLLOW_othvar), c("year", "FOLLOW", "N_scalers")]
knitr::kable(x)
```

| year | FOLLOW           | N_scalers |
|-----:|:-----------------|----------:|
| 2014 | Missing info     |         4 |
| 2014 | Partial reversal |         1 |
| 2014 | Stable           |         3 |
| 2014 | Growing          |        13 |
| 2014 | HG again         |         5 |

`FOLLOW_othvar` classifies the same firms by the other variable
(turnover for employment scalers).

## Step 7: Contribution to job and turnover creation

[`compute_contribution()`](https://amannj.github.io/OECDscaleup/reference/compute_contribution.md)
splits the change in employment and turnover from t-3 to t into creation
(firms that grew) and destruction (firms that shrank), by group of
firms, for the years 2014, 2017 and 2019-2021.

``` r

co <- compute_contribution(cfg, ai)
p1 <- co$contribution_p1
jobs <- p1[p1$year == 2019 & p1$category == "ALL" & p1$type == "creation" &
             p1$variable == "employment", c("sample", "N_firms", "S3sum")]
jobs$share_of_creation <- round(100 * jobs$S3sum / jobs$S3sum[jobs$sample == "ALL"], 1)
knitr::kable(jobs[jobs$sample %in% c("ALL", "HGE20", "nonHGE20", "entrants"), ])
```

| sample   | N_firms |  S3sum | share_of_creation |
|:---------|--------:|-------:|------------------:|
| ALL      |    1114 | 8932.0 |             100.0 |
| HGE20    |      39 | 2047.0 |              22.9 |
| nonHGE20 |     449 | 3703.7 |              41.5 |
| entrants |     238 | 1813.7 |              20.3 |

## Step 8: Predictors of scaling

[`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md)
classifies scalers by their position at t-3 among the firms of their
sector and year (top quartile of productivity, capital intensity or
wages, …) and estimates linear probability models of scaling on these
predictors. It needs `added_value`, `tangible_fixed_assets` and
`labour_costs`.

``` r

pr <- compute_predictors(cfg, ai)
names(pr)
#> [1] "desc_predictors" "regs_predictors"
table(pr$desc_predictors$type[pr$desc_predictors$category == "ALL"])
#> 
#>        <50 year-sector N             Expansionist             Missing info      Strategic (capital) 
#>                      120                        4                      109                      116 
#>       Strategic (labour)        Strategic (mixed) Strategic (productivity)         Transformational 
#>                      116                      117                      116                      120
reg <- pr$regs_predictors
knitr::kable(reg[reg$sample == "ALL" & reg$depvar == "HGE20" & grepl("^L3q4", reg$indepvar),
                 c("model", "controls", "indepvar", "b", "se", "obs")], digits = 3)
```

| model | controls | indepvar           |      b |    se | obs |
|------:|:---------|:-------------------|-------:|------:|----:|
|     1 | no       | L3q4_MFP_d         |  0.001 | 0.019 | 641 |
|     1 | yes      | L3q4_MFP_d         | -0.006 | 0.019 | 641 |
|     3 | no       | L3q4_avg_wage_d    | -0.009 | 0.017 | 738 |
|     3 | no       | L3q4_phys_assets_d | -0.007 | 0.017 | 738 |
|     3 | yes      | L3q4_avg_wage_d    | -0.010 | 0.017 | 738 |
|     3 | yes      | L3q4_phys_assets_d | -0.010 | 0.017 | 738 |
|     1 | no       | L3q4_MFP_d         | -0.011 | 0.020 | 430 |
|     1 | yes      | L3q4_MFP_d         | -0.013 | 0.020 | 430 |
|     3 | no       | L3q4_avg_wage_d    |  0.000 | 0.017 | 600 |
|     3 | no       | L3q4_phys_assets_d | -0.008 | 0.016 | 600 |
|     3 | yes      | L3q4_avg_wage_d    |  0.001 | 0.018 | 600 |
|     3 | yes      | L3q4_phys_assets_d | -0.006 | 0.017 | 600 |
|     1 | no       | L3q4_MFP_d         | -0.019 | 0.024 | 362 |
|     1 | yes      | L3q4_MFP_d         | -0.014 | 0.024 | 362 |
|     3 | no       | L3q4_avg_wage_d    | -0.006 | 0.025 | 420 |
|     3 | no       | L3q4_phys_assets_d | -0.023 | 0.023 | 420 |
|     3 | yes      | L3q4_avg_wage_d    | -0.011 | 0.026 | 420 |
|     3 | yes      | L3q4_phys_assets_d | -0.023 | 0.024 | 420 |

The `L3q4_*` terms are dummies for the top quartile at t-3;
`desc_predictors` describes the scalers of each type, `regs_predictors`
holds every coefficient of every model.

## Step 9: The scaler analysis

The scaler analysis looks more closely at the scalers of step 4.

**Top scalers.**
[`compute_top_scalers()`](https://amannj.github.io/OECDscaleup/reference/compute_top_scalers.md)
ranks the employment (`HGE20`) and turnover (`HGT20`) scalers of each
year on three measures of growth from t-3 to t: relative growth (`rel`),
absolute growth (`abs`) and the Birch-Schreyer index (`bs`, a mix of
both). It keeps the top 50 and the top 1, 5, 10 and 25 % and describes
each group in the format of step 5, with its share in job and turnover
creation.

``` r

top <- compute_top_scalers(cfg, ai)
x <- top[top$year == 2019 & top$category == "ALL" &
           top$sample %in% c("HGE20_ranked", "HGE20_abs_p25", "HGE20_abs_p10"),
         c("sample", "firm_count", "median_L3employment", "median_employment",
           "share_creation_employment")]
knitr::kable(x, digits = 2)
```

| sample | firm_count | median_L3employment | median_employment | share_creation_employment |
|:---|---:|---:|---:|---:|
| HGE20_ranked | 39 | 28.88 | 58.74 | 0.23 |
| HGE20_abs_p10 | 4 | 128.05 | 314.25 | 0.08 |
| HGE20_abs_p25 | 10 | 85.16 | 186.42 | 0.14 |

`HGE20_ranked` are all the ranked scalers, `HGE20_abs_p10` the top 10 %
by absolute growth. `joint_growth = TRUE` also requires the other
variable (turnover for employment scalers) to grow.

**Scalers to mid-caps.**
[`compute_midcap_transitions()`](https://amannj.github.io/OECDscaleup/reference/compute_midcap_transitions.md)
follows scalers, the non-scalers of their pool and the top scalers from
the start of their growth period (t-3), and records when they cross out
of the SME category, with exit as a competing outcome. Three definitions
are reported side by side:

- `small_midcap`: EU small mid-cap (Recommendation (EU) 2025/1099: under
  750 persons and turnover up to EUR 150 m or balance sheet up to EUR
  129 m); firms that jump past these ceilings are counted separately as
  “to large”;
- `sme_exit`: leaving the EU SME category, up to 3,000 employees;
- `employment_250`: reaching 250 employees, the definition that does not
  need financial data.

``` r

mc <- compute_midcap_transitions(cfg, ai)
names(mc)
#> [1] "incidence" "entry"     "by_year"   "coverage"  "hazard"
inc <- mc$incidence
x <- inc[inc$definition == "employment_250" & inc$category == "ALL" & inc$step == 5 &
           inc$sample %in% c("HGE20", "HGE20_nonscaler_pool"),
         c("sample", "step", "at_risk", "cif_mid", "cif_exit")]
knitr::kable(x, digits = 3)
```

| sample               | step | at_risk | cif_mid | cif_exit |
|:---------------------|-----:|--------:|--------:|---------:|
| HGE20                |    5 |     108 |   0.066 |    0.144 |
| HGE20_nonscaler_pool |    5 |    1078 |   0.012 |    0.176 |

`cif_mid` is the cumulative share of firms that have crossed by that
many years after entry, `cif_exit` the share that exited first. The
other tables give the entries into the risk set (`entry`), crossings by
calendar year (`by_year`), the coverage of the financial data
(`coverage`), and a hazard model of crossing, with scalers compared with
their pool (`hazard`):

``` r

hz <- mc$hazard
knitr::kable(hz[hz$term == "scaler" & hz$definition == "employment_250",
                c("sample", "window", "odds_ratio", "pval", "firms", "events")], digits = 3)
```

| sample                        | window       | odds_ratio |  pval | firms | events |
|:------------------------------|:-------------|-----------:|------:|------:|-------:|
| HGE20 vs HGE20_nonscaler_pool | from_t-3     |      1.366 | 0.535 |  1339 |     32 |
| HGE20 vs HGE20_nonscaler_pool | after_window |      0.587 | 0.399 |  1198 |     21 |
| HGT20 vs HGT20_nonscaler_pool | from_t-3     |      2.786 | 0.008 |  1339 |     36 |
| HGT20 vs HGT20_nonscaler_pool | after_window |      0.572 | 0.276 |  1198 |     21 |

Every variant (cut-offs, growth measures, definitions, the hazard from
t-3 and after the growth period) is written, so the choice among them is
left to the analysis.

## Step 10: Confidentiality

The tables hold aggregates only, and medians are approximate (step 5).
With `dominance = TRUE` in the configuration, each table also gets
`dom_<var>` columns: the share of a cell’s total held by its largest
`dom_num` firms, the statistic of the dominance rule.
[`dominance_share()`](https://amannj.github.io/OECDscaleup/reference/dominance_share.md)
computes it for one cell:

``` r

emp_2019 <- ai$employment[ai$year == 2019 & ai$HGE20 %in% 1]
dominance_share(emp_2019, top_n = 2)
#> [1] 0.198669
```

**Cells are not blanked automatically.** Which cells to suppress before
the tables leave the institute is the decision of the national
statistical institute; the package reports the statistics needed for it.

## Step 11: Running everything from files

In production, the input files are `.dta` files in `input_dir`, named as
in
[`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md),
together with the reference files `tl3_typology.dta` (for `region_3d`)
and `exchange_rates.dta` (for non-euro countries). With the example
data:

``` r

dir <- "path/to/input"
haven::write_dta(ex$base_financials, file.path(dir, "base_financials_FR.dta"))
haven::write_dta(ex$plants_raw, file.path(dir, "plants_RAW_FR.dta"))
haven::write_dta(tl3_typology, file.path(dir, "tl3_typology.dta"))

cfg <- config_scaleup(country = "FR", input_dir = dir, output_dir = "path/to/output",
                      nace_revision = "2")
check_inputs(cfg)          # step 3
run_scaleup_pipeline(cfg)  # steps 4 to 8
run_scaler_analysis(cfg)   # step 9
```

[`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)
writes the indicator panel `accounts_indicators_FR.dta` back to
`input_dir` and the tables `n13_<table>_FR.csv` to `output_dir`;
[`run_scaler_analysis()`](https://amannj.github.io/OECDscaleup/reference/run_scaler_analysis.md)
reads the panel and writes `sa_<table>_FR.csv`.

## Optional: trade

The trade part adds firm-level trade in goods: the transaction-level
file `trade_RAW_<CT>.dta` (see
[`vignette("input-trade-data")`](https://amannj.github.io/OECDscaleup/articles/input-trade-data.md))
is summed per firm and year and merged onto the panel.

``` r

tai <- build_trade_accounts_indicators(cfg, ex$base_financials, ex$trade_raw, ex$plants_raw,
                                       tl3_typology = tl3_typology)
round(100 * tapply(tai$exporter, tai$year, mean, na.rm = TRUE), 1)
#> 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 
#> 20.9 21.4 21.3 21.2 21.0 21.0 21.0 21.8 21.6 22.1 21.1 21.0 21.0
```

Among the turnover scalers, `HGX20` marks the heavy exporting scalers,
whose export growth is at least half of the turnover growth that makes a
scaler, and `HGNX20` the light exporting ones.
[`compute_trade_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_trade_characteristics.md)
describes them in the format of step 5:

``` r

tc <- compute_trade_characteristics(cfg, tai)
x <- tc$p2[tc$p2$year == 2019 & tc$p2$category == "ALL",
           c("sample", "firm_count", "median_exp_value", "share_HGX")]
knitr::kable(x, digits = 2)
```

| sample | firm_count | median_exp_value | share_HGX |
|:-------|-----------:|-----------------:|----------:|
| HGE10  |         30 |          1007.57 |      0.27 |
| HGT10  |         39 |          1110.61 |      0.31 |
| HGET10 |         47 |          1161.66 |      0.26 |
| HGE20  |          4 |          1917.27 |      0.50 |
| HGT20  |          7 |          1655.59 |      0.29 |
| HGET20 |          8 |          1233.26 |      0.25 |

From files, `run_trade_pipeline(cfg)` does the same with
`trade_RAW_FR.dta` in `input_dir` and writes
`trade_accounts_indicators_FR.dta` and
`n16_trade_characteristics_*.csv`. When that panel exists,
[`run_scaler_analysis()`](https://amannj.github.io/OECDscaleup/reference/run_scaler_analysis.md)
uses it and adds the exporter breakdown.

## Where to look next

- [`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md)
  and
  [`vignette("input-trade-data")`](https://amannj.github.io/OECDscaleup/articles/input-trade-data.md):
  every input variable, also as the dataset `variable_dictionary`.
- The [function
  reference](https://amannj.github.io/OECDscaleup/reference/index.html)
  for every argument and output column.
- The [changelog](https://amannj.github.io/OECDscaleup/news/index.html).
