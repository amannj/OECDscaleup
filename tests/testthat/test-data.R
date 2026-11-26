test_that("bundled reference data has the expected shape", {
  expect_true(all(c("region_3d", "typology_access_cities") %in% names(tl3_typology)))
  expect_true(all(c("year", "country", "rate") %in% names(exchange_rates)))
  expect_true(all(unique(exchange_rates$country) %in% country_patches$non_euro))
})

test_that("build_accounts_indicators works with the real bundled tl3_typology data", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  bf <- make_base_financials()
  bf$region_3d <- "FR101" # a real TL3 code present in the bundled data
  out <- build_accounts_indicators(cfg, bf, tl3_typology = tl3_typology)
  expect_true("typology_UR" %in% names(out))
  expect_true(all(!is.na(out$typology_UR[!is.na(out$region_3d)])))
})

test_that("build_accounts_indicators works with the real bundled exchange_rates data", {
  cfg <- config_scaleup(nace_revision = "2", country = "HR", input_dir = tempdir(), output_dir = tempdir())
  bf <- make_base_financials()
  out <- build_accounts_indicators(cfg, bf, exchange_rates = exchange_rates)
  # HR is a non-Euro country patch; turnover should have been converted via the real rate
  expect_true(all(!is.na(out$turnover)))
})
