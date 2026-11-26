#' Simulate example input data
#'
#' Generates a fabricated firm-level panel in the format of the input files
#' (see `vignette("input-data")` and `vignette("input-trade-data")`), large
#' enough for every part of the package to produce output: firms that enter
#' and exit, high-growth episodes, a few firms that grow past 250 employees,
#' plants, exports and imports. Used in `vignette("OECDscaleup")`; useful to
#' try the package without confidential data.
#'
#' The data are random and mean nothing: the sizes, growth rates and ratios
#' are only roughly plausible. The country is France (`"FR"`), so the region
#' codes are real French NUTS codes that link to [tl3_typology].
#'
#' @param n_firms Number of firms.
#' @param years Calendar years of the panel (consecutive).
#' @param seed Random seed; the same seed gives the same data. The global
#'   random number stream is left as it was.
#' @return A list of three data frames:
#'   * `base_financials`: one row per firm and year (`idf`, `year`,
#'     `birth_year`, sector, region, employment and the financial
#'     variables, `independent`, `uco`, `exit_acq`); money in EUR thousand;
#'   * `plants_raw`: one row per plant and year (`idf`, `idp`, `year`);
#'   * `trade_raw`: one row per firm, year, flow, destination and product
#'     (`idf`, `year`, `trade_type`, `trade_value`, `code_destin`,
#'     `prod_code`).
#' @examples
#' ex <- example_scaleup_data(n_firms = 200)
#' sapply(ex, nrow)
#' head(ex$base_financials)
#' @export
example_scaleup_data <- function(n_firms = 3000, years = 2010:2022, seed = 1) {
  stopifnot(n_firms >= 1, length(years) >= 2, all(diff(years) == 1))
  if (exists(".Random.seed", envir = globalenv())) {
    old_seed <- get(".Random.seed", envir = globalenv())
    on.exit(assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
  } else {
    on.exit(rm(".Random.seed", envir = globalenv()), add = TRUE)
  }
  set.seed(seed)
  y0 <- min(years)
  y1 <- max(years)

  # ---- firms ------------------------------------------------------------------
  divisions <- c(10, 20, 22, 25, 26, 28, 41, 43, 46, 47, 49, 55, 56, 62, 68, 70, 71, 73, 86, 96, 1, 64)
  div_weight <- c(5, 2, 3, 5, 2, 3, 6, 6, 8, 9, 4, 4, 6, 4, 3, 4, 4, 2, 3, 3, 1, 1)
  typ <- tl3_typology[tl3_typology$iso3 == "FRA" & tl3_typology$typology_access_cities %in%
                        c("MR-L", "MR-M", "NMR-M", "NMR-S", "NMR-R"), c("region_3d", "typology_access_cities")]
  typ <- typ[order(typ$region_3d), ]
  regions <- unlist(lapply(split(typ$region_3d, typ$typology_access_cities), function(r) r[seq_len(min(2, length(r)))]),
                    use.names = FALSE)

  incumbent <- stats::runif(n_firms) < 0.7
  start <- ifelse(incumbent, y0, sample(years[-1], n_firms, replace = TRUE))
  life <- stats::rgeom(n_firms, 0.06) + 2
  end <- pmin(y1, start + life - 1)
  firms <- data.frame(
    idf = seq_len(n_firms),
    start = start, end = end,
    birth_year = ifelse(incumbent, y0 - sample(1:30, n_firms, replace = TRUE), start),
    sector_2d = sample(divisions, n_firms, replace = TRUE, prob = div_weight),
    region_3d = sample(regions, n_firms, replace = TRUE),
    emp0 = pmax(1, stats::rlnorm(n_firms, log(ifelse(incumbent, 12, 4)), 1.1)),
    drift = stats::rnorm(n_firms, 0.01, 0.03),
    prod = stats::rlnorm(n_firms, log(120), 0.5),
    hg_start = ifelse(stats::runif(n_firms) < 0.15, sample(years, n_firms, replace = TRUE), NA),
    hg_len = sample(3:4, n_firms, replace = TRUE),
    va_share = stats::runif(n_firms, 0.25, 0.45),
    wage_share = stats::runif(n_firms, 0.5, 0.8),
    capital = stats::runif(n_firms, 0.1, 0.8),
    leverage = stats::runif(n_firms, 0.3, 0.8),
    independent = as.integer(stats::runif(n_firms) < 0.8),
    uco = sample(c("FR", "DE", "US", "NL"), n_firms, replace = TRUE, prob = c(0.85, 0.06, 0.05, 0.04)),
    plants = ifelse(stats::runif(n_firms) < 0.85, 1L, sample(2:5, n_firms, replace = TRUE)),
    acquired = stats::runif(n_firms) < 0.03
  )
  firms$sector_1d <- nace_section(firms$sector_2d, "2")
  firms$sector_3d <- firms$sector_2d * 10 + 1
  firms$region_2d <- substr(firms$region_3d, 1, 4)

  # ---- firm-years -----------------------------------------------------------------
  n_years <- firms$end - firms$start + 1
  bf <- firms[rep(seq_len(n_firms), n_years), ]
  bf$year <- bf$start + stats::ave(bf$idf, bf$idf, FUN = seq_along) - 1
  first <- bf$year == bf$start
  hg <- !is.na(bf$hg_start) & bf$year > bf$hg_start & bf$year <= bf$hg_start + bf$hg_len
  g_emp <- ifelse(first, 0, ifelse(hg, stats::rnorm(nrow(bf), 0.30, 0.05), stats::rnorm(nrow(bf), bf$drift, 0.12)))
  g_to <- ifelse(first, 0, g_emp + stats::rnorm(nrow(bf), 0.01, 0.08))
  bf$employment <- round(pmax(1, bf$emp0 * exp(stats::ave(g_emp, bf$idf, FUN = cumsum))), 1)
  bf$turnover <- round(bf$emp0 * bf$prod * exp(stats::ave(g_to, bf$idf, FUN = cumsum)), 1)
  bf$added_value <- round(bf$turnover * bf$va_share, 1)
  bf$labour_costs <- round(bf$added_value * bf$wage_share, 1)
  bf$tangible_fixed_assets <- round(bf$turnover * bf$capital, 1)
  bf$depr_amort <- round(bf$tangible_fixed_assets * 0.1, 1)
  bf$cash_flow <- round(bf$added_value - bf$labour_costs - bf$depr_amort * 0.5, 1)
  bf$current_assets <- round(bf$turnover * 0.4, 1)
  bf$total_assets <- round(bf$tangible_fixed_assets + bf$current_assets, 1)
  bf$total_liabilities <- round(bf$total_assets * bf$leverage, 1)
  bf$interest_costs <- round(bf$total_liabilities * 0.03, 1)
  bf$exit_acq <- as.integer(bf$acquired & bf$year == bf$end & bf$end < y1)
  # some missing financial values, as in real data
  for (v in c("added_value", "labour_costs", "tangible_fixed_assets", "depr_amort", "cash_flow", "total_assets")) {
    bf[[v]][stats::runif(nrow(bf)) < 0.05] <- NA
  }
  bf$uco[stats::runif(nrow(bf)) < 0.02] <- "."
  base_financials <- bf[c("idf", "year", "birth_year", "sector_1d", "sector_2d", "sector_3d", "region_2d", "region_3d",
                          "employment", "turnover", "added_value", "labour_costs", "tangible_fixed_assets", "depr_amort",
                          "cash_flow", "current_assets", "total_assets", "total_liabilities", "interest_costs",
                          "independent", "uco", "exit_acq")]
  rownames(base_financials) <- NULL

  # ---- plants -------------------------------------------------------------------------
  pl <- bf[rep(seq_len(nrow(bf)), bf$plants), c("idf", "year")]
  pl$idp <- pl$idf * 10 + stats::ave(pl$idf, pl$idf, pl$year, FUN = seq_along)
  plants_raw <- pl[c("idf", "idp", "year")]
  rownames(plants_raw) <- NULL

  # ---- trade ------------------------------------------------------------------------
  manuf <- firms$sector_2d < 35
  exporter <- stats::runif(n_firms) < ifelse(manuf, 0.6, 0.15)
  importer <- stats::runif(n_firms) < ifelse(manuf, 0.7, 0.3)
  export_share <- stats::runif(n_firms, 0.05, 0.5)
  products <- sprintf("%08d", c(84213920, 85044083, 39269097, 73181595, 94036090, 30049000, 22030001, 87089997,
                                61091000, 90189084, 84798997, 48191000))
  partners <- c("DE", "BE", "IT", "ES", "NL", "PL", "US", "GB", "CN", "CH")
  flows <- function(type, who, share) {
    fy <- bf[who[bf$idf] & stats::runif(nrow(bf)) < 0.9, c("idf", "year", "turnover")]
    k <- sample(1:5, nrow(fy), replace = TRUE)
    tr <- fy[rep(seq_len(nrow(fy)), k), ]
    tr$trade_value <- round(tr$turnover * share[tr$idf] / rep(k, k) * stats::runif(nrow(tr), 0.5, 1.5), 3)
    data.frame(idf = tr$idf, year = tr$year, trade_type = type, trade_value = tr$trade_value,
               code_destin = if (type == 2) sample(partners, nrow(tr), replace = TRUE) else "",
               prod_code = sample(products, nrow(tr), replace = TRUE), stringsAsFactors = FALSE)
  }
  trade_raw <- rbind(flows(2, exporter, export_share), flows(1, importer, export_share * 0.8))
  trade_raw <- trade_raw[order(trade_raw$idf, trade_raw$year, trade_raw$trade_type), ]
  rownames(trade_raw) <- NULL

  list(base_financials = base_financials, plants_raw = plants_raw, trade_raw = trade_raw)
}
