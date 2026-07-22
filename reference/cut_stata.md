# Bin a numeric variable into intervals (Stata's `egen ... = cut(x), at(...)`)

Assigns each value of `x` to the half-open interval `[at[i], at[i+1])`
it falls in, labelling it with the interval's **lower bound**. The final
breakpoint is exclusive: values equal to or beyond it (and values below
the first breakpoint) return `NA`, matching Stata's
[`cut()`](https://rdrr.io/r/base/cut.html) egen function.

## Usage

``` r
cut_stata(x, at)
```

## Arguments

- x:

  A numeric vector.

- at:

  A numeric vector of breakpoints, in increasing order.

## Value

A numeric vector of interval lower bounds (or `NA`).
