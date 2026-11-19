#' @keywords internal
persistence_hg_combinations <- function() {
  list(
    list(hgstub = "HGE", def = "10"), list(hgstub = "HGE", def = "20"),
    list(hgstub = "HGT", def = "10"), list(hgstub = "HGT", def = "20"),
    list(hgstub = "HGET", def = "10"), list(hgstub = "HGET", def = "20"),
    list(hgstub = "MHGE", def = "20"),
    list(hgstub = "MHGT", def = "20")
  )
}

#' @keywords internal
persistence_hg_spec <- function(hgstub, def) {
  hg <- paste0(hgstub, def)
  if (hgstub %in% c("HGE", "HGET", "MHGE")) {
    lab <- "employment"
    othlab <- "turnover"
  } else {
    lab <- "turnover"
    othlab <- "employment"
  }
  othhg <- switch(hgstub,
    HGE = paste0("HGT", def), HGET = paste0("HGT", def), MHGE = paste0("MHGT", def),
    HGT = paste0("HGE", def), MHGT = paste0("MHGE", def)
  )
  list(
    hg = hg, lab = lab, othlab = othlab, othhg = othhg,
    grvar3y = paste0(lab, "_growth3y"), othgrvar3y = paste0(othlab, "_growth3y"),
    grvar1y = paste0(lab, "_growth1y"), othgrvar1y = paste0(othlab, "_growth1y")
  )
}

#' @keywords internal
persistence_category_groups <- function() {
  c(
    "ALL", "L3size_cat", "L3age_cat", "L3tech_grad", "L3region_2d", "L3typology_UR",
    "L3independent", "L3foreign_owned", "L3multiplant"
  )
}

#' 6-tier FOLLOW/LEAD classification (Stata's sequential-overwrite rules)
#' @keywords internal
classify_scaling_var <- function(f_hg, f_grvar3y, f_rev) {
  x <- rep(NA_real_, length(f_hg))
  x <- stata_replace(x, stata_num(f_hg) == 1, 6)
  x <- stata_replace(x, !is.na(f_grvar3y) & f_grvar3y > 0.10 & stata_num(f_hg) == 0, 5)
  x <- stata_replace(x, stata_num(f_grvar3y) >= -0.10 & stata_num(f_grvar3y) <= 0.10, 4)
  x <- stata_replace(x, stata_num(f_grvar3y) < -0.10 & stata_num(f_rev) == 0, 3)
  x <- stata_replace(x, stata_num(f_rev) == 1, 2)
  x <- stata_replace(x, is.na(f_grvar3y), 1)
  x
}

#' 5-tier FOLLOW_othvar/LEAD_othvar-without-birth_year classification (no "reversal" tier)
#' @keywords internal
classify_other_var <- function(f_othhg, f_othgrvar3y) {
  x <- rep(NA_real_, length(f_othhg))
  x <- stata_replace(x, stata_num(f_othhg) == 1, 6)
  x <- stata_replace(x, !is.na(f_othgrvar3y) & f_othgrvar3y > 0.10 & stata_num(f_othhg) == 0, 5)
  x <- stata_replace(x, stata_num(f_othgrvar3y) >= -0.10 & stata_num(f_othgrvar3y) <= 0.10, 4)
  x <- stata_replace(x, stata_num(f_othgrvar3y) < -0.10, 3)
  x <- stata_replace(x, is.na(f_othgrvar3y), 1)
  x
}

#' 6-tier LEAD/LEAD_othvar classification (birth_year-based "Entry" tier, used pre-scaling only)
#' @keywords internal
classify_pre_scaling_var <- function(l_hg, l_grvar3y, birth_year) {
  x <- rep(NA_real_, length(l_hg))
  x <- stata_replace(x, stata_num(l_hg) == 1, 6)
  x <- stata_replace(x, !is.na(l_grvar3y) & l_grvar3y > 0.10 & stata_num(l_hg) == 0, 5)
  x <- stata_replace(x, stata_num(l_grvar3y) >= -0.10 & stata_num(l_grvar3y) <= 0.10, 4)
  x <- stata_replace(x, stata_num(l_grvar3y) < -0.10, 3)
  x <- stata_replace(x, !is.na(birth_year) & birth_year > 2011, 2)
  x <- stata_replace(x, is.na(l_grvar3y) & stata_num(birth_year) <= 2011, 1)
  x
}

