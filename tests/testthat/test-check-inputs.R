cfg_ci <- function(...) {
  config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(), nace_revision = "2", ...)
}
# 40 firms of 10-49 employees over 2 years, turnover per employee 100 (EUR thousand)
small_panel <- function() {
  d <- data.frame(idf = rep(1:40, each = 2), year = rep(2019:2020, 40), sector_1d = "C", sector_2d = 26,
                  sector_3d = 262, region_2d = "FR10", birth_year = 2005, stringsAsFactors = FALSE)
  d$employment <- 10 + d$idf
  d$turnover <- d$employment * 100
  d
}
quiet_check <- function(...) {
  out <- NULL
  utils::capture.output(out <- check_inputs(...))
  out
}
results <- function(rep, variable, check = NULL) {
  r <- rep[rep$variable == variable & (is.null(check) | rep$check %in% check), ]
  r$result
}

test_that("clean input gives no errors or warnings, and prints a summary", {
  out <- utils::capture.output(rep <- check_inputs(cfg_ci(), small_panel()))
  expect_s3_class(rep, "scaleup_input_check")
  expect_false(any(rep$result %in% c("error", "warning")))
  expect_match(out[1], "Input check for FR: 0 error\\(s\\), 0 warning\\(s\\)")
  expect_true("ok" %in% results(rep, "turnover", "unit"))
  expect_true("ok" %in% results(rep, "sector_1d", "revision"))
  expect_equal(results(rep, "exit_close", "presence"), "note")
  expect_false(any(rep$result %in% "error"))
  # the fixture of the build tests passes too
  expect_false(any(quiet_check(cfg_ci(), make_base_financials())$result == "error"))
})

test_that("what stops the build is an error", {
  d <- small_panel(); d$region_2d <- NULL
  expect_equal(results(quiet_check(cfg_ci(), d), "region_2d", "presence"), "error")
  d <- small_panel(); d$birth_year <- NULL
  expect_equal(results(quiet_check(cfg_ci(), d), "birth_year", "presence"), "error")
  d$age_cat <- 0
  expect_equal(results(quiet_check(cfg_ci(), d), "birth_year", "presence"), "note")
  d <- small_panel(); d$employment <- as.character(d$employment)
  expect_equal(results(quiet_check(cfg_ci(), d), "employment", "type"), "error")
  d <- small_panel(); d <- rbind(d, d[1, ])
  rep <- quiet_check(cfg_ci(), d)
  expect_true("error" %in% rep$result[rep$check == "panel"])
  d <- small_panel(); d$turnover <- NA_real_
  expect_equal(results(quiet_check(cfg_ci(), d), "turnover", "values"), "error")
})

test_that("sector codes are checked against the declared revision", {
  d <- small_panel(); d$sector_1d[d$year == 2020] <- "D" # division 26 is C
  rep <- quiet_check(cfg_ci(), d)
  expect_equal(results(rep, "sector_1d", "revision"), "error")
  expect_match(rep$detail[rep$variable == "sector_1d" & rep$check == "revision"], "2020: 40")
  d <- small_panel(); d$sector_2d <- 62; d$sector_3d <- 620; d$sector_1d <- "K" # Rev. 2.1 letters
  expect_equal(results(quiet_check(cfg_ci(), d), "sector_1d", "revision"), "error")
  expect_equal(results(quiet_check(config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(),
                                                  nace_revision = "2.1"), d), "sector_1d", "revision"), "ok")
  d <- small_panel(); d$sector_3d <- 271
  expect_equal(results(quiet_check(cfg_ci(), d), "sector_3d", "codes"), "warning")
  d <- small_panel(); d$sector_2d[1:8] <- 64; d$sector_1d[1:8] <- "K"; d$sector_3d[1:8] <- 641
  rep <- quiet_check(cfg_ci(), d)
  expect_match(rep$detail[rep$check == "sectors"], "^8 of 80 \\(10.0 %\\)")
})

