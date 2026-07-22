# Decode a category column to its readable string label

Generic dispatcher used everywhere the source calls
`decode <cat>, gen (group)` on a loop variable that could be any of
several category columns. If `cat_name` has an entry in
[value_labels](https://amannj.github.io/OECDscaleup/reference/value_labels.md),
look up each value there; otherwise (e.g. `region_2d`, `ind_a38`,
`reg_techgrad`) the column is already a plain string and is returned
as-is.

## Usage

``` r
decode_category(x, cat_name)
```

## Arguments

- x:

  The category column (integer-coded or already character).

- cat_name:

  Name of the category (used to find the label map).

## Value

A character vector.

## Details

A leading lag prefix (`L1`, `L2`, `L3`, `L6`, ...) is stripped before
the lookup, so e.g. `decode_category(x, "L3age_cat")` resolves to the
same map as `decode_category(x, "age_cat")` — lagged category columns
always mean the same categories as their contemporaneous counterpart.
