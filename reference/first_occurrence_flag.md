# Flag a firm's chronologically first occurrence of a 0/1 event

Returns `1` only on the earliest `time` value (per `id`) at which
`x == 1` — not the first row of each subsequent episode, the single
first occurrence ever. `NA` values in `x` are treated as "not an event"
and do not break the chain (matching Stata's
[`sum()`](https://rdrr.io/r/base/sum.html) treating missing as `0` in
the cumulative-sum idiom the source uses for this same purpose).

## Usage

``` r
first_occurrence_flag(id, time, x)
```

## Arguments

- id:

  Panel unit identifier vector (e.g. `idf`).

- time:

  Panel time vector (e.g. `year`).

- x:

  A 0/1 (or `NA`) numeric vector, the same length as `id`/`time`,
  typically a high-growth-firm flag.

## Value

An integer vector (`0L`/`1L`), the same length and order as `x`.
