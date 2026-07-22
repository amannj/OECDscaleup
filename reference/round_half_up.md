# Round half away from zero (Stata's `round()` convention)

Base R's [`round()`](https://rdrr.io/r/base/Round.html) uses "round half
to even" (banker's rounding): `round(0.5)` is `0`, `round(2.5)` is `2`.
Stata's [`round()`](https://rdrr.io/r/base/Round.html) always rounds a
`.5` away from zero: `round(0.5)` is `1`, `round(2.5)` is `3`. Several
disclosure-control calculations in this package (e.g.
[`approx_median()`](https://amannj.github.io/OECDscaleup/reference/approx_median.md)'s
"center" position) are defined in terms of Stata's convention, so this
helper is used instead of base
[`round()`](https://rdrr.io/r/base/Round.html) wherever the source Stata
code calls [`round()`](https://rdrr.io/r/base/Round.html).

## Usage

``` r
round_half_up(x, digits = 0)
```

## Arguments

- x:

  A numeric vector.

- digits:

  Number of decimal places (default `0`).

## Value

A numeric vector, rounded half-away-from-zero.
