#' OECD regional typology of small (TL3) regions
#'
#' The OECD territorial classification of small (TL3) regions, with their
#' typologies. [build_accounts_indicators()] joins it to `region_3d` to give
#' the urban/rural breakdown `typology_UR` (from the access-to-cities
#' typology), for the classification declared in
#' `config_scaleup(tl_classification = )`: `"TL2024"` (the default; NUTS 2024
#' for EU countries) or `"TL2021"` (NUTS 2021).
#'
#' **Version.** Package version 0.2.0.9000 ships the OECD territorial
#' correspondence table TL2024, version of **20 November 2026**: its TL2024
#' regions (2,628 TL3 regions in 49 countries) and its TL2021 regions (2,598
#' regions in 44 countries). The OECD revises the typologies in this table: the access-to-cities
#' typology of non-metropolitan regions in EU countries and of non-EU countries
#' was still being updated in that version, and Türkiye has no access-to-cities
#' typology in TL2024 (commuting data are not available). Version 0.1.0 shipped
#' the TL2021 table of the earlier routines (the same 2,598 regions and
#' typology). See `vignette("input-data")` for the versions by package version.
#'
#' Between TL2021 and TL2024 the TL3 codes changed in Germany, Finland, the
#' United Kingdom, Latvia, the Netherlands, Norway and Portugal, and the
#' access-to-cities typology of about 200 regions changed (most in Germany and
#' Türkiye). `check_inputs()` reports how many region codes of the data match
#' each classification.
#'
#' A `tl3_typology.dta` in the input folder replaces this table in
#' [run_scaleup_pipeline()] and [run_trade_pipeline()]; a table without a
#' `classification` column is used as it is.
#'
#' @format A data frame, one row per classification and TL3 region:
#' \describe{
#'   \item{classification}{`"TL2024"` or `"TL2021"`.}
#'   \item{iso3}{3-letter ISO country code.}
#'   \item{region_3d}{TL3 region code (the NUTS 3 code for EU countries): the
#'     key joined to `region_3d`.}
#'   \item{region_name}{Region name (English).}
#'   \item{tl3c_id}{TL2024 only: the aggregated metropolitan region (TL3C)
#'     the region belongs to; the OECD advises aggregating to it when several
#'     TL3 regions form one metropolitan region.}
#'   \item{typology_access_level1}{Access to cities, level 1: `MR`
#'     (metropolitan region) or `NM` (non-metropolitan).}
#'   \item{typology_access_cities}{Access to cities, level 2: `MR_L`
#'     (metropolitan, functional urban area above 1.5 million inhabitants),
#'     `MR_M` (metropolitan, 250,000 to 1.5 million), `NMR_M` (near a
#'     functional urban area above 250,000), `NMR_S` (near a functional urban
#'     area of 50,000 to 250,000), `NMR_R` (remote); `..` not available. The
#'     column the package uses.}
#'   \item{typology_rural_urban}{The earlier rural/urban typology: `3_PU`
#'     predominantly urban, `3_IN` intermediate, `3_PR` predominantly rural.}
#'   \item{typology_rural_urban_extended}{TL2024 only: the extended rural/urban
#'     typology (close to a city or remote), for some countries.}
#' }
#' @source OECD territorial correspondence table TL2024 (version of 20 November
#'   2026), OECD geographical definitions,
#'   \url{https://www.oecd.org/en/data/datasets/oecd-geographical-definitions.html}
#'   (\url{http://oe.cd/geostats}). Built by `data-raw/prepare-reference-data.R`.
"tl3_typology"

