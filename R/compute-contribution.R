#' @keywords internal
contribution_categories <- function(data) {
  # "ALL" is unconditional (the procedure creates it itself); the rest are
  # optional raw-input-derived categories, included only if present.
  c("ALL", intersect(
    c(
      "L3age_cat", "L3tech_grad", "L3region_2d", "L3typology_UR",
      "L3reg_techgrad", "L3ind_a38", "L3size_age", "L3size_cat"
    ),
    names(data)
  ))
}

#' @keywords internal
contribution_cond <- function(data, sample) {
  switch(sample,
    ALL = data$ALL == 1,
    micro = !is.na(data$L3size_cat) & data$L3size_cat == 0,
    SMEs = !is.na(data$L3size_cat) & data$L3size_cat > 0 & data$L3size_cat < 250,
    entrants = stata_num(data$entry) == 1 | stata_num(data$L1entry) == 1 | stata_num(data$L2entry) == 1,
    exiting = stata_num(data$L1exit) == 1 | stata_num(data$L2exit) == 1 | stata_num(data$L3exit) == 1,
    stata_num(data[[sample]]) == 1 & stata_num(data$L3size_cat) < 250
  )
}

#' @keywords internal
contribution_dominance <- function(data, sample, group, config) {
  if (!isTRUE(config$dominance)) {
    return(NULL)
  }
  grp <- data %>% dplyr::group_by(dplyr::across(dplyr::all_of(c("year", group))))
  out <- NULL
  for (domvar in config$dom_vars) {
    domvar2 <- if (identical(sample, "exiting")) paste0("L3", domvar) else domvar
    if (!domvar2 %in% names(data)) next
    dom <- grp %>%
      dplyr::summarise(!!paste0("dom_", domvar2) := dominance_share(.data[[domvar2]], config$dom_num), .groups = "drop")
    out <- if (is.null(out)) dom else dplyr::left_join(out, dom, by = c("year", group))
  }
  out
}

