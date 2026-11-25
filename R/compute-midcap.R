#' Scalers to mid-caps: crossings into mid-cap status
#'
#' New analysis (not part of the original Stata package). Follows firms from
#' the year they enter a risk set (their first year as a scaler, or as a
#' non-scaler of the pool) and records when they cross into mid-cap status,
#' with firm exit as a competing event.
#'
#' **Status** per firm-year, three definitions (`definition` column):
#' * `small_midcap`: EU small mid-cap (Recommendation (EU) 2025/1099). A firm
#'   leaves the SME category (Recommendation 2003/361/EC) with 250+ persons,
#'   or with turnover above EUR 50 m *and* balance sheet above EUR 43 m. It is
#'   a small mid-cap if it then has fewer than 750 persons and turnover of at
#'   most EUR 150 m *or* a balance sheet of at most EUR 129 m; above those
#'   ceilings it is `large`.
#' * `sme_exit`: leaving the SME category; `large` from 3,000 employees (the
#'   EIB mid-cap bound).
#' * `employment_250`: 250+ employees; `large` from 3,000 employees. The
#'   reference series (no balance sheet, no inflation).
#'
#' Money in EUR thousand, nominal (thresholds 50,000 / 43,000 / 150,000 /
#' 129,000); balance sheet = `total_assets`. Firm-level figures (the legal
#' definition adds up linked enterprises; use the `independent` breakdown).
#' Nothing is imputed: a status is missing when the available values cannot
#' decide it (e.g. turnover above EUR 50 m, under 250 employees, no balance
#' sheet). Where `consolidation_code` exists, only unconsolidated accounts
#' (`U1`, `U2`) get a status.
#'
#' **Crossing.** The first year after entry into the risk set in which the
#' firm is above SME status (`mid` or `large`) and is so again in the next
#' calendar year. A missing year or an exit before the confirmation year is
#' not a crossing. The crossing's type is the status in the crossing year:
#' `mid` or `large` (the firm jumped past the mid-cap band).
#'
#' **Risk set.** `HGE20` / `HGT20`: firms from their first year as a scaler;
#' `HGE20_nonscaler_pool` / `HGT20_nonscaler_pool`: firms from their first
#' year in the pool as a non-scaler (as in [compute_characteristics()];
#' firms that scale later stay in it). Entry needs 10 to fewer than 250
#' employees at t-3, the fourth panel year or later, and SME status in the
#' entry year: firms already above it, or without a status, are counted
#' (`n_above_at_entry`, `n_status_missing_at_entry`) and not followed.
#'
#' **Time** is years since entry (step 1 = the year after). A firm that
#' crosses at step k has its event at k; a firm whose last year L is before
#' the panel's last year exits at step L - entry (competing event); other
#' firms are censored at the last step whose crossing could still be
#' confirmed (panel end - 1 - entry). Firms with no step left are counted
#' (`n_no_followup`).
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param accounts_indicators The output of [build_accounts_indicators()]; needs
#'   `employment`, and for the first two definitions `turnover` and
#'   `total_assets`.
#' @param top_cutoffs Cut-offs of [compute_top_scalers()]: each top-scaler
#'   sample (e.g. `HGE20_rel_p10`) is also followed from its first year in
#'   the sample, category `ALL` only, so its crossings compare with those of
#'   all scalers (the link between the two analyses). `NULL` skips them.
#' @param money_unit Unit of `turnover` and `total_assets` in
#'   `accounts_indicators`: `"EUR thousand"` (as the variable dictionary asks)
#'   or `"EUR"` (a panel delivered in euros that the pipeline does not rescale).
#'   As a check, the function stops if firms with 10-49 employees have a
#'   median turnover per employee above 5,000 when `"EUR thousand"` is
#'   declared (EUR 5 m per person: euros, not thousands).
#' @return A list of tibbles:
#'   * `incidence`: by definition, sample, category, group (at entry) and
#'     step: firms at risk, crossings to `mid` and to `large`, exits,
#'     censored, and the cumulative incidence of each (Aalen-Johansen);
#'   * `entry`: per definition, sample, category and group, the firms
#'     entering the risk set and those not followed, by reason;
#'   * `by_year`: per definition, sample, category, group and calendar year,
#'     firms at risk and crossings;
#'   * `hazard`: discrete-time logit of a crossing (to `mid` or `large`) in
#'     year t, one per definition and scaler type, on scalers and their pool
#'     non-scalers together (`scaler` = 1 for the scalers' spells). Covariates
#'     at t-1: log employment, 1-year employment growth, log turnover per
#'     employee and, where present, independence and exporter status; plus a
#'     young-firm dummy (age class 0-5 at t-1), years since entry and its
#'     square, and a linear calendar trend. Firm-clustered standard errors
#'     (CR1, as Stata's `vce(cluster idf)`); `ame_scaler` is the average
#'     change in the yearly crossing probability when `scaler` goes from 0 to 1.
#'     Exits count as no crossing in their year (a cause-specific hazard).
#' @export
compute_midcap_transitions <- function(config, accounts_indicators, money_unit = c("EUR thousand", "EUR"),
                                       top_cutoffs = c(top50 = 50, p1 = 0.01, p5 = 0.05, p10 = 0.10, p25 = 0.25)) {
  money_unit <- match.arg(money_unit)
  data <- accounts_indicators
  data$ALL <- 1L
  if (has_column(data, "turnover")) {
    small <- !is.na(data$employment) & data$employment >= 10 & data$employment < 50 & !is.na(data$turnover)
    per_head <- if (any(small)) stats::median(as.double(data$turnover[small]) / as.double(data$employment[small])) else NA
    if (money_unit == "EUR thousand" && !is.na(per_head) && per_head > 5000) {
      stop("turnover looks like EUR, not EUR thousand: the median turnover per employee of firms with 10-49 ",
           "employees is above 5,000 (EUR 5 m). Pass money_unit = \"EUR\".", call. = FALSE)
    }
    if (money_unit == "EUR") {
      for (v in intersect(c("turnover", "total_assets"), names(data))) data[[v]] <- as.double(data[[v]]) / 1000
    }
  }
  first_year <- min(data$year, na.rm = TRUE)
  panel_end <- max(data$year, na.rm = TRUE)
  categories <- intersect(c("ALL", "size_cat", "age_cat", "tech_grad", "independent", "exporter"), names(data))

  definitions <- midcap_definitions(data)
  status <- lapply(setNames(definitions, definitions), function(d) {
    s <- midcap_status(data$employment, data$turnover, data$total_assets, d)
    if (has_column(data, "consolidation_code")) s[!data$consolidation_code %in% c("U1", "U2")] <- NA
    s
  })

  last_year <- group_fill(as.double(data$year), data$idf, "max")
  l3emp <- data$L3employment
  base_ok <- data$year >= first_year + 3 & !is.na(l3emp) & l3emp >= 10 & l3emp < 250
  specs <- list(
    HGE20 = stata_num(data$HGE20) == 1,
    HGE20_nonscaler_pool = stata_num(data$HGE20) == 0 & stata_num(data$HGE_pool) == 1,
    HGT20 = stata_num(data$HGT20) == 1,
    HGT20_nonscaler_pool = stata_num(data$HGT20) == 0 & stata_num(data$HGT_pool) == 1
  )
  specs <- specs[vapply(names(specs), function(s) has_column(data, sub("_nonscaler_pool$", "", s)), TRUE)]
  # link to compute_top_scalers(): each top-scaler sample is a risk set of its own (category ALL only)
  top_only_all <- character(0)
  if (length(top_cutoffs)) {
    for (m in top_scaler_membership(data, top_cutoffs)) {
      if (grepl("_ranked$", m$name)) next
      specs[[m$name]] <- seq_len(nrow(data)) %in% m$rows
      top_only_all <- c(top_only_all, m$name)
    }
  }

  covariates <- midcap_covariates(data)
  inc <- list(); ent <- list(); byy <- list(); haz <- list()
  for (d in definitions) {
    st <- status[[d]]
    above <- !is.na(st) & st != "sme"
    confirmed <- above & stata_num(panel_lead(as.integer(above), 1, data$idf, data$year)) == 1
    spells <- list()
    for (s in names(specs)) {
      sp <- midcap_spells(data$idf, data$year, st, confirmed, specs[[s]] & base_ok, last_year, panel_end)
      if (is.null(sp)) next
      spells[[s]] <- sp
      for (cat in if (s %in% top_only_all) "ALL" else categories) {
        g <- data[[cat]][sp$row]
        lab <- decode_category(g, cat)
        res <- midcap_tables(sp, lab)
        for (nm in names(res)) {
          if (!nrow(res[[nm]])) next
          res[[nm]]$definition <- d; res[[nm]]$sample <- s; res[[nm]]$category <- cat
        }
        inc[[length(inc) + 1]] <- res$incidence
        ent[[length(ent) + 1]] <- res$entry
        byy[[length(byy) + 1]] <- res$by_year
      }
    }
    for (scaler in c("HGE20", "HGT20")) {
      pool <- paste0(scaler, "_nonscaler_pool")
      if (is.null(spells[[scaler]]) || is.null(spells[[pool]])) next
      pp <- rbind(
        midcap_person_periods(spells[[scaler]], data$idf, covariates, scaler = 1L),
        midcap_person_periods(spells[[pool]], data$idf, covariates, scaler = 0L)
      )
      fit <- midcap_hazard_fit(pp)
      if (is.null(fit)) next
      fit$definition <- d
      fit$sample <- paste(scaler, "vs", pool)
      haz[[length(haz) + 1]] <- fit
    }
  }
  front <- c("definition", "sample", "category", "group")
  tidy <- function(x, front) {
    x <- dplyr::bind_rows(x)
    if (!nrow(x)) return(dplyr::tibble())
    dplyr::as_tibble(x[c(front, setdiff(names(x), front))])
  }
  list(incidence = tidy(inc, front), entry = tidy(ent, front), by_year = tidy(byy, front),
       hazard = tidy(haz, c("definition", "sample")))
}

