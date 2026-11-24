# Trade package (n0_2 / n1_6). Each expectation below mirrors a line of the Stata code;
# verified against Stata on the synthetic TR scenarios of the reproduction harness.

cfg_trade <- function(country = "FR", ...) {
  config_scaleup(country = country, input_dir = tempdir(), output_dir = tempdir(), ...)
}
trade_rows <- function(...) data.frame(..., stringsAsFactors = FALSE)

test_that("the trade panel counts distinct partners, EU partners and 6-digit products per flow", {
  tr <- trade_rows(
    idf = 1, year = 2015,
    trade_type = c(2, 2, 2, 2, 1, 1),
    trade_value = c(3, 2, 5, 4, 6, 1.5),
    code_destin = c("DE", "DE", "US", "EL", "", "."),
    prod_code = c("01012100", "01012190", "84713000", "84713000", "02031100", "02031190")
  )
  p <- build_trade_panel(cfg_trade(), tr)
  expect_equal(nrow(p), 1)
  expect_equal(p$exp_value, 14)
  expect_equal(p$exp_all_partners, 3)   # DE, US, EL
  expect_equal(p$exp_eu_partners, 2)    # DE, EL
  expect_equal(p$exp_products, 2)       # 010121 and 847130
  expect_equal(p$exp_core_prod, stata_float(9 / 14))
  expect_equal(p$imp_value, 7.5)
  expect_equal(p$imp_products, 1)       # both imports share 6-digit 020311
  # imports have no partner country: their partner counts are dropped
  expect_false(any(c("imp_all_partners", "imp_eu_partners") %in% names(p)))
})

test_that("products below 1 (thousand) are blanked before the counts; an all-missing flow stays missing", {
  tr <- trade_rows(
    idf = c(1, 1, 1, 2, 2, 3, 3), year = 2015,
    trade_type = c(2, 2, 1, 2, 1, 2, 1),
    trade_value = c(0.4, 0.5, 2, NA, 3, 0.2, 1),
    code_destin = c("DE", "FR", "", "DE", "", "US", ""),
    prod_code = c("01012100", "01012190", "84713000", "01012100", "84713000", "84713000", "84713000")
  )
  p <- build_trade_panel(cfg_trade(), tr)
  one <- p[p$idf == 1, ]
  expect_equal(one$exp_value, 0)             # 0.4 + 0.5 < 1 within 010121: blanked, summed as 0
  expect_true(is.na(one$exp_all_partners))   # no partner left: missing, not 0
  expect_true(is.na(one$exp_products))
  two <- p[p$idf == 2, ]
  expect_true(is.na(two$exp_value))          # only a missing value: restored to missing
  three <- p[p$idf == 3, ]
  expect_equal(three$exp_value, 0)
})

test_that("PT and HU trade values are divided by 1000, other countries' are not", {
  tr <- trade_rows(idf = 1, year = 2015, trade_type = c(2, 1), trade_value = c(5000, 3000),
                   code_destin = c("DE", ""), prod_code = "01012100")
  expect_equal(build_trade_panel(cfg_trade("PT"), tr)$exp_value, 5)
  expect_equal(build_trade_panel(cfg_trade("FR"), tr)$exp_value, 5000)
  # a float trade_value stays float after the division
  tr$trade_value <- c(1234567, 3000)
  p <- build_trade_panel(cfg_trade("PT"), tr, storage_types = c(trade_value = "float"))
  expect_equal(p$exp_value, stata_float(1234.567))
})

test_that("Stata's stop on non-numeric product codes (T5) is reproduced", {
  letters <- trade_rows(idf = 1, year = 2015, trade_type = c(2, 1), trade_value = 5, code_destin = c("DE", ""),
                        prod_code = c("0101AB00", "01012100"))
  expect_error(build_trade_panel(cfg_trade(), letters), class = "OECDscaleup_stata_crash")
})

