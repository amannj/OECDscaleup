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
#' Rules are applied in order, a later rule overwriting an earlier one. Types
#' 9 ("Missing info") and 50 ("<50 year-sector N") come first so that the
#' strategic types 1-4 can still be assigned from the quartiles that are known.
#'
#' Types 5/6 ("Transformational"/"Expansionist") say that *none* of the
#' three quartiles is the top one, which is only known when all three are known.
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
  no_top_quartile <- !is.na(data$L3q4_MFP) & !is.na(data$L3q4_phys_assets) & !is.na(data$L3q4_avg_wage) &
    data$L3q4_MFP != 4 & data$L3q4_phys_assets != 4 & data$L3q4_avg_wage != 4
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
#' The
#' entire procedure is a no-op unless `added_value`, `tangible_fixed_assets`,
#' and `labour_costs` all exist in `accounts_indicators`. First classifies
#' first-time-eligible scalers into 6 "driver" types based on which
#' pre-period predictor(s) (productivity, capital intensity, wages) sit in
#' the top sector-year quartile, then fits a battery of linear-probability
#' regressions of scaling on those same predictors.
#'
#' The strategic types use *levels* at t-3: MFP (the "productivity" type),
#' tangible fixed assets over turnover and the average wage.
#' MFP growth enters the regressions (model 2) and the Transformational
#' / Expansionist types.
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
  # encode codes of region_2d (they appear in the regression term names, e.g. 3.L3region_2d)
  region_codes <- attr(accounts_indicators, "stata_encode_levels")$region_2d
  if (is.null(region_codes) && "region_2d" %in% names(data)) region_codes <- stata_encode_levels(data$region_2d)

  # only the columns used below (the first row selection would copy them all)
  hg_cols <- c(outer(c("HGE", "HGT", "HGET"), c("10", "20", "_pool"), paste0))
  data <- data[intersect(names(data), c(
    "idf", "year", "size_cat", "sector_2d", "region_2d", hg_cols, "added_value", "labour_costs",
    "avg_wage", "phys_assets", "MFP", "MFP_gr", "L3age_cat", "L3tech_grad", "L3region_2d", "L3typology_UR",
    "L3independent", "L3size_age", "L3size_cat", "L3young", "L3age", "L3employment", "L3turnover",
    "employment", "turnover", "employment_growth3y", "turnover_growth3y",
    if (isTRUE(config$dominance)) config$dom_vars
  ))]

  # --- 1. Preparation ----------------------------------------------------------
  nonmicro <- as.integer(!is.na(data$size_cat) & data$size_cat >= 10)
  nonlarge <- as.integer(!is.na(data$size_cat) & data$size_cat < 250)
  ever_nonmicro <- group_fill(nonmicro, data$idf, "max")
  ever_nonlarge <- group_fill(nonlarge, data$idf, "max")
  data <- data[ever_nonmicro == 1 & ever_nonlarge == 1, ]

  for (hg in c("HGE10", "HGE20", "HGT10", "HGT20", "HGET10", "HGET20")) {
    data[[paste0("f_", hg)]] <- first_occurrence_flag(data$idf, data$year, data[[hg]])
  }

  data$gross_profit <- stata_float(data$added_value - data$labour_costs)
  data$gross_profit_gr <- stata_float(data$gross_profit - panel_lag(data$gross_profit, 3, data$idf, data$year))

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

  desc_cols <- intersect(c("type", "year", categories, median_vars, "employment_growth3y", "turnover_growth3y",
                           if (isTRUE(config$dominance)) config$dom_vars), names(data))
  desc_acc <- list()
  for (scaler in scalers) {
    in_scaler <- stata_num(data[[scaler]]) == 1
    if (!any(in_scaler)) next
    scaler_df <- data[in_scaler, desc_cols] # copied once per scaler, with only the columns used
    for (cat in categories) {
      subset_df <- scaler_df

      grp <- subset_df %>% dplyr::group_by(dplyr::across(dplyr::all_of(c("type", cat, "year"))))
      # medians before means: summarise() evaluates in order and the means
      # overwrite the growth columns the medians need
      cell <- grp %>%
        dplyr::summarise(
          N_firms = dplyr::n(),
          dplyr::across(dplyr::all_of(median_vars), approx_median, .names = "median_{.col}"),
          dplyr::across(dplyr::all_of(c("employment_growth3y", "turnover_growth3y")), ~ stata_double(mean(.x, na.rm = TRUE))),
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

      # here ALL is labelled "Total" (label define ALL 1 "Total")
      cell$group <- if (identical(cat, "ALL")) "Total" else decode_category(cell[[cat]], cat)
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
            used_cats <- if (controls_on) cat_vars else character(0)

            # `reg <scaler> <keyvars> [i.(<cat_vars>)] if year == <year> & <sample> == 1, robust`
            # Fix S6 (decided 2026-11-20): only firms that can be scalers under this
            # dependent variable (its HG pool: 10+ employees at t-3, growth known) and
            # with fewer than 250 employees at t-3. Stata used every firm present at t-3,
            # so micro and 250+ firms counted as non-scalers.
            pool <- paste0(sub("[0-9]+$", "", scaler), "_pool")
            row_filter <- !is.na(data$year) & data$year == year & stata_num(data[[sample]]) == 1 &
              stata_num(data[[pool]]) == 1 & !is.na(data$L3employment) & data$L3employment < 250
            fit_data <- data[row_filter, intersect(c(scaler, keyvars, used_cats, config$dom_vars), names(data))]
            complete <- stats::complete.cases(fit_data[c(scaler, keyvars, used_cats)])
            est_sample <- fit_data[complete, ]
            factors <- lapply(stats::setNames(used_cats, used_cats), function(cv) {
              x <- est_sample[[cv]]
              if (identical(cv, "L3region_2d")) unname(region_codes[x]) else as.double(x)
            })
            fit <- stata_regress_robust(as.double(est_sample[[scaler]]), est_sample[keyvars], factors)
            if (is.null(fit)) {
              next # `cap reg` failed (no observations); k still advances per keyvar group
            }
            ymean <- stata_round(mean(est_sample[[scaler]]), 0.0001)

            dom_scalars <- list()
            if (isTRUE(config$dominance)) {
              for (domvar in config$dom_vars) {
                if (domvar %in% names(est_sample)) {
                  dom_scalars[[domvar]] <- stata_round(dominance_share(est_sample[[domvar]], config$dom_num), 0.0001)
                }
              }
            }

            result <- data.frame(
              model = k, controls = covariates_label, obs = fit$N, year = year,
              sample = sample, depvar = scaler, mean_depvar = ymean, fit$table, df = fit$df_r,
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
  out$type <- export_label(out$type, output_labels$type)
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