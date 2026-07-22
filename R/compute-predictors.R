#' @keywords internal
predictors_quartile_var <- function(data, var, ymin, end_year) {
  n <- nrow(data)
  q4 <- rep(NA_real_, n)
  less50 <- rep(NA_real_, n)
  st_year <- if (identical(var, "MFP_gr")) ymin + 3 else ymin
  eligible <- !is.na(data$sector_2d) & data$year >= st_year & data$year <= end_year
  idx <- which(eligible)
  if (length(idx) == 0) {
    return(list(q4 = q4, less50 = less50))
  }
  sub <- data.frame(.row = idx, sector_2d = data$sector_2d[idx], year = data$year[idx], v = data[[var]][idx])
  sub <- sub %>%
    dplyr::group_by(.data$sector_2d, .data$year) %>%
    dplyr::mutate(
      n_v = sum(!is.na(.data$v)),
      less50_v = ifelse(.data$n_v < 50, 1, NA_real_),
      q4_v = ifelse(.data$n_v >= 50, quartile_bin(.data$v, 4), NA_integer_)
    ) %>%
    dplyr::ungroup()
  q4[sub$.row] <- sub$q4_v
  less50[sub$.row] <- sub$less50_v
  list(q4 = q4, less50 = less50)
}

#' Classify a row into one of the 6 predictor-driven scaler types (plus 0/9/50)
#'
#' A consequence of the rule structure worth noting explicitly (found while
#' writing this function's tests, not stated outright in the source): types
#' `9` ("Missing info") and `50` ("<50 year-sector N") are overridden by rules
#' 5/6 ("Transformational"/"Expansionist"), not only by the strategic-driver
#' rules 1-4. Rules 5 and 6 only test `MFP_gr`/`gross_profit_gr` against `0`
#' (via `stata_num()`, so a *missing* `L3q4_MFP`/`L3q4_phys_assets`/
#' `L3q4_avg_wage` still satisfies their "not top quartile" precondition) - so
#' whenever `gross_profit_gr` or `MFP_gr` is itself a known real number, one
#' of 5/6 fires regardless of whether the quartile predictors are missing or
#' small-cell-flagged. Types 9/50 only survive in the final output when
#' *both* growth measures are themselves unavailable too.
#' @keywords internal
predictors_classify_type <- function(data) {
  type <- rep(0, nrow(data))
  type <- stata_replace(
    type,
    is.na(data$L3q4_MFP) | is.na(data$MFP_gr) | is.na(data$L3q4_phys_assets) | is.na(data$L3q4_avg_wage),
    9
  )
  type <- stata_replace(
    type,
    type == 9 & (stata_num(data$L3less50_MFP) == 1 | stata_num(data$L3less50_phys_assets) == 1 |
      stata_num(data$L3less50_avg_wage) == 1),
    50
  )
  type <- stata_replace(
    type,
    stata_num(data$L3q4_MFP) == 4 | stata_num(data$L3q4_phys_assets) == 4 | stata_num(data$L3q4_avg_wage) == 4,
    1
  )
  type <- stata_replace(
    type,
    stata_num(data$L3q4_MFP) == 4 & stata_num(data$L3q4_phys_assets) != 4 & stata_num(data$L3q4_avg_wage) != 4,
    2
  )
  type <- stata_replace(
    type,
    stata_num(data$L3q4_MFP) != 4 & stata_num(data$L3q4_phys_assets) == 4 & stata_num(data$L3q4_avg_wage) != 4,
    3
  )
  type <- stata_replace(
    type,
    stata_num(data$L3q4_MFP) != 4 & stata_num(data$L3q4_phys_assets) != 4 & stata_num(data$L3q4_avg_wage) == 4,
    4
  )
  no_top_quartile <- stata_num(data$L3q4_MFP) != 4 & stata_num(data$L3q4_phys_assets) != 4 & stata_num(data$L3q4_avg_wage) != 4
  type <- stata_replace(
    type,
    no_top_quartile & (stata_num(data$MFP_gr) <= 0 | stata_num(data$gross_profit_gr) <= 0),
    6
  )
  type <- stata_replace(
    type,
    no_top_quartile & ((!is.na(data$MFP_gr) & data$MFP_gr > 0) | (!is.na(data$gross_profit_gr) & data$gross_profit_gr > 0)),
    5
  )
  type
}

