test_that("build_accounts_indicators runs end-to-end on a synthetic panel", {
  cfg <- config_scaleup(
    country = "FR",
    input_dir = tempdir(),
    output_dir = tempdir()
  )
  bf <- make_base_financials()

  out <- build_accounts_indicators(cfg, bf)

  expect_s3_class(out, "tbl_df")
  expect_true(all(c(
    "idf", "year", "employment", "turnover", "HGE20", "HGE10", "HGT20", "HGT10",
    "HGET20", "HGET10", "age_cat", "size_cat", "tech_grad", "entry", "exit"
  ) %in% names(out)))
})

test_that("a firm with genuine 20%-annualised employment growth is flagged HGE20", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  out <- build_accounts_indicators(cfg, make_base_financials())

  firm2 <- out[out$idf == 2, ]
  # employment goes 40 (2010) -> ~69 (2013): (69/40)^(1/3) - 1 > 0.20
  scaler_row <- firm2[firm2$year == 2013, ]
  expect_equal(nrow(scaler_row), 1)
  expect_equal(scaler_row$HGE20, 1)
  expect_equal(scaler_row$HGET20, 1) # HGET = HGE | HGT
})

test_that("a steady firm is never flagged as a scaler once eligible", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  out <- build_accounts_indicators(cfg, make_base_financials())

  firm1 <- out[out$idf == 1 & out$year >= 2013, ] # eligible once L3employment exists
  expect_true(all(firm1$HGE20 == 0, na.rm = TRUE))
  expect_true(all(firm1$HGE10 == 0, na.rm = TRUE))
})

test_that("entry is flagged on a firm's first year when that year isn't the panel start", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  out <- build_accounts_indicators(cfg, make_base_financials())

  firm4 <- out[out$idf == 4, ]
  expect_equal(firm4$entry[firm4$year == 2014], 1)
  expect_true(all(firm4$entry[firm4$year != 2014] %in% c(0, NA)))
})

test_that("exit is flagged on a firm's last year when that year isn't the panel end", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  out <- build_accounts_indicators(cfg, make_base_financials())

  firm5 <- out[out$idf == 5, ]
  expect_equal(firm5$exit[firm5$year == 2015], 1)
})

test_that("optional financial variables are computed only where their inputs exist", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  out <- build_accounts_indicators(cfg, make_base_financials())

  expect_true("labour_share" %in% names(out)) # firm 6 supplies labour_costs
  expect_true("MFP" %in% names(out)) # firm 6 supplies all 3 MFP inputs

  firm6 <- out[out$idf == 6, ]
  expect_true(all(!is.na(firm6$labour_share)))
  firm1 <- out[out$idf == 1, ]
  expect_true(all(is.na(firm1$labour_share))) # firm 1 never supplied labour_costs
})

test_that("a country not in any country_patches list is unaffected by the data patches", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  bf <- make_base_financials()
  out <- build_accounts_indicators(cfg, bf)
  # turnover should be untouched (no /1000 rescale, no non-Euro conversion)
  firm1_2010 <- out[out$idf == 1 & out$year == 2010, ]
  expect_equal(firm1_2010$turnover, 5000)
})

test_that("the currency-rescale country patch divides financials by 1000", {
  cfg <- config_scaleup(country = "PT", input_dir = tempdir(), output_dir = tempdir())
  bf <- make_base_financials()
  out <- build_accounts_indicators(cfg, bf)
  firm1_2010 <- out[out$idf == 1 & out$year == 2010, ]
  expect_equal(firm1_2010$turnover, 5)
})

test_that("build_accounts_indicators errors clearly when a required column is missing", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  bf <- make_base_financials()
  bf$sector_2d <- NULL
  expect_error(build_accounts_indicators(cfg, bf), class = "OECDscaleup_data_error")
})

test_that("build_accounts_indicators errors on duplicate (idf, year) pairs", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  bf <- make_base_financials()
  bf <- rbind(bf, bf[1, ])
  expect_error(build_accounts_indicators(cfg, bf), class = "OECDscaleup_data_error")
})

test_that("plants_raw produces a multiplant indicator", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  bf <- make_base_financials()
  plants <- data.frame(
    idf = c(1, 1, 1, 2), idp = c(1, 2, 1, 1), year = c(2010, 2010, 2011, 2010)
  )
  out <- build_accounts_indicators(cfg, bf, plants_raw = plants)
  expect_true("multiplant" %in% names(out))
  expect_equal(out$multiplant[out$idf == 1 & out$year == 2010], 1) # 2 distinct plants
  expect_equal(out$multiplant[out$idf == 1 & out$year == 2011], 0) # 1 plant
})
