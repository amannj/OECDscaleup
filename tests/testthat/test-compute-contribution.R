test_that("compute_contribution runs end-to-end with the expected shape", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials())
  out <- compute_contribution(cfg, ai)

  expect_false(is.null(out$contribution_p1))
  expect_false(is.null(out$contribution_p2))
  expect_true(all(c("year", "category", "group", "sample", "type", "variable", "N_firms", "S3sum", "L3sum") %in% names(out$contribution_p1)))
  expect_true(all(c("year", "category", "group", "sample", "variable", "N_firms", "L3sum") %in% names(out$contribution_p2)))
  expect_true(all(out$contribution_p1$year %in% c(2014, 2017, 2019, 2020, 2021)))
})

test_that("an entrant's full current value is attributed as job creation", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials())
  p1 <- compute_contribution(cfg, ai)$contribution_p1

  # firm 4 enters in 2014 with employment=15 and no prior record -> S3employment
  # = employment = 15 for that firm; it should appear as a creation row in the
  # ALL/employment cell for year 2014.
  cell <- p1[p1$year == 2014 & p1$category == "ALL" & p1$sample == "entrants" &
    p1$type == "creation" & p1$variable == "employment", ]
  expect_equal(nrow(cell), 1)
  expect_true(cell$S3sum >= 15)
})

test_that("an exiting firm's full prior value is attributed as job destruction", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials())
  p1 <- compute_contribution(cfg, ai)$contribution_p1

  # firm 5's last real year is 2015 (employment=30); 3 years later (2017) it
  # has no employment record, so S3employment = -L3employment = -30, a
  # destruction row in the ALL/employment cell for year 2017.
  cell <- p1[p1$year == 2017 & p1$category == "ALL" & p1$sample == "exiting" &
    p1$type == "destruction" & p1$variable == "employment", ]
  expect_equal(nrow(cell), 1)
  expect_true(cell$S3sum <= -30)
})

test_that("entrants never have a destruction row, and exiting firms never have a creation row", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials())
  p1 <- compute_contribution(cfg, ai)$contribution_p1

  expect_equal(nrow(p1[p1$sample == "entrants" & p1$type == "destruction", ]), 0)
  expect_equal(nrow(p1[p1$sample == "exiting" & p1$type == "creation", ]), 0)
})

test_that("entrants are excluded from the L3age_cat category (explicit source exclusion)", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials())
  p1 <- compute_contribution(cfg, ai)$contribution_p1

  expect_equal(nrow(p1[p1$sample == "entrants" & p1$category == "L3age_cat", ]), 0)
})

test_that("the SMEs sample is relabelled non_micro_SMEs in the output", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials())
  out <- compute_contribution(cfg, ai)

  expect_false("SMEs" %in% out$contribution_p1$sample)
  expect_true("non_micro_SMEs" %in% out$contribution_p1$sample || nrow(out$contribution_p1) == 0)
})

test_that("dominance columns are consolidated from the exiting sample's L3 variant", {
  ai_cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(ai_cfg, make_base_financials())

  cfg_on <- config_scaleup(
    country = "FR", input_dir = tempdir(), output_dir = tempdir(),
    dominance = TRUE, dom_vars = "employment", dom_num = 1
  )
  out <- compute_contribution(cfg_on, ai)
  expect_true("dom_employment" %in% names(out$contribution_p1))
  expect_false(any(grepl("^dom_L3", names(out$contribution_p1))))
  # the exiting/destruction rows must have a non-missing dom_employment,
  # sourced from dom_L3employment internally and consolidated into dom_employment
  exiting_rows <- out$contribution_p1[out$contribution_p1$sample == "exiting" & out$contribution_p1$variable == "employment", ]
  expect_true(nrow(exiting_rows) > 0)
  expect_true(all(!is.na(exiting_rows$dom_employment)))
})
