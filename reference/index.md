# Package index

## All functions

- [`approx_median()`](https://amannj.github.io/OECDscaleup/reference/approx_median.md)
  : Disclosure-safe "approximate median" (average of 5 central sorted
  values)

- [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
  : Build the firm-year analytical panel and its derived indicators

- [`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md)
  : Descriptive characteristics of scaler and non-scaler populations

- [`compute_contribution()`](https://amannj.github.io/OECDscaleup/reference/compute_contribution.md)
  : Job/turnover creation-destruction accounting by firm sample

- [`compute_persistence()`](https://amannj.github.io/OECDscaleup/reference/compute_persistence.md)
  : Growth trajectories before/after a scaling event ("transitions" and
  "evolutions")

- [`compute_predictors()`](https://amannj.github.io/OECDscaleup/reference/compute_predictors.md)
  : Classify scalers by pre-period predictor quartile and regress
  scaling on them

- [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md)
  : Build a Scale-Up pipeline configuration

- [`country_patches`](https://amannj.github.io/OECDscaleup/reference/country_patches.md)
  : Country-specific data patches

- [`cut_stata()`](https://amannj.github.io/OECDscaleup/reference/cut_stata.md)
  :

  Bin a numeric variable into intervals (Stata's
  `egen ... = cut(x), at(...)`)

- [`decode_category()`](https://amannj.github.io/OECDscaleup/reference/decode_category.md)
  : Decode a category column to its readable string label

- [`dominance_share()`](https://amannj.github.io/OECDscaleup/reference/dominance_share.md)
  : Dominance-rule concentration share (disclosure-control statistic)

- [`exchange_rates`](https://amannj.github.io/OECDscaleup/reference/exchange_rates.md)
  : Annual average Eurostat exchange rates

- [`first_occurrence_flag()`](https://amannj.github.io/OECDscaleup/reference/first_occurrence_flag.md)
  : Flag a firm's chronologically first occurrence of a 0/1 event

- [`has_column()`](https://amannj.github.io/OECDscaleup/reference/has_column.md)
  : Check whether a column exists and is non-empty in a data frame

- [`panel_diff1()`](https://amannj.github.io/OECDscaleup/reference/panel_diff1.md)
  :

  First-difference panel operator (Stata's `D1.var`)

- [`panel_lag()`](https://amannj.github.io/OECDscaleup/reference/panel_lag.md)
  :

  Gap-aware panel lag (Stata's `Ln.var`, e.g. `l3.employment`)

- [`panel_lead()`](https://amannj.github.io/OECDscaleup/reference/panel_lead.md)
  :

  Gap-aware panel lead (Stata's `Fn.var`, e.g. `f3.employment`)

- [`panel_sdiff()`](https://amannj.github.io/OECDscaleup/reference/panel_sdiff.md)
  :

  n-period difference panel operator (Stata's `Sn.var`, e.g.
  `S3.employment`)

- [`percentile_stata()`](https://amannj.github.io/OECDscaleup/reference/percentile_stata.md)
  : Percentile, using Stata's algorithm (Hyndman & Fan "Type 2")

- [`quartile_bin()`](https://amannj.github.io/OECDscaleup/reference/quartile_bin.md)
  :

  Grouped equal-frequency quartile bins (Stata's `xtile ..., nq(4)`)

- [`round_half_up()`](https://amannj.github.io/OECDscaleup/reference/round_half_up.md)
  :

  Round half away from zero (Stata's
  [`round()`](https://rdrr.io/r/base/Round.html) convention)

- [`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)
  : Run the full Scale-Up pipeline, reading and writing files on disk

- [`stata_num()`](https://amannj.github.io/OECDscaleup/reference/stata_num.md)
  : Prepare a numeric vector for Stata-style comparison against a
  constant

- [`stata_replace()`](https://amannj.github.io/OECDscaleup/reference/stata_replace.md)
  :

  Stata-style conditional replace, preserving the existing value on `NA`

- [`tl3_typology`](https://amannj.github.io/OECDscaleup/reference/tl3_typology.md)
  : TL3/NUTS3 region urbanisation typology

- [`winsorize_both()`](https://amannj.github.io/OECDscaleup/reference/winsorize_both.md)
  :

  Winsorize both tails to `NA`

- [`winsorize_upper()`](https://amannj.github.io/OECDscaleup/reference/winsorize_upper.md)
  :

  Winsorize the upper tail to `NA`
