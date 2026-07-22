# Prepare a numeric vector for Stata-style comparison against a constant

In Stata, numeric missing (`.`) is internally a very large finite value,
so **every** comparison operator (`==`, `!=`, `>`, `<`, `>=`, `<=`)
against a missing operand resolves to a definite `TRUE`/`FALSE` — never
a further "missing" result. E.g. `age_cat == 0` is `FALSE` (not missing)
when `age_cat` is missing; `age < 2` is `FALSE`; `age >= 2` is `TRUE`.
R's `==`/ `<`/etc. instead propagate `NA` when either side is `NA`.

## Usage

``` r
stata_num(x)
```

## Arguments

- x:

  A numeric vector.

## Value

A numeric vector with every `NA` replaced by `Inf`.

## Details

`stata_num(x) OP k` (for a literal constant `k`) reproduces Stata's
behaviour by substituting `Inf` for `NA` before comparing — since `Inf`
is larger than any finite `k`, every comparison operator then resolves
the same way Stata's missing-as-largest-value convention would. Only use
this at the exact point of comparison (it must not replace the vector's
stored value elsewhere); only valid when comparing against a literal,
itself never-missing, constant — for comparisons between two
possibly-missing variables, resolve missingness explicitly instead (see
`Pseudocode/00_conventions.md`'s `MISSING` note).
