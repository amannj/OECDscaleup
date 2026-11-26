#' Check the input data against the variable dictionary
#'
#' Run before [run_scaleup_pipeline()] or [run_trade_pipeline()]: checks the
#' input files of a country against [variable_dictionary] and the rules of
#' the build, and lists what would stop the build (errors), what looks wrong
#' or will be lost (warnings) and what the build will do to the data (notes).
#' The data are not changed.
#'
#' The report holds counts, shares and years only, never firm records or
#' values, so it can be shared, e.g. with the OECD team.
#'
#' With `base_financials = NULL` (the default) the files are read from
#' `config$input_dir`, as the pipelines read them: `base_financials_<CT>.dta`
#' and, where they exist, `plants_RAW_<CT>.dta`, `trade_RAW_<CT>.dta`,
#' `tl3_typology.dta` and `exchange_rates.dta` (only the columns the checks
#' need). Otherwise the data frames given are checked, as the pure functions
#' ([build_accounts_indicators()], [build_trade_accounts_indicators()]) take
#' them.
#'
#' Checks:
#' * every variable of the dictionary: present, of the right type, not all
#'   missing; share missing; negative values of the variables the build sets
#'   to missing; values of the 0/1 indicators and of `trade_type`; the form of
#'   the country, region and product codes;
#' * `base_financials`: duplicate firm-years; sector codes (NACE divisions,
#'   groups within their division, section letters against the declared
#'   `nace_revision`, the sectors the analysis leaves out); `birth_year`
#'   after `year`; the money unit (turnover per employee, after
#'   `financials_unit`); the reference data: the region codes against the
#'   TL3 typology of the declared `tl_classification` (and how many are found
#'   under TL2024 and TL2021), the years of a non-euro country against the
#'   exchange rates, and which tables are used (the package's, unless files
#'   in the input folder or arguments replace them);
#' * `plants_RAW` and `trade_RAW`: firms not in `base_financials`; for trade,
#'   whether exports fit EUR thousand next to turnover (after
#'   `trade_value_unit`).
#'
#' @param config A `scaleup_config` from [config_scaleup()].
#' @param base_financials,plants_raw,trade_raw Data frames to check; `NULL`
#'   reads them from `config$input_dir` (`plants_raw` and `trade_raw` only
#'   when `base_financials` is `NULL` too).
#' @param tl3_typology,exchange_rates Reference data replacing the package's
#'   [tl3_typology] and [exchange_rates], as in [build_accounts_indicators()].
#'   `NULL` (the default) uses the package's, or, when the files are read, a
#'   `tl3_typology.dta` / `exchange_rates.dta` in `config$input_dir`.
#' @return Invisibly, a data frame of class `scaleup_input_check` with one
#'   row per check: `dataset`, `variable` (`""` for checks of a whole file),
#'   `priority` (of the dictionary), `check`, `result` (`"error"`,
#'   `"warning"`, `"note"` or `"ok"`) and `detail`. Printing it lists the
#'   errors, warnings and notes.
#' @examples
#' cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(),
#'                       nace_revision = "2")
#' bf <- data.frame(idf = 1:3, year = 2020, sector_1d = "C", sector_2d = 26, sector_3d = 262,
#'                  region_2d = "FR10", employment = c(10, 20, 30), turnover = c(1000, 2500, 4000),
#'                  birth_year = 2010)
#' check_inputs(cfg, bf)
#' @export
check_inputs <- function(config, base_financials = NULL, plants_raw = NULL, trade_raw = NULL,
                         tl3_typology = NULL, exchange_rates = NULL) {
  ct <- config$country
  rep <- new_check_rows()
  add <- function(dataset, variable, check, result, detail, priority = "") {
    rep <<- rbind(rep, data.frame(dataset = dataset, variable = variable, priority = priority, check = check,
                                  result = result, detail = detail, stringsAsFactors = FALSE))
  }

  from_files <- is.null(base_financials)
  if (from_files) {
    path <- function(f) file.path(config$input_dir, f)
    files <- c(base_financials = paste0("base_financials_", ct, ".dta"), plants_RAW = paste0("plants_RAW_", ct, ".dta"),
               trade_RAW = paste0("trade_RAW_", ct, ".dta"))
    if (!file.exists(path(files[["base_financials"]]))) {
      add("base_financials", "", "file", "error", sprintf("%s not found in input_dir.", files[["base_financials"]]))
      return(finish_check(rep, ct))
    }
    base_financials <- read_check_columns(path(files[["base_financials"]]), "base_financials")
    add("base_financials", "", "file", "ok", sprintf("%s read.", files[["base_financials"]]))
    if (file.exists(path(files[["plants_RAW"]]))) {
      plants_raw <- read_check_columns(path(files[["plants_RAW"]]), "plants_RAW")
    } else {
      add("plants_RAW", "", "file", "note", sprintf("%s not found: optional, no multiplant indicator.", files[["plants_RAW"]]))
    }
    if (file.exists(path(files[["trade_RAW"]]))) {
      trade_raw <- read_check_columns(path(files[["trade_RAW"]]), "trade_RAW")
    } else {
      add("trade_RAW", "", "file", "note", sprintf("%s not found: needed for the trade package only.", files[["trade_RAW"]]))
    }
    if (file.exists(path("tl3_typology.dta"))) tl3_typology <- haven::read_dta(path("tl3_typology.dta"))
    if (file.exists(path("exchange_rates.dta"))) exchange_rates <- haven::read_dta(path("exchange_rates.dta"))
  }
  ref_name <- function(x) if (from_files) paste0(x, ".dta in input_dir") else sprintf("the `%s` argument", x)
  plain <- function(d) {
    d <- as.data.frame(d)
    for (v in names(d)) if (inherits(d[[v]], "haven_labelled")) d[[v]] <- haven::zap_labels(d[[v]])
    d
  }

  bf <- plain(base_financials)
  rep <- rbind(rep, check_variables(bf, "base_financials"))
  check_base_panel(bf, config, add, tl3_typology, exchange_rates, ref_name)
  if (!is.null(plants_raw)) {
    pl <- plain(plants_raw)
    rep <- rbind(rep, check_variables(pl, "plants_RAW"))
    check_linked_firms(pl, bf, "plants_RAW", add, "plant records whose firm is not in base_financials (not used)")
  }
  if (!is.null(trade_raw)) {
    tr <- plain(trade_raw)
    rep <- rbind(rep, check_variables(tr, "trade_RAW"))
    check_linked_firms(tr, bf, "trade_RAW", add, "trade records whose firm-year is not in base_financials (dropped)",
                       by_year = TRUE)
    check_trade_unit(tr, bf, config, add)
  }
  finish_check(rep, ct)
}

