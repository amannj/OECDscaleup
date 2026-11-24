#' Characteristics of exporting and non-exporting scalers (trade package)
#'
#' Translates `n1_6_trade_characteristics.do` (trade package v1.0), a variant
#' of [compute_characteristics()]:
#'
#' * **p1**: scalers, non-scalers and heavy/light exporting turnover scalers
#'   (`HGX`/`HGNX`) by exporter status, size-age group, sector group x
#'   exporter and digital intensity (all at t-3). The second package's
#'   statistics plus medians of export value, products and partners, the mean
#'   share of the core product, and the shares of first-time exporters and
#'   importers. `HGX`/`HGNX` samples are not broken down by size-age or
#'   digital intensity.
#' * **p2**: exporting scalers only (exporter at t), by the second package's
#'   breakdowns, trade statistics only plus the share of heavy exporters.
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param trade_accounts_indicators The output of
#'   [build_trade_accounts_indicators()].
#' @return A list with data frames `p1` and `p2`, matching
#'   `trade_characteristics_p1_<country>.csv` and `..._p2_...`.
#' @export
compute_trade_characteristics <- function(config, trade_accounts_indicators) {
  data <- trade_accounts_indicators
  data$L3idf <- panel_lag(data$idf, 3, data$idf, data$year)
  data <- add_findep_ratios(data)
  findep_vars <- attr(data, "findep_vars")
  data <- restrict_characteristics_sample(data)
  data$ALL <- 1L
  for (stub in c("HGE", "HGT", "HGET")) {
    for (i in c("10", "20")) {
      data[[paste0(stub, i, "_nonscaler_pool")]] <- as.integer(
        stata_num(data[[paste0(stub, i)]]) == 0 & stata_num(data[[paste0(stub, "_pool")]]) == 1
      )
    }
  }
  data$firms <- data$ALL

  opt <- function(v) intersect(v, names(data))
  trade_medians <- c("L3exp_value", "exp_value", "L3exp_products", "exp_products",
                     "L3exp_all_partners", "exp_all_partners", "L3exp_eu_partners", "exp_eu_partners")
  shares <- c("L3multiplant", "L3independent", "L3foreign_owned", "L3young", "multiplant", "independent", "foreign_owned")

  # --- PART 1 ---------------------------------------------------------------------
  p1_median_vars <- c(
    opt(c("L3age", "L3employment", "L3turnover", "L3labour_share", "L3avg_wage", "L3labour_prod")),
    opt(paste0("L3", findep_vars)), # (paste0 of an empty vector gives "L3")
    opt(c("L3phys_assets", "L3MFP", "employment", "turnover", "labour_share", "avg_wage", "labour_prod")),
    findep_vars,
    opt(c("phys_assets", "MFP", "employment_growth3y", "turnover_growth3y", "employment_futgrowth",
          "turnover_futgrowth", "MFP_gr")),
    trade_medians
  )
  p1_mean_vars <- c("employment_growth3y", "turnover_growth3y", "employment_futgrowth", "turnover_futgrowth",
                    "acquisition", "L3exp_core_prod", "exp_core_prod", opt(shares),
                    "y4_exporter", "L3importer", "importer")
  p1 <- trade_cells(
    config, data,
    samples = c("HGE10", "HGE10_nonscaler_pool", "HGT10", "HGT10_nonscaler_pool", "HGET10",
                "HGET10_nonscaler_pool", "HGE20", "HGE20_nonscaler_pool", "HGT20", "HGT20_nonscaler_pool",
                "HGET20", "HGET20_nonscaler_pool", "HGX10", "HGX20", "HGNX10", "HGNX20"),
    categories = c("L3exporter", "L3size_age", "L3sector_exporter", "L3digit_sect"),
    skip = function(sample, cat) sample %in% c("HGX10", "HGX20", "HGNX10", "HGNX20") && cat %in% c("L3size_age", "L3digit_sect"),
    median_vars = p1_median_vars, mean_vars = function(sample) p1_mean_vars
  )
  for (x in c("multiplant", "independent", "foreign_owned", "young")) {
    if (paste0("L3", x) %in% names(p1)) names(p1)[names(p1) == paste0("L3", x)] <- paste0("L3share_", x)
    if (x %in% names(p1)) names(p1)[names(p1) == x] <- paste0("share_", x)
  }
  for (v in c("employment_growth3y", "turnover_growth3y", "employment_futgrowth", "turnover_futgrowth")) {
    names(p1)[names(p1) == v] <- paste0("mean_", v)
  }
  names(p1)[names(p1) == "acquisition"] <- "share_acquisition"

  # --- PART 2: exporters at t only --------------------------------------------------
  exporters <- data[stata_num(data$exporter) == 1, ]
  p2 <- trade_cells(
    config, exporters,
    samples = c("HGE10", "HGT10", "HGET10", "HGE20", "HGT20", "HGET20"),
    categories = c("ALL", "L3size_cat", "L3age_cat", "L3tech_grad", "L3region_2d",
                   opt(c("L3typology_UR", "L3independent", "L3multiplant", "L3foreign_owned"))),
    skip = function(sample, cat) FALSE,
    median_vars = trade_medians,
    mean_vars = function(sample) c("L3exp_core_prod", "exp_core_prod", "y4_exporter", "L3importer", "importer",
                                   if (endsWith(sample, "10")) "HGX10" else "HGX20")
  )
  # rows of the 10% samples carry HGX10, those of the 20% samples HGX20
  if (!"HGX10" %in% names(p2)) p2$HGX10 <- NA_real_
  if (!"HGX20" %in% names(p2)) p2$HGX20 <- NA_real_
  p2$HGX20 <- dplyr::if_else(is.na(p2$HGX20) & !is.na(p2$HGX10), p2$HGX10, p2$HGX20)
  names(p2)[names(p2) == "HGX20"] <- "share_HGX"
  p2$HGX10 <- NULL

  finish <- function(out) {
    names(out)[names(out) == "firms"] <- "firm_count"
    for (v in c("y4_exporter", "L3importer", "importer")) names(out)[names(out) == v] <- paste0("share_", v)
    for (v in c("L3exp_core_prod", "exp_core_prod")) names(out)[names(out) == v] <- paste0("mean_", v)
    front <- c("year", "sample", "category", "group")
    dom_cols <- if (isTRUE(config$dominance)) grep("^dom_", names(out), value = TRUE) else character(0)
    dplyr::as_tibble(out[c(front, setdiff(names(out), c(front, dom_cols)), dom_cols)])
  }
  list(p1 = finish(p1), p2 = finish(p2))
}

# One collapse per (sample, category): firm count, approximate medians, means, dominance.
trade_cells <- function(config, data, samples, categories, skip, median_vars, mean_vars) {
  results <- list()
  for (sample in samples) {
    for (cat in categories) {
      if (skip(sample, cat)) next
      subset_df <- data[stata_num(data[[sample]]) == 1 & !is.na(data$L3idf), ]
      if (nrow(subset_df) == 0) next
      means <- intersect(mean_vars(sample), names(subset_df))
      grp <- subset_df %>% dplyr::group_by(dplyr::across(dplyr::all_of(c(cat, "year"))))
      cell <- grp %>%
        dplyr::summarise(
          firms = sum(.data$firms),
          dplyr::across(dplyr::all_of(median_vars), approx_median, .names = "median_{.col}"),
          dplyr::across(dplyr::all_of(means), ~ stata_double(mean(.x, na.rm = TRUE))),
          .groups = "drop"
        )
      if (isTRUE(config$dominance)) {
        dom <- grp %>%
          dplyr::summarise(
            dplyr::across(dplyr::all_of(config$dom_vars), ~ dominance_share(.x, config$dom_num), .names = "dom_{.col}"),
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
  dplyr::bind_rows(results)
}
