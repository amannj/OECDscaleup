test_that("a panel too short for either gate produces neither transitions nor evolutions", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  # make_base_financials() spans 2010-2018 (9 years): long enough for the
  # transitions gate but not the evolutions gate (needs finyear >= 2020) --
  # and neither of its firms scales within the 2014-2016 transitions window.
  ai <- build_accounts_indicators(cfg, make_base_financials())
  out <- compute_persistence(cfg, ai)

  expect_null(out$transitions) # no firm scales specifically in 2014-2016
  expect_null(out$evolutions_p1)
  expect_null(out$evolutions_p2)
})

test_that("compute_persistence produces transitions and evolutions on a long-enough panel", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials_long())
  out <- compute_persistence(cfg, ai)

  expect_false(is.null(out$transitions)) # firm 12 scales in 2015
  expect_false(is.null(out$evolutions_p1)) # firm 10 scales in 2017
  expect_false(is.null(out$evolutions_p2))
})

test_that("transitions output has the expected columns and only covers the 2014-2016 cohort", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials_long())
  tr <- compute_persistence(cfg, ai)$transitions

  expect_true(all(c("year", "FOLLOW", "FOLLOW_othvar", "category", "group", "hg", "var", "N_scalers") %in% names(tr)))
  expect_true(all(tr$year %in% 2014:2016))
  # every row has exactly one of FOLLOW / FOLLOW_othvar populated (see collapse_by_group_year)
  expect_true(all(xor(!is.na(tr$FOLLOW), !is.na(tr$FOLLOW_othvar))))
})

test_that("evolutions_p1 small-cell-suppresses a lone scaler to 'Aggregated' (9)", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials_long())
  p1 <- compute_persistence(cfg, ai)$evolutions_p1

  expect_true(all(c("LEAD", "LEAD_othvar", "FOLLOW", "FOLLOW_othvar", "category", "group", "N_scalers", "avgN_years_gr") %in% names(p1)))
  # this fixture has exactly 1 scaling firm per hg-definition (N_scalers <= 5),
  # so every cell must be suppressed to the "Aggregated" tier (9) on all four
  # classification dimensions -- see collapse_evolution_cell()'s suppress step.
  expect_true(all(p1$N_scalers <= 5))
  # written as Stata's export delimited writes them: the value label, not the code
  expect_true(all(p1$LEAD == "Aggregated" & p1$LEAD_othvar == "Aggregated" &
    p1$FOLLOW == "Aggregated" & p1$FOLLOW_othvar == "Aggregated"))
})

test_that("evolutions_p2 classifies the scaling firm as an incumbent (continuous panel presence)", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials_long())
  p2 <- compute_persistence(cfg, ai)$evolutions_p2

  expect_true(all(c("entrant", "incumbent", "exiting", "category", "group", "N_scalers") %in% names(p2)))
  all_cell <- p2[p2$category == "ALL", ]
  expect_true(any(all_cell$incumbent == 1 & all_cell$N_scalers > 0))
})

test_that("dominance columns appear in persistence outputs only when dominance = TRUE", {
  ai_cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(ai_cfg, make_base_financials_long())

  cfg_on <- config_scaleup(nace_revision = "2",
    country = "FR", input_dir = tempdir(), output_dir = tempdir(),
    dominance = TRUE, dom_vars = "employment", dom_num = 1
  )
  out_on <- compute_persistence(cfg_on, ai)
  expect_true("dom_employment" %in% names(out_on$transitions))
  expect_true("dom_employment" %in% names(out_on$evolutions_p1))
})
