#' Collapse transaction-level trade data to a firm-year panel
#'
#' Translates PART 2 of `n0_2_trade_accounts_indicators.do` (trade package
#' v1.0). The raw trade file has one row per firm, year, flow (`trade_type`
#' 1 = import, 2 = export), destination country and CN8 product. The result
#' has one row per firm-year with, for each flow, the total value, the number
#' of distinct 6-digit products and the largest product's share; for exports
#' also the number of destination countries (all and EU). Imports have no
#' partner country in the data, so their partner counts are dropped, as in
#' Stata.
#'
#' Stata semantics reproduced: `egen total()` and `gen` results are stored as
#' `float`, `collapse (sum)` as `double`; products whose 6-digit total is
#' below 1 (thousand EUR) are blanked before the counts; a flow whose values
#' were all missing stays missing after the collapse (which would sum them to
#' 0); a flow that is entirely absent stays missing after the reshape (bug
#' T2).
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param trade_raw Data frame with `idf, year, trade_type, trade_value`
#'   (numeric) and `code_destin, prod_code` (string), as in the `TRADE_RAW`
#'   sheet of `variable_dictionary_v2.xlsx`.
#' @param storage_types Optional Stata storage types of `trade_raw`'s columns
#'   (see [build_accounts_indicators()]); used for the PT/HU rescaling.
#' @return A data frame, one row per `(idf, year)` present in `trade_raw`.
#' @export
build_trade_panel <- function(config, trade_raw, storage_types = NULL) {
  d <- as.data.frame(trade_raw)
  required <- c("idf", "year", "trade_value", "trade_type", "code_destin", "prod_code")
  miss <- setdiff(required, names(d))
  if (length(miss)) {
    rlang::abort(sprintf("Missing required trade column(s): %s. Check variable_dictionary_v2.xlsx.",
                         paste(miss, collapse = ", ")), class = "OECDscaleup_data_error")
  }
  for (v in c("code_destin", "prod_code")) {
    if (!is.character(d[[v]])) rlang::abort(sprintf("`%s` must be a string column.", v), class = "OECDscaleup_data_error")
  }
  for (v in c("idf", "year", "trade_value", "trade_type")) {
    if (!is.numeric(d[[v]])) rlang::abort(sprintf("`%s` must be numeric.", v), class = "OECDscaleup_data_error")
  }
  d <- d[required]
  for (v in c("idf", "year", "trade_value", "trade_type")) d[[v]] <- as.double(haven::zap_labels(d[[v]]))
  d$code_destin[is.na(d$code_destin)] <- ""
  d$prod_code[is.na(d$prod_code)] <- ""

  # Fix T1: trade values to EUR thousand when supplied in EUR. Stata hard-coded
  # "only PT and maybe HU"; that is now the default of config$trade_value_unit.
  unit <- if (is.null(config$trade_value_unit)) {
    if (config$country %in% country_patches$trade_values_in_eur) "EUR" else "EUR thousand"
  } else config$trade_value_unit
  if (identical(unit, "EUR")) {
    orig_type <- if ("trade_value" %in% names(storage_types)) storage_types[["trade_value"]] else NA_character_
    d$trade_value <- d$trade_value / 1000
    if (stata_replace_type(orig_type) == "float") d$trade_value <- stata_float(d$trade_value)
  }

  d$prod_code <- substr(d$prod_code, 1, 6)
  flow <- paste(d$idf, d$year, d$trade_type, sep = "\r")
  # egen total() counts a missing value as 0 and stores a float
  value_prod_total <- stata_float(group_sum(d$trade_value, paste(flow, d$prod_code, sep = "\r")))

  # Fix T5: products are told apart by their 6-character code. Stata destring'ed it
  # (no force): a code with letters left the variable a string and the run stopped
  # at `replace prod_code = .` (type mismatch), and codes differing only in leading
  # zeros were merged. "" and "." are a missing code.
  pc <- trimws(d$prod_code)
  pc[pc %in% c("", ".")] <- NA_character_
  d$prod_code <- pc

  # a flow whose values are all missing must not become 0 in the collapse
  miss_value <- group_all(is.na(d$trade_value), flow)

  # products below 1 (thousand) are excluded (bug T7: assumes EUR thousand)
  small <- value_prod_total < 1
  d$prod_code[small] <- NA
  d$trade_value[small] <- NA
  d$code_destin[small] <- ""

  # destination country (exports only)
  country_code <- ifelse(stata_num(d$trade_type) == 2, d$code_destin, "")
  country_code[country_code == "."] <- ""

  # one row per distinct partner and product (the first in Stata's sort; any one does)
  partner_key <- paste(flow, country_code, sep = "\r")
  unique_trade_partner <- ifelse(country_code != "", as.integer(!duplicated(partner_key)), NA_integer_)
  prod_key <- paste(flow, d$prod_code, sep = "\r")
  unique_product <- ifelse(!is.na(d$prod_code), as.integer(!duplicated(prod_key)), NA_integer_)

  # share of each product in the flow (float egen totals, float gen)
  total_tmp <- stata_float(group_sum(d$trade_value, flow))
  total_prod <- stata_float(group_sum(d$trade_value, prod_key))
  share_product <- ifelse(stata_num(unique_product) == 1, stata_float(total_prod / total_tmp), NA_real_)
  share_product[!is.finite(share_product)] <- NA_real_

  # EU partner (fixed EU-27 list incl. EL and GR, bug T6)
  eu27 <- c("AT", "BE", "BG", "CZ", "DE", "EE", "IE", "EL", "GR", "ES", "FR", "HR", "HU", "CY", "IT",
            "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "DK", "FI", "SE")
  EU <- as.integer(country_code %in% eu27 & stata_num(unique_trade_partner) == 1)
  EU[country_code == ""] <- NA

  g <- data.frame(idf = d$idf, year = d$year, trade_type = d$trade_type, flow = flow,
                  trade_value = d$trade_value, unique_trade_partner, EU, unique_product, share_product,
                  miss_value)
  out <- g %>%
    dplyr::group_by(.data$trade_type, .data$idf, .data$year) %>%
    dplyr::summarise(
      value = sum(.data$trade_value, na.rm = TRUE),
      all_partners = sum(.data$unique_trade_partner, na.rm = TRUE),
      eu_partners = sum(.data$EU, na.rm = TRUE),
      products = sum(.data$unique_product, na.rm = TRUE),
      core_prod = if (all(is.na(.data$share_product))) NA_real_ else max(.data$share_product, na.rm = TRUE),
      miss_value = all(.data$miss_value),
      miss_all_partners = all(is.na(.data$unique_trade_partner)),
      miss_eu_partners = all(is.na(.data$EU)),
      miss_products = all(is.na(.data$unique_product)),
      .groups = "drop"
    )
  # restore what was missing before the collapse summed it to 0
  for (v in c("all_partners", "eu_partners", "products")) out[[v]][out[[paste0("miss_", v)]]] <- NA
  out$value[out$miss_value] <- NA
  out <- out[c("trade_type", "idf", "year", "value", "all_partners", "eu_partners", "products", "core_prod")]

  # reshape wide by flow
  types <- sort(unique(out$trade_type))
  if (anyNA(types)) {
    rlang::abort("`trade_type` has missing values: Stata's reshape stops.", class = "OECDscaleup_stata_crash")
  }
  # Fix T4: Stata stopped (`rename trade_value1`) when the data had no import (or
  # no export) rows. A flow absent from the whole file is now unknown: its
  # variables are missing for every firm.
  flows <- intersect(c(1, 2), types)
  if (!length(flows)) {
    rlang::abort("The trade data have neither import (trade_type 1) nor export (trade_type 2) rows.",
                 class = "OECDscaleup_data_error")
  }
  vars <- c("value", "all_partners", "eu_partners", "products", "core_prod")
  wide <- dplyr::distinct(out[c("idf", "year")])
  for (t in union(c(1, 2), types)) {
    prefix <- if (t == 1) "imp_" else if (t == 2) "exp_" else NULL
    new_names <- if (is.null(prefix)) paste0("trade_", vars, t) else paste0(prefix, vars)
    if (!t %in% types) {
      for (v in new_names) wide[[v]] <- NA_real_
      next
    }
    part <- out[out$trade_type == t, setdiff(names(out), "trade_type")]
    names(part)[match(vars, names(part))] <- new_names
    wide <- dplyr::left_join(wide, part, by = c("idf", "year"))
    # Fix T2: a firm-year in the trade file without this flow had a missing value
    # (so an import-only firm was neither exporter nor non-exporter); it has none,
    # i.e. 0, like a firm that does not appear in the trade file at all
    no_flow <- !paste(wide$idf, wide$year) %in% paste(part$idf, part$year)
    wide[[new_names[1]]][no_flow] <- 0
  }
  attr(wide, "flows") <- flows
  # import partners come from code_origin, which the package does not use: always empty, dropped
  if (sum(!is.na(wide$imp_all_partners)) == 0) {
    wide$imp_all_partners <- NULL
    wide$imp_eu_partners <- NULL
  }
  out <- dplyr::as_tibble(wide)
  attr(out, "flows") <- flows
  out
}

# egen total(): group sums with missing as 0, broadcast to the rows
group_sum <- function(x, g) {
  x0 <- ifelse(is.na(x), 0, x)
  stats::ave(x0, g, FUN = sum)
}

# TRUE on every row of a group whose x is TRUE on all rows
group_all <- function(x, g) {
  as.logical(stats::ave(as.integer(x), g, FUN = function(v) as.integer(all(v == 1L))))
}

#' Build the trade package's firm-year panel (`trade_accounts_indicators`)
#'
#' Translates `n0_2_trade_accounts_indicators.do`: the second package's
#' [build_accounts_indicators()] (an earlier version of it) with the firm-year
#' trade panel ([build_trade_panel()]) merged in, and exporter/importer flags,
#' first-time exporters (`y4_exporter`), heavy/light exporting turnover
#' scalers (`HGX10/20`, `HGNX10/20`), `sector_exporter` and `digit_sect`
#' added. Regions are not aggregated and there is no `reg_techgrad`.
#'
#' @inheritParams build_accounts_indicators
#' @param trade_raw The transaction-level trade data (see [build_trade_panel()]).
#' @param trade_storage_types Optional Stata storage types of `trade_raw`.
#' @return A data frame, one row per `(idf, year)` of `base_financials`, ready
#'   for [compute_trade_characteristics()].
#' @export
build_trade_accounts_indicators <- function(config,
                                            base_financials,
                                            trade_raw,
                                            plants_raw = NULL,
                                            exchange_rates = NULL,
                                            tl3_typology = NULL,
                                            storage_types = NULL,
                                            trade_storage_types = NULL) {
  panel <- build_trade_panel(config, trade_raw, storage_types = trade_storage_types)
  build_accounts_core(config, base_financials,
    plants_raw = plants_raw, exchange_rates = exchange_rates,
    tl3_typology = tl3_typology, storage_types = storage_types, trade_panel = panel
  )
}
