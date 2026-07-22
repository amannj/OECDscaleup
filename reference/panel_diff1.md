# First-difference panel operator (Stata's `D1.var`)

`x - panel_lag(x, 1, id, time)`.

## Usage

``` r
panel_diff1(x, id, time)
```

## Arguments

- x:

  Numeric vector to lag.

- id:

  Panel unit identifier vector (e.g. `idf`), same length as `x`.

- time:

  Panel time vector (e.g. `year`), same length as `x`.

## Value

A vector the same length as `x`.
