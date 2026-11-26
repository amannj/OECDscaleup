# Reference data shipped with the package: versions, defaults and selection.
# Update these strings with data-raw/prepare-reference-data.R.
reference_data_versions <- list(
  tl3_typology = "OECD territorial correspondence table TL2024, version of 20 November 2026 (TL2024 and TL2021)",
  exchange_rates = "Eurostat ert_bil_eur_a, update of 8 July 2026, 2008-2025; HRK from the ECB to 2022, fixed rate 7.53450 from 2023"
)

# The TL3 typology the build uses: the table given (a tl3_typology.dta of the input folder or the
# `tl3_typology` argument), else the package's; the rows of the declared classification when the table
# has a `classification` column (the package's has TL2024 and TL2021).
tl3_for_config <- function(tl3, config) {
  if (is.null(tl3)) tl3 <- OECDscaleup::tl3_typology
  cls <- if (is.null(config$tl_classification)) "TL2024" else config$tl_classification
  if ("classification" %in% names(tl3)) tl3 <- tl3[tl3$classification == cls, ]
  tl3
}

# The exchange rates the build uses: the table given, else the package's.
rates_or_default <- function(rates) {
  if (is.null(rates)) OECDscaleup::exchange_rates else rates
}

# Access-to-cities codes are written MR-L (earlier tables) or MR_L (TL2024): one form
access_code <- function(x) gsub("_", "-", as.character(x), fixed = TRUE)
