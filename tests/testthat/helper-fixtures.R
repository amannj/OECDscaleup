# Synthetic `base_financials`-shaped fixtures, matching `variable_dictionary` (data-raw/variable_dictionary.R).
# No real firm microdata ships with the source package (it's confidential and
# country-specific), so all test data here is fabricated.

#' A fresh, uniquely-named temp directory for a single test (base R only, no
#' `withr` dependency). Left for the OS/session to reclaim, same as this
#' suite's existing plain `tempdir()` usage elsewhere.
local_test_dir <- function() {
  d <- file.path(tempdir(), paste0("t", as.integer(Sys.time()), sample.int(1e6, 1)))
  dir.create(d, recursive = TRUE)
  d
}

#' A small multi-firm panel exercising the main code paths in
#' build_accounts_indicators(): a steady firm, a 20%-employment-growth scaler,
#' a shrinking firm, an entrant, an exiter, and a firm with missing optional
#' financials.
make_base_financials <- function() {
  make_firm <- function(idf, employment, turnover, year = 2010:2018, sector_1d = NULL,
                         sector_2d = 26, sector_3d = 262, region_2d = "FR10") {
    n <- length(year)
    stopifnot(length(employment) == n, length(turnover) == n)
    if (is.null(sector_1d)) sector_1d <- nace_section(sector_2d, "2") # the letter of the division (NACE Rev. 2)
    data.frame(
      idf = rep(idf, n),
      year = year,
      sector_1d = rep(sector_1d, n),
      sector_2d = rep(sector_2d, n),
      sector_3d = rep(sector_3d, n),
      region_2d = rep(region_2d, n),
      employment = employment,
      turnover = turnover,
      stringsAsFactors = FALSE
    )
  }

  # Firm 1: steady, non-scaler.
  f1 <- make_firm(1, rep(50, 9), rep(5000, 9))

  # Firm 2: a genuine >20%-annualised employment scaler from 2013 (t-3=2010,
  # employment 40 -> 75 by 2013 is (75/40)^(1/3)-1 ~= 0.233, comfortably > 0.20).
  emp2 <- c(40, 50, 60, 75, 80, 85, 90, 92, 94)
  f2 <- make_firm(2, emp2, emp2 * 100, sector_2d = 62, sector_3d = 620)

  # Firm 3: shrinking firm.
  f3 <- make_firm(3, seq(100, 20, length.out = 9), seq(10000, 2000, length.out = 9))

  # Firm 4: entrant in 2014 (no rows before), small.
  f4 <- make_firm(4, rep(15, 5), rep(1000, 5), year = 2014:2018)
  f4$birth_year <- 2014

  # Firm 5: exits after 2015 (no rows after).
  f5 <- make_firm(5, rep(30, 6), rep(3000, 6), year = 2010:2015)

  # Firm 6: has the optional financial variables populated, for MFP/labour-share tests.
  f6 <- make_firm(6, rep(60, 9), rep(6000, 9), sector_2d = 28)
  f6$added_value <- f6$turnover * 0.4
  f6$labour_costs <- f6$turnover * 0.25
  f6$tangible_fixed_assets <- f6$turnover * 0.6

  # bind_rows (not base rbind): the firm-specific pieces above have different
  # optional columns (birth_year, added_value, ...) and bind_rows fills the
  # gaps with NA, matching how real per-country raw extracts vary in which
  # optional variables they supply.
  dplyr::bind_rows(f1, f2, f3, f4, f5, f6)
}