#' @keywords internal
persistence_exit_acq_f3 <- function(data) {
  if (!has_column(data, "exit_acq")) {
    return(NULL)
  }
  f1 <- panel_lead(data$exit_acq, 1, data$idf, data$year)
  f2 <- panel_lead(data$exit_acq, 2, data$idf, data$year)
  as.integer(stata_num(data$exit_acq) == 1 | stata_num(f1) == 1 | stata_num(f2) == 1)
}

#' @keywords internal
collapse_by_group_year <- function(data, follow_col, group, hg, config) {
  vars <- intersect(
    c(hg, "L3employment", "employment", "F3employment", "L3turnover", "turnover", "F3turnover"),
    names(data)
  )
  grp <- data %>% dplyr::group_by(dplyr::across(dplyr::all_of(c(follow_col, group, "year"))))
  cell <- grp %>%
    dplyr::summarise(dplyr::across(dplyr::all_of(vars), ~ sum(.x, na.rm = TRUE)), .groups = "drop")
  if (isTRUE(config$dominance)) {
    dom <- grp %>%
      dplyr::summarise(
        dplyr::across(dplyr::all_of(config$dom_vars), ~ dominance_share(.x, config$dom_num), .names = "dom_{.col}"),
        .groups = "drop"
      )
    cell <- dplyr::left_join(cell, dom, by = c(follow_col, group, "year"))
  }
  cell <- cell[!is.na(cell[[group]]), ]
  if (nrow(cell) == 0) {
    return(NULL)
  }
  cell$category <- group
  cell$group_label <- decode_category(cell[[group]], group)
  cell[[group]] <- NULL
  names(cell)[names(cell) == hg] <- "N_scalers"
  cell
}

#' Growth trajectories before/after a scaling event ("transitions" and "evolutions")
#'
#' Translates `n1_3_persistence.do` (`Pseudocode/n1_3_persistence.md`). Computes
#' two related classification schemes: **transitions** (2014-2016 scaler
#' cohorts, follow-up only) and **evolutions** (2017 cohort, both lead-up and
#' follow-up, further split by entrant/incumbent/exiting status). Iterates
#' over 8 `(hgstub, def)` HGF-definition combinations, each starting fresh
#' from `accounts_indicators` — nothing computed for one combination carries
#' into the next.
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param accounts_indicators The output of [build_accounts_indicators()].
#' @return A named list with up to 3 elements — `transitions`,
#'   `evolutions_p1`, `evolutions_p2` — each a data frame matching PDF Table
#'   3.4, or absent from the list if this country's panel was too short to
#'   satisfy any `(hgstub, def)` combination's length requirement for that
#'   output (mirrors the source: a short panel may produce none of the 3
#'   CSVs).
#' @export
compute_persistence <- function(config, accounts_indicators) {
  list(
    transitions = compute_transitions(config, accounts_indicators),
    evolutions = compute_evolutions(config, accounts_indicators)
  ) -> parts

  out <- list()
  if (!is.null(parts$transitions)) out$transitions <- parts$transitions
  if (!is.null(parts$evolutions$evolutions_p1)) out$evolutions_p1 <- parts$evolutions$evolutions_p1
  if (!is.null(parts$evolutions$evolutions_p2)) out$evolutions_p2 <- parts$evolutions$evolutions_p2
  out
}

