# Stata storage / arithmetic semantics. Each expectation below was observed in
# Stata 19.5 output during the Stata <-> R reproduction (2026-11-18).

test_that("stata_float() stores single precision and turns non-finite results into missing", {
  # 8/10 is exactly 0.8 in double but 0.800000011920929 as a Stata float
  expect_false(8 / 10 > 0.8)
  expect_true(stata_float(8 / 10) > 0.8)
  expect_equal(stata_float(c(1, Inf, -Inf, NaN, NA)), c(1, NA, NA, NA, NA))
  expect_equal(stata_float(1 / 3), 0.3333333432674408, tolerance = 0)
})

test_that("stata_double() only maps x/0, ln(0) and 0/0 to missing", {
  expect_equal(stata_double(c(1 / 0, log(0), 0 / 0, 2.5)), c(NA, NA, NA, 2.5))
})

test_that("stata_pow() evaluates x^y as Stata does: exp(y * ln(x))", {
  expect_identical(stata_pow(8, 1 / 3), 1.9999999999999998)
  # exactly 10% / 20% a year over three years is *not* above the threshold in Stata
  expect_false(stata_pow(1.331, 1 / 3) - 1 > 0.1)
  expect_false(stata_pow(1.728, 1 / 3) - 1 > 0.2)
  expect_true(1.331^(1 / 3) - 1 > 0.1) # ... while R's pow() says it is
  expect_equal(stata_pow(0, 1 / 3), 0)
  expect_true(is.na(stata_pow(-1, 1 / 3)))
})

test_that("stata_encode_levels() uses byte order and extends an existing label", {
  codes <- stata_encode_levels(c("FRB0", "FR10", "FRa1", NA, "", "FR10"))
  expect_equal(names(codes), c("FR10", "FRB0", "FRa1")) # digits < upper case < lower case
  expect_equal(unname(codes), c(1, 2, 3))
  # typology_UR: the tl3_typology.dta label (".." = 1, ...) is extended, not replaced
  ext <- stata_encode_levels(c("Remote region", "..", "Metropolitan region"), existing = c(.. = 1, Intermediate = 2))
  expect_equal(ext[[".."]], 1)
  expect_equal(ext[["Metropolitan region"]], 3)
  expect_equal(ext[["Remote region"]], 4)
})

test_that("stata_regress_robust() reproduces regress, robust (HC1) and Stata's term names", {
  set.seed(3)
  n <- 120
  d <- data.frame(y = rbinom(n, 1, .3), x = rbinom(n, 1, .25), g = sample(c(0, 6, 11), n, TRUE))
  fit <- stata_regress_robust(d$y, d["x"], list(L3age_cat = d$g))
  expect_equal(fit$table$indepvar, c("x", "0b.L3age_cat", "6.L3age_cat", "11.L3age_cat", "_cons"))
  X <- model.matrix(~ x + factor(g), d)
  e <- resid(lm(y ~ x + factor(g), d))
  V <- solve(crossprod(X)) %*% crossprod(X * e) %*% solve(crossprod(X)) * n / (n - ncol(X))
  est <- fit$table[fit$table$indepvar != "0b.L3age_cat", ]
  expect_equal(est$b, unname(coef(lm(y ~ x + factor(g), d)))[c(2, 3, 4, 1)], tolerance = 1e-10)
  expect_equal(est$se, unname(sqrt(diag(V)))[c(2, 3, 4, 1)], tolerance = 1e-10)
  expect_equal(fit$df_r, n - 4)
  base <- fit$table[fit$table$indepvar == "0b.L3age_cat", ]
  expect_equal(base$b, 0)
  expect_true(is.na(base$se))
})

test_that("stata_regress_robust() drops collinear terms left to right as o. and rejects N < 2", {
  d <- data.frame(y = c(0, 1, 0, 1, 1, 0), x = c(1, 1, 0, 0, 1, 0))
  fit <- stata_regress_robust(d$y, data.frame(x = d$x, x2 = 2 * d$x), list())
  expect_equal(fit$table$indepvar, c("x", "o.x2", "_cons"))
  expect_equal(fit$table$b[2], 0)
  expect_true(is.na(fit$table$se[2]))
  expect_null(stata_regress_robust(1, data.frame(x = 1), list()))
  expect_null(stata_regress_robust(numeric(0), data.frame(x = numeric(0)), list()))
})