#' A longer panel (2010-2021) with a firm that scales specifically in 2017,
#' for exercising compute_persistence()'s panel-length gates (transitions
#' needs >=7 years reaching 2017; evolutions needs >=10 years reaching 2020).
make_base_financials_long <- function() {
  make_firm <- function(idf, employment, turnover, year = 2010:2021, sector_1d = NULL,
                         sector_2d = 26, sector_3d = 262, region_2d = "FR10") {
    n <- length(year)
    stopifnot(length(employment) == n, length(turnover) == n)
    if (is.null(sector_1d)) sector_1d <- nace_section(sector_2d, "2") # the letter of the division (NACE Rev. 2)
    data.frame(
      idf = rep(idf, n), year = year, sector_1d = rep(sector_1d, n),
      sector_2d = rep(sector_2d, n), sector_3d = rep(sector_3d, n),
      region_2d = rep(region_2d, n), employment = employment, turnover = turnover,
      stringsAsFactors = FALSE
    )
  }

  # Firm 10: flat 40 employees 2010-2014, then a clean >20%-annualised scale-up
  # completing exactly in 2017 (L3employment@2017 = employment@2014 = 40;
  # 75/40 = 1.875, (1.875)^(1/3)-1 ~= 0.233 > 0.20), then flattens out again -
  # engineered so 2017 is the *only* 3-year window crossing the 20% threshold.
  emp10 <- c(40, 40, 40, 40, 40, 50, 62, 75, 80, 85, 90, 92)
  f10 <- make_firm(10, emp10, emp10 * 100)

  # Firm 11: steady, non-scaler throughout - a comparison/"stable" case.
  f11 <- make_firm(11, rep(45, 12), rep(4500, 12), sector_2d = 62, sector_3d = 620)

  # Firm 12: scales within the 2014-2016 *transitions* cohort window (t-3=2012,
  # employment 30 -> 60 by 2015: (60/30)^(1/3)-1 ~= 0.26 > 0.20), flat before
  # and after so 2015 is the only qualifying window.
  emp12 <- c(30, 30, 30, 40, 50, 60, 62, 63, 64, 65, 66, 67)
  f12 <- make_firm(12, emp12, emp12 * 100)

  out <- dplyr::bind_rows(f10, f11, f12)
  out$birth_year <- 2000 # all 3 firms pre-date the panel; no entry/exit events to test here
  out
}

#' A larger randomized panel (80 firms x 2011-2020, single sector) clearing the
#' 50-observation-per-(sector,year)-cell disclosure floor in compute_predictors(),
#' with cross-sectional variation in productivity/wages/capital intensity and in
#' growth outcomes, for end-to-end testing of quartile typing and the regression
#' battery (neither of which produce non-trivial output on the small fixtures).
make_base_financials_wide <- function(seed = 42) {
  set.seed(seed)
  n_firms <- 80
  years <- 2011:2020
  firms <- lapply(seq_len(n_firms), function(i) {
    base_emp <- stats::rlnorm(1, meanlog = log(30), sdlog = 0.4)
    growth <- stats::rnorm(1, mean = 0.02, sd = 0.08)
    employment <- pmax(10, round(base_emp * (1 + growth)^(seq_along(years) - 1)))
    turnover <- employment * stats::rlnorm(1, meanlog = log(100), sdlog = 0.3)
    added_value <- turnover * stats::runif(1, 0.3, 0.5)
    labour_costs <- turnover * stats::runif(1, 0.15, 0.35)
    tangible_fixed_assets <- turnover * stats::runif(1, 0.4, 0.8)
    data.frame(
      idf = i, year = years, sector_1d = "C", sector_2d = 26, sector_3d = 262,
      region_2d = "FR10", employment = employment, turnover = turnover,
      added_value = added_value * stats::runif(length(years), 0.9, 1.1),
      labour_costs = labour_costs * stats::runif(length(years), 0.9, 1.1),
      tangible_fixed_assets = tangible_fixed_assets * stats::runif(length(years), 0.9, 1.1),
      birth_year = 2000,
      stringsAsFactors = FALSE
    )
  })
  dplyr::bind_rows(firms)
}

#' Minimal exchange_rates fixture.
make_exchange_rates <- function(country = "FR") {
  data.frame(year = 2010:2018, country = country, rate = 1.0)
}

#' Minimal tl3_typology fixture.
make_tl3_typology <- function() {
  data.frame(
    region_3d = c("FR101", "FR102"),
    typology_access_cities = c("MR-L", "NMR-R"),
    stringsAsFactors = FALSE
  )
}
