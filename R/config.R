#' Build a Scale-Up pipeline configuration
#'
#' Constructs and validates the configuration shared by every pipeline stage,
#' replacing the Stata global macros (`$country`, `$inputdir`, `$outputdir`,
#' `$dominance`, `$domvars`, `$dom_num`) set once in `MASTER_OECD_p2.do` and
#' read implicitly by every downstream `.do` file. See
#' `Pseudocode/00_conventions.md`'s `CONFIG` primitive and
#' `Pseudocode/MASTER_OECD_p2.md`.
#'
#' @param country 2-letter ISO country code (e.g. `"FR"`). Drives output file
#'   naming and several country-specific data patches inside
#'   [build_accounts_indicators()] (see `country_patches`).
#' @param input_dir Folder holding `base_financials_<country>.dta` (and
#'   `plants_RAW_<country>.dta` if available), `exchange_rates.dta`, and
#'   `tl3_typology.dta`. Must already exist.
#' @param output_dir Folder the final CSV outputs and logs are written to.
#'   Must already exist.
#' @param dominance Logical; if `TRUE`, every output table gains `dom_<var>`
#'   disclosure-control columns for each variable in `dom_vars`. Default
#'   `FALSE`.
#' @param dom_vars Character vector of variables the dominance ratio is
#'   computed on (only used if `dominance = TRUE`). Default
#'   `c("employment", "turnover")`.
#' @param dom_num Number of top units defining the dominance ratio (e.g. `2`
#'   means "share held by the 2 largest firms"). Default `2`.
#' @param trade_value_unit Trade package only: the unit of `trade_value` in
#'   `trade_RAW_<country>.dta`, `"EUR"` (divided by 1000) or `"EUR thousand"`.
#'   `NULL` (the default) follows the trade package: EUR for PT and HU, EUR
#'   thousand otherwise (`country_patches$trade_values_in_eur`).
#'
#' @return An object of class `scaleup_config`.
#' @export
#'
#' @examples
#' \dontrun{
#' cfg <- config_scaleup(
#'   country = "FR",
#'   input_dir = "V:/SCALE_UP/DTA/",
#'   output_dir = "V:/SCALE_UP/TMP/",
#'   dominance = FALSE
#' )
#' }
config_scaleup <- function(country,
                            input_dir,
                            output_dir,
                            dominance = FALSE,
                            dom_vars = c("employment", "turnover"),
                            dom_num = 2,
                            trade_value_unit = NULL) {
  if (!is.character(country) || length(country) != 1 || nchar(country) != 2) {
    rlang::abort(
      "`country` must be a single 2-letter ISO country code (e.g. \"FR\").",
      class = "OECDscaleup_config_error"
    )
  }
  if (!is.character(input_dir) || length(input_dir) != 1 || !dir.exists(input_dir)) {
    rlang::abort(
      sprintf("`input_dir` does not exist: %s", input_dir),
      class = "OECDscaleup_config_error"
    )
  }
  if (!is.character(output_dir) || length(output_dir) != 1 || !dir.exists(output_dir)) {
    rlang::abort(
      sprintf("`output_dir` does not exist: %s", output_dir),
      class = "OECDscaleup_config_error"
    )
  }
  if (!is.logical(dominance) || length(dominance) != 1 || is.na(dominance)) {
    rlang::abort("`dominance` must be a single TRUE/FALSE.", class = "OECDscaleup_config_error")
  }
  if (isTRUE(dominance) && (!is.character(dom_vars) || length(dom_vars) == 0)) {
    rlang::abort(
      "`dom_vars` must be a non-empty character vector when `dominance = TRUE`.",
      class = "OECDscaleup_config_error"
    )
  }
  if (!is.numeric(dom_num) || length(dom_num) != 1 || dom_num < 1) {
    rlang::abort("`dom_num` must be a single positive integer.", class = "OECDscaleup_config_error")
  }
  if (is.null(trade_value_unit)) {
    trade_value_unit <- if (toupper(country) %in% country_patches$trade_values_in_eur) "EUR" else "EUR thousand"
  }
  if (!identical(trade_value_unit, "EUR") && !identical(trade_value_unit, "EUR thousand")) {
    rlang::abort("`trade_value_unit` must be \"EUR\" or \"EUR thousand\".", class = "OECDscaleup_config_error")
  }

  structure(
    list(
      country = toupper(country),
      input_dir = input_dir,
      output_dir = output_dir,
      dominance = isTRUE(dominance),
      dom_vars = dom_vars,
      dom_num = as.integer(dom_num),
      trade_value_unit = trade_value_unit
    ),
    class = "scaleup_config"
  )
}

#' @export
print.scaleup_config <- function(x, ...) {
  cat("<scaleup_config>\n")
  cat("  country:    ", x$country, "\n")
  cat("  input_dir:  ", x$input_dir, "\n")
  cat("  output_dir: ", x$output_dir, "\n")
  cat("  dominance:  ", x$dominance, "\n")
  if (x$dominance) {
    cat("  dom_vars:   ", paste(x$dom_vars, collapse = ", "), "\n")
    cat("  dom_num:    ", x$dom_num, "\n")
  }
  invisible(x)
}

#' Check whether a column exists and is non-empty in a data frame
#'
#' Mirrors the source's pervasive `cap confirm v <var>` / `cap summ <var>`
#' guards: many financial and category variables are optional per
#' `variable_dictionary_v1.xlsx`, and whole blocks of logic are silently
#' skipped (not errored) when a given country's raw data lacks them.
#'
#' @param data A data frame.
#' @param var Column name (string).
#' @return `TRUE` if `var` is a column of `data` and has at least one
#'   non-missing value, `FALSE` otherwise.
#' @export
has_column <- function(data, var) {
  var %in% names(data) && sum(!is.na(data[[var]])) > 0
}
