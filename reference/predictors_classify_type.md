# Classify a row into one of the 6 predictor-driven scaler types (plus 0/9/50)

Rules are applied in order, a later rule overwriting an earlier one.
Types 9 ("Missing info") and 50 ("\<50 year-sector N") come first so
that the strategic types 1-4 can still be assigned from the quartiles
that are known.

## Usage

``` r
predictors_classify_type(data)
```

## Details

Types 5/6 ("Transformational"/"Expansionist") say that *none* of the
three quartiles is the top one, which is only known when all three are
known.