#' Hazard covariates, keyed by firm-year (values of year t, used for t + 1)
#' @noRd
midcap_covariates <- function(data) {
  emp <- as.double(data$employment)
  cov <- data.frame(
    idf = data$idf, year = as.double(data$year),
    log_employment = ifelse(!is.na(emp) & emp > 0, log(emp), NA_real_)
  )
  if (has_column(data, "employment_growth1y")) cov$employment_growth1y <- as.double(data$employment_growth1y)
  if (has_column(data, "turnover")) {
    to <- as.double(data$turnover)
    cov$log_turnover_per_employee <- ifelse(!is.na(to) & to > 0 & !is.na(emp) & emp > 0, log(to / emp), NA_real_)
  }
  if (has_column(data, "age_cat")) cov$young <- as.integer(as.double(data$age_cat) == 0)
  for (v in c("independent", "exporter")) if (has_column(data, v)) cov[[v]] <- as.double(data[[v]])
  cov
}

#' Person-period rows of the followed spells: one per step, outcome = crossing
#' @noRd
midcap_person_periods <- function(sp, idf, covariates, scaler) {
  f <- which(!is.na(sp$steps))
  if (!length(f)) return(NULL)
  n <- sp$steps[f]
  firm <- rep(idf[sp$row[f]], n)
  step <- sequence(n)
  year <- rep(sp$entry[f], n) + step
  last <- step == rep(n, n)
  y <- as.integer(last & rep(sp$type[f], n) %in% c("mid", "large"))
  at <- collapse::fmatch(list(firm, year - 1), list(covariates$idf, covariates$year))
  cov <- covariates[at, setdiff(names(covariates), c("idf", "year")), drop = FALSE]
  cbind(data.frame(idf = firm, year = year, step = step, y = y, scaler = scaler), cov)
}

