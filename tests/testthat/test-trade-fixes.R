# Fixes of bugs in the original Stata trade package (FixStataBugs branch). The bug ids (T1-T7)
# refer to NEWS.md "Known issues inherited from the Stata code".

cfg_t <- function(country = "FR", ...) config_scaleup(country = country, input_dir = tempdir(), output_dir = tempdir(), ...)
tr_rows <- function(...) data.frame(..., stringsAsFactors = FALSE)
exports_imports <- function(idf = 1, year = 2015, value = c(5000, 3000)) {
  tr_rows(idf = idf, year = year, trade_type = c(2, 1), trade_value = value, code_destin = c("DE", ""),
          prod_code = c("84713000", "01012100"))
}

test_that("T1: the trade build rescales the financials like the base package; trade units are a setting", {
  bf <- make_base_financials()
  tr <- exports_imports(idf = 1, year = 2010)
  # ES: financials divided by 1000 as in n0_1 (n0_2 did PT only)
  es <- build_trade_accounts_indicators(cfg_t("ES"), bf, tr)
  base_es <- build_accounts_indicators(cfg_t("ES"), bf)
  one <- function(d, v) d[[v]][d$idf == 1 & d$year == 2010]
  expect_equal(one(es, "turnover"), one(base_es, "turnover"))
  # trade values: EUR by default for PT and HU only, otherwise as configured
  expect_equal(build_trade_panel(cfg_t("PT"), tr)$exp_value, 5)
  expect_equal(build_trade_panel(cfg_t("ES"), tr)$exp_value, 5000)
  expect_equal(build_trade_panel(cfg_t("ES", trade_value_unit = "EUR"), tr)$exp_value, 5)
  expect_equal(build_trade_panel(cfg_t("PT", trade_value_unit = "EUR thousand"), tr)$exp_value, 5000)
  expect_error(cfg_t("FR", trade_value_unit = "USD"), class = "OECDscaleup_config_error")
})
