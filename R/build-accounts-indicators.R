#' Build the firm-year analytical panel and its derived indicators
#'
#' Translates `n0_1_accounts_indicators_v2.do`
#' (`Pseudocode/n0_1_accounts_indicators_v2.md`). Cleans the raw firm-level
#' panel, optionally folds in establishment-level plant data, and constructs
#' every derived variable the other 4 pipeline stages depend on: growth
#' rates, high-growth-firm (HGF) flags, age/size/sector/region categories,
#' the TL3 urbanisation typology, labour productivity, multi-factor
#' productivity (Solow residual), and the acquisition indicator.
#'
#' Unlike the source `.do` file, this is a pure function: it takes
#' already-loaded data frames and returns the built panel, rather than
#' reading/writing `.dta` files itself (that I/O now lives in
#' [run_scaleup_pipeline()], mirroring `MASTER_OECD_p2.do`'s role). This also
#' means the row-order-dependent `sort idf year` step in the source is
#' unnecessary here: every lag/lead below is computed via [panel_lag()] /
#' [panel_lead()], which key off `(idf, year)` values directly rather than
#' physical row position.
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param base_financials A data frame of raw firm-level financials, matching
#'   the `BASE_FINANCIALS` sheet of `variable_dictionary_v1.xlsx`. Must
#'   contain `idf, year, sector_1d, sector_2d, sector_3d, employment,
#'   turnover, region_2d`; every other column is optional and used only if
#'   present.
#' @param plants_raw Optional data frame of establishment-level data (the
#'   `PLANTS_RAW` sheet), with columns `idf, idp, year`. If `NULL` (the
#'   default), no `multiplant` indicator is produced.
#' @param exchange_rates Optional data frame with columns `year, country,
#'   rate` (as shipped in this package's `exchange_rates` dataset). Required
#'   only for the non-Euro countries listed in `country_patches$non_euro`.
#' @param tl3_typology Optional data frame with columns `region_3d,
#'   typology_access_cities` (as shipped in this package's `tl3_typology`
#'   dataset). Required only if `base_financials` has a `region_3d` column.
#' @param storage_types Optional named character vector giving the Stata
#'   storage type (`"byte"`, `"int"`, `"long"`, `"float"`, `"double"`) of the
#'   columns of `base_financials`, as stored in its `.dta` file.
#'   [run_scaleup_pipeline()] reads it from the file header. Where Stata
#'   rescales a `float` (or `byte`/`int`) variable in place, the result is
#'   stored in single precision, and R rounds it the same way. `NULL` (the
#'   default) treats every column as `double`.
#'
#' @return A data frame, one row per `(idf, year)`, ready to be passed to
#'   [compute_characteristics()], [compute_persistence()],
#'   [compute_contribution()], and [compute_predictors()].
#' @export
build_accounts_indicators <- function(config,
                                       base_financials,
                                       plants_raw = NULL,
                                       exchange_rates = NULL,
                                       tl3_typology = NULL,
                                       storage_types = NULL) {
  data <- base_financials

  # --- Step 2: optional plant-count / multiplant flag ------------------------
  if (!is.null(plants_raw)) {
    plant_counts <- plants_raw %>%
      dplyr::distinct(.data$idf, .data$idp, .data$year) %>%
      dplyr::count(.data$idf, .data$year, name = "number_plants") %>%
      dplyr::mutate(multiplant = dplyr::if_else(.data$number_plants > 1, 1, 0))
    # Stata merges the plant counts (master) onto base_financials (using): where
    # a firm-year has plant records the computed counts win; a base_financials
    # that already carries number_plants/multiplant (Stata saves the merge back
    # into it, so a second run sees them) keeps its own values elsewhere.
    data <- dplyr::left_join(
      data, dplyr::rename(plant_counts, .number_plants = "number_plants", .multiplant = "multiplant"),
      by = c("idf", "year")
    )
    for (v in c("number_plants", "multiplant")) {
      fresh <- data[[paste0(".", v)]]
      data[[v]] <- if (has_column(data, v)) dplyr::coalesce(as.numeric(fresh), as.numeric(data[[v]])) else fresh
      data[[paste0(".", v)]] <- NULL
    }
  }

  # --- Step 4: validation and normalization -----------------------------------
  data$country <- NULL # Orbis JY artifact

  required_vars <- c(
    "idf", "year", "sector_3d", "sector_2d", "employment", "turnover",
    "sector_1d", "region_2d"
  )
  missing_vars <- setdiff(required_vars, names(data))
  if (length(missing_vars) > 0) {
    rlang::abort(
      sprintf(
        "Missing required column(s): %s. Check variable_dictionary_v1.xlsx.",
        paste(missing_vars, collapse = ", ")
      ),
      class = "OECDscaleup_data_error"
    )
  }

  string_vars <- c("region_2d", "sector_1d")
  numeric_vars <- c("idf", "year", "sector_3d", "sector_2d", "employment", "turnover")
  if (has_column(data, "birth_year")) numeric_vars <- c(numeric_vars, "birth_year")
  for (v in string_vars) {
    if (!is.character(data[[v]])) {
      rlang::abort(sprintf("`%s` must be a string column.", v), class = "OECDscaleup_data_error")
    }
  }
  for (v in numeric_vars) {
    if (!is.numeric(data[[v]])) {
      rlang::abort(sprintf("`%s` must be numeric.", v), class = "OECDscaleup_data_error")
    }
  }

  data <- dplyr::filter(data, !.data$sector_1d %in% c("A", "K", "O", "T", "U"))

  # sector_L: computed on the *raw* sector_1d, before any "." -> NA normalization,
  # so a missing sector_1d yields 0 here (matches the source: a literal-string
  # comparison against "L", not a missing-propagating one).
  data$sector_L <- as.integer(!is.na(data$sector_1d) & data$sector_1d == "L")

  # `replace sector_1d = "" if sector_1d == "."` then `encode`: "." and "" become missing.
  # The encode code table is fixed here, before the year trimming below drops rows.
  data$sector_1d[data$sector_1d %in% c(".", "")] <- NA_character_
  encode_levels <- list(sector_1d = stata_encode_levels(data$sector_1d))

  # --- Step 5: clean implausible negative financial values --------------------
  negative_clean_vars <- c(
    "employment", "turnover", "added_value", "exp_revenues_goods",
    "exp_revenues_services", "labour_costs", "operating_costs", "services_costs",
    "depr_amort", "interest_costs", "intangible_fixed_assets",
    "tangible_fixed_assets", "fixed_assets", "current_assets", "total_assets",
    "loans", "total_liabilities"
  )
  for (v in intersect(negative_clean_vars, names(data))) {
    data[[v]] <- dplyr::if_else(data[[v]] < 0, NA_real_, data[[v]])
  }

  # --- Step 6: unit rescaling for specific countries (data-source patch) -----
  # Fix S16: the Stata list left out cash_flow (and gross_profit), so
  # findep_rat4 = (capex - cash_flow) / capex mixed thousands with units.
  if (config$country %in% country_patches$rescale_to_thousands) {
    rescale_vars <- c(
      "turnover", "added_value", "labour_costs", "operating_costs",
      "services_costs", "exp_revenues_goods", "exp_revenues_services",
      "depr_amort", "interest_costs", "intangible_fixed_assets",
      "tangible_fixed_assets", "fixed_assets", "current_assets",
      "total_assets", "loans", "total_liabilities", "cash_flow", "gross_profit"
    )
    # `replace v = v/1000` keeps a float variable float (and promotes byte/int to
    # float), so the stored result is the single-precision rounding of the quotient
    for (v in intersect(rescale_vars, names(data))) {
      orig_type <- if (v %in% names(storage_types)) storage_types[[v]] else NA_character_
      to_float <- stata_replace_type(orig_type) == "float"
      data[[v]] <- if (to_float) stata_float(data[[v]] / 1000) else data[[v]] / 1000
    }
  }

  # --- Step 7: trim implausible years -----------------------------------------
  year_bounds <- stats::quantile(data$year, probs = c(0.01, 0.99), na.rm = TRUE, type = 2)
  data$year <- dplyr::if_else(
    data$year < year_bounds[[1]] | data$year > year_bounds[[2]],
    NA_real_, data$year
  )
  data <- dplyr::filter(data, !is.na(.data$year))
  ymin <- min(data$year)
  ymax <- max(data$year)

  # --- Step 8: national-currency turnover for non-Euro countries --------------
  if (config$country %in% country_patches$non_euro) {
    if (is.null(exchange_rates)) {
      rlang::abort(
        "`exchange_rates` is required for non-Euro countries but was not supplied.",
        class = "OECDscaleup_data_error"
      )
    }
    rates <- exchange_rates %>%
      dplyr::filter(.data$country == config$country) %>%
      dplyr::select("year", "rate")
    data <- dplyr::left_join(data, rates, by = "year")
    data$turnover_nat <- stata_float(data$turnover * data$rate)
    data$rate <- NULL
  }

  # --- Step 9: panel integrity check ------------------------------------------
  if (anyDuplicated(data[c("idf", "year")]) > 0) {
    rlang::abort(
      "Duplicate (idf, year) pairs found - a firm must appear at most once per year.",
      class = "OECDscaleup_data_error"
    )
  }

  # --- Step 10: drop implausible growth "jumps" -------------------------------
  # A spike (e.g. 20-200-20) or dip is a year whose growth in and growth out are
  # both above 150% (mid-point growth rate) with opposite signs, for firms
  # averaging 20+ employees over the year before, the spike and the year after.
  # Fix S1: Stata tested growth in and out at t+1 (the year after the spike) and
  # blanked that year; the spike itself is now blanked.
  turnover_type <- if (config$country %in% country_patches$non_euro) "turnover_nat" else "turnover"
  for (v in c("employment", turnover_type)) {
    gr <- stata_float(panel_diff1(data[[v]], data$idf, data$year) /
      (0.5 * (data[[v]] + panel_lag(data[[v]], 1, data$idf, data$year))))
    f1_gr <- panel_lead(gr, 1, data$idf, data$year)
    avg3 <- (panel_lag(data$employment, 1, data$idf, data$year) + data$employment +
      panel_lead(data$employment, 1, data$idf, data$year)) / 3
    jump <- !is.na(gr) & !is.na(f1_gr) & abs(gr) > 1.5 & abs(f1_gr) > 1.5 &
      (gr * f1_gr) < 0 & !is.na(avg3) & avg3 >= 20
    data[[v]] <- dplyr::if_else(jump, NA_real_, data[[v]])
    if (v == "turnover_nat") {
      data$turnover <- dplyr::if_else(jump, NA_real_, data$turnover)
    }
  }

  # --- Step 11: entry (first appearance) and exit (last appearance) ----------
  data <- data %>%
    dplyr::group_by(.data$idf) %>%
    dplyr::mutate(.max_y = max(.data$year), .min_y = min(.data$year)) %>%
    dplyr::ungroup()

  age_cat_supplied <- has_column(data, "age_cat")
  # Fix S8: with both age_cat and birth_year supplied, Stata took branch A and
  # crashed (`gen birth_year` on an existing variable). Now birth_year wins
  # (exact age, entry and L3age); the supplied age_cat is kept as the age category.
  birth_year_supplied <- has_column(data, "birth_year") && any(!is.na(data$birth_year))
  if (age_cat_supplied && !birth_year_supplied) {
    # Branch A: age_cat supplied directly in the raw data.
    # stata_num(): a missing age_cat must compare FALSE to 0, not propagate NA (see stata_num()).
    data$entry <- as.integer(data$year == data$.min_y & data$year > ymin & stata_num(data$age_cat) == 0)
    birth_year_at_entry <- dplyr::if_else(data$entry == 1, data$year, NA_real_)
    data$birth_year <- stats::ave(birth_year_at_entry, data$idf, FUN = function(v) mean(v, na.rm = TRUE))
    data$birth_year[is.nan(data$birth_year)] <- NA_real_
    data$entry <- dplyr::if_else(data$year == ymin, NA_real_, data$entry)
  } else {
    # Branch B: birth_year supplied directly in the raw data (required here).
    if (!has_column(data, "birth_year")) {
      rlang::abort(
        "Either `age_cat` or `birth_year` must be present in the raw data.",
        class = "OECDscaleup_data_error"
      )
    }
    data$birth_year <- suppressWarnings(stats::ave(data$birth_year, data$idf, FUN = function(v) min(v, na.rm = TRUE)))
    data$birth_year[is.infinite(data$birth_year)] <- NA_real_
    if (!has_column(data, "age")) {
      data$age <- data$year - data$birth_year
    }
    data$age <- dplyr::if_else(data$age < 0, NA_real_, data$age)
    data$L3age <- panel_lag(data$age, 3, data$idf, data$year)

    data$entry <- as.integer(
      stata_num(data$year) == stata_num(data$birth_year) |
        (stata_num(data$age) < 2 & data$year == data$.min_y & data$year > ymin)
    )
    data <- data %>%
      dplyr::group_by(.data$idf) %>%
      dplyr::arrange(.data$year, .by_group = TRUE) %>%
      dplyr::mutate(
        .cumsum_entry = cumsum(.data$entry),
        entry = dplyr::if_else(.data$.cumsum_entry > 1, 0L, .data$entry)
      ) %>%
      dplyr::mutate(entry_tot = sum(.data$entry)) %>%
      dplyr::ungroup()
    data <- dplyr::filter(data, !(.data$.cumsum_entry == 0 & .data$entry_tot >= 1))
    data$.cumsum_entry <- NULL
    data$entry_tot <- NULL
    data$entry <- dplyr::if_else(is.na(data$birth_year) & data$.min_y == ymin, NA_real_, data$entry)
  }

  if (!has_column(data, "birth_year")) {
    birth_year_at_entry <- dplyr::if_else(data$entry == 1, data$year, NA_real_)
    data$birth_year <- stats::ave(birth_year_at_entry, data$idf, FUN = function(v) mean(v, na.rm = TRUE))
    data$birth_year[is.nan(data$birth_year)] <- NA_real_
  }
  data$birth_year <- dplyr::if_else(data$birth_year > ymax, NA_real_, data$birth_year)

  if (!has_column(data, "exit")) {
    data$exit <- as.integer(data$year == data$.max_y & data$year < ymax)
    data$exit <- dplyr::if_else(data$year == ymax, NA_real_, data$exit)
  }
  data$.max_y <- NULL
  data$.min_y <- NULL

  # --- Step 12: growth rates and HGF flags ------------------------------------
  for (spec in list(
    list(lab = "employment", var = "employment"),
    list(lab = "turnover", var = turnover_type)
  )) {
    lab <- spec$lab
    v <- spec$var
    l3v <- panel_lag(data[[v]], 3, data$idf, data$year)
    l1v <- panel_lag(data[[v]], 1, data$idf, data$year)
    f1v <- panel_lead(data[[v]], 1, data$idf, data$year)
    l3emp <- panel_lag(data$employment, 3, data$idf, data$year)

    # gen (float), then blank values above the p99 of the stored float values
    growth3y <- winsorize_upper(stata_float(data[[v]] / l3v - 1))
    growth1y <- winsorize_upper(stata_float(data[[v]] / l1v - 1))
    futgrowth <- winsorize_upper(stata_float(f1v / data[[v]] - 1))
    data[[paste0(lab, "_growth3y")]] <- growth3y
    data[[paste0(lab, "_growth1y")]] <- growth1y
    data[[paste0(lab, "_futgrowth")]] <- futgrowth

    # in-expression ratio (double); x/0 is missing, so l3.var == 0 never qualifies
    ratio3y <- stata_double(data[[v]] / l3v)
    eligible <- !is.na(ratio3y) & !is.na(l3emp) & l3emp >= 10
    # fix S9: micro = employers with fewer than 10 employees at t-3 (Stata: 1 <= l3emp < 10)
    eligible_micro <- !is.na(ratio3y) & !is.na(l3emp) & l3emp > 0 & l3emp < 10
    cagr <- stata_pow(ratio3y, 1 / 3) - 1 # Stata's ^ (see stata_pow())
    hg20 <- as.integer(eligible & cagr > 0.2)
    hg10 <- as.integer(eligible & cagr > 0.1)
    mhg20 <- as.integer(eligible_micro & cagr > 0.2)
    # the pool does not involve the ratio: var and l3.var non-missing, l3.employment >= 10
    pool <- as.integer(!is.na(data[[v]]) & !is.na(l3v) & !is.na(l3emp) & l3emp >= 10)
    missing_mask <- is.na(data[[v]]) | is.na(l3v)
    hg20[missing_mask] <- NA
    hg10[missing_mask] <- NA
    mhg20[missing_mask] <- NA
    pool[missing_mask] <- NA

    data[[paste0("HG_", lab, "20")]] <- hg20
    data[[paste0("HG_", lab, "10")]] <- hg10
    data[[paste0("MHG_", lab, "20")]] <- mhg20
    data[[paste0("HG_", lab, "_pool")]] <- pool
  }
  data$turnover_nat <- NULL

  # --- Step 13: rename and combine HGF flags ----------------------------------
  names(data) <- gsub("HG_employment", "HGE", names(data), fixed = TRUE)
  names(data) <- gsub("HG_turnover", "HGT", names(data), fixed = TRUE)
  for (i in c("10", "20")) {
    e <- data[[paste0("HGE", i)]]
    t <- data[[paste0("HGT", i)]]
    b <- as.integer(e == 1 & t == 1)
    b[is.na(e) | is.na(t)] <- NA
    data[[paste0("HGB", i)]] <- b
  }
  # stata_num(): HGE/HGT can be missing; Stata's `==1` on a missing flag is FALSE, not NA (see stata_num()).
  data$HGET20 <- as.integer(stata_num(data$HGE20) == 1 | stata_num(data$HGT20) == 1)
  data$HGET10 <- as.integer(stata_num(data$HGE10) == 1 | stata_num(data$HGT10) == 1)
  data$HGET_pool <- as.integer(stata_num(data$HGE_pool) == 1 | stata_num(data$HGT_pool) == 1)
  emp_missing <- is.na(data$employment) | is.na(panel_lag(data$employment, 3, data$idf, data$year))
  data$HGET10[emp_missing] <- NA
  data$HGET20[emp_missing] <- NA

  # --- Step 14: age and size categories ---------------------------------------
  if (!has_column(data, "age_cat")) {
    data$age_cat <- cut_stata(data$age, at = c(0, 6, 11, 9999))
  }
  data$size_cat <- cut_stata(data$employment, at = c(0, 10, 20, 50, 100, 250, 999999))
  data$size_age <- dplyr::case_when(
    data$size_cat %in% c(10, 20) & data$age_cat %in% c(0, 6) ~ "small_young",
    data$size_cat %in% c(10, 20) & data$age_cat == 11 ~ "small_old",
    TRUE ~ NA_character_
  )

  # --- Step 15: technology/sector grouping (tech_grad) ------------------------
  # stata_replace(): sequential overwrite rules, in this exact order (a later
  # rule wins on overlap) - a bare if_else here would wrongly null out an
  # earlier rule's assignment whenever a later rule's condition involves a
  # missing sector_2d/sector_3d (see stata_replace()'s docs).
  data$tech_grad <- NA_real_
  s2 <- data$sector_2d
  s3 <- data$sector_3d
  data$tech_grad <- stata_replace(data$tech_grad, s2 %in% c(20, 21) | (s2 > 25 & s2 < 31), 1)
  data$tech_grad <- stata_replace(
    data$tech_grad,
    (s2 > 4 & s2 < 10) | (s2 > 9 & s2 < 20) | (s2 > 21 & s2 < 26) | (s2 > 30 & s2 < 34), 2
  )
  # Fix S15 (decided 2026-11-20): Stata left 58-60 (except 582), 63, 77, 90-94
  # and 96 without a group. Now 58-63 are Advanced services, 77 Other services
  # tradable, 90-94 and 96 Other services non-tradable. 01-03, 64-66 and 84 stay
  # unclassified, as in Stata (likely deliberate).
  data$tech_grad <- stata_replace(data$tech_grad, s3 == 582 | (s2 >= 58 & s2 <= 63) | (s2 >= 69 & s2 <= 74), 3)
  data$tech_grad <- stata_replace(
    data$tech_grad,
    (s2 >= 49 & s2 < 54) | (s2 > 54 & s2 < 57) | s2 == 75 | s2 == 77 | (s2 >= 78 & s2 <= 82), 4
  )
  data$tech_grad <- stata_replace(data$tech_grad, s2 >= 85 & s2 <= 88, 5)
  data$tech_grad <- stata_replace(data$tech_grad, s2 >= 41 & s2 <= 43, 6)
  data$tech_grad <- stata_replace(
    data$tech_grad,
    (s2 > 44 & s2 < 48) | s2 == 68 | s2 == 95 | (s2 >= 35 & s2 <= 39) | (s2 >= 90 & s2 <= 94) | s2 == 96, 7
  )

  # --- Step 16: OECD STAN a38 industry grouping (ind_a38) ---------------------
  # Kept as a plain string throughout (no numeric code needed - see labels.R).
  # Fix S2: the Stata list also contained the aggregate "D68T82", assigned after
  # D69T71/D72/D73T75, so divisions 69-75 all ended up in "D68T82". It is not an
  # A38 group and is dropped; the remaining ranges do not overlap.
  stan_a38_codes <- c(
    "D26", "D72", "D21", "D27", "D13T15", "D85", "D28", "D05T09", "D20", "D36T39",
    "D19", "D29T30", "D84", "D62T63", "D61", "D69T71", "D16T18", "D58T60", "D22T23",
    "D24T25", "D10T12", "D73T75", "D31T33", "D94T96", "D55T56", "D90T93",
    "D35", "D41T43", "D45T47", "D77T82", "D86", "D49T53", "D87T88", "D01T03", "D68",
    "D64T66", "D97T98"
  )
  data$ind_a38 <- NA_character_
  for (code in stan_a38_codes) {
    if (nchar(code) == 3) {
      digits <- substr(code, 2, 3)
      data$ind_a38 <- stata_replace(data$ind_a38, !is.na(s2) & sprintf("%02d", s2) == digits, code)
    } else {
      start <- as.numeric(substr(code, 2, 3))
      end <- as.numeric(substr(code, 5, 6))
      data$ind_a38 <- stata_replace(data$ind_a38, !is.na(s2) & s2 >= start & s2 <= end, code)
    }
  }

  # --- Step 17: region aggregation for small TL2 regions, then region x tech --
  if (config$country %in% country_patches$aggregate_small_regions) {
    data <- dplyr::left_join(data, small_region_map(data), by = "region_2d")
  } else {
    data$region_adj <- data$region_2d
  }
  tech_grad_str <- decode_category(data$tech_grad, "tech_grad")
  # Fix S17: a missing region (empty, "." or NA) gives a missing pair. Stata
  # (`if region_adj != "." & tech_grad_str != ""`) excluded only the literal ".",
  # so an empty region formed a pseudo-region "_<sector group>".
  region_known <- !is.na(data$region_adj) & !data$region_adj %in% c("", ".")
  data$reg_techgrad <- dplyr::if_else(
    region_known & !is.na(tech_grad_str),
    paste0(data$region_adj, "_", tech_grad_str), NA_character_
  )
  data$region_adj <- NULL
  # `replace region_2d = "" if region_2d == "."` then `encode`
  data$region_2d[data$region_2d %in% c(".", "")] <- NA_character_

  # --- Step 18: TL3 urbanisation typology --------------------------------------
  if (has_column(data, "region_3d")) {
    if (is.null(tl3_typology)) {
      rlang::abort(
        "`tl3_typology` is required because `region_3d` is present but was not supplied.",
        class = "OECDscaleup_data_error"
      )
    }
    typ <- tl3_typology %>% dplyr::select("region_3d", "typology_access_cities")
    data <- dplyr::left_join(data, typ, by = "region_3d")
    # Fix S7: only the five documented groups exist; any other value (the ".."
    # of regions without a typology) is missing. Stata kept ".." as a category.
    data$typology_UR <- dplyr::case_when(
      data$typology_access_cities == "MR-L" ~ "Large metropolitan region",
      data$typology_access_cities == "MR-M" ~ "Metropolitan region",
      data$typology_access_cities == "NMR-M" ~ "Region near a metropolitan area",
      data$typology_access_cities == "NMR-S" ~ "Region with/near a small-medium city",
      data$typology_access_cities == "NMR-R" ~ "Remote region",
      TRUE ~ NA_character_
    )
    data$typology_access_cities <- NULL
    if (!has_column(data, "typology_UR")) {
      data$typology_UR <- NULL
    } else {
      data$L3typology_UR <- panel_lag(data$typology_UR, 3, data$idf, data$year)
    }
  }

  # --- Step 19: foreign ownership -----------------------------------------------
  if (has_column(data, "uco")) {
    data$foreign_owned <- as.integer(!data$uco %in% c("", ".", config$country) & !is.na(data$uco))
    data$foreign_owned[is.na(data$uco) | data$uco %in% c("", ".")] <- NA
  }

  # --- Step 20: labour productivity ---------------------------------------------
  for (v in intersect(c("added_value", "turnover"), names(data))) {
    log_var <- stata_float(log(data[[v]] / data$employment)) # ln(0) and x/0 are missing
    bounds <- stats::quantile(log_var, probs = c(0.01, 0.99), na.rm = TRUE, type = 2)
    log_var <- dplyr::if_else(!is.na(log_var) & (log_var < bounds[[1]] | log_var > bounds[[2]]),
      NA_real_, log_var
    )
    data[[paste0("log_", v, "_emp")]] <- log_var
    data[[paste0("L3log_", v, "_emp")]] <- panel_lag(log_var, 3, data$idf, data$year)
    data[[paste0("S3log_", v, "_emp")]] <- stata_float(panel_sdiff(log_var, 3, data$idf, data$year))
  }
  # `cap rename log_added_value_emp labour_prod` (and its L3); S3log_added_value_emp keeps its name
  names(data)[names(data) == "log_added_value_emp"] <- "labour_prod"
  names(data)[names(data) == "L3log_added_value_emp"] <- "L3labour_prod"
  for (v in c("employment", "turnover")) {
    data[[paste0("L3", v)]] <- stata_float(panel_lag(data[[v]], 3, data$idf, data$year))
    data[[paste0("S3", v)]] <- stata_float(panel_sdiff(data[[v]], 3, data$idf, data$year))
  }

  # --- Step 21: labour share, average wage, capital intensity --------------------
  # Labour share is labour costs over turnover, not value added: a documented
  # choice of the original package (S12), also used for the MFP weights below.
  if (has_column(data, "labour_costs")) {
    data$labour_share <- stata_float(data$labour_costs / data$turnover)
    data$avg_wage <- stata_float(data$labour_costs / data$employment)
    data$L3labour_share <- panel_lag(data$labour_share, 3, data$idf, data$year)
    data$L3avg_wage <- panel_lag(data$avg_wage, 3, data$idf, data$year)
  }
  if (has_column(data, "tangible_fixed_assets")) {
    data$phys_assets <- stata_float(data$tangible_fixed_assets / data$turnover)
    data$L3phys_assets <- panel_lag(data$phys_assets, 3, data$idf, data$year)
  }

  # --- Step 22: multi-factor productivity (Solow residual) ------------------------
  # Each intermediate is a separate float `gen` in Stata and stays in the dataset.
  if (has_column(data, "added_value") && has_column(data, "tangible_fixed_assets") &&
    has_column(data, "labour_share")) {
    data$va <- stata_float(log(data$added_value))
    data$sl <- stata_float(1 - data$labour_share)
    data$k <- stata_float(log(data$tangible_fixed_assets))
    data$slk <- stata_float(data$sl * data$k)
    data$l <- stata_float(log(data$employment))
    data$sll <- stata_float(data$labour_share * data$l)
    # S12: Stata then floored negative MFP at the smallest non-negative value;
    # exp() is never negative, so that step never applied and is dropped.
    data$MFP <- stata_float(exp(data$va - data$slk - data$sll))
    data$L3MFP <- panel_lag(data$MFP, 3, data$idf, data$year)
    data$MFP_gr <- stata_float((data$MFP - data$L3MFP) / data$L3MFP)
  }

  # --- Step 23: acquisition indicator -----------------------------------------------
  d1emp <- stata_float(panel_diff1(data$employment, data$idf, data$year))
  sharegr1 <- stata_float(d1emp / data$S3employment)
  sharegr2 <- stata_float(panel_lag(d1emp, 1, data$idf, data$year) / data$S3employment)
  sharegr3 <- stata_float(panel_lag(d1emp, 2, data$idf, data$year) / data$S3employment)
  acquisition <- as.integer(
    (!is.na(sharegr1) & sharegr1 > 0.8) | (!is.na(sharegr2) & sharegr2 > 0.8) |
      (!is.na(sharegr3) & sharegr3 > 0.8)
  ) * as.integer(!is.na(data$S3employment) & data$S3employment > 10)
  acquisition[is.na(data$S3employment) | is.na(sharegr1) | is.na(sharegr2) | is.na(sharegr3)] <- NA
  data$acquisition <- acquisition

  # --- Step 25: lag a broad set of category/context variables 3 years --------------
  groups <- c(
    "year", "sector_1d", "sector_2d", "sector_3d", "tech_grad", "age_cat", "size_cat",
    "region_2d", "multiplant", "independent", "foreign_owned", "reg_techgrad", "ind_a38",
    "size_age"
  )
  for (gr in intersect(groups, names(data))) {
    data[[paste0("L3", gr)]] <- panel_lag(data[[gr]], 3, data$idf, data$year)
  }
  data$L3young <- as.integer(data$L3age_cat == 0)
  data$L3young[is.na(data$L3age_cat)] <- NA

  # --- Step 26: drop always-missing columns -----------------------------------------
  keep_always <- c("year", "idf")
  for (v in setdiff(names(data), keep_always)) {
    if (sum(!is.na(data[[v]])) == 0) {
      data[[v]] <- NULL
    }
  }

  # Code tables Stata's `encode` assigned (sector_1d was fixed before the year
  # trimming; no rows are dropped after the other encodes). Used to write the
  # .dta exactly as Stata does and for Stata-style regression term names.
  for (v in c("size_age", "ind_a38", "reg_techgrad", "region_2d")) {
    if (v %in% names(data)) encode_levels[[v]] <- stata_encode_levels(data[[v]])
  }
  if ("typology_UR" %in% names(data)) {
    # the merge brings tl3_typology.dta's own `typology_UR` value label, which encode extends
    existing <- if (!is.null(tl3_typology)) attr(tl3_typology$typology_UR, "labels") else NULL
    if (!is.null(existing)) existing <- stats::setNames(as.double(existing), names(existing))
    encode_levels$typology_UR <- stata_encode_levels(data$typology_UR, existing)
  }
  out <- dplyr::as_tibble(data)
  attr(out, "stata_encode_levels") <- encode_levels
  # A user-supplied age_cat keeps the value label it arrived with (none if it
  # had none): Stata only defines `agelab` when it builds age_cat itself.
  if (age_cat_supplied) attr(out, "age_cat_labels") <- list(attr(base_financials$age_cat, "labels"))
  out
}

