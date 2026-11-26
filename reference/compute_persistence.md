# Growth trajectories before/after a scaling event ("transitions" and "evolutions")

Translates `n1_3_persistence.do`. Computes two related classification
schemes: **transitions** (2014-2016 scaler cohorts, follow-up only) and
**evolutions** (2017 cohort, both lead-up and follow-up, further split
by entrant/incumbent/exiting status). Iterates over 8 `(hgstub, def)`
HGF-definition combinations, each starting fresh from
`accounts_indicators` — nothing computed for one combination carries
into the next.

## Usage

``` r
compute_persistence(config, accounts_indicators)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- accounts_indicators:

  The output of
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md).

## Value

A named list with up to 3 elements — `transitions`, `evolutions_p1`,
`evolutions_p2` — each a data frame matching PDF Table 3.4, or absent
from the list if this country's panel was too short to satisfy any
`(hgstub, def)` combination's length requirement for that output
(mirrors the source: a short panel may produce none of the 3 CSVs).