#' Logit with firm-clustered (CR1) standard errors; NULL if it cannot be fitted
#' @noRd
midcap_hazard_fit <- function(pp) {
  if (is.null(pp) || !nrow(pp)) return(NULL)
  pp$step_sq <- pp$step^2
  pp$trend <- pp$year - stats::median(pp$year)
  xvars <- intersect(c("scaler", "log_employment", "employment_growth1y", "log_turnover_per_employee", "young",
                       "independent", "exporter", "step", "step_sq", "trend"), names(pp))
  xvars <- xvars[vapply(xvars, function(v) sum(!is.na(pp[[v]])) > 0, TRUE)]
  cc <- pp[stats::complete.cases(pp[c("y", xvars)]), ]
  xvars <- xvars[vapply(xvars, function(v) length(unique(cc[[v]])) > 1, TRUE)] # constant columns cannot be estimated
  events <- sum(cc$y)
  if (!events || events == nrow(cc) || !"scaler" %in% xvars) return(NULL)
  X <- cbind(`(Intercept)` = 1, as.matrix(cc[xvars]))
  fit <- suppressWarnings(stats::glm.fit(X, cc$y, family = stats::binomial()))
  b <- fit$coefficients
  ok <- !is.na(b)
  X <- X[, ok, drop = FALSE]; b <- b[ok]
  p <- as.vector(stats::plogis(X %*% b))
  bread <- solve(crossprod(X * sqrt(p * (1 - p))))
  scores <- rowsum(X * (cc$y - p), cc$idf, reorder = FALSE)
  G <- nrow(scores)
  V <- bread %*% crossprod(scores) %*% bread * G / (G - 1)
  se <- sqrt(diag(V))
  z <- b / se
  X1 <- X; X1[, "scaler"] <- 1
  X0 <- X; X0[, "scaler"] <- 0
  ame <- mean(stats::plogis(X1 %*% b) - stats::plogis(X0 %*% b))
  data.frame(
    term = names(b), b = unname(b), se = unname(se), z = unname(z), pval = 2 * stats::pnorm(-abs(unname(z))),
    lb95 = unname(b - stats::qnorm(0.975) * se), ub95 = unname(b + stats::qnorm(0.975) * se),
    odds_ratio = exp(unname(b)), obs = nrow(cc), firms = G, events = events,
    mean_depvar = mean(cc$y), ame_scaler = ame, converged = isTRUE(fit$converged)
  )
}

