# Prepares this package's bundled reference data from the OECD-supplied .dta
# files that ship with the original Stata package. Both are small,
# non-confidential lookup tables (not firm microdata), safe to bundle. Re-run this script (from the package root) only if the
# OECD publishes an updated tl3_typology.dta or exchange_rates.dta.

stata_dir <- "path/to/the/original/Stata/package" # holds tl3_typology.dta and exchange_rates.dta

tl3_typology <- haven::read_dta(file.path(stata_dir, "tl3_typology.dta"))
exchange_rates <- haven::read_dta(file.path(stata_dir, "exchange_rates.dta"))

usethis::use_data(tl3_typology, overwrite = TRUE)
usethis::use_data(exchange_rates, overwrite = TRUE)
