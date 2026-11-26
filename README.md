# OECDscaleup

<!-- badges: start -->
<!-- badges: end -->

`OECDscaleup` builds the firm-level "high-growth firm" (HGF) / scale-up
indicators used in the OECD Scale Up project from confidential national firm
microdata, and produces the disclosure-checked aggregate tabulations
(characteristics, transitions/evolutions, contribution, predictors) shared
back with the OECD. It also runs the OECD trade package (firm-level trade in
goods: exporters, importers, exporting scalers).

It is a translation of the OECD's original Stata packages: the "Second
Package" (`MASTER_OECD_p2.do` and its 5 worker `.do` files, version 1.3) and
the trade package (`MASTER_OECD_trade.do`, version 1.0). The
[changelog](https://amannj.github.io/OECDscaleup/news/index.html) lists every
departure from the Stata code and why.

## Installation

The package is not on CRAN. Install it from GitHub with `devtools`:

```r
# install.packages("devtools")
devtools::install_github("amannj/OECDscaleup", build_vignettes = TRUE)
```

This installs the default branch (see "Versions" below); add
`ref = "<branch or tag>"` for another version. The package uses
[renv](https://rstudio.github.io/renv/) to pin its dependency versions
(`renv.lock`); run `renv::restore()` after cloning the repository if you
develop on it.

## Usage

```r
library(OECDscaleup)

cfg <- config_scaleup(
  country = "FR",
  input_dir = "path/to/input",   # base_financials_FR.dta, etc.
  output_dir = "path/to/output",
  nace_revision = "2"            # the NACE revision of the sector codes: "2" or "2.1"
)

# checks the input files against the variable dictionary (counts only)
check_inputs(cfg)

# reads the raw .dta inputs, runs the full pipeline, writes every output CSV
outputs <- run_scaleup_pipeline(cfg)

# the trade package (needs trade_RAW_FR.dta as well)
trade_outputs <- run_trade_pipeline(cfg)
```

Every stage is also a pure function (data frames in, data frames out):

```r
accounts_indicators <- build_accounts_indicators(cfg, base_financials)
characteristics     <- compute_characteristics(cfg, accounts_indicators)
persistence         <- compute_persistence(cfg, accounts_indicators)
contribution        <- compute_contribution(cfg, accounts_indicators)
predictors          <- compute_predictors(cfg, accounts_indicators)
```

See the [getting-started article](https://amannj.github.io/OECDscaleup/articles/OECDscaleup.html)
for a worked example with synthetic data, including the `dominance`
confidentiality statistics.

Firm-level microdata is confidential and never leaves the country whose
national statistical institute holds it, so **no real data ships with this
package**. Every input variable is documented in the articles
[Input data](https://amannj.github.io/OECDscaleup/articles/input-data.html)
and [Input data for the trade package](https://amannj.github.io/OECDscaleup/articles/input-trade-data.html),
and in the package dataset `variable_dictionary`.

## Verification against the Stata code

The R output was compared table by table with the original Stata code (run
in Stata 19.5):

* Second Package: 9 synthetic scenarios built to reach every branch
  (country-specific rescaling, exchange rates and region aggregation,
  optional variables, short panels, dominance statistics, ...) and three
  national firm-level panels (confidential);
* trade package: 6 synthetic scenarios, 2 cases where Stata stops, and one
  national trade dataset (confidential).

All output tables match: rows, keys, labels and counts exactly, other values
within a relative 1e-4. The comparison harness lives outside this
repository, alongside the original Stata code.

## Versions

* Tags `stata-parity-v1_3`, `stata-parity-v1_3-1` (branch `master`) and
  `trade-parity-v1_0`: the R code reproduces the Stata code **including its
  bugs**, for verification.
* Branch `FixStataBugs`: the bugs fixed (listed one by one in the
  changelog), the NACE revision and money unit declared in
  `config_scaleup()`, the input checks, and a performance pass: a panel of
  8 million firm-years runs in about 15 minutes with under 20 GB of memory.
  Reducing the memory further is planned.

## Development

```r
devtools::test()      # run the test suite
devtools::document()  # regenerate NAMESPACE/man pages after editing roxygen comments
devtools::check()     # full package check
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for more.

## License

MIT — see [`LICENSE.md`](LICENSE.md).
