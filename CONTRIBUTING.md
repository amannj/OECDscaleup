# Contributing to OECDscaleup

Thanks for contributing. This package is a behaviour-preserving
translation of the OECD Scale Up project’s Stata pipeline, used by
national statistical institutes across the OECD to compute
internationally-comparable high-growth-firm statistics — correctness and
faithfulness to the documented methodology matter more here than in most
packages.

## Before you start

- For anything beyond a small fix, open an issue first to discuss the
  change — especially anything touching indicator definitions
  ([`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)),
  the classification rules in
  [`compute_persistence()`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md)/[`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md),
  or the disclosure-control logic
  ([`dominance_share()`](https://amannj.github.io/OECDscaleup/reference/dominance_share.md),
  [`approx_median()`](https://amannj.github.io/OECDscaleup/reference/approx_median.md)).
- If you’re changing behaviour rather than just refactoring, check
  whether the change should also be reflected in `Pseudocode/*.md` and
  `Analysis/stata.md` in the source repository this package was
  translated from, so the two stay in sync.

## Setup

``` r

renv::restore()               # install the pinned dependency versions
devtools::load_all()          # load the package for interactive development
devtools::test()              # run the test suite
```

## Making a change

1.  Create a branch for your change.
2.  Make the change, adding or updating tests in `tests/testthat/` —
    every exported function should have test coverage for its normal
    case, at least one edge case (missing/NA inputs are the most common
    source of subtle bugs in this codebase — see
    [`stata_num()`](https://amannj.github.io/OECDscaleup/reference/stata_num.md)/[`stata_replace()`](https://amannj.github.io/OECDscaleup/reference/stata_replace.md)’s
    documentation for why), and, for anything touching Stata-derived
    semantics, a test that documents *why* the expected value is what it
    is (not just that it matches).
3.  Run `devtools::document()` if you added or changed any roxygen
    comments, and commit the regenerated files under `man/` and
    `NAMESPACE`.
4.  Run `devtools::test()` and `devtools::check()` locally before
    opening a pull request — both also run in CI on every push and pull
    request.
5.  Update `NEWS.md` with a one-line summary of user-facing changes.

## Code style

- Follow the tidyverse style already used throughout (`snake_case`,
  `dplyr`-based data wrangling, roxygen2 with markdown enabled).
- Prefer adding a well-named, tested helper in `R/utils-panel.R` over
  inlining a workaround for a Stata/R semantic gap —
  [`stata_num()`](https://amannj.github.io/OECDscaleup/reference/stata_num.md)
  and
  [`stata_replace()`](https://amannj.github.io/OECDscaleup/reference/stata_replace.md)
  both started this way, and a third such gap is likely to recur
  elsewhere in the codebase.
- Don’t add speculative configuration options, abstractions, or
  generality beyond what an actual, current requirement needs.

## Reporting bugs

Please include: the function involved, a minimal reproducible example
(synthetic data only — never attach real firm microdata to an issue,
even internally), and, if you believe the translated behaviour diverges
from the original Stata pipeline, which `Pseudocode/*.md` step you
believe it diverges from.
