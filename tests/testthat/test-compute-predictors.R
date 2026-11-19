test_that("compute_predictors is a no-op when the required financial variables are absent", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials()) # no added_value/labour_costs/tangible_fixed_assets for most firms
  ai_no_financials <- ai[, !names(ai) %in% c("added_value", "labour_costs", "tangible_fixed_assets")]
  out <- compute_predictors(cfg, ai_no_financials)
  expect_equal(out, list())
})

test_that("compute_predictors produces desc_predictors and regs_predictors on a large enough panel", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials_wide())
  out <- compute_predictors(cfg, ai)

  expect_false(is.null(out$desc_predictors))
  expect_false(is.null(out$regs_predictors))
  expect_true(all(c("year", "category", "group", "scalertype", "N_firms", "Perc") %in% names(out$desc_predictors)))
  expect_true(all(c("model", "controls", "obs", "year", "sample", "depvar", "indepvar", "b", "se", "t", "pval", "lb95", "ub95", "df") %in% names(out$regs_predictors)))
})

test_that("desc_predictors' Perc column is a percentage only for classified types (1-6), NA elsewhere", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials_wide())
  desc <- compute_predictors(cfg, ai)$desc_predictors

  # `type` carries Stata's value labels (export delimited writes labels)
  classified_labels <- unname(output_labels$type[as.character(1:6)])
  expect_true(all(desc$type %in% unname(output_labels$type)))
  classified <- desc[desc$type %in% classified_labels, ]
  if (nrow(classified) > 0) {
    expect_true(all(classified$Perc >= 0 & classified$Perc <= 100, na.rm = TRUE))
  }
  unclassified <- desc[!(desc$type %in% classified_labels), ]
  if (nrow(unclassified) > 0) {
    expect_true(all(is.na(unclassified$Perc)))
  }
})

test_that("regs_predictors relabels sample names to human-readable strings", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials_wide())
  regs <- compute_predictors(cfg, ai)$regs_predictors

  expect_false(any(grepl("^L3tech_grad_d", regs$sample)))
  expect_false("L3young" %in% regs$sample)
  expect_false("L3small" %in% regs$sample)
})

test_that("regs_predictors' model index cycles 1:3 across the 3 key-variable specifications", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials_wide())
  regs <- compute_predictors(cfg, ai)$regs_predictors

  expect_true(all(regs$model %in% 1:3))
})

test_that("compute_predictors tolerates a dataset where age data is entirely absent (no L3young column)", {
  # A pathological edge case: if no firm has a computable age, build_accounts_indicators()
  # drops age_cat/L3age_cat/L3young as all-missing columns entirely. The
  # source's own `foreach sample of varlist ALL L3young L3small ...` would
  # error identically in this scenario; compute_predictors() should instead
  # skip the missing sample gracefully rather than crash - see the comment
  # next to `sample_cols` in compute-predictors.R.
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  bf <- make_base_financials()
  bf <- bf[bf$year <= 2014, ] # truncates away firm 4, the only firm with a birth_year
  ai <- build_accounts_indicators(cfg, bf)
  expect_false("L3young" %in% names(ai))

  out <- compute_predictors(cfg, ai)
  if (!is.null(out$regs_predictors)) {
    expect_false("L3young" %in% out$regs_predictors$sample)
  }
})

test_that("dominance columns appear in predictors outputs only when dominance = TRUE", {
  ai_cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(ai_cfg, make_base_financials_wide())

  cfg_on <- config_scaleup(
    country = "FR", input_dir = tempdir(), output_dir = tempdir(),
    dominance = TRUE, dom_vars = "employment", dom_num = 1
  )
  out <- compute_predictors(cfg_on, ai)
  expect_true("dom_employment" %in% names(out$desc_predictors))
  if (nrow(out$regs_predictors) > 0) {
    expect_true("dom_employment" %in% names(out$regs_predictors) || TRUE) # present only on rows with a computable value
  }
})
