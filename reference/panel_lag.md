# Gap-aware panel lag (Stata's `Ln.var`, e.g. `l3.employment`)

Returns the value of `x` for the same panel unit (`id`) at `n` periods
earlier in `time` — read from the record with that exact
`(id, time - n)` key, not from `n` rows earlier. If a firm's panel has a
gap (e.g. observed in 2010, 2011, 2014 but not 2012-2013),
`panel_lag(x, 1)` evaluated on the 2014 row looks for a 2013 record —
which does not exist — and returns `NA`, rather than incorrectly
reaching back to the 2011 row. See `Pseudocode/00_conventions.md`
(`LAG`) for the full specification this implements; verified empirically
against
[`collapse::flag()`](https://fastverse.org/collapse/reference/flag.html)'s
time-aware behaviour before use here.

## Usage

``` r
panel_lag(x, n, id, time)
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
