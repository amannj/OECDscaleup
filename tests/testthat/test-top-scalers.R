# compute_top_scalers(): indices, ranking with tie-breaks, cut-offs, creation shares.

test_that("lex_rank_desc ranks descending, breaks ties by the next keys, shares exact ties", {
  g  <- c(1, 1, 1, 1, 1, 2, 2)
  k1 <- c(5, 5, 5, 3, NA, 1, 1)
  k2 <- c(2, 2, 1, 9, 9, 0, 0)
  k3 <- c(0, 0, 0, 0, 0, 1, 2)
  # group 1: (5,2,0) x2 share rank 1; (5,1,0) is 3rd; (3,9,0) 4th; missing last. group 2: k3 decides.
  expect_equal(lex_rank_desc(g, k1, k2, k3), c(1L, 1L, 3L, 4L, 5L, 2L, 1L))
})

test_that("top_scaler_k: counts as given, shares rounded up, at least one firm", {
  expect_equal(top_scaler_k(0.01, c(150, 100, 10)), c(2, 1, 1))
  expect_equal(top_scaler_k(0.05, 100), 5)
  expect_equal(top_scaler_k(0.07, 100), 7) # 0.07 * 100 is 7.000000000000001 in double
  expect_equal(top_scaler_k(50, c(10, 200)), c(50, 50))
})

test_that("top_scaler_indices: relative, absolute and Birch-Schreyer growth", {
  idx <- top_scaler_indices(c(20, 30, 5), c(10, 0, NA))
  expect_equal(idx$rel, c(1, NA, NA))
  expect_equal(idx$abs, c(10, NA, NA))
  expect_equal(idx$bs, c(20, NA, NA))
})

# 24 firms observed 2010-2013, flat until 2012 (so the analysis year is 2013):
#  1-20: 20 -> 40 + i employees (all HGE20); 21: copy of firm 20 (an exact tie);
#  22: 100 -> 200 (lowest relative growth of the scalers, highest absolute);
#  23: 20 -> 80 but acquisition-driven (excluded); 24: 20 -> 25 (not a scaler).
top_fixture <- function() {
  l3 <- c(rep(20, 21), 100, 20, 20)
  x <- c(40 + 1:20, 60, 200, 80, 25)
  n <- length(x)
  ai <- data.frame(
    idf = rep(seq_len(n), 4), year = rep(2010:2013, each = n),
    employment = c(l3, l3, l3, x), L3employment = c(rep(NA, 3 * n), l3)
  )
  ai$turnover <- ai$employment * 100
  ai$L3turnover <- ai$L3employment * 100
  hg <- as.integer((ai$employment / ai$L3employment)^(1 / 3) - 1 > 0.2)
  ai$HGE20 <- hg
  ai$HGT20 <- hg
  ai$acquisition <- ifelse(ai$year == 2013, as.integer(ai$idf == 23), NA)
  ai
}

test_that("compute_top_scalers: population, tie inclusion and cut-offs (hand-checked)", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  out <- compute_top_scalers(cfg, top_fixture(), cutoffs = c(top2 = 2, p10 = 0.10))
  all <- out[out$category == "ALL", ]
  n_of <- function(s) all$firm_count[all$sample == s]

  expect_equal(unique(all$year), 2013)
  expect_equal(n_of("HGE20_ranked"), 22) # firms 1-22: acquisition (23) and non-scaler (24) out
  expect_equal(unique(all$n_ranked), 22)
  expect_equal(all$rank_cutoff[all$sample == "HGE20_rel_p10"], 3) # ceiling(0.1 * 22)

  # relative: firms 20 and 21 tie on all three indices (rank 1), firm 19 is 3rd
  expect_equal(n_of("HGE20_rel_top2"), 2)
  expect_equal(n_of("HGE20_rel_p10"), 3)
  # absolute: firm 22 first (100), firms 20/21 tied 2nd (40) -> both included in the top 2
  expect_equal(n_of("HGE20_abs_top2"), 3)
  # Birch-Schreyer: firm 22 = 100 * 2 = 200 first, firms 20/21 = 40 * 3 = 120 tied 2nd
  expect_equal(n_of("HGE20_bs_top2"), 3)
  expect_equal(n_of("HGT20_abs_top2"), 3)

  # share of creation: over all firms with growth in 2013, incl. the acquisition and the non-scaler
  total <- sum(c(40 + 1:20, 60, 200, 80, 25) - c(rep(20, 21), 100, 20, 20))
  row <- all[all$sample == "HGE20_rel_top2", ]
  expect_equal(row$S3pos_employment, 80)
  expect_equal(row$share_creation_employment, 80 / total)
  expect_equal(all$share_creation_turnover[all$sample == "HGT20_abs_top2"], (100 + 80) * 100 / (total * 100))
})

test_that("joint_growth drops employment scalers whose turnover fell", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- top_fixture()
  ai$turnover[ai$idf == 22 & ai$year == 2013] <- 5000 # 100 * 100 at t-3: turnover fell
  base <- compute_top_scalers(cfg, ai, cutoffs = c(top2 = 2))
  joint <- compute_top_scalers(cfg, ai, cutoffs = c(top2 = 2), joint_growth = TRUE)
  n_of <- function(out, s) out$firm_count[out$category == "ALL" & out$sample == s]
  expect_equal(n_of(base, "HGE20_abs_top2"), 3)
  expect_equal(n_of(joint, "HGE20_abs_top2"), 2) # firm 22 out: firms 20 and 21 remain
  expect_equal(n_of(joint, "HGE20_ranked"), 21)
  expect_true(all(joint$joint_growth) && !any(base$joint_growth))
})

test_that("compute_top_scalers runs on a built panel and keeps every cut-off", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  bf <- make_base_financials_wide()
  fast <- bf$idf <= 15 # steady 30 % a year: high-growth scalers every year from 2014
  bf$employment[fast] <- round(20 * 1.3^(bf$year[fast] - 2011) * (1 + bf$idf[fast] / 100))
  bf$turnover[fast] <- bf$employment[fast] * 100
  ai <- build_accounts_indicators(cfg, bf)
  out <- compute_top_scalers(cfg, ai)
  cols <- c("year", "sample", "category", "group", "firm_count", "n_ranked", "rank_cutoff",
            "S3pos_employment", "share_creation_employment")
  expect_true(all(cols %in% names(out)))
  expect_true(all(c("HGE20_rel_top50", "HGE20_bs_p25", "HGT20_abs_p1") %in% out$sample))
  ranked <- out[out$category == "ALL" & grepl("_ranked$", out$sample), ]
  tops <- out[out$category == "ALL" & !grepl("_ranked$", out$sample), ]
  m <- merge(tops, ranked[c("year", "firm_count")], by = "year", suffixes = c("", "_ranked"))
  expect_true(all(m$firm_count <= m$firm_count_ranked))
  expect_true(all(out$share_creation_employment >= 0 & out$share_creation_employment <= 1, na.rm = TRUE))
})
