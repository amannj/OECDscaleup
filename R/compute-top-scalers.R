#' Top scalers: the fastest-growing high-growth firms
#'
#' New analysis (not part of the original Stata package). Ranks the
#' high-growth scalers of each year by how much they grew over the 3-year
#' window t-3..t and describes the fastest ones, in the format of
#' [compute_characteristics()].
#'
#' **Population.** Scalers as in the package, 20 % definition: employment
#' scalers (`HGE20`) are ranked by employment indices, turnover scalers
#' (`HGT20`) by turnover indices; firms with 10 to fewer than 250 employees at
#' t-3, from the fourth panel year on (as in [compute_characteristics()]).
#' Growth driven by an acquisition (`acquisition == 1`) is excluded; a missing
#' `acquisition` flag does not exclude the firm.
#'
#' **Indices** (x = employment or turnover):
#' * `rel`: relative growth, x / L3x - 1 (same ranking as the CAGR);
#' * `abs`: absolute growth, x - L3x;
#' * `bs`: Birch-Schreyer, (x - L3x) * x / L3x.
#'
#' **Ranking.** Within each year (one country per run). Ties on the index are
#' broken by a second, then a third index: rel -> abs -> bs, abs -> rel -> bs,
#' bs -> abs -> rel. Firms still tied share the better rank, so every firm tied
#' at a cut-off is included.
#'
#' **Cut-offs.** `top50` = rank <= 50; `p1`, `p5`, `p10`, `p25` = rank <= the
#' share times the number of ranked scalers that year, rounded up (at least 1).
#' Every cut-off is reported for every cell; nothing is blanked.
#'
#' **Output.** One row per (year, sample, category, group). `sample` is
#' `<scaler>_<index>_<cutoff>` (e.g. `HGE20_rel_p10`) or `<scaler>_ranked` for
#' all ranked scalers. Columns as in [compute_characteristics()] (firm count,
#' approximate medians, means, ownership shares, optional dominance), plus:
#' * `n_ranked`, `rank_cutoff`: scalers ranked that year and the rank cut-off;
#' * `S3pos_employment`, `S3pos_turnover`: the cell's gross 3-year creation
#'   (sum of the positive x - L3x);
#' * `share_creation_employment`, `share_creation_turnover`: that creation over
#'   the gross creation of all firms in the same year and group (entrants count
#'   with their whole size, as in [compute_contribution()]; the group is taken
#'   at t-3, else at t).
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param accounts_indicators The output of [build_accounts_indicators()]
#'   (with the trade columns when built with a trade panel: then `L3exporter`
#'   is a breakdown too).
#' @param cutoffs Named cut-offs: values >= 1 are a number of firms, values
#'   below 1 a share of the ranked scalers.
#' @param joint_growth If `TRUE`, rank only scalers whose other variable also
#'   grew over t-3..t (turnover for employment scalers, employment for
#'   turnover scalers). [run_scaler_analysis()] reports both versions.
#' @return A tibble.
#' @export
compute_top_scalers <- function(config, accounts_indicators,
                                cutoffs = c(top50 = 50, p1 = 0.01, p5 = 0.05, p10 = 0.10, p25 = 0.25),
                                joint_growth = FALSE) {
  stopifnot(is.numeric(cutoffs), length(names(cutoffs)) == length(cutoffs), all(cutoffs > 0),
            is.logical(joint_growth), length(joint_growth) == 1)
  data <- accounts_indicators
  data$ALL <- 1L
  data$firms <- 1L
  data <- add_findep_ratios(data)
  findep_vars <- attr(data, "findep_vars")

  categories <- intersect(
    c("ALL", "L3size_cat", "L3age_cat", "L3tech_grad", "L3typology_UR", "L3independent",
      "L3foreign_owned", "L3multiplant", "L3exporter"),
    names(data)
  )
  median_vars <- intersect(c(
    "L3age", "L3employment", "L3turnover", "L3labour_prod", paste0("L3", findep_vars), "L3MFP",
    "employment", "turnover", "labour_prod", "employment_growth3y", "turnover_growth3y",
    "employment_futgrowth", "turnover_futgrowth"
  ), names(data))
  share_vars <- intersect(
    c("L3independent", "L3foreign_owned", "L3multiplant", "L3young", "L3exporter"), names(data)
  )
  mean_vars <- intersect(
    c("employment_growth3y", "turnover_growth3y", "employment_futgrowth", "turnover_futgrowth"), names(data)
  )

  # gross creation of all firms, per year and group (before the scaler restriction)
  creation <- top_scaler_creation_base(data, categories)

  for (v in c("employment", "turnover")) {
    s3 <- as.double(data[[v]]) - as.double(data[[paste0("L3", v)]])
    data[[paste0(".S3pos_", v)]] <- ifelse(!is.na(s3) & s3 > 0, s3, 0)
  }
  cell_cols <- intersect(c(
    "year", "firms", categories, median_vars, mean_vars, share_vars, ".S3pos_employment", ".S3pos_turnover",
    if (isTRUE(config$dominance)) config$dom_vars
  ), names(data))

  results <- list()
  for (m in top_scaler_membership(data, cutoffs, joint_growth)) {
    sdf <- data[m$rows, cell_cols]
    sdf$.n_ranked <- m$n_ranked
    sdf$.k <- m$k
    for (cat in categories) {
      cell <- top_scaler_cells(sdf, cat, median_vars, mean_vars, setdiff(share_vars, cat), config)
      if (is.null(cell)) next
      cell$sample <- m$name
      results[[length(results) + 1]] <- cell
    }
  }
  if (!length(results)) return(dplyr::tibble())
  out <- dplyr::bind_rows(results)

  out <- dplyr::left_join(out, creation, by = c("year", "category", "group"))
  out$share_creation_employment <- out$S3pos_employment / out$creation_employment
  out$share_creation_turnover <- out$S3pos_turnover / out$creation_turnover
  out$creation_employment <- NULL
  out$creation_turnover <- NULL

  for (v in mean_vars) names(out)[names(out) == v] <- paste0("mean_", v)
  for (v in share_vars) names(out)[names(out) == v] <- paste0("share_", v)
  names(out)[names(out) == "firms"] <- "firm_count"
  out$joint_growth <- joint_growth
  front <- c("year", "sample", "joint_growth", "category", "group", "firm_count", "n_ranked", "rank_cutoff")
  dom_cols <- grep("^dom_", names(out), value = TRUE)
  out <- out[c(front, setdiff(names(out), c(front, dom_cols)), dom_cols)]
  dplyr::as_tibble(out)
}