test_that("the money units are checked", {
  d <- small_panel(); d$turnover <- d$turnover * 1000
  expect_equal(results(quiet_check(cfg_ci(), d), "turnover", "unit"), "error")
  expect_equal(results(quiet_check(cfg_ci(financials_unit = "EUR"), d), "turnover", "unit"), "ok")
  tr <- data.frame(idf = 1:40, year = 2020, trade_type = 2, trade_value = 500 * 1000, code_destin = "DE",
                   prod_code = "12345678", stringsAsFactors = FALSE)
  rep <- quiet_check(cfg_ci(), small_panel(), trade_raw = tr)
  expect_equal(results(rep, "trade_value", "unit"), "warning")
  expect_true("warning" %in% results(rep, "trade_type", "coding")) # no imports at all
  rep <- quiet_check(cfg_ci(trade_value_unit = "EUR"), small_panel(), trade_raw = tr)
  expect_equal(results(rep, "trade_value", "unit"), "ok")
  # imports have no destination: code_destin is checked on the export rows only
  tr2 <- rbind(tr, transform(tr, trade_type = 1, code_destin = ""))
  rep <- quiet_check(cfg_ci(trade_value_unit = "EUR"), small_panel(), trade_raw = tr2)
  expect_equal(results(rep, "code_destin", "missing"), "ok")
  tr2$code_destin[1] <- "."
  rep <- quiet_check(cfg_ci(trade_value_unit = "EUR"), small_panel(), trade_raw = tr2)
  expect_match(rep$detail[rep$variable == "code_destin" & rep$check == "missing"], "1 of 40 .* export rows")
  tr$trade_type[1] <- NA
  expect_true("error" %in% results(quiet_check(cfg_ci(), small_panel(), trade_raw = tr), "trade_type", "coding"))
})

test_that("values, codings and codes are reported as counts, never as values", {
  d <- small_panel()
  d$turnover[1:4] <- -1
  d$exit <- 0; d$exit[1] <- 2
  d$uco <- "DE"; d$uco[1:2] <- "XYZQ"
  d$independent <- 1
  rep <- quiet_check(cfg_ci(), d)
  expect_equal(results(rep, "turnover", "negative"), "note")
  expect_match(rep$detail[rep$variable == "turnover" & rep$check == "negative"], "negative in 4 of 80")
  expect_equal(results(rep, "exit", "coding"), "warning")
  expect_equal(results(rep, "uco", "codes"), "warning")
  expect_false(any(grepl("XYZQ", rep$detail)))
  expect_equal(results(rep, "independent", "missing"), "ok")
})

test_that("reference data: TL3 typology for region_3d, exchange rates for non-euro countries", {
  d <- small_panel(); d$region_3d <- "FR101"
  expect_equal(results(quiet_check(cfg_ci(), d), "region_3d", "reference"), "error")
  d$region_3d[1:2] <- "FR999"
  expect_equal(results(quiet_check(cfg_ci(), d, tl3_typology = tl3_typology), "region_3d", "reference"), "warning")
  hr <- config_scaleup(country = "HR", input_dir = tempdir(), output_dir = tempdir(), nace_revision = "2")
  rep <- quiet_check(hr, small_panel())
  expect_true("error" %in% rep$result[rep$check == "reference"])
  rep <- quiet_check(hr, small_panel(), exchange_rates = exchange_rates)
  expect_true("ok" %in% rep$result[rep$check == "reference"])
})

test_that("plants and trade records are linked to base_financials", {
  pl <- data.frame(idf = c(1, 1, 99), idp = c(1, 2, 3), year = 2020)
  rep <- quiet_check(cfg_ci(), small_panel(), plants_raw = pl)
  expect_equal(results(rep[rep$dataset == "plants_RAW", ], "idf", "link"), "note")
  expect_equal(results(rep[rep$dataset == "plants_RAW", ], "hq", "presence"), "note")
  pl$idp <- NULL
  rep <- quiet_check(cfg_ci(), small_panel(), plants_raw = pl)
  expect_equal(results(rep[rep$dataset == "plants_RAW", ], "idp", "presence"), "error")
})

test_that("check_inputs() reads the files of input_dir", {
  dir <- local_test_dir()
  cfg <- config_scaleup(country = "FR", input_dir = dir, output_dir = dir, nace_revision = "2")
  rep <- quiet_check(cfg)
  expect_equal(rep$result, "error")
  haven::write_dta(small_panel(), file.path(dir, "base_financials_FR.dta"))
  rep <- quiet_check(cfg)
  expect_false(any(rep$result == "error"))
  expect_true(all(c("plants_RAW", "trade_RAW") %in% rep$dataset[rep$check == "file"]))
})