#' @keywords internal
predictors_type_labels <- c(
  `0` = "Unclassified", `1` = "Strategic (mixed)", `2` = "Strategic (productivity)",
  `3` = "Strategic (capital)", `4` = "Strategic (labour)", `5` = "Transformational",
  `6` = "Expansionist", `9` = "Missing info", `50` = "<50 year-sector N"
)

#' Classify scalers by pre-period predictor quartile and regress scaling on them
#'
#' Translates `n1_3_predictors.do` (`Pseudocode/n1_3_predictors.md`). The
#' entire procedure is a no-op unless `added_value`, `tangible_fixed_assets`,
#' and `labour_costs` all exist in `accounts_indicators`. First classifies
#' first-time-eligible scalers into 6 "driver" types based on which
#' pre-period predictor(s) (productivity, capital intensity, wages) sit in
#' the top sector-year quartile, then fits a battery of linear-probability
#' regressions of scaling on those same predictors.
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param accounts_indicators The output of [build_accounts_indicators()].
#' @return A named list with `desc_predictors` and `regs_predictors` data
#'   frames (PDF Tables 3.6/3.7), or an empty list if the precondition isn't
#'   met.
#' @export
compute_predictors <- function(config, accounts_indicators) {
  data <- accounts_indicators
  if (!(has_column(data, "added_value") && has_column(data, "tangible_fixed_assets") &&
    has_column(data, "labour_costs"))) {
    return(list())
  }

  # --- 1. Preparation ----------------------------------------------------------
  nonmicro <- as.integer(!is.na(data$size_cat) & data$size_cat >= 10)
  nonlarge <- as.integer(!is.na(data$size_cat) & data$size_cat < 250)
  ever_nonmicro <- stats::ave(nonmicro, data$idf, FUN = max)
  ever_nonlarge <- stats::ave(nonlarge, data$idf, FUN = max)
  data <- data[ever_nonmicro == 1 & ever_nonlarge == 1, ]

  for (hg in c("HGE10", "HGE20", "HGT10", "HGT20", "HGET10", "HGET20")) {
    data[[paste0("f_", hg)]] <- first_occurrence_flag(data$idf, data$year, data[[hg]])
  }

  data$gross_profit <- data$added_value - data$labour_costs
  data$gross_profit_gr <- data$gross_profit - panel_lag(data$gross_profit, 3, data$idf, data$year)

  # --- 2. Predictor quartiles ---------------------------------------------------
  ymin <- min(data$year)
  end_year <- max(data$year)
  for (v in c("avg_wage", "phys_assets", "MFP", "MFP_gr")) {
    res <- predictors_quartile_var(data, v, ymin, end_year)
    data[[paste0("q4_", v)]] <- res$q4
    data[[paste0("less50_", v)]] <- res$less50
  }

  # --- 3. Descriptives: classify into 6 driver types -----------------------------
  for (v in c("q4_MFP", "q4_avg_wage", "q4_phys_assets", "less50_MFP", "less50_phys_assets", "less50_avg_wage", "idf")) {
    data[[paste0("L3", v)]] <- panel_lag(data[[v]], 3, data$idf, data$year)
  }
  min_year <- min(data$year)
  data <- data[data$year >= min_year + 3 & !is.na(data$L3idf), ]
  if (nrow(data) == 0) {
    return(list())
  }

  data$type <- predictors_classify_type(data)
  data$ALL <- 1L

  categories <- intersect(
    c("ALL", "L3age_cat", "L3tech_grad", "L3region_2d", "L3typology_UR", "L3independent", "L3size_age"),
    names(data)
  )
  scalers <- c(
    "HGE20", "HGT20", "HGET20", "f_HGE20", "f_HGT20", "f_HGET20",
    "HGE10", "HGT10", "HGET10", "f_HGE10", "f_HGT10", "f_HGET10"
  )
  median_vars <- intersect(
    c("L3age", "L3employment", "L3turnover", "employment", "turnover", "employment_growth3y", "turnover_growth3y"),
    names(data)
  )

  desc_acc <- list()
  for (scaler in scalers) {
    for (cat in categories) {
      subset_df <- data[stata_num(data[[scaler]]) == 1, ]
      if (nrow(subset_df) == 0) next

      grp <- subset_df %>% dplyr::group_by(dplyr::across(dplyr::all_of(c("type", cat, "year"))))
      cell <- grp %>%
        dplyr::summarise(
          N_firms = dplyr::n(),
          dplyr::across(dplyr::all_of(c("employment_growth3y", "turnover_growth3y")), ~ mean(.x, na.rm = TRUE)),
          dplyr::across(dplyr::all_of(median_vars), approx_median, .names = "median_{.col}"),
          .groups = "drop"
        )
      if (isTRUE(config$dominance)) {
        dom <- grp %>%
          dplyr::summarise(
            dplyr::across(dplyr::all_of(config$dom_vars), ~ dominance_share(.x, config$dom_num), .names = "dom_{.col}"),
            .groups = "drop"
          )
        cell <- dplyr::left_join(cell, dom, by = c("type", cat, "year"))
      }
      cell <- cell[!is.na(cell[[cat]]), ]
      if (nrow(cell) == 0) next

      totals <- cell[cell$type >= 1 & cell$type <= 6, c(cat, "year", "N_firms")]
      if (nrow(totals) > 0) {
        totals <- stats::aggregate(N_firms ~ ., data = totals, FUN = sum)
        names(totals)[names(totals) == "N_firms"] <- "total"
        cell <- dplyr::left_join(cell, totals, by = c(cat, "year"))
      } else {
        cell$total <- NA_real_
      }
      cell$Perc <- ifelse(cell$type >= 1 & cell$type <= 6, cell$N_firms / cell$total * 100, NA_real_)
      cell$total <- NULL

      cell$group <- decode_category(cell[[cat]], cat)
      cell[[cat]] <- NULL
      cell$category <- cat
      cell$scalertype <- scaler
      desc_acc[[length(desc_acc) + 1]] <- cell
    }
  }

  # --- 4. Regressions --------------------------------------------------------------
  for (v in c("L3q4_MFP", "L3q4_avg_wage", "L3q4_phys_assets", "q4_MFP_gr")) {
    data[[paste0(v, "_d")]] <- as.integer(stata_num(data[[v]]) == 4)
    data[[paste0(v, "_d")]][is.na(data[[v]])] <- NA
  }
  data$L3small <- as.integer(data$L3size_cat < 50)
  data$L3small[is.na(data$L3size_cat)] <- NA

  tech_levels <- sort(unique(stats::na.omit(data$L3tech_grad)))
  tech_dummy_cols <- character(0)
  tech_dummy_labels <- character(0)
  for (lvl in tech_levels) {
    col <- paste0("L3tech_grad_d", lvl)
    data[[col]] <- as.integer(!is.na(data$L3tech_grad) & data$L3tech_grad == lvl)
    tech_dummy_cols <- c(tech_dummy_cols, col)
    tech_dummy_labels <- c(tech_dummy_labels, unname(value_labels$tech_grad[as.character(lvl)]))
  }
  names(tech_dummy_labels) <- tech_dummy_cols

  years <- c(2014, 2017, 2020)
  scalers2 <- c("HGE10", "HGT10", "HGET10", "HGE20", "HGT20", "HGET20")
  # L3young/L3small are always created by build_accounts_indicators() for any
  # realistic dataset; intersect() guards only the pathological edge case
  # where age data is entirely absent (which would make the source's own
  # `foreach ... of varlist` error identically - see the comment above
  # predictors_classify_type() and this function's tests).
  sample_cols <- intersect(c("ALL", "L3young", "L3small", tech_dummy_cols), names(data))
  keyvar_groups <- list("L3q4_MFP_d", "q4_MFP_gr_d", c("L3q4_avg_wage_d", "L3q4_phys_assets_d"))

  regs_acc <- list()
  for (year in years) {
    for (sample in sample_cols) {
      cat_vars <- if (identical(sample, "ALL")) {
        c("L3age_cat", "L3size_cat", "L3region_2d")
      } else if (identical(sample, "L3young")) {
        c("L3size_cat", "L3region_2d")
      } else if (identical(sample, "L3small")) {
        c("L3age_cat", "L3region_2d")
      } else {
        c("L3size_cat", "L3age_cat", "L3region_2d")
      }
      cat_vars <- intersect(cat_vars, names(data))

      for (scaler in scalers2) {
        k <- 1
        for (keyvars in keyvar_groups) {
          for (controls_on in c(FALSE, TRUE)) {
            covariates_label <- if (controls_on) "yes" else "no"
            controls_terms <- if (controls_on) paste0("factor(", cat_vars, ")") else character(0)
            formula_str <- paste(scaler, "~", paste(c(keyvars, controls_terms), collapse = " + "))

            row_filter <- !is.na(data$year) & data$year == year & stata_num(data[[sample]]) == 1
            fit_data <- data[row_filter, ]

            model <- tryCatch(
              fixest::feols(stats::as.formula(formula_str), data = fit_data, vcov = "hetero"),
              error = function(e) NULL, warning = function(w) NULL
            )
            if (is.null(model)) {
              next # k advances once per keyvar_group regardless of outcome - see below
            }

            formula_vars <- all.vars(stats::as.formula(formula_str))
            complete <- stats::complete.cases(fit_data[formula_vars])
            est_sample <- fit_data[complete, ]
            ymean <- round_half_up(mean(est_sample[[scaler]], na.rm = TRUE), 4)

            dom_scalars <- list()
            if (isTRUE(config$dominance)) {
              for (domvar in config$dom_vars) {
                if (domvar %in% names(est_sample)) {
                  dom_scalars[[domvar]] <- dominance_share(est_sample[[domvar]], config$dom_num)
                }
              }
            }

            ct <- fixest::coeftable(model)
            ci <- stats::confint(model)
            indepvars <- rownames(ct)
            result <- data.frame(
              model = k, controls = covariates_label, obs = stats::nobs(model), year = year,
              sample = sample, depvar = scaler, mean_depvar = ymean, indepvar = indepvars,
              b = ct[, "Estimate"], se = ct[, "Std. Error"], t = ct[, "t value"], pval = ct[, "Pr(>|t|)"],
              lb95 = ci[indepvars, 1], ub95 = ci[indepvars, 2], df = stats::df.residual(model),
              stringsAsFactors = FALSE
            )
            for (domvar in names(dom_scalars)) {
              result[[paste0("dom_", domvar)]] <- dom_scalars[[domvar]]
            }
            regs_acc[[length(regs_acc) + 1]] <- result
          }
          k <- k + 1
        }
      }
    }
  }

  list(
    desc_predictors = finalize_desc_predictors(desc_acc, config),
    regs_predictors = finalize_regs_predictors(regs_acc, tech_dummy_labels)
  )
}

#' @keywords internal
finalize_desc_predictors <- function(accumulator, config) {
  if (length(accumulator) == 0) {
    return(NULL)
  }
  out <- dplyr::bind_rows(accumulator)
  names(out)[names(out) == "employment_growth3y"] <- "mean_employment_growth3y"
  names(out)[names(out) == "turnover_growth3y"] <- "mean_turnover_growth3y"
  front <- c("category", "group", "scalertype")
  dom_cols <- if (isTRUE(config$dominance)) grep("^dom_", names(out), value = TRUE) else character(0)
  rest <- setdiff(names(out), c(front, dom_cols, "year"))
  dplyr::as_tibble(out[c("year", front, rest, dom_cols)])
}

#' @keywords internal
finalize_regs_predictors <- function(accumulator, tech_dummy_labels) {
  if (length(accumulator) == 0) {
    return(NULL)
  }
  out <- dplyr::bind_rows(accumulator)
  for (col in names(tech_dummy_labels)) {
    out$sample[out$sample == col] <- tech_dummy_labels[[col]]
  }
  out$sample[out$sample == "L3young"] <- "Young firms"
  out$sample[out$sample == "L3small"] <- "Small firms (< 50 employees)"
  dplyr::as_tibble(out)
}