#' Firm-years in each top-scaler sample
#'
#' The ranked population (scalers with 10 to fewer than 250 employees at t-3,
#' from the fourth panel year, observed at t-3, not acquisition-driven, all
#' three indices defined) and, per index and cut-off, the firm-years within it.
#' Also used by [compute_midcap_transitions()] to follow top scalers.
#' @return A list of samples in output order, each `list(name, rows, n_ranked,
#'   k)`: rows of `data`, the scalers ranked that year and the rank cut-off
#'   (NA for the `_ranked` sample).
#' @noRd
top_scaler_membership <- function(data, cutoffs, joint_growth = FALSE) {
  first_year <- min(data$year)
  l3idf <- panel_lag(data$idf, 3, data$idf, data$year)
  l3e <- data$L3employment
  clean <- if (has_column(data, "acquisition")) stata_num(data$acquisition) != 1 else TRUE
  base <- data$year >= first_year + 3 & !is.na(l3e) & l3e > 0 & l3e < 250 & !is.na(l3idf) & clean
  chains <- list(rel = c("rel", "abs", "bs"), abs = c("abs", "rel", "bs"), bs = c("bs", "abs", "rel"))
  out <- list()
  specs <- list(list(scaler = "HGE20", var = "employment", other = "turnover"),
                list(scaler = "HGT20", var = "turnover", other = "employment"))
  for (spec in specs) {
    if (!has_column(data, spec$scaler)) next
    idx <- top_scaler_indices(data[[spec$var]], data[[paste0("L3", spec$var)]])
    ranked <- base & stata_num(data[[spec$scaler]]) == 1 & !is.na(idx$rel) & !is.na(idx$abs) & !is.na(idx$bs)
    if (joint_growth) {
      other <- as.double(data[[spec$other]]) - as.double(data[[paste0("L3", spec$other)]])
      ranked <- ranked & !is.na(other) & other > 0
    }
    if (!any(ranked)) next
    r <- which(ranked)
    yr <- data$year[r]
    idx <- idx[r, ]
    n_ranked <- as.vector(table(yr)[as.character(yr)])
    out[[length(out) + 1]] <- list(name = paste0(spec$scaler, "_ranked"), rows = r, n_ranked = n_ranked,
                                   k = rep(NA_real_, length(r)))
    for (index in names(chains)) {
      ch <- chains[[index]]
      rk <- lex_rank_desc(yr, idx[[ch[1]]], idx[[ch[2]]], idx[[ch[3]]])
      for (cut in names(cutoffs)) {
        k <- top_scaler_k(cutoffs[[cut]], n_ranked)
        keep <- rk <= k
        out[[length(out) + 1]] <- list(name = paste(spec$scaler, index, cut, sep = "_"), rows = r[keep],
                                       n_ranked = n_ranked[keep], k = k[keep])
      }
    }
  }
  out
}

#' The three growth indices over t-3..t (double precision, from the stored values)
#' @noRd
top_scaler_indices <- function(x, l3x) {
  x <- as.double(x)
  l3x <- as.double(l3x)
  ok <- !is.na(x) & !is.na(l3x) & l3x > 0
  ratio <- ifelse(ok, x / l3x, NA_real_)
  data.frame(rel = ratio - 1, abs = ifelse(ok, x - l3x, NA_real_), bs = ifelse(ok, (x - l3x) * ratio, NA_real_))
}

