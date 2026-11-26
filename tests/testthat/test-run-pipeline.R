test_that("run_scaleup_pipeline reads/writes files and produces the expected CSVs", {
  input_dir <- local_test_dir()
  output_dir <- local_test_dir()

  haven::write_dta(make_base_financials(), file.path(input_dir, "base_financials_FR.dta"))

  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = input_dir, output_dir = output_dir)
  result <- run_scaleup_pipeline(cfg)

  expect_true(file.exists(file.path(input_dir, "accounts_indicators_FR.dta")))
  expect_true(file.exists(file.path(output_dir, "n13_characteristics_FR.csv")))
  expect_true(is.list(result))
  expect_true("characteristics" %in% names(result))

  # a re-read of the written CSV should round-trip the same row count
  written <- utils::read.csv(file.path(output_dir, "n13_characteristics_FR.csv"))
  expect_equal(nrow(written), nrow(result$characteristics))
})

test_that("run_scaleup_pipeline picks up plants_RAW, exchange_rates, and tl3_typology when present", {
  input_dir <- local_test_dir()
  output_dir <- local_test_dir()

  bf <- make_base_financials()
  bf$region_3d <- "FR101"
  haven::write_dta(bf, file.path(input_dir, "base_financials_FR.dta"))
  haven::write_dta(
    data.frame(idf = c(1, 1), idp = c(1, 2), year = c(2010, 2010)),
    file.path(input_dir, "plants_RAW_FR.dta")
  )
  haven::write_dta(tl3_typology, file.path(input_dir, "tl3_typology.dta"))

  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = input_dir, output_dir = output_dir)
  result <- run_scaleup_pipeline(cfg)

  ai <- haven::read_dta(file.path(input_dir, "accounts_indicators_FR.dta"))
  expect_true("multiplant" %in% names(ai))
  expect_true("typology_UR" %in% names(ai))
})

test_that("run_scaleup_pipeline errors clearly when base_financials is missing", {
  input_dir <- local_test_dir()
  output_dir <- local_test_dir()
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = input_dir, output_dir = output_dir)
  expect_error(run_scaleup_pipeline(cfg), class = "OECDscaleup_data_error")
})

test_that("run_scaleup_pipeline writes no CSV for an output that was never produced", {
  input_dir <- local_test_dir()
  output_dir <- local_test_dir()
  # a panel far too short for persistence's transitions/evolutions gates
  # (finyear < 2017), and missing the 3 financial variables
  # compute_predictors() requires. Truncate at 2014, not earlier, so firm 4
  # (the only firm with a non-missing birth_year, at its 2014 entry row)
  # survives the filter - otherwise build_accounts_indicators() correctly
  # rejects the fixture for having neither age_cat nor birth_year at all.
  bf <- make_base_financials()
  bf <- bf[bf$year <= 2014, ]
  haven::write_dta(bf, file.path(input_dir, "base_financials_FR.dta"))

  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = input_dir, output_dir = output_dir)
  run_scaleup_pipeline(cfg)

  expect_false(file.exists(file.path(output_dir, "n13_transitions_FR.csv")))
  expect_false(file.exists(file.path(output_dir, "n13_regs_predictors_FR.csv")))
})
