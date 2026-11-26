# Fix N1 (NACE Rev. 2 / Rev. 2.1) and fix N2 (unit of the money variables).

cfg_n <- function(...) config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(), ...)

test_that("nace_section: letters per revision, NA for divisions that do not exist", {
  s2 <- c(1, 26, 45, 47, 58, 61, 62, 64, 68, 77, 84, 95, 97, 99, 34)
  expect_equal(nace_section(s2, "2"),
               c("A", "C", "G", "G", "J", "J", "J", "K", "L", "N", "O", "S", "T", "U", NA))
  expect_equal(nace_section(s2, "2.1"),
               c("A", "C", NA, "G", "J", "K", "K", "L", "M", "O", "P", "T", "U", "V", NA))
})

test_that("config_scaleup: nace_revision is required and checked", {
  expect_error(config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir()),
               "nace_revision", class = "OECDscaleup_config_error")
  expect_error(cfg_n(nace_revision = "2.2"), class = "OECDscaleup_config_error")
  expect_error(cfg_n(nace_revision = "2.1", nace_rev21_from = 2025), class = "OECDscaleup_config_error")
  expect_equal(cfg_n(nace_revision = 2.1)$nace_revision, "2.1")
  expect_equal(cfg_n(nace_revision = "2", nace_rev21_from = 2025)$nace_rev21_from, 2025L)
})

# the same firms coded in Rev. 2 and in Rev. 2.1: IT (62), finance (64, excluded), vehicle repair
# (45.2 = Rev. 2.1 95.3), administrative services (77), manufacturing (26)
nace_panel <- function(rev) {
  bf <- make_base_financials_wide()
  code <- function(ids, s2, s3) {
    k <- bf$idf %in% ids
    bf$sector_2d[k] <<- s2; bf$sector_3d[k] <<- s3; bf$sector_1d[k] <<- nace_section(s2, rev)
  }
  code(1:10, 62, 620)
  code(11:15, 64, 641)
  if (rev == "2") code(16:20, 45, 452) else code(16:20, 95, 953)
  code(21:25, 77, 771)
  bf$sector_1d[bf$idf > 25] <- "C"
  bf
}

test_that("Rev. 2.1 input gives the same panel as its Rev. 2 sibling; mismatches stop the build", {
  ref <- build_accounts_indicators(cfg_n(nace_revision = "2"), nace_panel("2"))
  expect_false(any(ref$idf %in% 11:15)) # finance left out
  got <- build_accounts_indicators(cfg_n(nace_revision = "2.1"), nace_panel("2.1"))
  expect_equal(got, ref)

  # Rev. 2.1 codes declared as Rev. 2 (and the reverse): stop, with counts
  expect_error(build_accounts_indicators(cfg_n(nace_revision = "2"), nace_panel("2.1")),
               "do not match the declared revision", class = "OECDscaleup_data_error")
  expect_error(build_accounts_indicators(cfg_n(nace_revision = "2.1"), nace_panel("2")),
               "division 45", class = "OECDscaleup_data_error")

  # a panel that switches in 2016
  mixed <- nace_panel("2")
  late <- mixed$year >= 2016
  mixed[late, ] <- nace_panel("2.1")[late, ]
  got_mixed <- build_accounts_indicators(cfg_n(nace_revision = "2", nace_rev21_from = 2016), mixed)
  expect_equal(got_mixed, ref)
})

test_that("the excluded sectors are found by division, and by letter only without a division", {
  bf <- nace_panel("2")
  bf$sector_1d[bf$idf == 11] <- "." # finance with no letter: still left out (by division)
  bf$sector_2d[bf$idf == 12] <- NA  # finance with no division: left out by its letter K
  ai <- build_accounts_indicators(cfg_n(nace_revision = "2"), bf)
  expect_false(any(ai$idf %in% 11:12))
})

test_that("financials_unit: euros are rescaled when declared, and stop the build when not", {
  bf <- make_base_financials_wide()
  ref <- build_accounts_indicators(cfg_n(nace_revision = "2"), bf)
  eur <- bf
  money <- c("turnover", "added_value", "labour_costs", "tangible_fixed_assets")
  eur[money] <- lapply(eur[money], function(x) x * 1000)
  expect_error(build_accounts_indicators(cfg_n(nace_revision = "2"), eur), "looks like EUR",
               class = "OECDscaleup_data_error")
  got <- build_accounts_indicators(cfg_n(nace_revision = "2", financials_unit = "EUR"), eur)
  expect_equal(got$turnover, ref$turnover)
  expect_equal(got$MFP, ref$MFP)
  # thousands declared as euros: too small after the division
  expect_error(build_accounts_indicators(cfg_n(nace_revision = "2", financials_unit = "EUR"), bf),
               "too small", class = "OECDscaleup_data_error")
  # the default keeps the original country list
  expect_equal(config_scaleup(nace_revision = "2", country = "PT", input_dir = tempdir(), output_dir = tempdir())$financials_unit, "EUR")
  expect_equal(cfg_n(nace_revision = "2")$financials_unit, "EUR thousand")
})