#' Which TL2 regions are merged into their TL1 region (small-region aggregation)
#'
#' A TL2 region is "small" when it averages fewer than 100 HGET10 firms a year.
#' All TL2 regions of a TL1 are merged into the TL1 when the small ones hold
#' more than half of the TL1's HGET10 firms.
#'
#' Fix S3: in Stata a TL1 without any small TL2 had a missing share, which
#' compares as +infinity, so large regions were merged too. Now such a TL1 has
#' share 0 (not merged); a TL1 whose regions are all small but have no HGET10
#' firm at all (0/0) has share 1 (merged), as in Stata.
#'
#' @param data Panel with `region_2d`, `year` and `HGET10`.
#' @return Data frame with `region_2d` and `region_adj` (TL1 code or `region_2d`).
#' @noRd
small_region_map <- function(data) {
  region_avg <- data %>%
    dplyr::group_by(.data$region_2d, .data$year) %>%
    dplyr::summarise(HGET10 = sum(.data$HGET10, na.rm = TRUE), .groups = "drop") %>%
    dplyr::group_by(.data$region_2d) %>%
    dplyr::summarise(HGET10 = mean(.data$HGET10, na.rm = TRUE), .groups = "drop") %>%
    dplyr::mutate(region_1d = substr(.data$region_2d, 1, 3), small = .data$HGET10 < 100)
  shares <- region_avg %>%
    dplyr::group_by(.data$region_1d) %>%
    dplyr::summarise(
      n_total = sum(.data$HGET10, na.rm = TRUE),
      n_small = sum(.data$HGET10[.data$small], na.rm = TRUE),
      any_small = any(.data$small),
      .groups = "drop"
    ) %>%
    dplyr::mutate(share_small = dplyr::case_when(
      !.data$any_small ~ 0,
      .data$n_total == 0 ~ 1,
      TRUE ~ .data$n_small / .data$n_total
    ))
  region_avg %>%
    dplyr::left_join(shares, by = "region_1d") %>%
    dplyr::mutate(region_adj = dplyr::if_else(.data$share_small > 0.5, .data$region_1d, .data$region_2d)) %>%
    dplyr::select("region_2d", "region_adj")
}

