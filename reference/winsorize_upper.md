# Winsorize the upper tail to `NA`

`x` is set to `NA` wherever it exceeds its own 99th percentile (Stata
algorithm — see
[`percentile_stata()`](https://amannj.github.io/OECDscaleup/reference/percentile_stata.md));
values at or below the 99th percentile, and missing values, are returned
unchanged.

## Usage

``` r
winsorize_upper(x, upper_prob = 0.99)
```

## Arguments

- x:

  A numeric vector.

- upper_prob:

  Upper percentile threshold (default `0.99`).

## Value

A numeric vector the same length as `x`.
