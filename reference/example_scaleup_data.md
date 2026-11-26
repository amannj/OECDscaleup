# Simulate example input data

Generates a fabricated firm-level panel in the format of the input files
(see
[`vignette("input-data")`](https://amannj.github.io/OECDscaleup/articles/input-data.md)
and
[`vignette("input-trade-data")`](https://amannj.github.io/OECDscaleup/articles/input-trade-data.md)),
large enough for every part of the package to produce output: firms that
enter and exit, high-growth episodes, a few firms that grow past 250
employees, plants, exports and imports. Used in
[`vignette("OECDscaleup")`](https://amannj.github.io/OECDscaleup/articles/OECDscaleup.md);
useful to try the package without confidential data.

## Usage

``` r
example_scaleup_data(n_firms = 3000, years = 2010:2022, seed = 1)
```

## Arguments

- n_firms:

  Number of firms.

- years:

  Calendar years of the panel (consecutive).

- seed:

  Random seed; the same seed gives the same data. The global random
  number stream is left as it was.

## Value

A list of three data frames:

- `base_financials`: one row per firm and year (`idf`, `year`,
  `birth_year`, sector, region, employment and the financial variables,
  `independent`, `uco`, `exit_acq`); money in EUR thousand;

- `plants_raw`: one row per plant and year (`idf`, `idp`, `year`);

- `trade_raw`: one row per firm, year, flow, destination and product
  (`idf`, `year`, `trade_type`, `trade_value`, `code_destin`,
  `prod_code`).

## Details

The data are random and mean nothing: the sizes, growth rates and ratios
are only roughly plausible. The country is France (`"FR"`), so the
region codes are real French NUTS codes that link to
[tl3_typology](https://amannj.github.io/OECDscaleup/reference/tl3_typology.md).

## Examples

``` r
ex <- example_scaleup_data(n_firms = 200)
sapply(ex, nrow)
#> base_financials      plants_raw       trade_raw 
#>            1614            2181            3199 
head(ex$base_financials)
#>   idf year birth_year sector_1d sector_2d sector_3d region_2d region_3d
#> 1   1 2010       1998         C        25       251      FRB0     FRB02
#> 2   1 2011       1998         C        25       251      FRB0     FRB02
#> 3   1 2012       1998         C        25       251      FRB0     FRB02
#> 4   1 2013       1998         C        25       251      FRB0     FRB02
#> 5   1 2014       1998         C        25       251      FRB0     FRB02
#> 6   1 2015       1998         C        25       251      FRB0     FRB02
#>   employment turnover added_value labour_costs tangible_fixed_assets depr_amort
#> 1        7.2    966.7       297.5        165.3                 736.5       73.7
#> 2        8.1   1075.2       330.9        183.9                 819.1       81.9
#> 3        7.9   1110.9       341.9        190.0                 846.3       84.6
#> 4        9.5   1281.1       394.2        219.0                 976.0       97.6
#> 5       10.9   1693.6       521.2        289.6                1290.3      129.0
#> 6       10.3   1686.4       519.0        288.4                    NA      128.5
#>   cash_flow current_assets total_assets total_liabilities interest_costs
#> 1      95.3          386.7       1123.2             710.2           21.3
#> 2     106.0          430.1           NA             789.8           23.7
#> 3     109.6          444.4       1290.7             816.1           24.5
#> 4        NA          512.4       1488.4             941.1           28.2
#> 5     167.1          677.4       1967.7            1244.1           37.3
#> 6     166.4          674.6       1959.4            1238.9           37.2
#>   independent uco exit_acq
#> 1           1  FR        0
#> 2           1  FR        0
#> 3           1  FR        0
#> 4           1  FR        0
#> 5           1  FR        0
#> 6           1  FR        0
```
