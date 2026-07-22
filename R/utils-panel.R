#' Round half away from zero (Stata's `round()` convention)
#'
#' Base R's `round()` uses "round half to even" (banker's rounding): `round(0.5)`
#' is `0`, `round(2.5)` is `2`. Stata's `round()` always rounds a `.5` away from
#' zero: `round(0.5)` is `1`, `round(2.5)` is `3`. Several disclosure-control
#' calculations in this package (e.g. [approx_median()]'s "center" position) are
#' defined in terms of Stata's convention, so this helper is used instead of
#' base `round()` wherever the source Stata code calls `round()`.
#'
#' @param x A numeric vector.
#' @param digits Number of decimal places (default `0`).
#' @return A numeric vector, rounded half-away-from-zero.
#' @export
round_half_up <- function(x, digits = 0) {
  scale <- 10^digits
  sign(x) * floor(abs(x) * scale + 0.5) / scale
}

#' Prepare a numeric vector for Stata-style comparison against a constant
#'
#' In Stata, numeric missing (`.`) is internally a very large finite value, so
#' **every** comparison operator (`==`, `!=`, `>`, `<`, `>=`, `<=`) against a
#' missing operand resolves to a definite `TRUE`/`FALSE` — never a further
#' "missing" result. E.g. `age_cat == 0` is `FALSE` (not missing) when
#' `age_cat` is missing; `age < 2` is `FALSE`; `age >= 2` is `TRUE`. R's `==`/
#' `<`/etc. instead propagate `NA` when either side is `NA`.
#'
#' `stata_num(x) OP k` (for a literal constant `k`) reproduces Stata's
#' behaviour by substituting `Inf` for `NA` before comparing — since `Inf` is
#' larger than any finite `k`, every comparison operator then resolves the
#' same way Stata's missing-as-largest-value convention would. Only use this
#' at the exact point of comparison (it must not replace the vector's stored
#' value elsewhere); only valid when comparing against a literal, itself
#' never-missing, constant — for comparisons between two possibly-missing
#' variables, resolve missingness explicitly instead (see
#' `Pseudocode/00_conventions.md`'s `MISSING` note).
#'
#' @param x A numeric vector.
#' @return A numeric vector with every `NA` replaced by `Inf`.
#' @export
stata_num <- function(x) {
  ifelse(is.na(x), Inf, x)
}

#' Stata-style conditional replace, preserving the existing value on `NA`
#'
#' Reproduces Stata's `replace x = value if cond`: rows where `cond` is
#' `FALSE` **or `NA`** keep their current value of `x` unchanged; only rows
#' where `cond` is definitely `TRUE` get `value`. This differs from
#' [dplyr::if_else()], which returns `NA` when `cond` is `NA` — correct for a
#' fresh `gen`-style computation (there is no "existing value" to fall back
#' to), but wrong for a `replace`, where an unresolved condition must leave
#' the row exactly as it was. Used throughout the sequential-overwrite
#' classification rules (`tech_grad`, `ind_a38`, `type`, `FOLLOW`/`LEAD`, ...)
#' documented in `Pseudocode/*.md` as "later rule overwrites earlier" chains.
#'
#' @param cur The current value of the variable being updated.
#' @param cond A logical vector (may contain `NA`).
#' @param value The replacement value (recycled as needed) where `cond` is
#'   `TRUE`.
#' @return A vector the same length/type as `cur`.
#' @export
stata_replace <- function(cur, cond, value) {
  cond[is.na(cond)] <- FALSE
  dplyr::if_else(cond, value, cur)
}

#' Bin a numeric variable into intervals (Stata's `egen ... = cut(x), at(...)`)
#'
#' Assigns each value of `x` to the half-open interval `[at[i], at[i+1])` it
#' falls in, labelling it with the interval's **lower bound**. The final
#' breakpoint is exclusive: values equal to or beyond it (and values below the
#' first breakpoint) return `NA`, matching Stata's `cut()` egen function.
#'
#' @param x A numeric vector.
#' @param at A numeric vector of breakpoints, in increasing order.
#' @return A numeric vector of interval lower bounds (or `NA`).
#' @export
cut_stata <- function(x, at) {
  stopifnot(length(at) >= 2, !is.unsorted(at))
  bins <- cut(x, breaks = at, right = FALSE, labels = at[-length(at)])
  as.numeric(as.character(bins))
}

