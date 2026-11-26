# Job/turnover creation-destruction accounting by firm sample

Translates `n1_3_contribution.do`. For 5 selected years and 16 firm
samples, computes total employment/turnover created vs. destroyed over
the prior 3-year window, treating entrants as creating their full
current value and exits as destroying their full 3-years-ago value.

## Usage

``` r
compute_contribution(config, accounts_indicators)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- accounts_indicators:

  The output of
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md).

## Value

A named list with two data frames, `contribution_p1` (creation/
destruction detail) and `contribution_p2` (undifferentiated aggregate),
matching PDF Table 3.5.
