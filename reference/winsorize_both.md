# Winsorize both tails to `NA`

`x` is set to `NA` wherever it falls below its own 1st percentile or
above its own 99th percentile (Stata algorithm — see
[`percentile_stata()`](https://amannj.github.io/OECDscaleup/reference/percentile_stata.md)).

## Usage

``` r
winsorize_both(x, lower_prob = 0.01, upper_prob = 0.99)
```

## Arguments

- x:

  A numeric vector.

- lower_prob:

  Lower percentile threshold (default `0.01`).

- upper_prob:

  Upper percentile threshold (default `0.99`).

## Value

A numeric vector the same length as `x`.