#' Job/turnover creation-destruction accounting by firm sample
#'
#' Translates `n1_3_contribution.do` (`Pseudocode/n1_3_contribution.md`). For
#' 5 selected years and 16 firm samples, computes total employment/turnover
#' created vs. destroyed over the prior 3-year window, treating entrants as
#' creating their full current value and exits as destroying their full
#' 3-years-ago value.
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param accounts_indicators The output of [build_accounts_indicators()].
#' @return A named list with two data frames, `contribution_p1` (creation/
#'   destruction detail) and `contribution_p2` (undifferentiated aggregate),
#'   matching PDF Table 3.5.
#' @export
compute_contribution <- function(config, accounts_indicators) {
  data <- accounts_indicators
  groups <- contribution_categories(data)

  # --- Step 2: balance the panel (FILLIN idf x year) --------------------------
  full_grid <- expand.grid(idf = unique(data$idf), year = unique(data$year))
  data <- dplyr::full_join(full_grid, data, by = c("idf", "year"))
  data$ALL <- 1L # set *after* FILLIN so newly-inserted rows get 1, not NA

  # --- Step 3: extra entry/exit lags ------------------------------------------
  data$L1entry <- panel_lag(data$entry, 1, data$idf, data$year)
  data$L2entry <- panel_lag(data$entry, 2, data$idf, data$year)
  data$L1exit <- panel_lag(data$exit, 1, data$idf, data$year)
  data$L2exit <- panel_lag(data$exit, 2, data$idf, data$year)
  data$L3exit <- panel_lag(data$exit, 3, data$idf, data$year)

  # --- Step 4: dominance L3 lags -----------------------------------------------
  if (isTRUE(config$dominance)) {
    for (domvar in config$dom_vars) {
      if (has_column(data, domvar)) {
        data[[paste0("L3", domvar)]] <- panel_lag(data[[domvar]], 3, data$idf, data$year)
      }
    }
  }

  # --- Step 5: recompute L3/S3 for employment/turnover on the balanced panel --
  for (v in c("employment", "turnover")) {
    l3v <- panel_lag(data[[v]], 3, data$idf, data$year)
    data[[paste0("L3", v)]] <- l3v
    s3v <- data[[paste0("S3", v)]]
    s3v <- ifelse(!is.na(data[[v]]) & is.na(l3v), data[[v]], s3v)
    s3v <- ifelse(is.na(data[[v]]) & !is.na(l3v), -l3v, s3v)
    data[[paste0("S3", v)]] <- s3v
  }

  # --- Step 6: category-group fallback for entrants ---------------------------
  for (gr in setdiff(groups, "ALL")) {
    gr2 <- sub("L3", "", gr, fixed = TRUE)
    lag_gr2 <- panel_lag(data[[gr2]], 3, data$idf, data$year)
    data[[gr]] <- ifelse(!is.na(lag_gr2), lag_gr2, data[[gr2]])
  }

  # --- Step 7: drop uninformative rows -----------------------------------------
  data <- data[
    !(is.na(data$employment) & is.na(data$turnover) & is.na(data$L3employment) & is.na(data$L3turnover)) &
      !(stata_num(data$employment) == 0 & stata_num(data$L3employment) == 0),
  ]

  # --- Step 8: restrict to the 5 analysis years --------------------------------
  data <- data[data$year %in% c(2014, 2017, 2019, 2020, 2021), ]

  # --- Step 9/10: sample-independent helper columns ----------------------------
  data$firms <- 1L
  for (stub in c("HGE", "HGT", "HGET")) {
    for (i in c("10", "20")) {
      data[[paste0("non", stub, i)]] <- as.integer(
        stata_num(data[[paste0(stub, i)]]) == 0 & stata_num(data[[paste0(stub, "_pool")]]) == 1
      )
    }
  }

  samples <- c(
    "ALL", "micro", "SMEs", "HGE10", "HGE20", "HGT10", "HGT20", "HGET10", "HGET20",
    "nonHGE10", "nonHGE20", "nonHGT10", "nonHGT20", "nonHGET10", "nonHGET20",
    "entrants", "exiting"
  )

  acc_p1 <- list()
  acc_p2 <- list()

  for (var in c("employment", "turnover")) {
    X <- if (var == "employment") "E" else "T"
    xxx <- if (var == "employment") "emp" else "trn"
    s3var <- data[[paste0("S3", var)]]
    l3var <- data[[paste0("L3", var)]]

    for (sample in samples) {
      cond <- contribution_cond(data, sample)

      for (Y in c("C", "D")) {
        if (Y == "C") {
          xy <- ifelse(!is.na(s3var) & s3var > 0 & cond, s3var, NA_real_)
          n_xy <- as.integer(!is.na(s3var) & s3var > 0 & cond)
          l3xxx_sample <- ifelse(cond, l3var, NA_real_)
        } else {
          xy <- ifelse(!is.na(s3var) & s3var < 0 & cond, s3var, NA_real_)
          n_xy <- as.integer(!is.na(s3var) & s3var <= 0 & cond)
        }
        n_xy[is.na(n_xy)] <- 0L

        for (group in groups) {
          if (identical(sample, "entrants") && identical(group, "L3age_cat")) next

          # --- detail block -> contribution_p1 ---
          detail <- data[n_xy == 1, ]
          if (nrow(detail) > 0) {
            detail$.xy <- xy[n_xy == 1]
            detail$.l3xxx <- l3xxx_sample[n_xy == 1]
            dom <- contribution_dominance(detail, sample, group, config)
            cell <- detail %>%
              dplyr::group_by(dplyr::across(dplyr::all_of(c("year", group)))) %>%
              dplyr::summarise(
                N_firms = sum(.data$firms), S3sum = sum(.data$.xy, na.rm = TRUE),
                L3sum = sum(.data$.l3xxx, na.rm = TRUE), .groups = "drop"
              )
            if (!is.null(dom)) cell <- dplyr::left_join(cell, dom, by = c("year", group))
            cell <- cell[!is.na(cell[[group]]), ]
            if (nrow(cell) > 0) {
              cell$category <- group
              cell$group_label <- decode_category(cell[[group]], group)
              cell[[group]] <- NULL
              cell$sample <- sample
              cell$type <- Y
              cell$variable <- var
              acc_p1[[length(acc_p1) + 1]] <- cell
            }
          }

          # --- aggregate block -> contribution_p2 (once per (var,sample,group)) ---
          if (Y == "D" && sample != "exiting") next
          agg_src <- data[cond, ]
          if (nrow(agg_src) > 0) {
            agg_src$.l3xxx <- l3xxx_sample[cond]
            dom <- contribution_dominance(agg_src, sample, group, config)
            cell2 <- agg_src %>%
              dplyr::group_by(dplyr::across(dplyr::all_of(c("year", group)))) %>%
              dplyr::summarise(N_firms = sum(.data$firms), L3sum = sum(.data$.l3xxx, na.rm = TRUE), .groups = "drop")
            if (!is.null(dom)) cell2 <- dplyr::left_join(cell2, dom, by = c("year", group))
            cell2 <- cell2[!is.na(cell2[[group]]), ]
            if (nrow(cell2) > 0) {
              cell2$category <- group
              cell2$group_label <- decode_category(cell2[[group]], group)
              cell2[[group]] <- NULL
              cell2$sample <- sample
              cell2$variable <- var
              acc_p2[[length(acc_p2) + 1]] <- cell2
            }
          }
        }
      }
    }
  }

  list(
    contribution_p1 = finalize_contribution(acc_p1, config, is_p1 = TRUE),
    contribution_p2 = finalize_contribution(acc_p2, config, is_p1 = FALSE)
  )
}

#' @keywords internal
finalize_contribution <- function(accumulator, config, is_p1) {
  if (length(accumulator) == 0) {
    return(NULL)
  }
  out <- dplyr::bind_rows(accumulator)
  names(out)[names(out) == "group_label"] <- "group"

  if (is_p1) {
    out <- out[!(out$sample == "entrants" & out$type == "D"), ]
    out <- out[!(out$sample == "exiting" & out$type == "C"), ]
    out$type <- ifelse(out$type == "C", "creation", "destruction")
    front <- c("category", "group", "sample", "type", "variable")
  } else {
    front <- c("category", "group", "sample", "variable")
  }
  out$sample[out$sample == "SMEs"] <- "non_micro_SMEs"

  if (isTRUE(config$dominance)) {
    for (domvar in config$dom_vars) {
      dom_col <- paste0("dom_", domvar)
      l3_dom_col <- paste0("dom_L3", domvar)
      if (l3_dom_col %in% names(out)) {
        if (!dom_col %in% names(out)) out[[dom_col]] <- NA_real_
        out[[dom_col]] <- ifelse(is.na(out[[dom_col]]) & !is.na(out[[l3_dom_col]]), out[[l3_dom_col]], out[[dom_col]])
        out[[l3_dom_col]] <- NULL
      }
    }
  }

  rest <- setdiff(names(out), c(front, "year"))
  dplyr::as_tibble(out[c("year", front, rest)])
}