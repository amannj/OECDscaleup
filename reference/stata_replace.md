# Stata-style conditional replace, preserving the existing value on `NA`

Reproduces Stata's `replace x = value if cond`: rows where `cond` is
`FALSE` **or `NA`** keep their current value of `x` unchanged; only rows
where `cond` is definitely `TRUE` get `value`. This differs from
[`dplyr::if_else()`](https://dplyr.tidyverse.org/reference/if_else.html),
which returns `NA` when `cond` is `NA` — correct for a fresh `gen`-style
computation (there is no "existing value" to fall back to), but wrong
for a `replace`, where an unresolved condition must leave the row
exactly as it was. Used throughout the sequential-overwrite
classification rules (`tech_grad`, `ind_a38`, `type`, `FOLLOW`/`LEAD`,
...) documented in `Pseudocode/*.md` as "later rule overwrites earlier"
chains.

## Usage

``` r
stata_replace(cur, cond, value)
```

## Arguments

- cur:

  The current value of the variable being updated.

- cond:

  A logical vector (may contain `NA`).

- value:

  The replacement value (recycled as needed) where `cond` is `TRUE`.

## Value

A vector the same length/type as `cur`.
