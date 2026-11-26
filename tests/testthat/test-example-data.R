test_that("example_scaleup_data() is reproducible and leaves the global random stream alone", {
  set.seed(42)
  before <- stats::runif(1)
  set.seed(42)
  a <- example_scaleup_data(n_firms = 200, seed = 7)
  after <- stats::runif(1)
  expect_equal(before, after)
  b <- example_scaleup_data(n_firms = 200, seed = 7)
  expect_identical(a, b)
  expect_false(identical(a$base_financials, example_scaleup_data(n_firms = 200, seed = 8)$base_financials))
})

test_that("example_scaleup_data() follows the input format and passes check_inputs()", {
  ex <- example_scaleup_data(n_firms = 300, years = 2012:2020)
  expect_named(ex, c("base_financials", "plants_raw", "trade_raw"))
  bf <- ex$base_financials
  expect_equal(anyDuplicated(bf[c("idf", "year")]), 0)
  expect_true(all(bf$year %in% 2012:2020))
  expect_true(all(bf$sector_1d == nace_section(bf$sector_2d, "2")))
  expect_true(all(c(trade_required_vars) %in% names(ex$trade_raw)))
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(), nace_revision = "2")
  rep <- NULL
  utils::capture.output(rep <- check_inputs(cfg, bf, ex$plants_raw, ex$trade_raw, tl3_typology = tl3_typology))
  expect_false(any(rep$result %in% c("error", "warning")))
})

test_that("the example data produce scalers and run through the build", {
  ex <- example_scaleup_data(n_firms = 600)
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(), nace_revision = "2")
  ai <- build_accounts_indicators(cfg, ex$base_financials, ex$plants_raw, tl3_typology = tl3_typology)
  expect_gt(sum(ai$HGE20 %in% 1), 20)
  expect_gt(sum(ai$employment >= 250, na.rm = TRUE), 0)
  expect_true(all(c("multiplant", "typology_UR", "MFP") %in% names(ai)))
})