#' Definitions computable from the columns present
#' @noRd
midcap_definitions <- function(data) {
  fin <- has_column(data, "turnover") && has_column(data, "total_assets")
  c(if (fin) c("small_midcap", "sme_exit"), "employment_250")
}

#' Status per firm-year: "sme", "mid", "large" or NA (undecidable)
#'
#' Three-valued logic: a missing value leaves the status missing only when
#' the other values cannot decide it.
#' @noRd
midcap_status <- function(employment, turnover, total_assets, definition) {
  emp <- as.double(employment)
  if (definition == "employment_250") {
    above <- emp >= 250
    large <- emp >= 3000
  } else {
    to <- as.double(turnover)
    bs <- as.double(total_assets)
    above <- emp >= 250 | (to > 50000 & bs > 43000)
    large <- if (definition == "small_midcap") !(emp < 750 & (to <= 150000 | bs <= 129000)) else emp >= 3000
  }
  out <- rep(NA_character_, length(emp))
  out[!is.na(above) & !above] <- "sme"
  out[!is.na(above) & above & !is.na(large) & !large] <- "mid"
  out[!is.na(above) & above & !is.na(large) & large] <- "large"
  out
}

#' One spell per firm: entry year, step of the first event, event type
#'
#' @param entry_ok Rows where the firm may enter the risk set (the sample's
#'   condition); the firm enters at its first such year.
#' @return NULL when no firm enters; else a list with `row` (the entry row of
#'   each firm), `entry`, `steps` (NA when not followed), `type` ("mid",
#'   "large", "exit", "censored") and `not_followed` (NA, "above",
#'   "status_missing" or "no_followup").
#' @noRd
midcap_spells <- function(idf, year, status, confirmed, entry_ok, last_year, panel_end) {
  entry_ok <- !is.na(entry_ok) & entry_ok
  if (!any(entry_ok)) return(NULL)
  yr <- as.double(year)
  entry <- group_fill(ifelse(entry_ok, yr, NA_real_), idf, "min")
  first_cross <- group_fill(ifelse(confirmed & !is.na(entry) & yr > entry, yr, NA_real_), idf, "min")
  # status in the crossing year (2 = large, 1 = mid), one value per firm
  cross_code <- group_fill(ifelse(!is.na(first_cross) & yr == first_cross, ifelse(status == "large", 2, 1), NA_real_),
                           idf, "max")

  row <- which(entry_ok & yr == entry)
  row <- row[!duplicated(idf[row])]
  e <- entry[row]
  st0 <- status[row]
  fc <- first_cross[row]
  ly <- last_year[row]

  not_followed <- ifelse(is.na(st0), "status_missing", ifelse(st0 != "sme", "above", NA_character_))
  type <- ifelse(!is.na(fc), "cross", ifelse(ly < panel_end, "exit", "censored"))
  steps <- ifelse(type == "cross", fc - e, ifelse(type == "exit", ly - e, panel_end - 1 - e))
  type[type == "cross"] <- ifelse(cross_code[row] == 2, "large", "mid")[type == "cross"]
  no_fu <- is.na(not_followed) & steps < 1
  not_followed[no_fu] <- "no_followup"
  steps[!is.na(not_followed)] <- NA
  type[!is.na(not_followed)] <- NA
  list(row = row, entry = e, steps = steps, type = type, not_followed = not_followed)
}