#' Rank within groups, descending on k1, ties broken by k2 then k3
#'
#' Competition ranking ("1224"): a firm's rank is 1 + the number of firms in
#' its group that are strictly better on (k1, k2, k3); firms tied on all three
#' share the rank. Missing keys rank last.
#' @noRd
lex_rank_desc <- function(g, k1, k2, k3) {
  low <- function(k) ifelse(is.na(k), -Inf, k)
  k1 <- low(k1); k2 <- low(k2); k3 <- low(k3)
  o <- order(g, -k1, -k2, -k3)
  gs <- g[o]
  new_group <- c(TRUE, gs[-1] != gs[-length(gs)])
  new_tuple <- new_group | c(TRUE, k1[o][-1] != k1[o][-length(o)] | k2[o][-1] != k2[o][-length(o)] |
                               k3[o][-1] != k3[o][-length(o)])
  pos <- sequence(rle(as.character(gs))$lengths)
  rk <- ifelse(new_tuple, pos, NA_integer_)
  # carry the first position of each tied run forward
  rk <- rk[cummax(seq_along(rk) * !is.na(rk))]
  out <- integer(length(g))
  out[o] <- rk
  out
}

#' Rank cut-off: a count (>= 1) or a share of the ranked scalers, rounded up
#' @noRd
top_scaler_k <- function(cutoff, n_ranked) {
  if (cutoff >= 1) return(rep(cutoff, length(n_ranked)))
  pmax(1, ceiling(round(cutoff * n_ranked, 8)))
}

#' One sample x category: counts, medians, means, shares, creation, dominance
#' @noRd
top_scaler_cells <- function(sdf, cat, median_vars, mean_vars, share_vars, config) {
  if (!nrow(sdf)) return(NULL)
  grp <- dplyr::group_by(sdf, dplyr::across(dplyr::all_of(c(cat, "year"))))
  cell <- dplyr::summarise(
    grp,
    firms = sum(.data$firms),
    n_ranked = max(.data$.n_ranked),
    rank_cutoff = max(.data$.k),
    dplyr::across(dplyr::all_of(median_vars), approx_median, .names = "median_{.col}"),
    dplyr::across(dplyr::all_of(c(mean_vars, share_vars)), ~ mean(.x, na.rm = TRUE)),
    S3pos_employment = sum(.data$.S3pos_employment),
    S3pos_turnover = sum(.data$.S3pos_turnover),
    .groups = "drop"
  )
  if (isTRUE(config$dominance)) {
    dom <- dplyr::summarise(
      grp,
      dplyr::across(dplyr::all_of(intersect(config$dom_vars, names(sdf))), ~ dominance_share(.x, config$dom_num),
                    .names = "dom_{.col}"),
      .groups = "drop"
    )
    cell <- dplyr::left_join(cell, dom, by = c(cat, "year"))
  }
  cell <- cell[!is.na(cell[[cat]]), ]
  if (!nrow(cell)) return(NULL)
  cell$group <- decode_category(cell[[cat]], cat)
  cell[[cat]] <- NULL
  cell$category <- cat
  cell
}

#' Gross 3-year creation of all firms per (year, category, group)
#'
#' x - L3x where positive; an entrant (no t-3 value) counts with x, as in
#' compute_contribution(). The group is the category at t-3, else at t.
#' Years from the fourth panel year on.
#' @noRd
top_scaler_creation_base <- function(data, categories) {
  first_year <- min(data$year, na.rm = TRUE)
  d <- data[data$year >= first_year + 3, ]
  pos <- list()
  for (v in c("employment", "turnover")) {
    x <- as.double(d[[v]])
    l3 <- as.double(d[[paste0("L3", v)]])
    s3 <- ifelse(!is.na(x) & is.na(l3), x, x - l3)
    pos[[v]] <- ifelse(!is.na(s3) & s3 > 0, s3, 0)
  }
  out <- list()
  for (cat in categories) {
    g <- if (cat == "ALL") d$ALL else {
      now <- sub("^L3", "", cat)
      cur <- if (has_column(d, now)) d[[now]] else rep(NA, nrow(d))
      ifelse(!is.na(d[[cat]]), d[[cat]], cur)
    }
    keep <- !is.na(g)
    if (!any(keep)) next
    key <- interaction(d$year[keep], g[keep], drop = TRUE, lex.order = TRUE)
    e <- vapply(split(pos$employment[keep], key), sum, numeric(1))
    t <- vapply(split(pos$turnover[keep], key), sum, numeric(1))
    first <- !duplicated(key)
    lev <- data.frame(year = d$year[keep][first], code = g[keep][first], key = as.character(key[first]))
    out[[cat]] <- data.frame(
      year = lev$year, category = cat, group = decode_category(lev$code, cat),
      creation_employment = unname(e[lev$key]), creation_turnover = unname(t[lev$key])
    )
  }
  dplyr::bind_rows(out)
}
