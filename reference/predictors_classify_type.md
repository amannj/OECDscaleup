# Classify a row into one of the 6 predictor-driven scaler types (plus 0/9/50)

A consequence of the rule structure worth noting explicitly (found while
writing this function's tests, not stated outright in the source): types
`9` ("Missing info") and `50` ("\<50 year-sector N") are overridden by
rules 5/6 ("Transformational"/"Expansionist"), not only by the
strategic-driver rules 1-4. Rules 5 and 6 only test
`MFP_gr`/`gross_profit_gr` against `0` (via
[`stata_num()`](https://amannj.github.io/OECDscaleup/reference/stata_num.md),
so a *missing* `L3q4_MFP`/`L3q4_phys_assets`/ `L3q4_avg_wage` still
satisfies their "not top quartile" precondition) - so whenever
`gross_profit_gr` or `MFP_gr` is itself a known real number, one of 5/6
fires regardless of whether the quartile predictors are missing or
small-cell-flagged. Types 9/50 only survive in the final output when
*both* growth measures are themselves unavailable too.

## Usage

``` r
predictors_classify_type(data)
```
