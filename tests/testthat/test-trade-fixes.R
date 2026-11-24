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

test_that("T2: a firm in the trade file without one of the flows has 0 for it, not missing", {
  tr <- rbind(
    tr_rows(idf = 1, year = 2015, trade_type = 1, trade_value = 3, code_destin = "", prod_code = "01012100"),  # imports only
    tr_rows(idf = 2, year = 2015, trade_type = 2, trade_value = 4, code_destin = "DE", prod_code = "01012100") # exports only
  )
  p <- build_trade_panel(cfg_t(), tr)
  expect_equal(p$exp_value[p$idf == 1], 0)
  expect_equal(p$imp_value[p$idf == 2], 0)
  # its other variables stay missing, as for a firm with no trade at all
  expect_true(is.na(p$exp_products[p$idf == 1]))
  # an initially missing value is still missing
  tr$trade_value[2] <- NA
  expect_true(is.na(build_trade_panel(cfg_t(), tr)$exp_value[2]))
})

test_that("T4: trade data without import rows no longer stop; imports are unknown, not 0", {
  bf <- make_base_financials()
  tr <- tr_rows(idf = 1, year = 2010:2012, trade_type = 2, trade_value = 5, code_destin = "DE", prod_code = "01012100")
  p <- build_trade_panel(cfg_t(), tr)
  expect_true(all(is.na(p$imp_value)))
  expect_equal(attr(p, "flows"), 2)
  out <- build_trade_accounts_indicators(cfg_t(), bf, tr)
  expect_equal(out$exp_value[out$idf == 2 & out$year == 2010], 0) # non-trader: non-exporter
  expect_false("importer" %in% names(out))                         # unknown everywhere: column dropped
  expect_error(build_trade_panel(cfg_t(), tr[0, ]), class = "OECDscaleup_data_error")
})

test_that("T5: product codes with letters are counted, and leading zeros are kept", {
  tr <- tr_rows(idf = 1, year = 2015, trade_type = c(2, 2, 2, 2, 1), trade_value = c(5, 4, 3, 2, 1),
                code_destin = c("DE", "DE", "DE", "DE", ""),
                prod_code = c("0101AB00", "010121", "10121", ".", "01012100"))
  p <- build_trade_panel(cfg_t(), tr)
  expect_equal(p$exp_products, 3) # 0101AB, 010121, 10121 ("." is missing); Stata stopped
  expect_equal(p$exp_value, 14)
})

test_that("T3: y4_exporter is unknown while a firm exporting from its first observed year is in t-3..t", {
  bf <- make_base_financials_wide()
  years <- 2011:2020
  ex <- function(id, from) tr_rows(idf = id, year = years, trade_type = 2, trade_value = ifelse(years >= from, 100, 0),
                                   code_destin = "DE", prod_code = "84713000")
  imp <- tr_rows(idf = 99, year = 2011, trade_type = 1, trade_value = 1, code_destin = "", prod_code = "84713000")
  out <- build_trade_accounts_indicators(cfg_t(), bf, rbind(ex(1, 2011), ex(2, 2016), imp))
  y4 <- function(id) vapply(years, function(y) out$y4_exporter[out$idf == id & out$year == y], numeric(1))
  expect_equal(y4(1), c(NA, NA, NA, NA, 0, 0, 0, 0, 0, 0)) # exports in 2011, its first year: unknown
  expect_equal(y4(2), c(0, 0, 0, 0, 0, 1, 1, 1, 1, 0))     # starts exporting in 2016: first-time 2016-2019
})

test_that("T6: EU partners follow the membership of the year (UK until 2020, Croatia from 2013)", {
  rows <- function(y) tr_rows(idf = 1, year = y, trade_type = c(2, 2, 2, 1), trade_value = 5,
                              code_destin = c("GB", "HR", "DE", ""), prod_code = "01012100")
  p <- build_trade_panel(cfg_t(), rbind(rows(2012), rows(2015), rows(2021)))
  eu <- stats::setNames(p$exp_eu_partners, p$year)
  expect_equal(unname(eu[c("2012", "2015", "2021")]), c(2, 3, 2)) # GB+DE; GB+HR+DE; HR+DE
  expect_true(all(p$exp_all_partners == 3))
})
