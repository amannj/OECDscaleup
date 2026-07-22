test_that("config_scaleup builds a valid config with sensible defaults", {
  cfg <- config_scaleup(country = "fr", input_dir = tempdir(), output_dir = tempdir())
  expect_s3_class(cfg, "scaleup_config")
  expect_equal(cfg$country, "FR") # uppercased
  expect_false(cfg$dominance)
  expect_equal(cfg$dom_vars, c("employment", "turnover"))
  expect_equal(cfg$dom_num, 2L)
})

test_that("config_scaleup rejects a malformed country code", {
  expect_error(
    config_scaleup(country = "FRA", input_dir = tempdir(), output_dir = tempdir()),
    class = "OECDscaleup_config_error"
  )
  expect_error(
    config_scaleup(country = "F", input_dir = tempdir(), output_dir = tempdir()),
    class = "OECDscaleup_config_error"
  )
})

test_that("config_scaleup rejects nonexistent directories", {
  expect_error(
    config_scaleup(country = "FR", input_dir = "Z:/does/not/exist", output_dir = tempdir()),
    class = "OECDscaleup_config_error"
  )
  expect_error(
    config_scaleup(country = "FR", input_dir = tempdir(), output_dir = "Z:/does/not/exist"),
    class = "OECDscaleup_config_error"
  )
})

test_that("config_scaleup rejects a non-boolean dominance flag", {
  expect_error(
    config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(), dominance = "yes"),
    class = "OECDscaleup_config_error"
  )
})

test_that("config_scaleup requires dom_vars when dominance is TRUE", {
  expect_error(
    config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(), dominance = TRUE, dom_vars = character(0)),
    class = "OECDscaleup_config_error"
  )
})

test_that("config_scaleup rejects a non-positive dom_num", {
  expect_error(
    config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(), dom_num = 0),
    class = "OECDscaleup_config_error"
  )
  expect_error(
    config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir(), dom_num = -1),
    class = "OECDscaleup_config_error"
  )
})

test_that("print.scaleup_config runs without error and mentions the country", {
  cfg <- config_scaleup(country = "FR", input_dir = tempdir(), output_dir = tempdir())
  expect_output(print(cfg), "FR")
})