#' Gap-aware panel lag (Stata's `Ln.var`, e.g. `l3.employment`)
#'
#' Returns the value of `x` for the same panel unit (`id`) at `n` periods
#' earlier in `time` — read from the record with that exact `(id, time - n)`
#' key, not from `n` rows earlier. If a firm's panel has a gap (e.g. observed
#' in 2010, 2011, 2014 but not 2012-2013), `panel_lag(x, 1)` evaluated on the
#' 2014 row looks for a 2013 record — which does not exist — and returns `NA`,
#' rather than incorrectly reaching back to the 2011 row. See
#' `Pseudocode/00_conventions.md` (`LAG`) for the full specification this
#' implements; verified empirically against `collapse::flag()`'s time-aware
#' behaviour before use here.
#'
#' @param x Numeric vector to lag.
#' @param n Number of periods to lag by.
#' @param id Panel unit identifier vector (e.g. `idf`), same length as `x`.
#' @param time Panel time vector (e.g. `year`), same length as `x`.
#' @return A vector the same length as `x`.
#' @export
panel_lag <- function(x, n, id, time) {
  collapse::flag(x, n = n, g = id, t = time)
}

#' Gap-aware panel lead (Stata's `Fn.var`, e.g. `f3.employment`)
#'
#' Symmetric to [panel_lag()]: the value of `x` for the same `id` at `n`
#' periods later in `time`, or `NA` if that exact key does not exist.
#'
#' @inheritParams panel_lag
#' @return A vector the same length as `x`.
#' @export
panel_lead <- function(x, n, id, time) {
  collapse::flag(x, n = -n, g = id, t = time)
}

#' First-difference panel operator (Stata's `D1.var`)
#'
#' `x - panel_lag(x, 1, id, time)`.
#'
#' @inheritParams panel_lag
#' @return A vector the same length as `x`.
#' @export
panel_diff1 <- function(x, id, time) {
  x - panel_lag(x, 1, id, time)
}

#' n-period difference panel operator (Stata's `Sn.var`, e.g. `S3.employment`)
#'
#' `x - panel_lag(x, n, id, time)` — a single subtraction against the value `n`
#' periods ago (not an iterated first-difference).
#'
#' @inheritParams panel_lag
#' @return A vector the same length as `x`.
#' @export
panel_sdiff <- function(x, n, id, time) {
  x - panel_lag(x, n, id, time)
}

#' Disclosure-safe "approximate median" (average of 5 central sorted values)
#'
#' A confidentiality-preserving stand-in for a true median: true medians are
#' not published per this project's disclosure rules. Sorts `x` ascending
#' (`NA` sorted last, matching Stata's convention — see
#' `Pseudocode/00_conventions.md`, `MISSING`), then averages the (up to) 5
#' values centred on position `round_half_up(n_non_missing / 2)`. This is
#' **not** interchangeable with a true median except by coincidence — do not
#' replace with `median()`.
#'
#' Typically used inside a `dplyr::summarise()` / grouped aggregation, one
#' call per output cell, rather than reproducing the source's
#' compute-then-collapse-then-mean row-broadcast mechanics (which reduce to
#' exactly this value).
#'
#' @param x A numeric vector (the values within one group).
#' @return A single numeric value (or `NA` if `x` has no non-missing values).
#' @export
approx_median <- function(x) {
  n <- sum(!is.na(x))
  if (n == 0) {
    return(NA_real_)
  }
  center <- round_half_up(n / 2)
  x_sorted <- sort(x, na.last = TRUE)
  idx <- (center - 2):(center + 2)
  idx <- idx[idx >= 1 & idx <= n]
  mean(x_sorted[idx], na.rm = TRUE)
}

#' Dominance-rule concentration share (disclosure-control statistic)
#'
#' The share of the total held by the `top_n` largest units — a standard
#' "(n,k)-dominance rule" statistic. Missing values are treated as `0` when
#' accumulating (matching Stata's `sum()`/`total()` egen functions) and sort
#' last (never among the "top" units), matching
#' `Pseudocode/00_conventions.md`'s `DOMINANCE_SHARE` primitive. Returns `NA`
#' if the group has fewer than `top_n` units, or if the group's total is `0`.
#'
#' @param x A numeric vector (the values within one group, e.g. `employment`
#'   or `turnover`).
#' @param top_n Number of top units defining the dominance ratio (
#'   `dominance$dom_num` from [config_scaleup()]).
#' @return A single numeric value in `[0, 1]`, or `NA`.
#' @export
dominance_share <- function(x, top_n) {
  n <- length(x)
  if (top_n > n) {
    return(NA_real_)
  }
  total <- sum(x, na.rm = TRUE)
  if (is.na(total) || total == 0) {
    return(NA_real_)
  }
  x_sorted <- sort(x, decreasing = TRUE, na.last = TRUE)
  x_sorted[is.na(x_sorted)] <- 0
  sum(x_sorted[seq_len(top_n)]) / total
}