test_that("exporter flags: non-traders are 0, a firm without a flow is 0 for it (fix T2); y4_exporter and HGX", {
  bf <- make_base_financials_wide()
  years <- 2011:2020
  # firm 1 exports throughout with exports tripling from 2015; firm 2 only imports; firm 3 has no trade
  t1 <- trade_rows(idf = 1, year = years, trade_type = 2,
                   trade_value = ifelse(years >= 2015, 3000, 1000), code_destin = "DE", prod_code = "84713000")
  t2 <- trade_rows(idf = 2, year = years, trade_type = 1, trade_value = 50, code_destin = "", prod_code = "84713000")
  out <- build_trade_accounts_indicators(cfg_trade(), bf, rbind(t1, t2))
  f <- function(id, y, v) out[[v]][out$idf == id & out$year == y]
  expect_equal(f(1, 2015, "exporter"), 1)
  expect_equal(f(2, 2015, "exporter"), 0)  # import-only: a non-exporter (Stata: missing, T2)
  expect_equal(f(2, 2015, "importer"), 1)
  expect_equal(f(3, 2015, "exp_value"), 0)
  expect_equal(f(3, 2015, "exporter"), 0)
  # first observed export year is 2011, so y4_exporter is 1 in 2011-2014 (left-censored, T3)
  expect_equal(vapply(2011:2015, function(y) f(1, y, "y4_exporter"), numeric(1)), c(1, 1, 1, 1, 0))
  # HGX = 1 only for an HGT scaler with export growth >= half the HGT turnover growth
  hgt <- out$HGT10 == 1 & out$idf == 1
  if (any(hgt, na.rm = TRUE)) {
    expect_true(all(out$HGX10[which(hgt)] %in% c(0, 1)))
    expect_true(all(out$HGNX10[which(hgt)] == 1 - out$HGX10[which(hgt)]))
  }
  expect_true(all(out$HGX10[out$idf == 2] %in% c(0, NA))) # no exports: never a heavy exporter
  expect_false(any(c("reg_techgrad", "sector_L") %in% names(out)))
  expect_setequal(unique(stats::na.omit(out$sector_exporter)), c("manufact_export", "manufact_not_export"))
  expect_true(all(out$digit_sect == 3)) # sector 26 -> D26 -> medium-high digital intensity
})

test_that("compute_trade_characteristics returns p1 and p2 with n1_6's columns", {
  bf <- make_base_financials_wide()
  set.seed(3)
  tr <- do.call(rbind, lapply(1:60, function(i) trade_rows(
    idf = i, year = 2011:2020, trade_type = rep(c(2, 1), length.out = 10),
    trade_value = stats::rlnorm(10, log(200)), code_destin = ifelse(rep(c(2, 1), length.out = 10) == 2, "DE", ""),
    prod_code = "84713000")))
  ai <- build_trade_accounts_indicators(cfg_trade(dominance = TRUE, dom_vars = c("turnover", "exp_value")), bf, tr)
  res <- compute_trade_characteristics(cfg_trade(dominance = TRUE, dom_vars = c("turnover", "exp_value")), ai)
  expect_named(res, c("p1", "p2"))
  expect_true(all(c("year", "sample", "category", "group", "firm_count", "median_L3exp_value", "mean_exp_core_prod",
                    "share_y4_exporter", "share_importer", "dom_exp_value") %in% names(res$p1)))
  expect_true(all(c("L3exporter", "L3sector_exporter", "L3digit_sect") %in% res$p1$category))
  expect_true(all(res$p1$group[res$p1$category == "L3exporter"] %in% c("Exporter", "Non-exporter")))
  expect_false(any(res$p1$sample %in% c("HGX10", "HGNX10") & res$p1$category == "L3digit_sect"))
  expect_true("share_HGX" %in% names(res$p2))
  expect_false(any(c("HGX10", "HGX20") %in% names(res$p2)))
})