new_check_rows <- function() {
  data.frame(dataset = character(), variable = character(), priority = character(), check = character(),
             result = character(), detail = character(), stringsAsFactors = FALSE)
}

finish_check <- function(rep, country) {
  rep <- dplyr::as_tibble(rep)
  attr(rep, "country") <- country
  class(rep) <- c("scaleup_input_check", class(rep))
  print(rep)
  invisible(rep)
}

#' @export
print.scaleup_input_check <- function(x, ...) {
  n <- table(factor(x$result, c("error", "warning", "note", "ok")))
  cat(sprintf("Input check for %s: %d error(s), %d warning(s), %d note(s); %d check(s) ok.\n",
              attr(x, "country"), n[["error"]], n[["warning"]], n[["note"]], n[["ok"]]))
  for (r in c("error", "warning", "note")) {
    s <- x[x$result == r, ]
    if (!nrow(s)) next
    cat(sprintf("\n%s:\n", c(error = "Errors (the build stops)", warning = "Warnings", note = "Notes")[[r]]))
    lab <- ifelse(s$variable == "", s$dataset, paste0(s$dataset, "$", s$variable))
    cat(paste0("  ", format(lab), "  ", s$detail), sep = "\n")
  }
  invisible(x)
}

# Read only the columns the checks use (the whole file of a large panel need not be in memory).
read_check_columns <- function(file, dataset) {
  have <- names(haven::read_dta(file, n_max = 0))
  want <- c(variable_dictionary$variable[variable_dictionary$dataset == dataset],
            if (dataset == "base_financials") "age_cat")
  haven::read_dta(file, col_select = dplyr::all_of(intersect(have, want)))
}

is_missing_value <- function(x) {
  if (is.character(x)) is.na(x) | x %in% c("", ".") else is.na(x)
}

pct <- function(k, n) if (n == 0) "0 %" else sprintf("%s %%", format(round(100 * k / n, 1), nsmall = 1))
count_share <- function(k, n) sprintf("%s of %s (%s)", format(k, big.mark = ","), format(n, big.mark = ","), pct(k, n))