#' @keywords internal
compute_transitions <- function(config, accounts_indicators) {
  groups <- persistence_category_groups()
  accumulator <- list()

  for (combo in persistence_hg_combinations()) {
    data <- accounts_indicators # fresh, unmodified copy every iteration
    spec <- persistence_hg_spec(combo$hgstub, combo$def)

    finyear <- max(data$year)
    inityear <- min(data$year)
    if (!(finyear - inityear >= 6 && inityear <= 2013 && finyear >= 2017)) next

    for (v in c("employment", "turnover", "idf", spec$hg, spec$othhg)) {
      data[[paste0("F3", v)]] <- stata_float(panel_lead(data[[v]], 3, data$idf, data$year)) # gen (float)
    }
    f3grvar3y <- panel_lead(data[[spec$grvar3y]], 3, data$idf, data$year)
    f3othgrvar3y <- panel_lead(data[[spec$othgrvar3y]], 3, data$idf, data$year)

    f3_exit_acq <- persistence_exit_acq_f3(data)

    l6lab <- panel_lag(data[[spec$lab]], 6, data$idf, data$year)
    rev <- as.integer(data[[spec$lab]] <= l6lab)
    rev[is.na(data[[spec$lab]]) | is.na(l6lab)] <- NA
    f3rev <- panel_lead(rev, 3, data$idf, data$year)

    data$ALL <- 1L
    keep <- first_occurrence_flag(data$idf, data$year, data[[spec$hg]]) == 1 &
      data$year >= 2014 & data$year <= 2016 &
      !is.na(data$L3employment) & data$L3employment >= 1 & data$L3employment <= 249
    data <- data[keep, ]
    if (nrow(data) == 0) next
    f3grvar3y <- f3grvar3y[keep]
    f3othgrvar3y <- f3othgrvar3y[keep]
    f3rev <- f3rev[keep]
    if (!is.null(f3_exit_acq)) f3_exit_acq <- f3_exit_acq[keep]

    data$FOLLOW <- classify_scaling_var(data[[paste0("F3", spec$hg)]], f3grvar3y, f3rev)
    data$FOLLOW_othvar <- classify_other_var(data[[paste0("F3", spec$othhg)]], f3othgrvar3y)
    if (!is.null(f3_exit_acq)) {
      data$FOLLOW <- ifelse(stata_num(f3_exit_acq) == 1, 0, data$FOLLOW)
      data$FOLLOW_othvar <- ifelse(stata_num(f3_exit_acq) == 1, 0, data$FOLLOW_othvar)
    }

    for (group in intersect(groups, names(data))) {
      own <- collapse_by_group_year(data, "FOLLOW", group, spec$hg, config)
      if (!is.null(own)) {
        own$hg <- spec$hg
        own$var <- spec$lab
        accumulator[[length(accumulator) + 1]] <- own
      }
      oth <- collapse_by_group_year(data, "FOLLOW_othvar", group, spec$hg, config)
      if (!is.null(oth)) {
        oth$hg <- spec$hg
        oth$var <- spec$othlab
        accumulator[[length(accumulator) + 1]] <- oth
      }
    }
  }

  if (length(accumulator) == 0) {
    return(NULL)
  }
  out <- dplyr::bind_rows(accumulator)
  names(out)[names(out) == "group_label"] <- "group"
  out$FOLLOW <- export_label(out$FOLLOW, output_labels$follow_transitions)
  out$FOLLOW_othvar <- export_label(out$FOLLOW_othvar, output_labels$follow_oth_transitions)
  front <- c("category", "group", "hg", "var")
  follow_cols <- intersect(c("FOLLOW", "FOLLOW_othvar"), names(out))
  rest <- setdiff(names(out), c(front, follow_cols, "year"))
  out[c("year", follow_cols, front, rest)]
}

