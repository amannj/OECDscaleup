test_that("compute_characteristics runs end-to-end and has the expected output shape", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials())
  out <- compute_characteristics(cfg, ai)

  expect_s3_class(out, "tbl_df")
  expect_true(all(c(
    "year", "sample", "category", "group", "firm_count",
    "mean_employment_growth3y", "median_employment", "share_acquisition"
  ) %in% names(out)))
  expect_true(nrow(out) > 0)
  expect_true(all(out$firm_count > 0))
})

test_that("micro-only samples skip the L3size_cat category", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials())
  out <- compute_characteristics(cfg, ai)

  expect_equal(nrow(out[out$sample == "micro" & out$category == "L3size_cat", ]), 0)
  expect_equal(nrow(out[out$sample == "MHGE20" & out$category == "L3size_cat", ]), 0)
})

test_that("the ALL category has exactly one group value ('full sample')", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials())
  out <- compute_characteristics(cfg, ai)

  all_cat <- out[out$category == "ALL", ]
  expect_true(nrow(all_cat) > 0)
  expect_true(all(all_cat$group == "full sample"))
})

test_that("dominance columns appear only when dominance = TRUE", {
  ai_cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(ai_cfg, make_base_financials())

  cfg_off <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir(), dominance = FALSE)
  out_off <- compute_characteristics(cfg_off, ai)
  expect_false(any(grepl("^dom_", names(out_off))))

  cfg_on <- config_scaleup(nace_revision = "2",
    country = "FR", input_dir = tempdir(), output_dir = tempdir(),
    dominance = TRUE, dom_vars = c("employment", "turnover"), dom_num = 1
  )
  out_on <- compute_characteristics(cfg_on, ai)
  expect_true(all(c("dom_employment", "dom_turnover") %in% names(out_on)))
  # dominance share must be a proportion
  expect_true(all(out_on$dom_employment >= 0 & out_on$dom_employment <= 1, na.rm = TRUE))
})

test_that("category columns not present in the input data are silently omitted", {
  cfg <- config_scaleup(nace_revision = "2", country = "FR", input_dir = tempdir(), output_dir = tempdir())
  ai <- build_accounts_indicators(cfg, make_base_financials())
  # this fixture has no `independent`/`foreign_owned`/`region_3d` raw columns
  expect_false("independent" %in% names(ai))
  out <- compute_characteristics(cfg, ai)
  expect_false("L3independent" %in% unique(out$category))
})
