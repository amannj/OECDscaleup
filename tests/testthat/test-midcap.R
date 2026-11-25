# compute_midcap_transitions(): status rules, two-year crossing rule, risk set, competing exit.

test_that("midcap_status follows the EU thresholds, with three-valued logic for missing values", {
  emp <- c(300, 100, 100, 800, 3500, 100, 300, 100, 100, 749.9, 300, 250, 249.5)
  to  <- c(1000, 60000, 200000, 1000, 1000, 60000, 60000, 40000, 50000, 150000, 150001, 1, 1)
  bs  <- c(1000, 50000, 140000, 1000, 1000, NA, NA, NA, 43001, 200000, 129001, 1, 1)
  expect_equal(
    midcap_status(emp, to, bs, "small_midcap"),
    c("mid", "mid", "large", "large", "large", NA, "mid", "sme", "sme", "mid", "large", "mid", "sme")
  )
  expect_equal(
    midcap_status(emp, to, bs, "sme_exit"),
    c("mid", "mid", "mid", "mid", "large", NA, "mid", "sme", "sme", "mid", "mid", "mid", "sme")
  )
  expect_equal(
    midcap_status(emp, to, bs, "employment_250"),
    c("mid", "sme", "sme", "mid", "large", "sme", "mid", "sme", "sme", "mid", "mid", "mid", "sme")
  )
})

# Panel 2010-2020; every firm scales (HGE20) in its entry year, employment drives the status:
# Panel 2010-2020; the sample year t is 2013 (firm 6: 2019), so firms enter at t-3 = 2010 (firm 6: 2016).
# Employment drives the status:
#  1: 100 to 2013, 300, 100, 300, 300 ... -> 2014 not confirmed; crossing 2016 (step 6, mid)
#  2: 100, ..., 300 (2014), [no 2015 row], 3500 ... -> 2014 not confirmed (gap); crossing 2016 (step 6, large)
#  3: 100 ..., 300 in its last year 2015 -> no confirmation; exit at step 5
#  4: 100 throughout -> censored at 2019 (step 9)
#  5: 300 from 2013 -> crossing during the growth window, 2013 (step 3, mid)
#  6: enters 2016, censored at 2019 (step 3)
#  7: employment missing at t-3 -> status missing, not followed
#  8: 300 at t-3 -> above at entry, not followed
midcap_fixture <- function() {
  rows <- function(idf, years, emp) data.frame(idf = idf, year = years, employment = emp)
  ai <- rbind(
    rows(1, 2010:2020, c(100, 100, 100, 100, 300, 100, rep(300, 5))),
    rows(2, c(2010:2014, 2016:2020), c(100, 100, 100, 100, 300, rep(3500, 5))),
    rows(3, 2010:2015, c(100, 100, 100, 100, 100, 300)),
    rows(4, 2010:2020, 100),
    rows(5, 2010:2020, c(100, 100, 100, 300, rep(300, 7))),
    rows(6, 2016:2020, 100),
    rows(7, 2010:2020, c(NA, rep(100, 10))),
    rows(8, 2010:2020, c(300, rep(100, 10)))
  )
  ai$L3employment <- 100 # the sample condition at t (10 to < 250 at t-3), set directly
  ai$HGE20 <- as.integer((ai$idf != 6 & ai$year == 2013) | (ai$idf == 6 & ai$year == 2019))
  ai$HGE_pool <- 0L
  ai$turnover <- 1000
  ai$total_assets <- 1000
  ai
}