#' @keywords internal
collapse_evolution_cell <- function(data, by_cols, hg, config, suppress = FALSE) {
  if (suppress) {
    n_hg <- data %>%
      dplyr::group_by(dplyr::across(dplyr::all_of(by_cols))) %>%
      dplyr::transmute(.n_hg = sum(.data[[hg]], na.rm = TRUE)) %>%
      dplyr::pull(".n_hg")
    for (col in c("LEAD", "LEAD_othvar", "FOLLOW", "FOLLOW_othvar")) {
      data[[col]] <- ifelse(n_hg <= 5, 9, data[[col]])
    }
  }

  vars <- intersect(
    c(
      "L6employment", "L3employment", "employment", "F3employment",
      "L6turnover", "L3turnover", "turnover", "F3turnover", hg
    ),
    names(data)
  )
  grp <- data %>% dplyr::group_by(dplyr::across(dplyr::all_of(by_cols)))
  cell <- grp %>%
    dplyr::summarise(
      dplyr::across(dplyr::all_of(vars), ~ sum(.x, na.rm = TRUE)),
      nb_years_grow = mean(.data$nb_years_grow, na.rm = TRUE),
      .groups = "drop"
    )
  if (isTRUE(config$dominance)) {
    dom <- grp %>%
      dplyr::summarise(
        dplyr::across(dplyr::all_of(config$dom_vars), ~ dominance_share(.x, config$dom_num), .names = "dom_{.col}"),
        .groups = "drop"
      )
    cell <- dplyr::left_join(cell, dom, by = by_cols)
  }
  group_col <- setdiff(by_cols, c("LEAD", "LEAD_othvar", "FOLLOW", "FOLLOW_othvar", "entrant", "incumbent", "exiting"))
  cell <- cell[!is.na(cell[[group_col]]), ]
  if (nrow(cell) == 0) {
    return(NULL)
  }
  cell$category <- group_col
  cell$group_label <- decode_category(cell[[group_col]], group_col)
  cell[[group_col]] <- NULL
  names(cell)[names(cell) == hg] <- "N_scalers"
  cell
}

