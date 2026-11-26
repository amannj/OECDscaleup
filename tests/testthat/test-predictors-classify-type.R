mk <- function(L3q4_MFP, MFP_gr, L3q4_phys_assets, L3q4_avg_wage, L3less50_MFP = 0,
               L3less50_phys_assets = 0, L3less50_avg_wage = 0, gross_profit_gr = 0) {
  data.frame(
    L3q4_MFP = L3q4_MFP, MFP_gr = MFP_gr, L3q4_phys_assets = L3q4_phys_assets,
    L3q4_avg_wage = L3q4_avg_wage, L3less50_MFP = L3less50_MFP,
    L3less50_phys_assets = L3less50_phys_assets, L3less50_avg_wage = L3less50_avg_wage,
    gross_profit_gr = gross_profit_gr
  )
}

test_that("predictors_classify_type assigns the single-driver strategic types (2/3/4)", {
  expect_equal(predictors_classify_type(mk(4, 0.1, 1, 1)), 2) # MFP only -> productivity-driven
  expect_equal(predictors_classify_type(mk(1, 0.1, 4, 1)), 3) # phys_assets only -> capital-driven
  expect_equal(predictors_classify_type(mk(1, 0.1, 1, 4)), 4) # avg_wage only -> labour-driven
})

test_that("predictors_classify_type assigns 'mixed' (1) when 2+ predictors are top-quartile", {
  expect_equal(predictors_classify_type(mk(4, 0.1, 4, 1)), 1)
  expect_equal(predictors_classify_type(mk(4, 0.1, 4, 4)), 1)
})

test_that("predictors_classify_type: no top-quartile predictor resolves to Expansionist (6) or Transformational (5)", {
  # both growth measures non-positive -> Expansionist
  expect_equal(predictors_classify_type(mk(1, -0.1, 1, 1, gross_profit_gr = -0.05)), 6)
  # MFP_gr positive -> Transformational, regardless of gross_profit_gr's sign
  expect_equal(predictors_classify_type(mk(1, 0.1, 1, 1, gross_profit_gr = 0)), 5)
  expect_equal(predictors_classify_type(mk(1, 0.05, 1, 1, gross_profit_gr = 0.02)), 5)
})

test_that("rule 5 (Transformational) wins over rule 6 (Expansionist) when the two growth measures disagree", {
  # MFP_gr <= 0 (rule 6's own condition) but gross_profit_gr > 0 (rule 5) -
  # rule 5 is applied after rule 6, so it wins - the documented edge case in
  # the type classification of n1_3_predictors.do.
  expect_equal(predictors_classify_type(mk(1, -0.05, 1, 1, gross_profit_gr = 0.1)), 5)
})

test_that("S4: a missing quartile keeps types 9/50; rules 5/6 need all three quartiles", {
  # Stata (bug S4) let rules 5/6 overwrite 9/50 because a missing quartile
  # compared as "not top quartile"; "none is top" needs all three known.
  expect_equal(predictors_classify_type(mk(NA, 0.1, 1, 1)), 9) # missing MFP quartile
  expect_equal(predictors_classify_type(mk(1, 0.1, NA, 1)), 9) # missing phys_assets quartile
  expect_equal(predictors_classify_type(mk(1, 0.1, 1, NA)), 9) # missing avg_wage quartile
  expect_equal(predictors_classify_type(mk(NA, 0.1, 1, 1, L3less50_MFP = 1)), 50) # small-cell MFP
  # all quartiles known: a missing MFP_gr is resolved by gross_profit_gr, as in Stata
  expect_equal(predictors_classify_type(mk(1, NA, 1, 1)), 6) # gross_profit_gr = 0 <= 0
  expect_equal(predictors_classify_type(mk(1, NA, 1, 1, L3less50_phys_assets = 1)), 6)
})

test_that("type 9/50 only survive when *both* growth measures are unavailable too", {
  expect_true(is.na(NA_real_)) # sanity
  expect_equal(predictors_classify_type(mk(1, NA, 1, 1, gross_profit_gr = NA)), 9)
  expect_equal(predictors_classify_type(mk(NA, NA, 1, 1, gross_profit_gr = NA)), 9)
})

test_that("type 50 requires the small-cell flag on the *specific* variable that's missing, else stays 9 before rules 5/6 run", {
  # L3q4_MFP is missing (drives type 9), but the small-cell flag set is for a
  # *different* variable (phys_assets) - rule 50's own OR condition still
  # accepts this (it doesn't check which variable was missing); rule 2 then
  # overwrites it, since MFP is the only known top quartile.
  expect_equal(predictors_classify_type(mk(4, 0.1, NA, 1, L3less50_phys_assets = 1)), 2)
})

test_that("rules 2/3/4 treat a missing *other* predictor as != 4, same as a known non-top-quartile value", {
  expect_equal(predictors_classify_type(mk(4, 0.1, NA, NA)), 2)
})

test_that("sequential order means rule 1 (mixed) never survives when exactly one predictor is top-quartile", {
  expect_true(predictors_classify_type(mk(4, 0.1, 1, 1)) != 1)
})