#' Flag a firm's chronologically first occurrence of a 0/1 event
#'
#' Returns `1` only on the earliest `time` value (per `id`) at which `x == 1`
#' — not the first row of each subsequent episode, the single first
#' occurrence ever. `NA` values in `x` are treated as "not an event" and do
#' not break the chain (matching Stata's `sum()` treating missing as `0` in
#' the cumulative-sum idiom the source uses for this same purpose — see
#' `Pseudocode/00_conventions.md`, `FIRST_OCCURRENCE_FLAG`).
#'
#' @param id Panel unit identifier vector (e.g. `idf`).
#' @param time Panel time vector (e.g. `year`).
#' @param x A 0/1 (or `NA`) numeric vector, the same length as `id`/`time`,
#'   typically a high-growth-firm flag.
#' @return An integer vector (`0L`/`1L`), the same length and order as `x`.
#' @export
first_occurrence_flag <- function(id, time, x) {
  ord <- order(id, time)
  increment <- ifelse(is.na(x[ord]) | x[ord] != 1, 0L, 1L)
  running <- stats::ave(increment, id[ord], FUN = cumsum)
  flag_ord <- as.integer(increment == 1 & running == 1)
  flag <- integer(length(x))
  flag[ord] <- flag_ord
  flag
}

#' Grouped equal-frequency quartile bins (Stata's `xtile ..., nq(4)`)
#'
#' Thin wrapper around [statar::xtile()] documenting the contract this package
#' relies on: `NA` in, `NA` out; non-missing values split into `n` groups of
#' (approximately) equal size, numbered `1..n`. See
#' `Pseudocode/00_conventions.md`'s `QUARTILE` primitive. Callers are
#' responsible for applying this only within already-grouped data (this
#' package additionally imposes a minimum group size of 50 before calling this
#' at all — see `compute_predictors()`).
#'
#' Stata's own `xtile` is confirmed to use a percentile algorithm equivalent
#' to R's `quantile(type = 2)` (see `percentile_stata()` and its source
#' comment); `statar::xtile()` is a separate, independent R reimplementation,
#' and its exact tie-breaking at quartile boundaries has not been verified
#' here to match Stata's bit-for-bit. For this package's use (classifying
#' scalers into descriptive predictor-quartile groups), this is a low-stakes
#' residual risk — a handful of firms sitting exactly on a cutpoint could
#' land in an adjacent bin — flagged rather than silently assumed away.
#'
#' @param x A numeric vector.
#' @param n Number of equal-frequency bins (default `4`, i.e. quartiles).
#' @return An integer vector of bin numbers `1..n` (or `NA`).
#' @export
quartile_bin <- function(x, n = 4) {
  statar::xtile(x, n = n)
}

#' Percentile, using Stata's algorithm (Hyndman & Fan "Type 2")
#'
#' Stata's `summarize, detail` / `_pctile` / `xtile` all use a percentile
#' algorithm confirmed equivalent to R's `quantile(type = 2)` (Hyndman & Fan
#' 1996) — *not* R's default `type = 7`. Used here instead of bare
#' `stats::quantile()` wherever the source computes `r(p1)`/`r(p99)` for
#' winsorizing or trimming.
#'
#' @param x A numeric vector.
#' @param probs A numeric vector of probabilities in `[0, 1]`.
#' @return A named numeric vector of the requested percentiles.
#' @export
percentile_stata <- function(x, probs) {
  stats::quantile(x, probs = probs, na.rm = TRUE, type = 2)
}

#' Winsorize the upper tail to `NA`
#'
#' `x` is set to `NA` wherever it exceeds its own 99th percentile (Stata
#' algorithm — see [percentile_stata()]); values at or below the 99th
#' percentile, and missing values, are returned unchanged.
#'
#' @param x A numeric vector.
#' @param upper_prob Upper percentile threshold (default `0.99`).
#' @return A numeric vector the same length as `x`.
#' @export
winsorize_upper <- function(x, upper_prob = 0.99) {
  p <- percentile_stata(x, upper_prob)
  dplyr::if_else(!is.na(x) & x > p, NA_real_, x)
}

#' Winsorize both tails to `NA`
#'
#' `x` is set to `NA` wherever it falls below its own 1st percentile or above
#' its own 99th percentile (Stata algorithm — see [percentile_stata()]).
#'
#' @param x A numeric vector.
#' @param lower_prob Lower percentile threshold (default `0.01`).
#' @param upper_prob Upper percentile threshold (default `0.99`).
#' @return A numeric vector the same length as `x`.
#' @export
winsorize_both <- function(x, lower_prob = 0.01, upper_prob = 0.99) {
  bounds <- percentile_stata(x, c(lower_prob, upper_prob))
  dplyr::if_else(!is.na(x) & (x < bounds[[1]] | x > bounds[[2]]), NA_real_, x)
}
