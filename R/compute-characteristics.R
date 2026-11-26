#' Descriptive characteristics of scaler and non-scaler populations
#'
#' For every combination of 24 firm samples (each HGF definition, its
#' "eligible non-scaler" complement, micro/non-micro) and up to 12 category
#' breakdowns (age, size, sector, region, ownership, ...), reports firm
#' counts, mean growth rates, the disclosure-safe [approx_median()] of
#' size/age/productivity/financial variables, and (optionally)
#' [dominance_share()] concentration statistics.
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param accounts_indicators The output of [build_accounts_indicators()].
#' @return A data frame, one row per `(sample, category, group, year)` cell,
#'   matching the column contract of `n13_characteristics_<country>.csv`
#'   (PDF Table 3.3).
#' @export
compute_characteristics <- function(config, accounts_indicators) {
  data <- accounts_indicators
  data$ALL <- 1L
  data$firms <- data$ALL

  data$f_HGET20 <- first_occurrence_flag(data$idf, data$year, data$HGET20)
  data$f_HGET10 <- first_occurrence_flag(data$idf, data$year, data$HGET10)
  data$L3idf <- panel_lag(data$idf, 3, data$idf, data$year)

  # --- financial dependency ratios (each conditional on its inputs) ----------
  data <- add_findep_ratios(data)
  findep_vars <- attr(data, "findep_vars")
  l3_findep_vars <- paste0("L3", findep_vars)

  categories <- intersect(
    c(
      "ALL", "L3size_cat", "L3age_cat", "L3tech_grad", "L3region_2d", "L3typology_UR",
      "L3independent", "L3multiplant", "L3foreign_owned", "L3reg_techgrad", "L3ind_a38",
      "L3size_age"
    ),
    names(data)
  )

  median_vars <- intersect(c(
    "L3age", "L3employment", "L3turnover", "L3labour_share", "L3avg_wage", "L3labour_prod",
    l3_findep_vars, "L3phys_assets", "L3MFP", "employment", "turnover", "labour_share",
    "avg_wage", "labour_prod", findep_vars, "phys_assets", "MFP", "employment_growth3y",
    "turnover_growth3y", "employment_futgrowth", "turnover_futgrowth", "MFP_gr"
  ), names(data))

  # --- keep only the columns used below, then restrict the sample --------------
  data <- data[intersect(names(data), c(
    "year", "firms", "L3idf", "L3employment", categories, median_vars,
    c(outer(c("HGE", "HGT", "HGET", "HGB"), c("10", "20"), paste0)), "MHGE20", "MHGT20",
    "HGE_pool", "HGT_pool", "HGET_pool", "f_HGET10", "f_HGET20",
    "employment_growth3y", "turnover_growth3y", "employment_futgrowth", "turnover_futgrowth", "acquisition",
    "L3multiplant", "L3independent", "L3foreign_owned", "L3young", "multiplant", "independent", "foreign_owned",
    if (isTRUE(config$dominance)) config$dom_vars
  ))]
  data <- restrict_characteristics_sample(data)

  # --- sample definitions (24), as columns on the restricted data ------------
  for (stub in c("HGE", "HGT", "HGET")) {
    for (i in c("10", "20")) {
      flag <- data[[paste0(stub, i)]]
      pool <- data[[paste0(stub, "_pool")]]
      data[[paste0(stub, i, "_nonscaler_pool")]] <- as.integer(stata_num(flag) == 0 & stata_num(pool) == 1)
    }
  }
  for (i in c("10", "20")) {
    data[[paste0("HGB", i, "_nonscaler_pool")]] <- as.integer(
      stata_num(data[[paste0("HGE", i)]]) == 0 & stata_num(data[[paste0("HGT", i)]]) == 0 &
        !is.na(data$L3employment) & data$L3employment >= 10
    )
  }
  # Fix S9: micro = fewer than 10 employees at t-3, as documented and as for the
  # micro scalers; Stata's 1-9 left e.g. 9.5 FTE out of the comparison pool.
  for (scaler in c("MHGE20", "MHGT20")) {
    data[[paste0(scaler, "_nonscaler_pool")]] <- as.integer(
      stata_num(data[[scaler]]) == 0 & !is.na(data$L3employment) &
        data$L3employment > 0 & data$L3employment < 10
    )
  }
  data$micro <- as.integer(data$L3employment < 10)
  data$non_micro_sme <- as.integer(data$L3employment >= 10)

  samples <- c(
    "HGE10", "HGE10_nonscaler_pool", "HGT10", "HGT10_nonscaler_pool", "HGET10",
    "HGET10_nonscaler_pool", "f_HGET10", "HGB10", "HGB10_nonscaler_pool",
    "HGE20", "HGE20_nonscaler_pool", "HGT20", "HGT20_nonscaler_pool", "HGET20",
    "HGET20_nonscaler_pool", "f_HGET20", "HGB20", "HGB20_nonscaler_pool",
    "MHGE20", "MHGT20", "MHGE20_nonscaler_pool", "MHGT20_nonscaler_pool",
    "non_micro_sme", "micro"
  )

  micro_only_samples <- c("MHGE20", "MHGT20", "MHGE20_nonscaler_pool", "MHGT20_nonscaler_pool", "micro")

  othcat_for <- function(cat) {
    full <- intersect(
      c("L3multiplant", "L3independent", "L3foreign_owned", "L3young", "multiplant", "independent", "foreign_owned"),
      names(data)
    )
    if (identical(cat, "L3multiplant")) {
      return(setdiff(full, c("L3multiplant", "multiplant")))
    }
    if (identical(cat, "L3independent")) {
      return(setdiff(full, c("L3independent", "independent")))
    }
    if (identical(cat, "L3foreign_owned")) {
      return(setdiff(full, c("L3foreign_owned", "foreign_owned")))
    }
    if (identical(cat, "L3age_cat")) {
      return(setdiff(full, "L3young"))
    }
    full
  }

  # columns the cells use (each sample's rows are copied once, with only these)
  cell_cols <- intersect(c(
    "year", "firms", categories, median_vars, "employment_growth3y", "turnover_growth3y",
    "employment_futgrowth", "turnover_futgrowth", "acquisition", othcat_for("ALL"),
    if (isTRUE(config$dominance)) config$dom_vars
  ), names(data))

  results <- list()
  for (sample in samples) {
    in_sample <- stata_num(data[[sample]]) == 1 & !is.na(data$L3idf)
    if (!any(in_sample)) next
    sample_df <- data[in_sample, cell_cols]
    for (cat in categories) {
      if (sample %in% micro_only_samples && cat == "L3size_cat") next

      subset_df <- sample_df

      othcat <- othcat_for(cat)
      mean_vars <- intersect(
        c("employment_growth3y", "turnover_growth3y", "employment_futgrowth", "turnover_futgrowth", "acquisition", othcat),
        names(subset_df)
      )

      grp <- subset_df %>%
        dplyr::group_by(dplyr::across(dplyr::all_of(c(cat, "year"))))

      # Medians before means: summarise() evaluates in order, and the means
      # overwrite the growth columns that the medians also need.
      cell <- grp %>%
        dplyr::summarise(
          firms = sum(.data$firms),
          dplyr::across(dplyr::all_of(median_vars), approx_median, .names = "median_{.col}"),
          dplyr::across(dplyr::all_of(mean_vars), ~ stata_double(mean(.x, na.rm = TRUE))),
          .groups = "drop"
        )

      if (isTRUE(config$dominance)) {
        dom <- grp %>%
          dplyr::summarise(
            dplyr::across(
              dplyr::all_of(config$dom_vars), ~ dominance_share(.x, config$dom_num),
              .names = "dom_{.col}"
            ),
            .groups = "drop"
          )
        cell <- dplyr::left_join(cell, dom, by = c(cat, "year"))
      }

      cell <- cell[!is.na(cell[[cat]]), ]
      if (nrow(cell) == 0) next

      cell$group <- decode_category(cell[[cat]], cat)
      cell[[cat]] <- NULL
      cell$category <- cat
      cell$sample <- sample

      results[[length(results) + 1]] <- cell
    }
  }

  out <- dplyr::bind_rows(results)

  # --- finalize -----------------------------------------------------------------
  for (x in c("multiplant", "independent", "foreign_owned", "young")) {
    l3x <- paste0("L3", x)
    if (l3x %in% names(out)) names(out)[names(out) == l3x] <- paste0("L3share_", x)
    if (x %in% names(out)) names(out)[names(out) == x] <- paste0("share_", x)
  }
  for (v in c("employment_growth3y", "turnover_growth3y", "employment_futgrowth", "turnover_futgrowth")) {
    if (v %in% names(out)) names(out)[names(out) == v] <- paste0("mean_", v)
  }
  names(out)[names(out) == "firms"] <- "firm_count"
  names(out)[names(out) == "acquisition"] <- "share_acquisition"

  front <- c("sample", "category", "group")
  dom_cols <- if (isTRUE(config$dominance)) grep("^dom_", names(out), value = TRUE) else character(0)
  rest <- setdiff(names(out), c(front, dom_cols, "year"))
  out <- out[c("year", front, rest, dom_cols)]

  dplyr::as_tibble(out)
}

