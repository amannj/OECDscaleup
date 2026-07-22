#' TL3/NUTS3 region urbanisation typology
#'
#' Classifies TL3 (NUTS3-equivalent) regions by their access to cities, per
#' the OECD regional urban/rural typology. Supplied by the OECD alongside the
#' original Stata package (`Stata/tl3_typology.dta`); bundled here as-is
#' because it is small, non-confidential reference data (not firm microdata).
#' Used by [build_accounts_indicators()] to derive `typology_UR` when the raw
#' input data has a `region_3d` column.
#'
#' @format A data frame with 2,598 rows and 8 columns:
#' \describe{
#'   \item{iso3}{3-letter ISO country code.}
#'   \item{region_3d}{TL3/NUTS3 region code — the join key used by
#'     [build_accounts_indicators()].}
#'   \item{classificationlatesttl2021}{TL classification vintage.}
#'   \item{tl}{Territorial level (always `"3"` in this table).}
#'   \item{regionalnameeng}{Region name (English).}
#'   \item{regionalnamepublicationeng}{Region name with country/state suffix.}
#'   \item{typology_access_cities}{5-letter urbanisation code (`MR-L`, `MR-M`,
#'     `NMR-M`, `NMR-S`, `NMR-R`) — the column
#'     [build_accounts_indicators()] actually reads and remaps to readable
#'     labels.}
#'   \item{typology_UR}{An OECD-supplied labelled urban/rural code, unused by
#'     this package (which derives its own `typology_UR` from
#'     `typology_access_cities` instead — see
#'     `Pseudocode/n0_1_accounts_indicators_v2.md` step 18).}
#' }
#' @source OECD Scale Up project, `tl3_typology.dta` (`Stata/` in the
#'   original package).
"tl3_typology"

#' Annual average Eurostat exchange rates
#'
#' Annual average EUR exchange rates for the 5 non-Euro countries this
#' project covers, 2008-2022. Supplied by the OECD alongside the original
#' Stata package (`Stata/exchange_rates.dta`); bundled here as-is because it
#' is small, non-confidential reference data. Used by
#' [build_accounts_indicators()] to convert `turnover` to national currency
#' for the countries in `country_patches$non_euro`.
#'
#' @format A data frame with 75 rows and 4 columns:
#' \describe{
#'   \item{currency}{3-letter currency code (e.g. `"HRK"`).}
#'   \item{year}{Calendar year.}
#'   \item{rate}{Annual average units of national currency per EUR.}
#'   \item{country}{2-letter country code — the join key used by
#'     [build_accounts_indicators()], alongside `year`.}
#' }
#' @source Eurostat, via the OECD Scale Up project's `exchange_rates.dta`
#'   (`Stata/` in the original package). See
#'   \url{https://ec.europa.eu/eurostat/databrowser/view/ERT_BIL_EUR_A/default/table?lang=en}.
"exchange_rates"
