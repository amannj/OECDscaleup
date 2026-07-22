# Grouped equal-frequency quartile bins (Stata's `xtile ..., nq(4)`)

Thin wrapper around
[`statar::xtile()`](https://rdrr.io/pkg/statar/man/xtile.html)
documenting the contract this package relies on: `NA` in, `NA` out;
non-missing values split into `n` groups of (approximately) equal size,
numbered `1..n`. See `Pseudocode/00_conventions.md`'s `QUARTILE`
primitive. Callers are responsible for applying this only within
already-grouped data (this package additionally imposes a minimum group
size of 50 before calling this at all — see
[`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md)).

## Usage

``` r
quartile_bin(x, n = 4)
```

## Arguments

- x:

  A numeric vector.

- n:

  Number of equal-frequency bins (default `4`, i.e. quartiles).

## Value

An integer vector of bin numbers `1..n` (or `NA`).

## Details

Stata's own `xtile` is confirmed to use a percentile algorithm
equivalent to R's `quantile(type = 2)` (see
[`percentile_stata()`](https://amannj.github.io/OECDscaleup/reference/percentile_stata.md)
and its source comment);
[`statar::xtile()`](https://rdrr.io/pkg/statar/man/xtile.html) is a
separate, independent R reimplementation, and its exact tie-breaking at
quartile boundaries has not been verified here to match Stata's
bit-for-bit. For this package's use (classifying scalers into
descriptive predictor-quartile groups), this is a low-stakes residual
risk — a handful of firms sitting exactly on a cutpoint could land in an
adjacent bin — flagged rather than silently assumed away.
