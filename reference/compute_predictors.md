# Classify scalers by pre-period predictor quartile and regress scaling on them

Translates `n1_3_predictors.do` (`Pseudocode/n1_3_predictors.md`). The
entire procedure is a no-op unless `added_value`,
`tangible_fixed_assets`, and `labour_costs` all exist in
`accounts_indicators`. First classifies first-time-eligible scalers into
6 "driver" types based on which pre-period predictor(s) (productivity,
capital intensity, wages) sit in the top sector-year quartile, then fits
a battery of linear-probability regressions of scaling on those same
predictors.

## Usage

``` r
compute_predictors(config, accounts_indicators)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- accounts_indicators:

  The output of
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md).

## Value

A named list with `desc_predictors` and `regs_predictors` data frames
(PDF Tables 3.6/3.7), or an empty list if the precondition isn't met.