# Columns the build stops on when their type is wrong (build_accounts_core() step 4, build_trade_panel()).
type_stops_build <- list(
  base_financials = c("idf", "year", "sector_3d", "sector_2d", "employment", "turnover", "birth_year",
                      "region_2d", "sector_1d"),
  trade_RAW = c("idf", "year", "trade_value", "trade_type", "code_destin", "prod_code")
)

check_variables <- function(data, dataset) {
  dict <- variable_dictionary[variable_dictionary$dataset == dataset, ]
  out <- new_check_rows()
  add <- function(v, prio, check, result, detail) {
    out <<- rbind(out, data.frame(dataset = dataset, variable = v, priority = prio, check = check, result = result,
                                  detail = detail, stringsAsFactors = FALSE))
  }
  n <- nrow(data)
  for (i in seq_len(nrow(dict))) {
    v <- dict$variable[i]
    prio <- dict$priority[i]
    req <- dict$package_requirement[i]
    required <- startsWith(req, "required")
    if (!v %in% names(data)) {
      if (v == "birth_year" && has_column(data, "age_cat")) {
        add(v, prio, "presence", "note", "absent: age_cat is used for age and entry instead.")
      } else if (required) {
        add(v, prio, "presence", "error",
            if (v == "birth_year") "absent, and no age_cat either: the build needs one of them." else "absent: the build needs it.")
      } else {
        add(v, prio, "presence", "note", sprintf("absent (%s; package: %s).", prio, req))
      }
      next
    }
    x <- data[[v]]
    rows_of <- "rows"
    if (v == "code_destin" && is.numeric(data$trade_type)) {
      x <- x[as.double(data$trade_type) %in% 2] # imports have no destination
      rows_of <- "export rows"
      if (!length(x)) next
    }
    want_num <- dict$format[i] == "numeric"
    if (want_num != is.numeric(x)) {
      stops <- v %in% type_stops_build[[dataset]]
      add(v, prio, "type", if (stops) "error" else "warning",
          sprintf("is %s, expected %s%s.", if (is.numeric(x)) "numeric" else "a string",
                  if (want_num) "numeric" else "a string", if (stops) ": the build stops" else ""))
      next
    }
    miss <- is_missing_value(x)
    if (all(miss)) {
      add(v, prio, "values", if (required) "error" else "warning",
          sprintf("present but missing in every row: %s.", if (required) "the build needs values" else "treated as absent"))
      next
    }
    add(v, prio, "missing", if (any(miss)) "note" else "ok",
        if (any(miss)) sprintf("missing in %s %s.", count_share(sum(miss), length(x)), rows_of) else "no missing values.")
    xv <- x[!miss]
    if (dict$negatives_missing[i]) {
      k <- sum(xv < 0)
      if (k) add(v, prio, "negative", "note", sprintf("negative in %s non-missing rows: set to missing by the build.",
                                                     count_share(k, length(xv))))
    }
    if (grepl("^1 = .*0 = ", dict$coding[i]) || v %in% c("exit", "exit_acq", "exit_close", "independent", "hq")) {
      k <- sum(!as.double(xv) %in% c(0, 1))
      if (k) add(v, prio, "coding", "warning", sprintf("values other than 0 and 1 in %s non-missing rows.",
                                                       count_share(k, length(xv))))
    }
    pattern <- switch(v,
      uco = , code_destin = "^[A-Z]{2}$",
      region_2d = , p_region_2d = "^[A-Z]{2}[A-Z0-9]{2}$",
      region_3d = , p_region_3d = "^[A-Z]{2}[A-Z0-9]{3}$",
      sector_1d = "^[A-V]$",
      NULL
    )
    if (!is.null(pattern)) {
      k <- sum(!grepl(pattern, xv))
      if (k) add(v, prio, "codes", "warning", sprintf("not of the expected form (%s) in %s non-missing rows.",
                                                      code_form(v), count_share(k, length(xv))))
    }
  }
  if (dataset == "trade_RAW" && "trade_type" %in% names(data) && is.numeric(data$trade_type)) {
    tt <- as.double(data$trade_type)
    if (anyNA(tt)) add("trade_type", MUST_PRIORITY, "coding", "error",
                       sprintf("missing in %s rows: the build stops.", count_share(sum(is.na(tt)), n)))
    if (!any(tt %in% c(1, 2))) {
      add("trade_type", MUST_PRIORITY, "coding", "error", "neither imports (1) nor exports (2): the build stops.")
    } else {
      for (t in c(1, 2)) if (!any(tt %in% t)) {
        add("trade_type", MUST_PRIORITY, "coding", "warning",
            sprintf("no %s (%d) at all: their variables are missing for every firm.", c("imports", "exports")[t], t))
      }
      k <- sum(!is.na(tt) & !tt %in% c(1, 2))
      if (k) add("trade_type", MUST_PRIORITY, "coding", "warning",
                 sprintf("values other than 1 and 2 in %s rows: not used.", count_share(k, n)))
    }
  }
  if (dataset == "trade_RAW" && "prod_code" %in% names(data) && is.character(data$prod_code)) {
    pc <- data$prod_code[!is_missing_value(data$prod_code)]
    k <- sum(!grepl("^[0-9]{8}$", trimws(pc)))
    if (k) add("prod_code", MUST_PRIORITY, "codes", "note",
               sprintf("not an 8-digit CN code in %s non-missing rows (the first 6 characters are used).",
                       count_share(k, length(pc))))
  }
  out
}
MUST_PRIORITY <- "must-have"