#' @keywords internal
compute_evolutions <- function(config, accounts_indicators) {
  groups <- persistence_category_groups()
  acc_p1 <- list()
  acc_p2 <- list()

  for (combo in persistence_hg_combinations()) {
    data <- accounts_indicators # fresh, unmodified copy every iteration
    spec <- persistence_hg_spec(combo$hgstub, combo$def)

    finyear <- max(data$year)
    inityear <- min(data$year)
    if (!(finyear - inityear >= 9 && finyear >= 2020)) next

    keep_tmp <- as.integer(stata_num(data[[spec$hg]]) == 1 & data$year == 2017)
    keep <- stats::ave(keep_tmp, data$idf, FUN = max)
    data <- data[keep == 1, ]
    if (nrow(data) == 0) next

    # every copy is a float `gen` in Stata
    for (v in c("employment", "turnover", "idf", spec$hg, spec$othhg, spec$grvar3y, spec$othgrvar3y)) {
      data[[paste0("F3", v)]] <- stata_float(panel_lead(data[[v]], 3, data$idf, data$year))
    }
    for (v in c(spec$grvar3y, spec$othgrvar3y, spec$hg, spec$othhg)) {
      data[[paste0("L3", v)]] <- stata_float(panel_lag(data[[v]], 3, data$idf, data$year))
    }
    data[[paste0("L6", spec$lab)]] <- stata_float(panel_lag(data[[spec$lab]], 6, data$idf, data$year))
    data[[paste0("L6", spec$othlab)]] <- stata_float(panel_lag(data[[spec$othlab]], 6, data$idf, data$year))

    for (v in c("entry", "exit")) {
      v_year <- ifelse(stata_num(data[[v]]) == 1, data$year, NA_real_)
      data[[paste0(v, "_year")]] <- stats::ave(v_year, data$idf, FUN = function(x) mean(x, na.rm = TRUE))
      data[[paste0(v, "_year")]][is.nan(data[[paste0(v, "_year")]])] <- NA_real_
      # `replace <var>_year = . if <var> == .`
      data[[paste0(v, "_year")]][is.na(data[[v]])] <- NA_real_
    }

    l6idf <- panel_lag(data$idf, 6, data$idf, data$year)
    f3idf <- panel_lead(data$idf, 3, data$idf, data$year)
    data$incumbent <- as.integer(!is.na(l6idf) & !is.na(f3idf))
    data$entrant <- as.integer(is.na(l6idf) & !is.na(data$entry_year) & data$entry_year > 2011)
    data$exiting <- as.integer(is.na(f3idf) & stata_num(data$exit_year) < 2020)

    f3_exit_acq <- persistence_exit_acq_f3(data)

    pos_grvar1y <- as.integer(!is.na(data[[spec$grvar1y]]) & data[[spec$grvar1y]] > 0.10)
    data$nb_years_grow <- stats::ave(pos_grvar1y, data$idf, FUN = function(x) sum(x, na.rm = TRUE))

    keep2 <- data$year == 2017 & !is.na(data$L3employment) & data$L3employment >= 1 & data$L3employment <= 249
    data <- data[keep2, ]
    if (nrow(data) == 0) next
    if (!is.null(f3_exit_acq)) f3_exit_acq <- f3_exit_acq[keep2]

    f3lab <- data[[paste0("F3", spec$lab)]]
    l3lab <- data[[paste0("L3", spec$lab)]]
    f3rev <- as.integer(f3lab <= l3lab)
    f3rev[is.na(f3lab) | is.na(l3lab)] <- NA

    data$LEAD <- classify_pre_scaling_var(data[[paste0("L3", spec$hg)]], data[[paste0("L3", spec$grvar3y)]], data$birth_year)
    data$LEAD_othvar <- classify_pre_scaling_var(
      data[[paste0("L3", spec$othhg)]], data[[paste0("L3", spec$othgrvar3y)]], data$birth_year
    )
    data$FOLLOW <- classify_scaling_var(data[[paste0("F3", spec$hg)]], data[[paste0("F3", spec$grvar3y)]], f3rev)
    if (!is.null(f3_exit_acq)) {
      data$FOLLOW <- ifelse(stata_num(f3_exit_acq) == 1, 0, data$FOLLOW)
    }
    data$FOLLOW_othvar <- classify_other_var(data[[paste0("F3", spec$othhg)]], data[[paste0("F3", spec$othgrvar3y)]])
    # NB: FOLLOW_othvar gets no exit_acq override in evolutions - see Pseudocode/n1_3_persistence.md.

    data$ALL <- 1L

    for (group in intersect(groups, names(data))) {
      p1 <- collapse_evolution_cell(
        data, c("LEAD", "LEAD_othvar", "FOLLOW", "FOLLOW_othvar", group), spec$hg, config,
        suppress = TRUE
      )
      if (!is.null(p1)) {
        p1$hg <- spec$hg
        acc_p1[[length(acc_p1) + 1]] <- p1
      }
      p2 <- collapse_evolution_cell(data, c("entrant", "incumbent", "exiting", group), spec$hg, config, suppress = FALSE)
      if (!is.null(p2)) {
        p2$hg <- spec$hg
        acc_p2[[length(acc_p2) + 1]] <- p2
      }
    }
  }

  finalize <- function(accumulator, id_cols) {
    if (length(accumulator) == 0) {
      return(NULL)
    }
    out <- dplyr::bind_rows(accumulator)
    names(out)[names(out) == "group_label"] <- "group"
    names(out)[names(out) == "nb_years_grow"] <- "avgN_years_gr"
    if ("LEAD" %in% names(out)) {
      out$LEAD <- export_label(out$LEAD, output_labels$lead_evolutions)
      out$LEAD_othvar <- export_label(out$LEAD_othvar, output_labels$lead_evolutions)
      out$FOLLOW <- export_label(out$FOLLOW, output_labels$follow_evolutions)
      out$FOLLOW_othvar <- export_label(out$FOLLOW_othvar, output_labels$follow_oth_evolutions)
    }
    front <- c("category", "group", "hg", "N_scalers", "avgN_years_gr")
    rest <- setdiff(names(out), c(front, id_cols))
    out[c(id_cols, front, rest)]
  }

  list(
    evolutions_p1 = finalize(acc_p1, c("LEAD", "LEAD_othvar", "FOLLOW", "FOLLOW_othvar")),
    evolutions_p2 = finalize(acc_p2, c("entrant", "incumbent", "exiting"))
  )
}
