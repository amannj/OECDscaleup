# OECDscaleup

`OECDscaleup` builds the firm-level “high-growth firm” (HGF) / scale-up
indicators used in the OECD Scale Up project from confidential national
firm microdata, and produces the disclosure-checked aggregate
tabulations (characteristics, transitions/evolutions, contribution,
predictors) shared back with the OECD.

It is a behaviour-preserving translation of the OECD’s original Stata
pipeline (`MASTER_OECD_p2.do` and 5 worker `.do` files, package version
1.3) — see the
[changelog](https://amannj.github.io/OECDscaleup/news/index.html) for
what changed in the translation and why.

## Verification against the Stata code

The R output has been compared table by table with the original Stata
code (run in Stata 19.5) on 9 synthetic scenarios built to reach every
branch (country-specific rescaling, exchange rates and region
aggregation, optional variables, short panels, dominance statistics, …)
and on one full national firm-level dataset (confidential). All output
tables match: rows, keys, labels and counts exactly, other values within
a relative 1e-4.

At the git tag `stata-parity-v1_3` the R code reproduces the Stata code
**including its bugs**. Those bugs are being fixed on the `FixStataBugs`
branch; see “Known issues inherited from the Stata code” in the
changelog. The comparison harness lives outside this repository,
alongside the original Stata code.

Running on a full national panel needs a lot of memory (tens of GB for a
panel of several million firm-years); reducing it is planned.

Firm-level microdata is confidential and never leaves the country whose
national statistical institute holds it, so **no real data ships with
this package** — every input this package needs is documented in
`variable_dictionary_v1.xlsx` from the original Stata package.

## Installation

This package isn’t on CRAN — it’s distributed internally to the OECD
Scale Up project’s participating national statistical institutes.
Install from source:

``` r

# from a local clone/copy of the package source
devtools::install_local("path/to/OECDscaleup")

# or, from a git remote your organisation hosts internally
devtools::install_git("https://your-internal-git-host/OECDscaleup.git")
```

The package uses [renv](https://rstudio.github.io/renv/) to pin its
exact dependency versions (`renv.lock`); run
[`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html)
after cloning the source repository if you’re developing on it directly.

## Usage

``` r

library(OECDscaleup)

cfg <- config_scaleup(
  country = "FR",
  input_dir = "path/to/input",   # base_financials_FR.dta, etc.
  output_dir = "path/to/output"
)

# reads the raw .dta inputs, runs the full pipeline, writes every output CSV
outputs <- run_scaleup_pipeline(cfg)
```

Every pipeline stage is also available as a pure function (data frame
in, data frame out) if you already have your data loaded in R:

``` r

accounts_indicators <- build_accounts_indicators(cfg, base_financials)
characteristics     <- compute_characteristics(cfg, accounts_indicators)
persistence         <- compute_persistence(cfg, accounts_indicators)
contribution        <- compute_contribution(cfg, accounts_indicators)
predictors          <- compute_predictors(cfg, accounts_indicators)
```

See
[`vignette("OECDscaleup")`](https://amannj.github.io/OECDscaleup/articles/OECDscaleup.md)
for a complete walkthrough with a synthetic worked example, including
how to use the `dominance` confidentiality-check statistics.

## Development

``` r

devtools::test()      # run the test suite
devtools::document()  # regenerate NAMESPACE/man pages after editing roxygen comments
devtools::check()     # full package check
```

See
[`CONTRIBUTING.md`](https://amannj.github.io/OECDscaleup/CONTRIBUTING.md)
for more.

## License

MIT — see
[`LICENSE.md`](https://amannj.github.io/OECDscaleup/LICENSE.md).