# The message of a build error (rlang bullets) on one line
one_line <- function(cnd) {
  m <- c(rlang::cnd_header(cnd), rlang::cnd_body(cnd))
  paste(trimws(gsub("\\s+", " ", m[nzchar(m)])), collapse = " ")
}

code_form <- function(v) {
  switch(v, uco = , code_destin = "two capital letters, e.g. SE",
         region_2d = , p_region_2d = "NUTS2, e.g. FR10", region_3d = , p_region_3d = "NUTS3, e.g. FR101",
         sector_1d = "one section letter A-V", "")
}

check_base_panel <- function(bf, config, add, tl3_typology, exchange_rates, ref_name) {
  B <- "base_financials"
  n <- nrow(bf)
  ok_num <- function(v) v %in% names(bf) && is.numeric(bf[[v]])
  if (ok_num("idf") && ok_num("year")) {
    k <- sum(duplicated(bf[c("idf", "year")]))
    add(B, "", "panel", if (k) "error" else "ok",
        if (k) sprintf("%s duplicate (idf, year) rows: a firm may appear only once per year.", format(k, big.mark = ","))
        else "one row per firm and year.")
    yr <- as.double(bf$year)
    add(B, "", "panel", "note", sprintf("%s firm-years of %s firms, years %s to %s.", format(n, big.mark = ","),
                                        format(length(unique(bf$idf)), big.mark = ","),
                                        min(yr, na.rm = TRUE), max(yr, na.rm = TRUE)))
  }
  if (ok_num("sector_2d") && ok_num("year")) {
    s2 <- as.double(bf$sector_2d)
    rev21 <- if (identical(config$nace_revision, "2.1")) rep(TRUE, n) else if (!is.null(config$nace_rev21_from)) {
      !is.na(bf$year) & as.double(bf$year) >= config$nace_rev21_from
    } else rep(FALSE, n)
    known <- !is.na(s2)
    div_ok <- ifelse(rev21, !is.na(nace_section(s2, "2.1")), !is.na(nace_section(s2, "2")))
    k <- sum(known & !div_ok)
    if (k) add(B, "sector_2d", "codes", "warning",
               sprintf("not a NACE division of the declared revision in %s non-missing rows (no sector group).",
                       count_share(k, sum(known))), MUST_PRIORITY)
    if (ok_num("sector_3d")) {
      s3 <- as.double(bf$sector_3d)
      both <- known & !is.na(s3)
      k <- sum(both & floor(s3 / 10) != s2)
      if (k) add(B, "sector_3d", "codes", "warning",
                 sprintf("group not within its division (sector_3d %%/%% 10 != sector_2d) in %s rows with both.",
                         count_share(k, sum(both))), MUST_PRIORITY)
    }
    if ("sector_1d" %in% names(bf) && is.character(bf$sector_1d)) {
      d <- bf[c("year", "sector_1d", "sector_2d")]
      d$sector_3d <- if (ok_num("sector_3d")) bf$sector_3d else NA_real_
      res <- tryCatch({ nace_to_rev2(d, config); NULL }, OECDscaleup_data_error = function(e) e)
      if (is.null(res)) {
        add(B, "sector_1d", "revision", "ok", sprintf("section letters match their divisions under NACE Rev. %s%s.",
                                                     config$nace_revision,
                                                     if (is.null(config$nace_rev21_from)) "" else sprintf(" (Rev. 2.1 from %d)", config$nace_rev21_from)),
            MUST_PRIORITY)
      } else {
        add(B, "sector_1d", "revision", "error", one_line(res), MUST_PRIORITY)
      }
      s1 <- bf$sector_1d
      s1[s1 %in% c(".", "")] <- NA
      # the exclusion works on Rev. 2 codes; in Rev. 2.1 the excluded divisions are the same
      k <- sum(nace_excluded(s1, s2) & !(rev21 & is.na(s2)))
      add(B, "", "sectors", "note", sprintf("%s firm-years in sectors the analysis leaves out (agriculture, finance, public administration, households, extraterritorial).",
                                            count_share(k, n)))
    }
  }
  if (ok_num("birth_year") && ok_num("year")) {
    k <- sum(!is.na(bf$birth_year) & !is.na(bf$year) & bf$birth_year > bf$year)
    if (k) add(B, "birth_year", "values", "warning", sprintf("after year in %s rows (negative age, set to missing).",
                                                             count_share(k, n)), MUST_PRIORITY)
  }
  if (ok_num("employment") && ok_num("turnover")) {
    d <- data.frame(employment = as.double(bf$employment), turnover = as.double(bf$turnover))
    d$turnover[!is.na(d$turnover) & d$turnover < 0] <- NA
    if (identical(config$financials_unit, "EUR")) d$turnover <- d$turnover / 1000
    small <- sum(!is.na(d$employment) & d$employment >= 10 & d$employment < 50 & !is.na(d$turnover))
    res <- tryCatch({ check_financials_unit(d, config); NULL }, OECDscaleup_data_error = function(e) e)
    unit <- sprintf("financials_unit = \"%s\"%s", config$financials_unit,
                    if (isTRUE(config$financials_unit_default)) " (the default for this country)" else "")
    if (!is.null(res)) {
      add(B, "turnover", "unit", "error", one_line(res), MUST_PRIORITY)
    } else if (small < 30) {
      add(B, "turnover", "unit", "note", sprintf("too few firm-years with 10-49 employees to check the money unit (%s).", unit),
          MUST_PRIORITY)
    } else {
      add(B, "turnover", "unit", "ok", sprintf("turnover per employee fits EUR thousand with %s.", unit), MUST_PRIORITY)
    }
  }
  if (has_column(bf, "region_3d") && is.character(bf$region_3d)) {
    P1 <- "nice-to-have, first order"
    cls <- if (is.null(config$tl_classification)) "TL2024" else config$tl_classification
    r3 <- bf$region_3d[!is_missing_value(bf$region_3d)]
    if (is.null(tl3_typology)) {
      # the package's table: report the match under both classifications
      pkg <- OECDscaleup::tl3_typology
      share_in <- function(k) count_share(sum(r3 %in% pkg$region_3d[pkg$classification == k]), length(r3))
      miss <- vapply(c("TL2024", "TL2021"), function(k) sum(!r3 %in% pkg$region_3d[pkg$classification == k]), 0)
      src <- sprintf("the package's %s typology (OECD territorial correspondence table, version of 20 November 2026)", cls)
      add(B, "region_3d", "reference", if (miss[[cls]]) "warning" else "ok",
          if (miss[[cls]]) sprintf("not in %s in %s non-missing rows (no urban/rural type).", src, count_share(miss[[cls]], length(r3)))
          else sprintf("every region_3d is in %s.", src), P1)
      add(B, "region_3d", "reference", "note", sprintf("region codes found in TL2024: %s; in TL2021: %s.",
                                                       share_in("TL2024"), share_in("TL2021")), P1)
      other <- setdiff(c("TL2024", "TL2021"), cls)
      if (miss[[other]] < miss[[cls]]) {
        add(B, "region_3d", "reference", "warning",
            sprintf("more region codes are found in %s than in the declared %s: set tl_classification = \"%s\" in config_scaleup() if the data use %s codes.",
                    other, cls, other, other), P1)
      }
    } else {
      tl <- tl3_for_config(tl3_typology, config)
      k <- sum(!r3 %in% as.character(tl$region_3d))
      add(B, "region_3d", "reference", if (k) "warning" else "ok",
          if (k) sprintf("not in the TL3 typology of %s in %s non-missing rows (no urban/rural type).", ref_name("tl3_typology"),
                         count_share(k, length(r3)))
          else sprintf("every region_3d is in the TL3 typology of %s.", ref_name("tl3_typology")), P1)
      if (!"classification" %in% names(tl3_typology)) {
        add(B, "region_3d", "reference", "warning",
            sprintf("%s is used instead of the package's TL2024/TL2021 typology; it has no `classification` column (a table of an earlier release?). Remove it to use the package's table (version of 20 November 2026).",
                    ref_name("tl3_typology")), P1)
      }
    }
  }
  if (config$country %in% country_patches$non_euro && ok_num("year")) {
    rates <- rates_or_default(exchange_rates)
    src <- if (is.null(exchange_rates)) "the package's exchange rates (2008-2025)" else ref_name("exchange_rates")
    if (!is.null(exchange_rates)) {
      add(B, "", "reference", "note", sprintf("%s is used instead of the package's exchange rates (2008-2025).", src))
    }
    have <- as.double(rates$year[rates$country == config$country & !is.na(rates$rate)])
    yrs <- sort(unique(as.double(bf$year)))
    gap <- setdiff(yrs, have)
    add(B, "", "reference", if (length(gap)) "warning" else "ok",
        if (length(gap)) sprintf("no exchange rate for %s in %s (%s): turnover growth is missing there.", config$country,
                                 paste(gap, collapse = ", "), src)
        else sprintf("%s cover every year.", src))
  }
}

