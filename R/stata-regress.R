#' Stata's `regress y x1 x2 i.(f1 f2), robust`, row for row
#'
#' Reproduces what the original code posts from `r(table)` for every
#' coefficient in `e(b)`:
#'
#' * terms in Stata's order: continuous regressors, then each factor's levels
#'   in code order (the lowest level present is the base, named `<code>b.<var>`),
#'   then `_cons`;
#' * collinear regressors are dropped left to right with `_cons` kept (as
#'   Stata's `_rmcoll` does) and still reported, as `o.<var>` /
#'   `<code>o.<var>`, with `b = 0` and missing `se`, `t`, `pval`, `lb95`,
#'   `ub95`; base levels are reported the same way;
#' * heteroskedasticity-robust (HC1) standard errors, `V = (X'X)^-1 X' diag(e^2)
#'   X (X'X)^-1 * N / (N - k)`, t-based p-values and 95% intervals on `N - k`
#'   residual degrees of freedom, which is also the `df` of every row.
#'
#' Listwise deletion of missing values happens before the call.
#'
#' @param y Numeric response.
#' @param X Data frame of continuous regressors (may have zero columns).
#' @param factors Named list of numeric factor codes (Stata `i.` variables).
#' @param tol Relative tolerance for collinearity.
#' @return `NULL` with fewer than 2 observations (Stata `r(2000)`/`r(2001)`;
#'   a fit with zero residual degrees of freedom is still reported), else a list
#'   with `N`, `df_r` and `table` (one row per coefficient: `indepvar, b, se,
#'   t, pval, lb95, ub95`).
#' @noRd
stata_regress_robust <- function(y, X, factors = list(), tol = 1e-12) {
  n <- length(y)
  if (n < 2) return(NULL) # regress: r(2000) no observations / r(2001) insufficient observations

  cols <- list(); names_out <- character(0); is_base <- logical(0)
  for (nm in names(X)) {
    cols[[length(cols) + 1]] <- as.double(X[[nm]]); names_out <- c(names_out, nm); is_base <- c(is_base, FALSE)
  }
  for (fn in names(factors)) {
    f <- factors[[fn]]
    lv <- sort(unique(f))
    for (j in seq_along(lv)) {
      cols[[length(cols) + 1]] <- as.double(f == lv[j])
      code <- format(lv[j], scientific = FALSE, trim = TRUE)
      names_out <- c(names_out, if (j == 1) paste0(code, "b.", fn) else paste0(code, ".", fn))
      is_base <- c(is_base, j == 1)
    }
  }

  # greedy left-to-right rank detection, constant first (modified Gram-Schmidt)
  basis <- list(rep(1 / sqrt(n), n))
  keep <- logical(length(cols))
  for (i in seq_along(cols)) {
    if (is_base[i]) next
    v <- cols[[i]]
    norm0 <- sqrt(sum(v^2))
    if (norm0 == 0) next
    for (q in basis) v <- v - sum(q * v) * q
    if (sqrt(sum(v^2)) > tol * max(norm0, 1) * sqrt(n)) {
      keep[i] <- TRUE
      basis[[length(basis) + 1]] <- v / sqrt(sum(v^2))
    }
  }
  omitted <- !keep & !is_base
  names_out[omitted] <- sub("^([0-9.]+)\\.", "\\1o.", names_out[omitted])
  names_out[omitted & !grepl("^[0-9]", names_out)] <- paste0("o.", names_out[omitted & !grepl("^[0-9]", names_out)])

  Xm <- if (any(keep)) cbind(matrix(unlist(cols[keep]), nrow = n), rep(1, n)) else matrix(1, n, 1)
  k <- ncol(Xm)
  df_r <- n - k
  XtX_inv <- solve(crossprod(Xm))
  b <- drop(XtX_inv %*% crossprod(Xm, y))
  e <- drop(y - Xm %*% b)
  V <- if (df_r > 0) XtX_inv %*% crossprod(Xm * e) %*% XtX_inv * (n / df_r) else matrix(NA_real_, k, k)
  se <- sqrt(pmax(diag(V), 0))
  se[!is.finite(se)] <- NA_real_
  t <- stata_double(b / se)
  p <- if (df_r > 0) 2 * stats::pt(-abs(t), df_r) else rep(NA_real_, k)
  crit <- if (df_r > 0) stats::qt(0.975, df_r) else NA_real_

  est <- data.frame(b = b, se = se, t = t, pval = p, lb95 = b - crit * se, ub95 = b + crit * se)
  tab <- data.frame(indepvar = c(names_out, "_cons"), b = 0, se = NA_real_, t = NA_real_, pval = NA_real_,
                    lb95 = NA_real_, ub95 = NA_real_, stringsAsFactors = FALSE)
  est_rows <- c(which(keep), length(names_out) + 1)
  tab[est_rows, c("b", "se", "t", "pval", "lb95", "ub95")] <- est
  list(N = n, df_r = df_r, table = tab)
}
