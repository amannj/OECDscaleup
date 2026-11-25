#' Run the scaler analysis (top scalers, scalers to mid-caps) from files
#'
#' New analysis, after [run_scaleup_pipeline()] (or [run_trade_pipeline()]):
#' reads the indicators panel those write to `config$input_dir`, preferring
#' `trade_accounts_indicators_<country>.dta` (it adds exporter status as a
#' breakdown) over `accounts_indicators_<country>.dta`, runs
#' [compute_top_scalers()] twice (without and with `joint_growth`) and
#' [compute_midcap_transitions()], and writes to `config$output_dir`:
#' * `sa_top_scalers_<country>.csv` (both versions, column `joint_growth`);
#' * `sa_midcap_incidence_<country>.csv`, `sa_midcap_entry_<country>.csv`,
#'   `sa_midcap_by_year_<country>.csv`, `sa_midcap_coverage_<country>.csv`,
#'   `sa_midcap_hazard_<country>.csv`.
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param money_unit Unit of turnover and total assets in the indicators
#'   panel, see [compute_midcap_transitions()].
#' @return Invisibly, a list of the tables written.
#' @export
run_scaler_analysis <- function(config, money_unit = c("EUR thousand", "EUR")) {
  money_unit <- match.arg(money_unit)
  files <- file.path(config$input_dir, paste0(c("trade_accounts_indicators_", "accounts_indicators_"), config$country, ".dta"))
  found <- files[file.exists(files)]
  if (!length(found)) {
    rlang::abort(sprintf("No indicators panel in %s: run run_scaleup_pipeline() first.", config$input_dir),
                 class = "OECDscaleup_data_error")
  }
  ai <- haven::read_dta(found[1])

  top <- dplyr::bind_rows(
    compute_top_scalers(config, ai, joint_growth = FALSE),
    compute_top_scalers(config, ai, joint_growth = TRUE)
  )
  mid <- compute_midcap_transitions(config, ai, money_unit = money_unit)
  out <- c(list(top_scalers = top), stats::setNames(mid, paste0("midcap_", names(mid))))
  for (nm in names(out)) {
    utils::write.csv(out[[nm]], file.path(config$output_dir, sprintf("sa_%s_%s.csv", nm, config$country)),
                     row.names = FALSE, na = "")
  }
  invisible(out)
}
