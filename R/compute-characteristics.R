#' Descriptive characteristics of scaler and non-scaler populations
#'
#' Translates `n1_3_characteristics.do` (`Pseudocode/n1_3_characteristics.md`).
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
  findep_vars <- character(0)
  if (has_column(data, "current_assets") && has_column(data, "total_assets")) {
    data$findep_rat1 <- data$current_assets / data$total_assets
    data$L3findep_rat1 <- panel_lag(data$findep_rat1, 3, data$idf, data$year)
    findep_vars <- c(findep_vars, "findep_rat1")
  }
  if (has_column(data, "total_liabilities") && has_column(data, "total_assets")) {
    data$findep_rat2 <- data$total_liabilities / data$total_assets
    data$L3findep_rat2 <- panel_lag(data$findep_rat2, 3, data$idf, data$year)
    findep_vars <- c(findep_vars, "findep_rat2")
  }
  if (has_column(data, "total_liabilities") && has_column(data, "interest_costs")) {
    data$findep_rat3 <- data$interest_costs / data$total_liabilities
    data$L3findep_rat3 <- panel_lag(data$findep_rat3, 3, data$idf, data$year)
    findep_vars <- c(findep_vars, "findep_rat3")
  }
  if (has_column(data, "tangible_fixed_assets") && has_column(data, "depr_amort") && has_column(data, "cash_flow")) {
    capex <- data$tangible_fixed_assets -
      panel_lag(data$tangible_fixed_assets, 1, data$idf, data$year) + data$depr_amort
    data$findep_rat4 <- (capex - data$cash_flow) / capex
    data$L3findep_rat4 <- panel_lag(data$findep_rat4, 3, data$idf, data$year)
    findep_vars <- c(findep_vars, "findep_rat4")
  }
  l3_findep_vars <- paste0("L3", findep_vars)

  # --- restrict the sample -----------------------------------------------------
  startyear <- min(data$year)
  data <- data[
    data$year >= startyear + 3 & !is.na(data$L3employment) &
      data$L3employment >= 1 & data$L3employment <= 249,
  ]

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
  for (scaler in c("MHGE20", "MHGT20")) {
    data[[paste0(scaler, "_nonscaler_pool")]] <- as.integer(
      stata_num(data[[scaler]]) == 0 & !is.na(data$L3employment) &
        data$L3employment >= 1 & data$L3employment <= 9
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

  results <- list()
  for (sample in samples) {
    for (cat in categories) {
      if (sample %in% micro_only_samples && cat == "L3size_cat") next

      subset_df <- data[stata_num(data[[sample]]) == 1 & !is.na(data$L3idf), ]
      if (nrow(subset_df) == 0) next

      othcat <- othcat_for(cat)
      mean_vars <- intersect(
        c("employment_growth3y", "turnover_growth3y", "employment_futgrowth", "turnover_futgrowth", "acquisition", othcat),
        names(subset_df)
      )

      grp <- subset_df %>%
        dplyr::group_by(dplyr::across(dplyr::all_of(c(cat, "year"))))

      cell <- grp %>%
        dplyr::summarise(
          firms = sum(.data$firms),
          dplyr::across(dplyr::all_of(mean_vars), ~ mean(.x, na.rm = TRUE)),
          dplyr::across(dplyr::all_of(median_vars), approx_median, .names = "median_{.col}"),
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
