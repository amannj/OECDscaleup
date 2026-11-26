# Value-label maps (Stata's `label define` / `label values`)

Most category variables in the source Stata code are stored as
hand-assigned integer codes with an attached value-label map, later
`decode`d back to readable strings for output "group" columns. R has no
storage-efficiency reason to keep these as integers, so this package
keeps only the variables whose codes are genuinely compared/ranged
against specific numbers elsewhere in the logic (`age_cat`, `size_cat`,
`tech_grad`, plus the classification codes in
[`compute_persistence()`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md)
and
[`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md))
as integers with a label map here; every other category (`sector_1d`,
`region_2d`, `ind_a38`, `reg_techgrad`, `size_age`, `typology_UR`) is
kept as a plain character string throughout, since nothing ever compares
them to a specific hardcoded value.

## Usage

``` r
value_labels
```

## Details

`multiplant`, `independent`, and `foreign_owned` are a deliberate
dual-use case: they stay `0`/`1` numeric throughout (so they can be
averaged into `share_*` columns), and are only mapped to
`"Yes"`/`"No"`/`"Affiliate"`/ `"Independent"` at the specific points
where the source itself calls `decode` on them (when used as a
`by`-category rather than an outcome).
