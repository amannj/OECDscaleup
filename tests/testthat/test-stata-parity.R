# Behaviour that must match the original Stata code bit for bit (found and
# verified in the Stata <-> R reproduction, 2026-11-18). Several of these are
# Stata *bugs* reproduced on purpose; they will change in the fixes phase.

cfg_fr <- function() config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())

test_that("turnover 0 at t-3: no HG flag and no growth rate (x/0 is missing), but still in the pool", {
  bf <- make_base_financials()
  bf$turnover[bf$idf == 1 & bf$year == 2010] <- 0
  ai <- build_accounts_indicators(cfg_fr(), bf)
  r <- ai[ai$idf == 1 & ai$year == 2013, ]
  expect_equal(r$HGT20, 0L)
  expect_equal(r$HGT10, 0L)
  expect_true(is.na(r$turnover_growth3y))
  expect_equal(r$HGT_pool, 1L)
  expect_false(any(vapply(ai, function(x) is.numeric(x) && any(is.infinite(x)), logical(1))))
})

test_that("added_value 0 gives missing MFP (ln(0) is missing), not 0", {
  bf <- make_base_financials()
  bf$added_value[bf$idf == 6 & bf$year == 2012] <- 0
  ai <- build_accounts_indicators(cfg_fr(), bf)
  expect_true(is.na(ai$MFP[ai$idf == 6 & ai$year == 2012]))
  expect_true(is.na(ai$va[ai$idf == 6 & ai$year == 2012]))
})

test_that("the Solow intermediates stay in the data and log_added_value_emp is renamed", {
  ai <- build_accounts_indicators(cfg_fr(), make_base_financials())
  expect_true(all(c("va", "sl", "k", "slk", "l", "sll", "labour_prod", "L3labour_prod", "S3log_added_value_emp") %in% names(ai)))
  expect_false(any(c("log_added_value_emp", "L3log_added_value_emp") %in% names(ai)))
})

test_that("L3age is created in the birth_year branch", {
  ai <- build_accounts_indicators(cfg_fr(), make_base_financials())
  expect_true("L3age" %in% names(ai))
  r <- ai[ai$idf == 1, ]
  expect_equal(r$L3age[r$year == 2014], r$age[r$year == 2011])
})

test_that("plant counts replace number_plants/multiplant already in base_financials, as Stata's merge does", {
  # Stata saves the plant merge back into base_financials, so a later run sees the columns already there
  bf <- make_base_financials()
  bf$number_plants <- 5
  bf$multiplant <- 1
  plants <- data.frame(idf = c(1, 1, 1), idp = c(1, 2, 1), year = c(2010, 2010, 2011))
  out <- build_accounts_indicators(cfg_fr(), bf, plants_raw = plants)
  expect_false(any(grepl("\\.(x|y)$|^\\.", names(out))))
  one <- function(y, v) out[[v]][out$idf == 1 & out$year == y]
  expect_equal(c(one(2010, "number_plants"), one(2010, "multiplant")), c(2, 1)) # from the plants file
  expect_equal(c(one(2011, "number_plants"), one(2011, "multiplant")), c(1, 0))
  expect_equal(c(one(2012, "number_plants"), one(2012, "multiplant")), c(5, 1)) # no plant record: kept
})

test_that("region_2d '.' becomes missing and never forms a '._<sector>' pair", {
  bf <- make_base_financials()
  bf$region_2d[bf$idf == 3] <- "."
  ai <- build_accounts_indicators(cfg_fr(), bf)
  expect_true(all(is.na(ai$region_2d[ai$idf == 3])))
  expect_false(any(startsWith(stats::na.omit(ai$reg_techgrad), "._")))
})

test_that("an exactly 10% a year 3-year growth is not a 10% high-growth event (Stata's ^)", {
  bf <- make_base_financials()
  bf$employment[bf$idf == 1 & bf$year == 2010] <- 100
  bf$employment[bf$idf == 1 & bf$year == 2013] <- 133.1
  ai <- build_accounts_indicators(cfg_fr(), bf)
  expect_equal(ai$HGE10[ai$idf == 1 & ai$year == 2013], 0L)
})

test_that("approximate medians of growth rates are medians, not means", {
  ai <- build_accounts_indicators(cfg_fr(), make_base_financials_wide())
  ch <- compute_characteristics(cfg_fr(), ai)
  differ <- ch$median_employment_growth3y != ch$mean_employment_growth3y
  expect_true(any(differ, na.rm = TRUE))
})

test_that("accounts_indicators is written with Stata's labelled numeric categories", {
  ai <- build_accounts_indicators(cfg_fr(), make_base_financials())
  st <- as_stata_accounts(ai)
  expect_true(haven::is.labelled(st$region_2d))
  expect_true(haven::is.labelled(st$age_cat))
  expect_equal(as.character(haven::as_factor(st$region_2d)), ai$region_2d)
  expect_equal(attr(st$tech_grad, "labels")[["Advanced services"]], 3)
})
