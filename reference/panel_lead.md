# Gap-aware panel lead (Stata's `Fn.var`, e.g. `f3.employment`)

Symmetric to
[`panel_lag()`](https://amannj.github.io/OECDscaleup/reference/panel_lag.md):
the value of `x` for the same `id` at `n` periods later in `time`, or
`NA` if that exact key does not exist.

## Usage

``` r
panel_lead(x, n, id, time)
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
