# OECDscaleup

> **Development version.** OECDscaleup is under active development, so
> functions and outputs may still change. Please report problems and
> suggestions as an [issue on
> GitHub](https://github.com/amannj/OECDscaleup/issues) or to
> <scaleup@oecd.org>. Use synthetic data in a report (for example from
> [`example_scaleup_data()`](https://amannj.github.io/OECDscaleup/reference/example_scaleup_data.md)),
> never confidential firm data.

OECDscaleup computes indicators on high-growth firms (“scalers”) from
national firm-level microdata, for the OECD Scale Up project. It is part
of the OECD’s work to understand SMEs and their potential to scale up:
see [Helping SMEs scale
up](https://www.oecd.org/en/about/programmes/helping-smes-scale-up.html).
It builds on previous OECD routines written in Stata.

The firm-level data never leave the national statistical institute that
holds them: the package produces aggregate tables, with the statistics
needed to check them for confidentiality before they are shared. It
covers:

- **the baseline**: a firm-year panel of indicators, and tables on the
  characteristics of scalers, what happens before and after scaling,
  their contribution to job and turnover creation, and the predictors of
  scaling;
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

## Getting started

- [Get
  started](https://amannj.github.io/OECDscaleup/articles/OECDscaleup.html):
  a step-by-step walkthrough of the whole analysis on simulated data.
- [Input
  data](https://amannj.github.io/OECDscaleup/articles/input-data.html)
  and [Input data for
  trade](https://amannj.github.io/OECDscaleup/articles/input-trade-data.html):
  every input variable, how it is defined and what the package does with
  it.

In short, with the input files of a country in `input_dir`:

``` r

library(OECDscaleup)

cfg <- config_scaleup(
  country = "FR",
  input_dir = "path/to/input",   # base_financials_FR.dta, ...
  output_dir = "path/to/output",
  nace_revision = "2"            # the NACE revision of the sector codes: "2" or "2.1"
)

check_inputs(cfg)          # checks the input files (counts only)
run_scaleup_pipeline(cfg)  # the baseline tables
run_scaler_analysis(cfg)   # top scalers and scalers to mid-caps
run_trade_pipeline(cfg)    # optional: trade
```

No real data ship with the package;
[`example_scaleup_data()`](https://amannj.github.io/OECDscaleup/reference/example_scaleup_data.md)
simulates input data to try it.

## Versions

- The default branch `ScalerAnalysis` holds the development version
  described here.
- The branch `Stata-to-R` holds version 0.1.0, the first translation of
  the OECD routines to R.

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

CC0 1.0 Universal (public domain dedication) — see
[`LICENSE.md`](https://amannj.github.io/OECDscaleup/LICENSE.md).