#' Convert accounts_indicators to Stata's storage (labelled numeric categories)
#'
#' Categories that Stata `encode`s become numeric codes in byte sort order;
#' categories with a `label define` keep their codes and gain the labels; the
#' `L3` copies share their base variable's codes and labels.
#'
#' @param data Output of [build_accounts_indicators()].
#' @return `data` with category columns as `haven_labelled` doubles.
#' @noRd
as_stata_accounts <- function(data) {
  levels <- attr(data, "stata_encode_levels")
  for (v in c("sector_1d", "size_age", "ind_a38", "reg_techgrad", "region_2d", "typology_UR")) {
    if (!v %in% names(data)) next
    lv <- levels[[v]]
    if (is.null(lv)) lv <- stata_encode_levels(data[[v]])
    for (col in intersect(c(v, paste0("L3", v)), names(data))) data[[col]] <- stata_encode(data[[col]], lv)
  }
  user_age <- attr(data, "age_cat_labels")
  for (v in c("age_cat", "size_cat", "tech_grad", "multiplant", "independent", "foreign_owned")) {
    map <- value_labels[[v]]
    labs <- stats::setNames(as.double(names(map)), unname(map))
    if (v == "age_cat" && !is.null(user_age)) labs <- user_age[[1]]
    for (col in intersect(c(v, paste0("L3", v)), names(data))) {
      x <- as.double(haven::zap_labels(data[[col]]))
      data[[col]] <- if (is.null(labs)) x else haven::labelled(x, labels = labs)
    }
  }
  data
}
