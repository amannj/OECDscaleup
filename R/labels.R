#' Value-label maps (Stata's `label define` / `label values`)
#'
#' Most category variables in the source Stata code are stored as
#' hand-assigned integer codes with an attached value-label map, later
#' `decode`d back to readable strings for output "group" columns. R has no
#' storage-efficiency reason to keep these as integers, so this package keeps
#' only the variables whose codes are genuinely compared/ranged against
#' specific numbers elsewhere in the logic (`age_cat`, `size_cat`,
#' `tech_grad`, plus the classification codes in `compute_persistence()` and
#' `compute_predictors()`) as integers with a label map here; every other
#' category (`sector_1d`, `region_2d`, `ind_a38`, `reg_techgrad`, `size_age`,
#' `typology_UR`) is kept as a plain character string throughout, since
#' nothing ever compares them to a specific hardcoded value.
#'
#' `multiplant`, `independent`, and `foreign_owned` are a deliberate dual-use
#' case: they stay `0`/`1` numeric throughout (so they can be averaged into
#' `share_*` columns), and are only mapped to `"Yes"`/`"No"`/`"Affiliate"`/
#' `"Independent"` at the specific points where the source itself calls
#' `decode` on them (when used as a `by`-category rather than an outcome).
#'
#' @keywords internal
value_labels <- list(
  age_cat = c(`0` = "Young (0-5)", `6` = "Medium-age (6-10)", `11` = "Mature (11+)"),
  size_cat = c(
    `0` = "size 0-9", `10` = "size 10-19", `20` = "size 20-49",
    `50` = "size 50-99", `100` = "size 100-249", `250` = "size 250+"
  ),
  tech_grad = c(
    `1` = "Medium-high tech mfg", `2` = "Medium-low tech mfg & extractive",
    `3` = "Advanced services", `4` = "Other services tradable",
    `5` = "Education, social, health", `6` = "Construction",
    `7` = "Other services non-tradable"
  ),
  multiplant = c(`0` = "No", `1` = "Yes"),
  independent = c(`0` = "Affiliate", `1` = "Independent"),
  foreign_owned = c(`0` = "No", `1` = "Yes"),
  ALL = c(`1` = "full sample"),
  # trade package: `label define digit_sectl` (n0_2) and `exporterl` (n1_6, L3exporter only)
  digit_sect = c(`1` = "Low digital intensity", `2` = "Medium-low digital intensity",
                 `3` = "Medium-high digital intensity", `4` = "High digital intensity"),
  exporter = c(`0` = "Non-exporter", `1` = "Exporter")
)

#' Value labels of the classification codes written to the output CSVs
#'
#' Stata's `export delimited` writes the value label instead of the code
#' (unless `nolabel` is given), so these columns carry the label text in the
#' original output files.
#'
#' @keywords internal
output_labels <- list(
  follow_transitions = c(`6` = "HG again", `5` = "Growing", `4` = "Stable", `3` = "Partial reversal",
                         `2` = "Full reversal", `1` = "Missing info", `0` = "Acquisition"),
  follow_oth_transitions = c(`6` = "HG again", `5` = "Growing", `4` = "Stable", `3` = "Shrinking",
                             `1` = "Missing info", `0` = "Acquisition"),
  lead_evolutions = c(`6` = "HG", `5` = "Growing", `4` = "Stable", `3` = "Shrinking", `2` = "Entry",
                      `1` = "Missing info", `9` = "Aggregated"),
  follow_evolutions = c(`6` = "HG again", `5` = "Growing", `4` = "Stable", `3` = "Partial reversal",
                        `2` = "Full reversal", `1` = "Missing info", `0` = "Acquisition", `9` = "Aggregated"),
  follow_oth_evolutions = c(`6` = "HG again", `5` = "Growing", `4` = "Stable", `3` = "Shrinking",
                            `1` = "Missing info", `9` = "Aggregated"),
  type = c(`0` = "Unclassified", `1` = "Strategic (mixed)", `2` = "Strategic (productivity)",
           `3` = "Strategic (capital)", `4` = "Strategic (labour)", `5` = "Transformational",
           `6` = "Expansionist", `9` = "Missing info", `50` = "<50 year-sector N")
)

#' Write a code as Stata's `export delimited` does: its label, else the number
#' @param x Numeric codes.
#' @param map Named character vector (code -> label).
#' @return A character vector (`NA` stays `NA`).
#' @noRd
export_label <- function(x, map) {
  out <- unname(map[as.character(x)])
  unlabelled <- is.na(out) & !is.na(x)
  out[unlabelled] <- as.character(x[unlabelled])
  out
}

#' Decode a category column to its readable string label
#'
#' Generic dispatcher used everywhere the source calls `decode <cat>, gen
#' (group)` on a loop variable that could be any of several category columns.
#' If `cat_name` has an entry in [value_labels], look up each value there;
#' otherwise (e.g. `region_2d`, `ind_a38`, `reg_techgrad`) the column is
#' already a plain string and is returned as-is.
#'
#' A leading lag prefix (`L1`, `L2`, `L3`, `L6`, ...) is stripped before the
#' lookup, so e.g. `decode_category(x, "L3age_cat")` resolves to the same map
#' as `decode_category(x, "age_cat")` — lagged category columns always mean
#' the same categories as their contemporaneous counterpart.
#'
#' @param x The category column (integer-coded or already character).
#' @param cat_name Name of the category (used to find the label map).
#' @return A character vector.
#' @keywords internal
#' @export
decode_category <- function(x, cat_name) {
  base_name <- sub("^L[0-9]+", "", cat_name)
  map <- value_labels[[base_name]]
  if (is.null(map)) {
    return(as.character(x))
  }
  unname(map[as.character(x)])
}
