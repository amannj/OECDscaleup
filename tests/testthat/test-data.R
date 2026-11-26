test_that("bundled reference data has the expected shape", {
  expect_true(all(c("classification", "region_3d", "typology_access_cities") %in% names(tl3_typology)))
  expect_setequal(unique(tl3_typology$classification), c("TL2024", "TL2021"))
  expect_equal(anyDuplicated(tl3_typology[c("classification", "region_3d")]), 0)
  expect_true(all(access_code(tl3_typology$typology_access_cities) %in% c("MR-L", "MR-M", "NMR-M", "NMR-S", "NMR-R", "..")))
  expect_true(all(c("year", "country", "rate") %in% names(exchange_rates)))
  expect_setequal(unique(exchange_rates$country), country_patches$non_euro)
  # every non-euro country has a rate for every year 2008-2025
  expect_equal(as.vector(table(exchange_rates$country[exchange_rates$year %in% 2008:2025])), rep(18L, 5))
  # Croatia: the fixed conversion rate from the euro adoption (2023) on
  expect_true(all(exchange_rates$rate[exchange_rates$country == "HR" & exchange_rates$year >= 2023] == 7.5345))
})

test_that("the declared TL classification selects the typology; codes MR_L and MR-L both work", {
  bf <- make_base_financials()
  bf$region_3d <- "FR101"
  only21 <- setdiff(tl3_typology$region_3d[tl3_typology$classification == "TL2021"],
                    tl3_typology$region_3d[tl3_typology$classification == "TL2024"])
  bf$region_3d[bf$idf == 2] <- only21[1]
  ai24 <- build_accounts_indicators(config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(),
                                                   output_dir = tempdir()), bf)
  expect_true(all(ai24$typology_UR[ai24$idf == 1] == "Large metropolitan region"))
  expect_true(all(is.na(ai24$typology_UR[ai24$idf == 2])))
  ai21 <- build_accounts_indicators(config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(),
                                                   output_dir = tempdir(), tl_classification = "TL2021"), bf)
  expect_true(all(!is.na(ai21$typology_UR[ai21$idf == 2])))
  # a table of an earlier release (no classification column, codes with a hyphen) is used as it is
  old <- data.frame(region_3d = "FR101", typology_access_cities = "MR-L")
  ai_old <- build_accounts_indicators(config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(),
                                                     output_dir = tempdir()), bf, tl3_typology = old)
  expect_true(all(ai_old$typology_UR[ai_old$idf == 1] == "Large metropolitan region"))
  expect_error(config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir(),
                              tl_classification = "TL2016"), class = "OECDscaleup_config_error")
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

test_that("variable_dictionary matches what the build does", {
  d <- variable_dictionary
  expect_setequal(unique(d$dataset), c("base_financials", "plants_RAW", "trade_RAW"))
  expect_equal(anyDuplicated(d[c("dataset", "variable")]), 0)
  expect_true(all(d$priority %in% c("must-have", "nice-to-have, first order", "nice-to-have, second order")))
  expect_true(all(d$format %in% c("numeric", "string", "string (letter)")))
  bf <- d[d$dataset == "base_financials", ]
  expect_setequal(bf$variable[bf$package_requirement == "required"], base_required_vars)
  expect_setequal(bf$variable[bf$money], base_money_vars)
  expect_setequal(bf$variable[bf$negatives_missing], base_negatives_missing)
  tr <- d[d$dataset == "trade_RAW", ]
  expect_setequal(tr$variable[tr$package_requirement == "required"], trade_required_vars)
  expect_true(all(tr$priority == "must-have"))
  # first-order nice-to-have by decision of the OECD team
  expect_equal(bf$priority[bf$variable %in% c("exit_acq", "exit_close")], rep("nice-to-have, first order", 2))
})

test_that("a missing required column points to the input-data article", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  bf <- make_base_financials()
  bf$region_2d <- NULL
  expect_error(build_accounts_indicators(cfg, bf), "region_2d.*input-data", class = "OECDscaleup_data_error")
})
