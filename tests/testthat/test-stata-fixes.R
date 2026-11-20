# Fixes of bugs in the original Stata code (FixStataBugs branch). Each test
# pins the corrected behaviour; the bug ids (S1-S16) refer to NEWS.md
# "Known issues inherited from the Stata code".

cfg_fr <- function() config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())

# a panel whose firms cover the given 2-digit sectors (one firm per sector)
bf_sectors <- function(s2) {
  bf <- make_base_financials()
  one <- bf[bf$idf == 1, ]
  dplyr::bind_rows(lapply(seq_along(s2), function(i) {
    f <- one; f$idf <- 100 + i; f$sector_2d <- s2[i]; f$sector_3d <- s2[i] * 10; f$birth_year <- 2000; f
  }))
}

test_that("S2: NACE 68-82 get their own A38 groups, no D68T82 aggregate", {
  s2 <- c(68, 69, 70, 71, 72, 73, 74, 75, 77, 78, 79, 80, 81, 82)
  ai <- build_accounts_indicators(cfg_fr(), bf_sectors(s2))
  got <- unique(ai[c("sector_2d", "ind_a38")])
  got <- stats::setNames(got$ind_a38, got$sector_2d)
  expect_equal(unname(got[as.character(s2)]),
               c("D68", rep("D69T71", 3), "D72", rep("D73T75", 3), rep("D77T82", 6)))
  expect_false("D68T82" %in% ai$ind_a38)
})

test_that("S3: a TL1 without small TL2 regions is not merged; small-dominated ones are", {
  # one row per region-year with HGET10 = the region's count of HG firms that year
  d <- data.frame(
    region_2d = rep(c("ITC1", "ITC2", "ITH1", "ITH2", "ITF1", "ITF2"), each = 2),
    year = rep(2015:2016, 6),
    HGET10 = c(200, 200, 300, 300,   # ITC: both large -> share 0 (Stata: missing -> merged)
               20, 20, 150, 150,     # ITH: small 20 of 170 -> share 0.12, not merged
               0, 0, 0, 0)           # ITF: all small, no HG firm -> 0/0 -> merged, as in Stata
  )
  m <- small_region_map(d)
  adj <- stats::setNames(m$region_adj, m$region_2d)
  expect_equal(unname(adj[c("ITC1", "ITC2", "ITH1", "ITH2", "ITF1", "ITF2")]),
               c("ITC1", "ITC2", "ITH1", "ITH2", "ITF", "ITF"))
  d2 <- data.frame(region_2d = c("ITI1", "ITI2"), year = 2015, HGET10 = c(90, 60)) # small 150 of 150
  expect_equal(small_region_map(d2)$region_adj, c("ITI", "ITI"))
})

test_that("S8: with both age_cat and birth_year, birth_year drives age and entry; age_cat is kept", {
  bf <- make_base_financials()
  bf$birth_year <- ifelse(bf$idf == 4, 2014, 2000)
  bf$age_cat <- 11 # deliberately inconsistent with birth_year: must be kept as supplied
  ai <- build_accounts_indicators(cfg_fr(), bf)
  expect_true(all(ai$age_cat == 11))
  expect_equal(ai$age[ai$idf == 1 & ai$year == 2015], 15)
  expect_equal(ai$entry[ai$idf == 4 & ai$year == 2014], 1)
  expect_true("L3age" %in% names(ai))
  # an empty birth_year column falls back to the age_cat branch
  bf2 <- make_base_financials(); bf2$birth_year <- NA_real_; bf2$age_cat <- 11
  expect_no_error(build_accounts_indicators(cfg_fr(), bf2))
})

test_that("S16: cash_flow and gross_profit are rescaled to thousands with the other financials", {
  bf <- make_base_financials()
  bf$birth_year <- 2000
  bf$cash_flow <- 2000; bf$gross_profit <- 3000; bf$total_assets <- 10000
  cfg <- config_scaleup(country = "PT", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, bf)
  expect_true(all(ai$cash_flow == 2, na.rm = TRUE))
  expect_true(all(ai$gross_profit == 3, na.rm = TRUE))
  expect_true(all(ai$total_assets == 10, na.rm = TRUE))
})