check_linked_firms <- function(data, bf, dataset, add, what, by_year = FALSE) {
  if (!all(c("idf", "year") %in% names(data)) || !all(c("idf", "year") %in% names(bf))) return(invisible())
  key <- if (by_year) list(as.double(data$idf), as.double(data$year)) else list(as.double(data$idf))
  bkey <- if (by_year) list(as.double(bf$idf), as.double(bf$year)) else list(as.double(bf$idf))
  k <- sum(is.na(collapse::fmatch(key, bkey)))
  add(dataset, "idf", "link", if (k) "note" else "ok",
      if (k) sprintf("%s: %s.", what, count_share(k, nrow(data))) else "every record links to base_financials.",
      MUST_PRIORITY)
}

# Exports next to turnover: summed per firm-year in the declared units, a median above 10 times turnover
# among exporters means trade values are in euros, not EUR thousand.
check_trade_unit <- function(tr, bf, config, add) {
  need <- c("idf", "year", "trade_type", "trade_value")
  if (!all(need %in% names(tr)) || !all(vapply(tr[need], is.numeric, TRUE)) ||
      !all(c("idf", "year", "turnover") %in% names(bf)) || !is.numeric(bf$turnover)) return(invisible())
  ex <- tr[as.double(tr$trade_type) %in% 2 & !is.na(tr$trade_value), c("idf", "year", "trade_value")]
  if (!nrow(ex)) return(invisible())
  ex <- stats::aggregate(list(exports = as.double(ex$trade_value)), list(idf = as.double(ex$idf), year = as.double(ex$year)), sum)
  if (identical(config$trade_value_unit, "EUR")) ex$exports <- ex$exports / 1000
  to <- as.double(bf$turnover)
  if (identical(config$financials_unit, "EUR")) to <- to / 1000
  tm <- to[collapse::fmatch(list(ex$idf, ex$year), list(as.double(bf$idf), as.double(bf$year)))]
  ok <- !is.na(tm) & tm > 0
  ratio <- ex$exports[ok] / tm[ok]
  unit <- sprintf("trade_value_unit = \"%s\"", config$trade_value_unit)
  if (length(ratio) < 30) {
    add("trade_RAW", "trade_value", "unit", "note", sprintf("too few exporters with turnover to check the unit (%s).", unit), MUST_PRIORITY)
  } else if (stats::median(ratio) > 10) {
    add("trade_RAW", "trade_value", "unit", "warning",
        sprintf("the median exporter exports more than 10 times its turnover (%s): trade values look like euros; set trade_value_unit = \"EUR\".", unit),
        MUST_PRIORITY)
  } else {
    add("trade_RAW", "trade_value", "unit", "ok", sprintf("exports fit EUR thousand next to turnover (%s).", unit), MUST_PRIORITY)
  }
}
