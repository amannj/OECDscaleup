test_that("round_half_up matches Stata's round-half-away-from-zero", {
  expect_equal(round_half_up(0.5), 1)
  expect_equal(round_half_up(1.5), 2)
  expect_equal(round_half_up(2.5), 3)
  expect_equal(round_half_up(-0.5), -1)
  expect_equal(round_half_up(0.25, digits = 1), 0.3)
  # sanity check that this genuinely differs from base R's banker's rounding
  expect_false(isTRUE(all.equal(round(0.5), round_half_up(0.5))))
})

test_that("stata_num() reproduces Stata's definite (non-propagating) missing-value comparisons", {
  x <- c(5, NA, -3, 0)
  expect_equal(stata_num(x) == 0, c(FALSE, FALSE, FALSE, TRUE))
  expect_equal(stata_num(x) < 2, c(FALSE, FALSE, TRUE, TRUE))
  expect_equal(stata_num(x) > 10, c(FALSE, TRUE, FALSE, FALSE))
  expect_equal(stata_num(x) >= 5, c(TRUE, TRUE, FALSE, FALSE))
  # contrast with base R's NA-propagating behaviour, to document *why* this helper exists
  expect_true(is.na((x == 0)[2]))
})

test_that("stata_replace preserves the current value when cond is NA (unlike dplyr::if_else)", {
  cur <- c(1, 1, NA)
  cond <- c(TRUE, NA, TRUE)
  expect_equal(stata_replace(cur, cond, 99), c(99, 1, 99))
  # contrast with dplyr::if_else, to document *why* this helper exists
  expect_true(is.na(dplyr::if_else(cond, 99, cur)[2]))
})

test_that("cut_stata bins with lower-bound labels and an exclusive final breakpoint", {
  x <- c(-1, 0, 5, 6, 10, 11, 50, 9998, 9999, 10000, NA)
  out <- cut_stata(x, at = c(0, 6, 11, 9999))
  expect_equal(out, c(NA, 0, 0, 6, 6, 11, 11, 11, NA, NA, NA))
})

test_that("panel_lag/panel_lead are calendar-aware, not row-offset", {
  id <- c(1, 1, 1, 1)
  year <- c(2010, 2011, 2014, 2015)
  x <- c(100, 105, 120, 125)

  expect_true(is.na(panel_lag(x, 1, id, year)[year == 2014])) # needs 2013, gap
  expect_equal(panel_lag(x, 3, id, year)[year == 2014], 105) # needs 2011, exists
  expect_equal(panel_lag(x, 1, id, year)[year == 2015], 120) # needs 2014, exists
  expect_true(is.na(panel_lag(x, 3, id, year)[year == 2015])) # needs 2012, gap
  expect_true(is.na(panel_lead(x, 1, id, year)[year == 2011])) # needs 2012, gap
  expect_equal(panel_lead(x, 1, id, year)[year == 2010], 105) # needs 2011, exists
})

test_that("panel_diff1 and panel_sdiff are defined relative to panel_lag", {
  id <- c(1, 1, 1)
  year <- c(2010, 2011, 2012)
  x <- c(10, 15, 25)
  expect_equal(panel_diff1(x, id, year), x - panel_lag(x, 1, id, year))
  expect_equal(panel_sdiff(x, 2, id, year), x - panel_lag(x, 2, id, year))
})

test_that("approx_median averages the 5 central sorted non-missing values", {
  expect_equal(approx_median(1:10), 5) # n=10, center=5, positions 3:7
  expect_equal(approx_median(1:7), 4) # n=7, center=round_half_up(3.5)=4, positions 2:6
  expect_equal(approx_median(c(10, 20, 30)), 20) # n=3, window clipped to all 3
  expect_equal(approx_median(c(1:5, NA, NA)), 3) # missing sorted last, excluded from n
  expect_true(is.na(approx_median(c(NA, NA))))
})

test_that("approx_median is not simply the true median", {
  # a case where the 5-point local average and the true median differ
  x <- c(1, 2, 3, 4, 100)
  expect_equal(approx_median(x), mean(x)) # n=5, center=3, window=all 5 -> mean, not median
  expect_equal(stats::median(x), 3)
  expect_false(isTRUE(all.equal(approx_median(x), stats::median(x))))
})

test_that("dominance_share computes top-N concentration and handles edge cases", {
  emp <- c(10, 50, 5, 100, 20, NA)
  expect_equal(dominance_share(emp, 2), 150 / 185)
  expect_true(is.na(dominance_share(c(1, 2), 5))) # top_n > n
  expect_true(is.na(dominance_share(c(NA, NA), 1))) # total is 0/NA
  expect_true(is.na(dominance_share(c(0, 0), 1))) # total is exactly 0
})

test_that("first_occurrence_flag fires once, at the chronologically first event", {
  id <- c(1, 1, 1, 1, 1, 2, 2, 2)
  year <- c(2010, 2011, 2012, 2013, 2014, 2010, 2011, 2012)
  x <- c(0, 1, 0, 1, 0, NA, 0, 1)
  flag <- first_occurrence_flag(id, year, x)
  expect_equal(flag[id == 1], c(0L, 1L, 0L, 0L, 0L))
  expect_equal(flag[id == 2], c(0L, 0L, 1L))
})

test_that("first_occurrence_flag is robust to input row order", {
  id <- c(1, 1, 1)
  year <- c(2012, 2010, 2011) # deliberately out of order
  x <- c(0, 1, 0)
  flag <- first_occurrence_flag(id, year, x)
  # year 2010 (x=1) is the first chronologically, regardless of row position
  expect_equal(flag[year == 2010], 1L)
  expect_equal(flag[year == 2011], 0L)
  expect_equal(flag[year == 2012], 0L)
})

test_that("quartile_bin passes NA through and bins into 1..n", {
  x <- c(1:20, NA, NA)
  q <- quartile_bin(x, n = 4)
  expect_true(all(is.na(q[is.na(x)])))
  expect_equal(range(q, na.rm = TRUE), c(1, 4))
})

test_that("has_column detects presence and all-missing columns", {
  df <- data.frame(a = c(1, 2, NA), b = c(NA_real_, NA_real_, NA_real_))
  expect_true(has_column(df, "a"))
  expect_false(has_column(df, "b")) # exists but entirely missing
  expect_false(has_column(df, "c")) # doesn't exist at all
})
