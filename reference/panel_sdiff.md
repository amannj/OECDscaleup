# n-period difference panel operator (Stata's `Sn.var`, e.g. `S3.employment`)

`x - panel_lag(x, n, id, time)` — a single subtraction against the value
`n` periods ago (not an iterated first-difference).

## Usage

``` r
panel_sdiff(x, n, id, time)
```

## Arguments

- x:

  Numeric vector to lag.

- n:

  Number of periods to lag by.

- id:

  Panel unit identifier vector (e.g. `idf`), same length as `x`.

- time:

  Panel time vector (e.g. `year`), same length as `x`.

## Value

A vector the same length as `x`.
