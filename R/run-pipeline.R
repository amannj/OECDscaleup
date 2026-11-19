#' Run the full Scale-Up pipeline, reading and writing files on disk
#'
#' Mirrors `MASTER_OECD_p2.do` (`Pseudocode/MASTER_OECD_p2.md`): reads the raw
#' inputs from `config$input_dir`, runs [build_accounts_indicators()] followed
#' by the four independent downstream stages ([compute_characteristics()],
#' [compute_persistence()], [compute_contribution()], [compute_predictors()]),
#' and writes every output CSV to `config$output_dir` plus the intermediate
#' `accounts_indicators_<country>.dta` back to `config$input_dir` (as the
#' source PDF documents it - used for the manual confidentiality-check
#' worked example).
#'
#' This is the only function in the package that performs file I/O; every
#' `compute_*()`/`build_*()` function is a pure, directly-testable
#' data-frame-in-data-frame-out transformation (see `Stata2R/recommendation.md`).
#' Call the pure functions directly if you already have the inputs loaded in
#' R (e.g. this package's own bundled `tl3_typology`/`exchange_rates` data).
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @return Invisibly, a named list of every non-`NULL` output table produced
#'   (the same tables written to `config$output_dir`).
#' @export
run_scaleup_pipeline <- function(config) {
  base_financials_path <- file.path(config$input_dir, paste0("base_financials_", config$country, ".dta"))
  if (!file.exists(base_financials_path)) {
    rlang::abort(sprintf("Required input not found: %s", base_financials_path), class = "OECDscaleup_data_error")
  }
  base_financials <- haven::read_dta(base_financials_path)

  plants_path <- file.path(config$input_dir, paste0("plants_RAW_", config$country, ".dta"))
  plants_raw <- if (file.exists(plants_path)) haven::read_dta(plants_path) else NULL

  exchange_rates_path <- file.path(config$input_dir, "exchange_rates.dta")
  exchange_rates <- if (file.exists(exchange_rates_path)) haven::read_dta(exchange_rates_path) else NULL

  tl3_typology_path <- file.path(config$input_dir, "tl3_typology.dta")
  tl3_typology <- if (file.exists(tl3_typology_path)) haven::read_dta(tl3_typology_path) else NULL

  accounts_indicators <- build_accounts_indicators(
    config, base_financials,
    plants_raw = plants_raw, exchange_rates = exchange_rates, tl3_typology = tl3_typology
  )
  haven::write_dta(
    as_stata_accounts(accounts_indicators),
    file.path(config$input_dir, paste0("accounts_indicators_", config$country, ".dta"))
  )

  characteristics <- compute_characteristics(config, accounts_indicators)
  persistence <- compute_persistence(config, accounts_indicators)
  contribution <- compute_contribution(config, accounts_indicators)
  predictors <- compute_predictors(config, accounts_indicators)

  outputs <- list(characteristics = characteristics)
  outputs <- c(outputs, persistence)
  outputs <- c(outputs, contribution)
  outputs <- c(outputs, predictors)
  outputs <- outputs[!vapply(outputs, is.null, logical(1))]

  for (name in names(outputs)) {
    out_path <- file.path(config$output_dir, sprintf("n13_%s_%s.csv", name, config$country))
    utils::write.csv(outputs[[name]], out_path, row.names = FALSE, na = "")
  }

  invisible(outputs)
}
