# Dominance-rule concentration share (disclosure-control statistic)

The share of the total held by the `top_n` largest units — a standard
"(n,k)-dominance rule" statistic. Missing values are treated as `0` when
accumulating (matching Stata's
[`sum()`](https://rdrr.io/r/base/sum.html)/`total()` egen functions) and
sort last (never among the "top" units). Returns `NA` if the group has
fewer than `top_n` units, or if the group's total is `0`.

## Usage

``` r
dominance_share(x, top_n)
```

## Arguments

- x:

  A numeric vector (the values within one group, e.g. `employment` or
  `turnover`).

- top_n:

  Number of top units defining the dominance ratio ( `dominance$dom_num`
  from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md)).

## Value

A single numeric value in `[0, 1]`, or `NA`.
