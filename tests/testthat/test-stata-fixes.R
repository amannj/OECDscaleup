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