#' Incidence, entry and calendar-year tables for one breakdown
#' @noRd
midcap_tables <- function(sp, lab) {
  keep_lab <- !is.na(lab)
  entry <- data.frame(group = lab, nf = sp$not_followed)[keep_lab, ]
  entry_tab <- if (nrow(entry)) {
    dplyr::summarise(
      dplyr::group_by(entry, .data$group),
      n_entering = dplyr::n(),
      n_followed = sum(is.na(.data$nf)),
      n_above_at_entry = sum(.data$nf %in% "above"),
      n_status_missing_at_entry = sum(.data$nf %in% "status_missing"),
      n_no_followup = sum(.data$nf %in% "no_followup"),
      .groups = "drop"
    )
  } else data.frame()

  f <- keep_lab & !is.na(sp$steps)
  if (!any(f)) return(list(incidence = data.frame(), entry = entry_tab, by_year = data.frame()))
  d <- data.frame(group = lab[f], steps = sp$steps[f], type = sp$type[f], entry = sp$entry[f])

  incidence <- dplyr::bind_rows(lapply(split(d, d$group), function(x) {
    k <- seq_len(max(x$steps))
    at_risk <- vapply(k, function(i) sum(x$steps >= i), 0)
    ev <- function(t) vapply(k, function(i) sum(x$steps == i & x$type == t), 0)
    mid <- ev("mid"); large <- ev("large"); ex <- ev("exit"); cens <- ev("censored")
    surv_before <- cumprod(c(1, 1 - (mid + large + ex) / at_risk))[k]
    data.frame(
      group = x$group[1], step = k, at_risk = at_risk, cross_mid = mid, cross_large = large, exits = ex,
      censored = cens,
      cif_mid = cumsum(surv_before * mid / at_risk), cif_large = cumsum(surv_before * large / at_risk),
      cif_exit = cumsum(surv_before * ex / at_risk)
    )
  }))

  # calendar years: a firm is at risk in entry + 1 .. entry + steps
  rep_n <- d$steps
  cal <- data.frame(
    group = rep(d$group, rep_n), year = rep(d$entry, rep_n) + sequence(rep_n),
    last = rep(seq_along(rep_n), rep_n) # index of the firm
  )
  is_last <- c(cal$last[-1] != cal$last[-nrow(cal)], TRUE)
  ev_type <- ifelse(is_last, d$type[cal$last], "none")
  by_year <- dplyr::summarise(
    dplyr::group_by(data.frame(cal[c("group", "year")], ev = ev_type), .data$group, .data$year),
    at_risk = dplyr::n(), cross_mid = sum(.data$ev == "mid"), cross_large = sum(.data$ev == "large"),
    exits = sum(.data$ev == "exit"),
    .groups = "drop"
  )
  list(incidence = incidence, entry = entry_tab, by_year = by_year)
}
