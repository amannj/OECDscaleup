# run_scaler_analysis(): reads the indicators panel, writes the scaler-analysis tables.

test_that("run_scaler_analysis writes every table from accounts_indicators_<CT>.dta", {
  dir <- local_test_dir()
  cfg <- config_scaleup(country = "FR", input_dir = dir, output_dir = dir)
  expect_error(run_scaler_analysis(cfg), class = "OECDscaleup_data_error")

  bf <- make_base_financials_wide()
  fast <- bf$idf <= 15
  bf$employment[fast] <- round(20 * 1.3^(bf$year[fast] - 2011) * (1 + bf$idf[fast] / 100))
  bf$turnover[fast] <- bf$employment[fast] * 100
  ai <- build_accounts_indicators(cfg, bf)
  haven::write_dta(as_stata_accounts(ai), file.path(dir, "accounts_indicators_FR.dta"))

  out <- run_scaler_analysis(cfg)
  files <- sprintf("sa_%s_FR.csv", c("top_scalers", "midcap_incidence", "midcap_entry", "midcap_by_year", "midcap_coverage", "midcap_hazard"))
  expect_true(all(file.exists(file.path(dir, files))))
  expect_setequal(unique(out$top_scalers$joint_growth), c(FALSE, TRUE))
  expect_equal(nrow(utils::read.csv(file.path(dir, "sa_top_scalers_FR.csv"))), nrow(out$top_scalers))
})