test_that("compute_midcap_transitions: entry, two-year rule, gaps, exit and censoring (hand-checked)", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  res <- compute_midcap_transitions(cfg, midcap_fixture())
  pick <- function(tab, d = "employment_250") tab[tab$definition == d & tab$sample == "HGE20" & tab$category == "ALL", ]

  ent <- pick(res$entry)
  expect_equal(ent$n_entering, 8)
  expect_equal(ent$n_followed, 6)
  expect_equal(c(ent$n_above_at_entry, ent$n_status_missing_at_entry, ent$n_no_followup), c(1, 1, 0))

  inc <- pick(res$incidence)
  expect_equal(inc$step, 1:9)
  expect_equal(inc$at_risk, c(6, 6, 6, 4, 4, 3, 1, 1, 1))
  expect_equal(inc$cross_mid, c(0, 0, 1, 0, 0, 1, 0, 0, 0))
  expect_equal(inc$cross_large, c(0, 0, 0, 0, 0, 1, 0, 0, 0))
  expect_equal(inc$exits, c(0, 0, 0, 0, 1, 0, 0, 0, 0))
  expect_equal(inc$censored, c(0, 0, 1, 0, 0, 0, 0, 0, 1))
  # Aalen-Johansen: mid 1/6 at step 3; S(3) = 5/6; exit 5/6 * 1/4 at step 5; S(5) = 5/8;
  # mid and large 5/8 * 1/3 each at step 6
  expect_equal(inc$cif_mid[3], 1 / 6)
  expect_equal(inc$cif_exit[9], 5 / 24)
  expect_equal(inc$cif_mid[9], 1 / 6 + 5 / 24)
  expect_equal(inc$cif_large[9], 5 / 24)

  # the three definitions agree here (turnover and balance sheet far below the limits; 3,500 is large in all)
  for (d in c("small_midcap", "sme_exit")) expect_equal(pick(res$incidence, d)$cif_large, inc$cif_large)

  by <- pick(res$by_year)
  expect_equal(by$year, 2011:2019)
  expect_equal(by$at_risk, c(5, 5, 5, 4, 4, 3, 2, 2, 2))
  expect_equal(by$cross_mid, c(0, 0, 1, 0, 0, 1, 0, 0, 0))
  expect_equal(by$cross_large, c(0, 0, 0, 0, 0, 1, 0, 0, 0))
  expect_equal(by$exits, c(0, 0, 0, 0, 1, 0, 0, 0, 0))
})

test_that("top-scaler samples are followed as risk sets of their own (the link to part 1)", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  res <- compute_midcap_transitions(cfg, midcap_fixture(), top_cutoffs = c(top50 = 50))
  pick <- function(tab) tab[tab$definition == "employment_250" & tab$sample == "HGE20_rel_top50", ]
  # all 8 firms are ranked (each observed at t-3 and t); firm 7 has no status and firm 8 is above at t-3
  e <- pick(res$entry)
  expect_equal(c(e$n_entering, e$n_followed, e$n_above_at_entry, e$n_status_missing_at_entry), c(8, 6, 1, 1))
  expect_equal(unique(pick(res$incidence)$category), "ALL")
  expect_equal(pick(res$incidence)$cif_mid[9], 1 / 6 + 5 / 24)
  expect_false(any(grepl("top50", compute_midcap_transitions(cfg, midcap_fixture(), top_cutoffs = NULL)$entry$sample)))
})

test_that("midcap_person_periods: one row per step, outcome in the event step, covariates from t-1", {
  sp <- list(row = c(1L, 2L, 3L), entry = c(2013, 2013, 2014), steps = c(3, NA, 2), type = c("mid", NA, "exit"))
  covariates <- data.frame(idf = c(10, 10, 10, 30, 30), year = c(2013, 2014, 2015, 2014, 2015),
                           log_employment = c(1, 2, 3, 7, 8))
  pp <- midcap_person_periods(sp, c(10, 20, 30), covariates, scaler = 1L)
  expect_equal(pp$idf, c(10, 10, 10, 30, 30))
  expect_equal(pp$year, c(2014, 2015, 2016, 2015, 2016))
  expect_equal(pp$step, c(1, 2, 3, 1, 2))
  expect_equal(pp$y, c(0, 0, 1, 0, 0)) # the exit is not a crossing
  expect_equal(pp$log_employment, c(1, 2, 3, 7, 8))
})

