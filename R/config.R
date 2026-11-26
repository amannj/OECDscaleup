#' Build a Scale-Up pipeline configuration
#'
#' Constructs and validates the configuration shared by every pipeline stage,
#' replacing the Stata global macros (`$country`, `$inputdir`, `$outputdir`,
#' `$dominance`, `$domvars`, `$dom_num`) set once in `MASTER_OECD_p2.do` and
#' read implicitly by every downstream `.do` file.
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
#' @param nace_revision Required. The NACE revision of the sector codes
#'   (`sector_1d`, `sector_2d`, `sector_3d`) in `base_financials`: `"2"` (NACE
#'   Rev. 2) or `"2.1"` (NACE Rev. 2.1, used for statistics from reference
#'   year 2025). The pipeline's sector rules are written for Rev. 2; Rev. 2.1
#'   codes are converted to Rev. 2 first. The build stops if the codes do not
#'   match the declared revision (a section letter that does not belong to its
#'   division, division 45 in Rev. 2.1, section V in Rev. 2).
#' @param nace_rev21_from For a panel coded in Rev. 2 up to some year and in
#'   Rev. 2.1 after: the first year in Rev. 2.1 (with `nace_revision = "2"`).
#'   `NULL` (the default): one revision for every year.
#' @param financials_unit The unit of the money variables in
#'   `base_financials`: `"EUR thousand"` (as the variable dictionary asks) or
#'   `"EUR"` (divided by 1000 on input). `NULL` (the default) follows the
#'   original package: EUR for the countries in
#'   `country_patches$rescale_to_thousands`, EUR thousand otherwise. The build
#'   stops when turnover per employee does not fit EUR thousand after this step.
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
#'   nace_revision = "2",
#'   dominance = FALSE
#' )
#' }
config_scaleup <- function(country,
                            input_dir,
                            output_dir,
                            nace_revision,
                            nace_rev21_from = NULL,
                            dominance = FALSE,
                            dom_vars = c("employment", "turnover"),
                            dom_num = 2,
                            financials_unit = NULL,
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
  if (missing(nace_revision)) {
    rlang::abort(
      c("`nace_revision` is required: the NACE revision of the sector codes, \"2\" or \"2.1\".",
        "i" = "NACE Rev. 2.1 applies to statistics from reference year 2025; for a panel that switches, use nace_revision = \"2\" with nace_rev21_from = <first Rev. 2.1 year>."),
      class = "OECDscaleup_config_error"
    )
  }
  if (is.numeric(nace_revision)) nace_revision <- format(nace_revision)
  if (!is.character(nace_revision) || length(nace_revision) != 1 || !nace_revision %in% c("2", "2.1")) {
    rlang::abort("`nace_revision` must be \"2\" or \"2.1\".", class = "OECDscaleup_config_error")
  }
  if (!is.null(nace_rev21_from)) {
    if (!is.numeric(nace_rev21_from) || length(nace_rev21_from) != 1 || is.na(nace_rev21_from) ||
        nace_rev21_from != round(nace_rev21_from)) {
      rlang::abort("`nace_rev21_from` must be a single year (or NULL).", class = "OECDscaleup_config_error")
    }
    if (nace_revision != "2") {
      rlang::abort("`nace_rev21_from` goes with nace_revision = \"2\" (the years before it are Rev. 2).",
                   class = "OECDscaleup_config_error")
    }
  }
  financials_unit_default <- is.null(financials_unit)
  if (financials_unit_default) {
    financials_unit <- if (toupper(country) %in% country_patches$rescale_to_thousands) "EUR" else "EUR thousand"
  }
  if (!identical(financials_unit, "EUR") && !identical(financials_unit, "EUR thousand")) {
    rlang::abort("`financials_unit` must be \"EUR\" or \"EUR thousand\".", class = "OECDscaleup_config_error")
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
      nace_revision = nace_revision,
      nace_rev21_from = if (is.null(nace_rev21_from)) NULL else as.integer(nace_rev21_from),
      financials_unit = financials_unit,
      financials_unit_default = financials_unit_default,
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
  cat("  NACE:       ", if (is.null(x$nace_rev21_from)) paste("Rev.", x$nace_revision) else
    sprintf("Rev. 2, Rev. 2.1 from %d", x$nace_rev21_from), "\n")
  cat("  financials: ", x$financials_unit, "\n")
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
#' [variable_dictionary], and whole blocks of logic are silently
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
