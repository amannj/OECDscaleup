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

test_that("S1: the jump filter blanks the spike year, not the year after", {
  bf <- make_base_financials()
  bf$birth_year <- 2000
  bf$employment[bf$idf == 1 & bf$year == 2013] <- 500 # 50-500-50
  bf$turnover[bf$idf == 3 & bf$year == 2015] <- 80000 # 6000-80000-4000 turnover spike, employment ~50
  ai <- build_accounts_indicators(cfg_fr(), bf)
  e <- ai[ai$idf == 1, ]
  expect_true(is.na(e$employment[e$year == 2013]))
  expect_equal(e$employment[e$year %in% c(2012, 2014)], c(50, 50))
  t3 <- ai[ai$idf == 3, ]
  expect_true(is.na(t3$turnover[t3$year == 2015]))
  expect_false(anyNA(t3$turnover[t3$year %in% c(2014, 2016)]))
  # a lasting level change is not a spike
  bf2 <- make_base_financials(); bf2$birth_year <- 2000
  bf2$employment[bf2$idf == 1 & bf2$year >= 2013] <- 500
  ai2 <- build_accounts_indicators(cfg_fr(), bf2)
  expect_false(anyNA(ai2$employment[ai2$idf == 1]))
})

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

test_that("S6: a firm that is micro at t-3 does not enter the regressions", {
  bf <- make_base_financials_wide()
  extra <- bf[bf$idf == 1, ]
  extra$idf <- 999
  extra$employment <- ifelse(extra$year <= 2013, 5, 12) # micro at t-3 = 2011, not in the HG pool in 2014
  ai0 <- build_accounts_indicators(cfg_fr(), bf)
  ai1 <- build_accounts_indicators(cfg_fr(), rbind(bf, extra))
  r0 <- compute_predictors(cfg_fr(), ai0)$regs_predictors
  r1 <- compute_predictors(cfg_fr(), ai1)$regs_predictors
  key <- c("model", "controls", "year", "sample", "depvar", "indepvar")
  m <- merge(r0[r0$year == 2014, c(key, "obs")], r1[r1$year == 2014, c(key, "obs")], by = key)
  expect_gt(nrow(m), 0)
  expect_equal(m$obs.x, m$obs.y)
})

test_that("S7: a region with typology '..' has a missing typology, not a '..' category", {
  bf <- make_base_financials()
  dotdot <- tl3_typology$region_3d[tl3_typology$typology_access_cities == ".."][1]
  bf$region_3d <- "FR101"
  bf$region_3d[bf$idf == 2] <- dotdot
  ai <- build_accounts_indicators(cfg_fr(), bf, tl3_typology = tl3_typology)
  expect_true(all(is.na(ai$typology_UR[ai$idf == 2])))
  expect_false(".." %in% ai$typology_UR)
  expect_true(all(!is.na(ai$typology_UR[ai$idf == 1])))
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

test_that("S5: contribution years need their t-3 inside the panel", {
  bf <- make_base_financials()
  bf$birth_year <- 2000
  ai <- build_accounts_indicators(cfg_fr(), bf[bf$year >= 2012, ]) # panel 2012-2018
  co <- compute_contribution(cfg_fr(), ai)
  expect_false(2014 %in% co$contribution_p1$year) # t-3 = 2011 is outside the panel
  expect_true(all(co$contribution_p1$year %in% 2017))
  ai_full <- build_accounts_indicators(cfg_fr(), bf) # panel 2010-2018: 2014 and 2017
  expect_setequal(unique(compute_contribution(cfg_fr(), ai_full)$contribution_p1$year), c(2014, 2017))
})

test_that("S9: fractional FTE below 10 (or below 1) at t-3 is micro, in scalers and comparison pool alike", {
  bf <- make_base_financials_wide()
  bf$employment[bf$idf == 1 & bf$year == 2012] <- 9.5 # micro non-scaler at 2015
  bf$employment[bf$idf == 1 & bf$year == 2015] <- 9.6
  # micro scaler at 2015 (0.5 -> 2), small all along so the jump filter (S1) leaves it alone
  bf$employment[bf$idf == 2 & bf$year <= 2015] <- c(0.5, 0.5, 1, 1.5, 2)
  ai <- build_accounts_indicators(cfg_fr(), bf)
  expect_equal(ai$MHGE20[ai$idf == 2 & ai$year == 2015], 1L)
  ch <- compute_characteristics(cfg_fr(), ai)
  pool <- ch[ch$sample == "MHGE20_nonscaler_pool" & ch$category == "ALL" & ch$year == 2015, ]
  scal <- ch[ch$sample == "MHGE20" & ch$category == "ALL" & ch$year == 2015, ]
  expect_equal(pool$firm_count, 1) # the 9.5 FTE firm
  expect_equal(scal$firm_count, 1) # the 0.5 FTE firm
})

test_that("S13: an unlabelled user-supplied age_cat does not stop the pipeline (Stata crashed)", {
  bf <- make_base_financials_long()
  bf$birth_year <- NULL
  bf$age_cat <- 11 # plain numeric, no value labels
  ai <- build_accounts_indicators(cfg_fr(), bf)
  ch <- compute_characteristics(cfg_fr(), ai)
  expect_true("L3age_cat" %in% ch$category)
})

test_that("S14: with no regression year in the panel, desc_predictors is still produced (Stata crashed)", {
  bf <- make_base_financials_wide()
  bf <- bf[bf$year >= 2015 & bf$year <= 2019, ] # regressions need 2014/2017/2020 after the t-3 cut
  ai <- build_accounts_indicators(cfg_fr(), bf)
  pr <- compute_predictors(cfg_fr(), ai)
  expect_gt(nrow(pr$desc_predictors), 0)
  expect_true(is.null(pr$regs_predictors) || nrow(pr$regs_predictors) == 0)
})

test_that("S15: the divisions Stata left without a tech_grad group are assigned", {
  s2 <- c(58, 59, 60, 63, 77, 90, 91, 92, 93, 94, 96, 1, 64, 84)
  ai <- build_accounts_indicators(cfg_fr(), bf_sectors(s2))
  got <- unique(ai[c("sector_2d", "tech_grad")])
  got <- stats::setNames(got$tech_grad, got$sector_2d)
  expect_equal(unname(got[as.character(s2)]), c(3, 3, 3, 3, 4, 7, 7, 7, 7, 7, 7, NA, NA, NA))
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