#' Annual average euro exchange rates
#'
#' Annual averages of the euro exchange rate (units of national currency per
#' euro) for the non-euro countries in `country_patches$non_euro`: Canada
#' (CAD), Denmark (DKK), Croatia (HRK), Hungary (HUF) and Romania (RON).
#' [build_accounts_indicators()] converts `turnover` to national currency with
#' them before computing turnover growth, so that growth rates are not moved
#' by the exchange rate. Without a rate for a year, the turnover growth of that
#' year is missing; `check_inputs()` reports such years.
#'
#' **Version.** Package version 0.2.0.9000 covers **2008-2025**:
#' * CAD, DKK, HUF, RON: Eurostat `ert_bil_eur_a`, as extracted from the update
#'   of 8 July 2026;
#' * HRK: Croatia adopted the euro on 1 January 2023, and Eurostat no longer
#'   publishes the kuna series. 2008-2022: the ECB annual averages (series
#'   `EXR.A.HRK.EUR.SP00.A`, the source of the Eurostat series), rounded to 4
#'   decimals; from 2023: the fixed conversion rate 7.53450, so that turnover
#'   growth over windows ending in 2023 or later equals growth in euros.
#'
#' Version 0.1.0 shipped the rates of the earlier routines, 2008-2022 (the same
#' Eurostat values for CAD, DKK, HUF and RON; for HRK values within 0.02 % of the
#' ECB averages). See `vignette("input-data")` for the versions by package
#' version.
#'
#' An `exchange_rates.dta` in the input folder replaces this table in
#' [run_scaleup_pipeline()] and [run_trade_pipeline()].
#'
#' @format A data frame with one row per currency and year:
#' \describe{
#'   \item{currency}{3-letter currency code (e.g. `"HUF"`).}
#'   \item{year}{Calendar year.}
#'   \item{rate}{Annual average, units of national currency per euro.}
#'   \item{country}{2-letter country code, joined with `year` to the data.}
#' }
#' @source Eurostat, `ert_bil_eur_a`,
#'   \url{https://ec.europa.eu/eurostat/databrowser/view/ERT_BIL_EUR_A/default/table?lang=en};
#'   ECB, \url{https://data.ecb.europa.eu/data/datasets/EXR}. Built by
#'   `data-raw/prepare-reference-data.R`.
"exchange_rates"

#' Variable dictionary of the input data
#'
#' The input variables the OECD Scale Up project asks for, one row per
#' variable of each input file: the firm-level panel `base_financials`, the
#' optional establishment file `plants_RAW` and, for the trade package, the
#' transaction-level `trade_RAW`. It carries the OECD variable dictionary
#' (definitions, formats, codings, sources, priorities and notes) and adds
#' what this package does with each variable. `vignette("input-data")` and
#' `vignette("input-trade-data")` are built from it.
#'
#' @format A data frame with one row per dataset and variable:
#' \describe{
#'   \item{dataset}{`"base_financials"`, `"plants_RAW"` or `"trade_RAW"`.}
#'   \item{file}{File name the pipeline reads from `input_dir`; `<CT>` is
#'     the two-letter country code of [config_scaleup()].}
#'   \item{variable}{Variable name, as the pipeline expects it.}
#'   \item{definition}{What the variable measures.}
#'   \item{format}{`"numeric"` or `"string"`.}
#'   \item{coding}{Values of an indicator or code variable.}
#'   \item{source}{Usual statistical source: BR (business register), BD
#'     (business demography), SBS (structural business statistics), ITGS /
#'     ITSS (international trade in goods / services statistics), IFATS
#'     (inward foreign affiliates statistics), EuroGroups register.}
#'   \item{sbs_code}{SBS variable code, where there is one.}
#'   \item{priority}{The OECD request: `"must-have"`, `"nice-to-have, first
#'     order"` or `"nice-to-have, second order"`.}
#'   \item{notes}{Further notes of the OECD dictionary.}
#'   \item{package_requirement}{What the package needs: `"required"` (the
#'     build stops without it), `"required unless age_cat is supplied"`,
#'     `"required (if the file is supplied)"`, `"optional"` (used when
#'     present) or `"not used"`.}
#'   \item{package_use}{What the package does with the variable.}
#'   \item{money}{`TRUE` for money variables, expected in EUR thousand and
#'     divided by 1000 when `financials_unit = "EUR"` (for `trade_value`:
#'     `trade_value_unit = "EUR"`).}
#'   \item{negatives_missing}{`TRUE` if the build sets negative values to
#'     missing.}
#' }
#' @source OECD Scale Up project variable dictionary (Phase 3); the package
#'   columns from this package's code. Built by `data-raw/variable_dictionary.R`.
"variable_dictionary"