#' Financial dependency ratios of n1_3 / n1_6 (each only if its inputs exist)
#' @return `data` with the ratios and their L3 lags; their names in attribute `findep_vars`.
#' @noRd
add_findep_ratios <- function(data) {
  findep_vars <- character(0)
  if (has_column(data, "current_assets") && has_column(data, "total_assets")) {
    data$findep_rat1 <- stata_float(data$current_assets / data$total_assets)
    data$L3findep_rat1 <- panel_lag(data$findep_rat1, 3, data$idf, data$year)
    findep_vars <- c(findep_vars, "findep_rat1")
  }
  if (has_column(data, "total_liabilities") && has_column(data, "total_assets")) {
    data$findep_rat2 <- stata_float(data$total_liabilities / data$total_assets)
    data$L3findep_rat2 <- panel_lag(data$findep_rat2, 3, data$idf, data$year)
    findep_vars <- c(findep_vars, "findep_rat2")
  }
  if (has_column(data, "total_liabilities") && has_column(data, "interest_costs")) {
    data$findep_rat3 <- stata_float(data$interest_costs / data$total_liabilities)
    data$L3findep_rat3 <- panel_lag(data$findep_rat3, 3, data$idf, data$year)
    findep_vars <- c(findep_vars, "findep_rat3")
  }
  if (has_column(data, "tangible_fixed_assets") && has_column(data, "depr_amort") && has_column(data, "cash_flow")) {
    tfa <- as.double(data$tangible_fixed_assets)
    l1_tfa <- as.double(panel_lag(data$tangible_fixed_assets, 1, data$idf, data$year))
    dep <- as.double(data$depr_amort)
    capex <- tfa - l1_tfa + dep
    # Fix N3: a firm that does not invest has tfa falling by exactly its depreciation, so capex is 0 and the
    # ratio missing (x/0). In EUR thousand (and in Stata's float storage) the three values no longer cancel
    # exactly and leave a residue of ~1e-17 to 1e-7 of their size, which made the ratio +-1e16 instead of
    # missing and moved its medians. A capex within 1e-6 of the size of its inputs is zero.
    scale <- pmax(abs(tfa), abs(l1_tfa), abs(dep))
    capex[!is.na(capex) & abs(capex) <= 1e-6 * scale] <- 0
    capex <- stata_float(capex)
    data$findep_rat4 <- stata_float((capex - data$cash_flow) / capex)
    data$L3findep_rat4 <- panel_lag(data$findep_rat4, 3, data$idf, data$year)
    findep_vars <- c(findep_vars, "findep_rat4")
  }
  attr(data, "findep_vars") <- findep_vars
  data
}

#' n1_3 / n1_6: drop the first 3 years and keep firms with fewer than 250 employees at t-3
#' @noRd
restrict_characteristics_sample <- function(data) {
  # Fix S9: the documented universe is employers with fewer than 250 employees at
  # t-3 (0 < L3employment < 250); Stata's 1-249 left out fractional FTE such as
  # 0.5 or 249.5.
  startyear <- min(data$year)
  data[
    data$year >= startyear + 3 & !is.na(data$L3employment) &
      data$L3employment > 0 & data$L3employment < 250,
  ]
}
