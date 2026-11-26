# Builds the package's reference data: `tl3_typology` (OECD regional typology) and `exchange_rates`
# (annual average euro exchange rates). Both are small, public lookup tables, not firm microdata.
# Run from the package root (readxl is needed; it is not a package dependency):
#   Rscript --no-init-file data-raw/prepare-reference-data.R "path/to/OECD Territorial correspondence - TL2024c.xlsx"
# After an update, change the version strings in R/reference-data.R, the documentation in R/data.R and
# the table of reference-data versions in vignettes/input-data.Rmd.

# ---- TL3 typology ------------------------------------------------------------------------------
# OECD territorial correspondence table, https://www.oecd.org/en/data/datasets/oecd-geographical-definitions.html
# (http://oe.cd/geostats). Used: version of 20 November 2026, sheets "Regions TL2024" and
# "Regions - TL2021"; small (TL3) regions only.
xlsx <- commandArgs(trailingOnly = TRUE)[1]
read_sheet <- function(sheet) as.data.frame(readxl::read_excel(xlsx, sheet = sheet, skip = 2, col_types = "text"))
col <- function(d, pattern) d[[grep(pattern, names(d))[1]]]

t24 <- read_sheet("Regions TL2024")
t24 <- t24[t24$TL %in% "3", ]
tl24 <- data.frame(
  classification = "TL2024",
  iso3 = t24$ISO3,
  region_3d = t24$REG_ID,
  region_name = col(t24, "^Name \\(publication-eng\\)"),
  tl3c_id = col(t24, "^TL3C_ID"),
  typology_access_level1 = col(t24, "^Access to city - Level 1"),
  typology_access_cities = col(t24, "^Access to city - Level 2"),
  typology_rural_urban = col(t24, "^Rural/urban typology"),
  typology_rural_urban_extended = col(t24, "^Extended rural/urban"),
  stringsAsFactors = FALSE
)

t21 <- read_sheet("Regions - TL2021")
t21 <- t21[t21$TL %in% "3", ]
acc21 <- col(t21, "^Typology access to functional urban areas")
tl21 <- data.frame(
  classification = "TL2021",
  iso3 = t21$ISO3,
  region_3d = t21$REG_ID,
  region_name = col(t21, "^Regional name \\(publication-eng\\)"),
  tl3c_id = NA_character_,
  typology_access_level1 = ifelse(startsWith(acc21, "MR"), "MR", ifelse(startsWith(acc21, "NMR"), "NM", acc21)),
  typology_access_cities = acc21,
  typology_rural_urban = col(t21, "^Typology rural/urban"),
  typology_rural_urban_extended = NA_character_,
  stringsAsFactors = FALSE
)
tl3_typology <- rbind(tl24, tl21)
tl3_typology$typology_access_cities[is.na(tl3_typology$typology_access_cities)] <- ".."
stopifnot(!anyDuplicated(tl3_typology[c("classification", "region_3d")]))
tl3_typology <- tibble::as_tibble(tl3_typology)

# ---- Exchange rates --------------------------------------------------------------------------
# Annual averages, national currency per EUR, for the non-euro countries of country_patches$non_euro.
# CAD, DKK, HUF, RON: Eurostat ert_bil_eur_a (as extracted: update of 8 July 2026).
# HRK: no longer in ert_bil_eur_a since Croatia adopted the euro (1 January 2023): the ECB annual
# averages (the source of the Eurostat series) to 2022, rounded to 4 decimals; from 2023 the fixed
# conversion rate 7.53450, so that growth in national currency equals growth in euros.
years <- 2008:2025
es <- utils::read.csv("https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/ert_bil_eur_a?format=SDMX-CSV&compressed=false",
                      stringsAsFactors = FALSE)
es <- es[es$statinfo == "AVG" & es$unit == "NAC" & es$currency %in% c("CAD", "DKK", "HUF", "RON") &
           es$TIME_PERIOD %in% years, ]
ecb <- utils::read.csv("https://data-api.ecb.europa.eu/service/data/EXR/A.HRK.EUR.SP00.A?format=csvdata&startPeriod=2008&endPeriod=2022",
                       stringsAsFactors = FALSE)
er <- rbind(
  data.frame(currency = es$currency, year = es$TIME_PERIOD, rate = es$OBS_VALUE),
  data.frame(currency = "HRK", year = ecb$TIME_PERIOD, rate = round(ecb$OBS_VALUE, 4)),
  data.frame(currency = "HRK", year = 2023:max(years), rate = 7.5345)
)
er$country <- unname(c(CAD = "CA", DKK = "DK", HRK = "HR", HUF = "HU", RON = "RO")[er$currency])
er$year <- as.double(er$year)
er <- er[order(er$country, er$year), ]
stopifnot(nrow(er) == 5 * length(years), !anyNA(er$rate))
rownames(er) <- NULL
exchange_rates <- tibble::as_tibble(er)

save(tl3_typology, file = "data/tl3_typology.rda", compress = "bzip2", version = 2)
save(exchange_rates, file = "data/exchange_rates.rda", compress = "bzip2", version = 2)
cat("tl3_typology:", nrow(tl3_typology), "rows; exchange_rates:", nrow(exchange_rates), "rows\n")