test_that("midcap_hazard_fit recovers the logit and gives clustered errors near the model ones", {
  set.seed(7)
  n <- 20000
  firm <- data.frame(idf = seq_len(n), scaler = rbinom(n, 1, 0.3), entry = sample(2012:2016, n, TRUE),
                     size = rnorm(n, 3.5, 0.6))
  pp <- firm[rep(seq_len(n), each = 4), ]
  pp$step <- rep(1:4, n)
  pp$year <- pp$entry + pp$step
  pp$log_employment <- pp$size + rnorm(nrow(pp), 0, 0.1)
  pp$y <- rbinom(nrow(pp), 1, plogis(-6 + 1 * pp$scaler + 0.6 * pp$log_employment))
  fit <- midcap_hazard_fit(pp[c("idf", "year", "step", "y", "scaler", "log_employment")])
  b <- setNames(fit$b, fit$term); se <- setNames(fit$se, fit$term)
  expect_lt(abs(b[["scaler"]] - 1), 4 * se[["scaler"]])
  expect_lt(abs(b[["log_employment"]] - 0.6), 4 * se[["log_employment"]])
  # model-based SE for comparison: no within-firm dependence beyond the covariates, so similar
  X <- cbind(1, as.matrix(pp[c("scaler", "log_employment", "step")]), pp$step^2, pp$year - median(pp$year))
  m <- glm(pp$y ~ X - 1, family = binomial())
  ratio <- se[["scaler"]] / sqrt(diag(vcov(m)))[2]
  expect_gt(ratio, 0.85)
  expect_lt(ratio, 1.15)
  expect_gt(fit$ame_scaler[1], 0)
  expect_equal(fit$events[1], sum(pp$y))
})

test_that("the hazard table has the full model and the net one (years after the growth window)", {
  set.seed(11)
  n <- 600
  cross <- ifelse(runif(n) < ifelse(seq_len(n) %% 2 == 1, 0.5, 0.15), sample(2011:2019, n, TRUE), Inf)
  ai <- data.frame(idf = rep(seq_len(n), each = 11), year = rep(2010:2020, n))
  ai$employment <- ifelse(ai$year >= cross[ai$idf], 300, 100)
  ai$L3employment <- 100
  ai$HGE20 <- as.integer(ai$year == 2013 & ai$idf %% 2 == 1)
  ai$HGE_pool <- as.integer(ai$year == 2013)
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  h <- compute_midcap_transitions(cfg, ai, top_cutoffs = NULL)$hazard
  h <- h[h$definition == "employment_250" & h$term == "scaler", ]
  expect_setequal(h$window, c("from_t-3", "after_window"))
  full <- h[h$window == "from_t-3", ]; net <- h[h$window == "after_window", ]
  expect_lt(net$obs, full$obs)
  expect_lt(net$events, full$events)
  expect_gt(net$b, 0) # scalers cross more often after the window too, by construction here
})

test_that("money_unit: euros are caught when thousands are declared, and rescaled when declared", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- midcap_fixture()
  ai$employment[ai$idf == 4] <- 20 # a firm with 10-49 employees for the check
  ref <- compute_midcap_transitions(cfg, ai)
  eur <- ai
  eur$turnover <- eur$turnover * 1000 * 10 # EUR 500,000 per employee for the 20-employee firm
  eur$total_assets <- eur$total_assets * 1000
  expect_error(compute_midcap_transitions(cfg, eur), "money_unit = \"EUR\"")
  eur$turnover <- ai$turnover * 1000
  expect_equal(compute_midcap_transitions(cfg, eur, money_unit = "EUR"), ref)
})

test_that("consolidated accounts get no status, and a status needs the financials it depends on", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- midcap_fixture()
  ai$consolidation_code <- ifelse(ai$idf == 4 & ai$year == 2010, "C1", "U1")
  ent <- compute_midcap_transitions(cfg, ai)$entry
  e <- ent[ent$definition == "employment_250" & ent$sample == "HGE20" & ent$category == "ALL", ]
  expect_equal(e$n_status_missing_at_entry, 2) # firm 7 and firm 4's consolidated entry year (t-3)

  ai <- midcap_fixture()
  ai$total_assets <- NULL
  res <- compute_midcap_transitions(cfg, ai)
  expect_equal(unique(res$incidence$definition), "employment_250")
})
