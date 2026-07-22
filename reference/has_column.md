# Check whether a column exists and is non-empty in a data frame

Mirrors the source's pervasive `cap confirm v <var>` / `cap summ <var>`
guards: many financial and category variables are optional per
`variable_dictionary_v1.xlsx`, and whole blocks of logic are silently
skipped (not errored) when a given country's raw data lacks them.

## Usage

``` r
has_column(data, var)
```

## Arguments

- data:

  A data frame.

- var:

  Column name (string).

## Value

`TRUE` if `var` is a column of `data` and has at least one non-missing
value, `FALSE` otherwise.
