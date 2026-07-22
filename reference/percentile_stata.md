# Percentile, using Stata's algorithm (Hyndman & Fan "Type 2")

Stata's `summarize, detail` / `_pctile` / `xtile` all use a percentile
algorithm confirmed equivalent to R's `quantile(type = 2)` (Hyndman &
Fan 1996) — *not* R's default `type = 7`. Used here instead of bare
[`stats::quantile()`](https://rdrr.io/r/stats/quantile.html) wherever
the source computes `r(p1)`/`r(p99)` for winsorizing or trimming.

## Usage

``` r
percentile_stata(x, probs)
```

## Arguments

- x:

  A numeric vector.

- probs:

  A numeric vector of probabilities in `[0, 1]`.

## Value

A named numeric vector of the requested percentiles.
