# Disclosure-safe "approximate median" (average of 5 central sorted values)

A confidentiality-preserving stand-in for a true median: true medians
are not published per this project's disclosure rules. Sorts `x`
ascending (`NA` sorted last, matching Stata's convention), then averages
the (up to) 5 values centred on position
`round_half_up(n_non_missing / 2)`. This is **not** interchangeable with
a true median except by coincidence — do not replace with
[`median()`](https://rdrr.io/r/stats/median.html).

## Usage

``` r
approx_median(x)
```

## Arguments

- x:

  A numeric vector (the values within one group).

## Value

A single numeric value (or `NA` if `x` has no non-missing values).

## Details

Typically used inside a
[`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
/ grouped aggregation, one call per output cell, rather than reproducing
the source's compute-then-collapse-then-mean row-broadcast mechanics
(which reduce to exactly this value).
