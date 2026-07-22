test_that("classify_scaling_var assigns each of the 6 tiers correctly", {
  # hg, grvar3y, rev
  expect_equal(classify_scaling_var(1, 0.5, 0), 6) # HG again
  expect_equal(classify_scaling_var(0, 0.15, 0), 5) # growing
  expect_equal(classify_scaling_var(0, 0.0, 0), 4) # stable
  expect_equal(classify_scaling_var(0, -0.15, 0), 3) # partial reversal
  expect_equal(classify_scaling_var(0, -0.15, 1), 2) # full reversal (overrides tier 3)
  expect_equal(classify_scaling_var(0, NA, 0), 1) # missing info (overrides earlier tiers)
})

test_that("classify_scaling_var: missing hg/rev compare FALSE/definite, not NA (stata_num semantics)", {
  # a missing hg must not satisfy tier 6, and must not block tier 4/5 evaluation
  expect_equal(classify_scaling_var(NA, 0.0, 0), 4)
})

test_that("classify_scaling_var: a real declining value with unresolved reversal status is unclassified", {
  # Genuine gap in the source's own tier rules, faithfully preserved (not "fixed"
  # in translation): grvar3y = -0.15 is real and < -0.10, so tier 1 ("is.na
  # (grvar3y)") never fires; but tier 3 additionally requires `rev == 0`, which
  # is Stata-FALSE (not TRUE) when rev itself is missing - so tier 3 doesn't
  # fire either. No tier matches, so the result stays at its initial NA -
  # this row is unclassified in the original Stata output too.
  expect_true(is.na(classify_scaling_var(0, -0.15, NA)))
})

test_that("classify_scaling_var: later rules override earlier ones on overlap (documented edge case)", {
  # F3hg==1 (-> 6) AND grvar3y in [-0.10,0.10] (-> 4): rule 4 is written after rule 6, so 4 wins.
  # This is the exact edge case called out in Pseudocode/n1_3_persistence.md step 8.
  expect_equal(classify_scaling_var(1, 0.05, 0), 4)
})

test_that("classify_other_var has only 5 tiers (no 'full reversal' concept)", {
  expect_equal(classify_other_var(1, 0.5), 6)
  expect_equal(classify_other_var(0, 0.15), 5)
  expect_equal(classify_other_var(0, 0.0), 4)
  expect_equal(classify_other_var(0, -0.15), 3)
  expect_equal(classify_other_var(0, NA), 1)
  expect_false(2 %in% classify_other_var(c(1, 0, 0, 0), c(0.5, 0.15, 0, -0.15)))
})

test_that("classify_pre_scaling_var uses birth_year for the 'Entry' tier (2)", {
  # l_hg, l_grvar3y, birth_year
  expect_equal(classify_pre_scaling_var(1, 0.5, 2000), 6)
  expect_equal(classify_pre_scaling_var(0, 0.15, 2000), 5)
  expect_equal(classify_pre_scaling_var(0, 0.0, 2000), 4)
  expect_equal(classify_pre_scaling_var(0, -0.15, 2000), 3)
  expect_equal(classify_pre_scaling_var(0, NA, 2015), 2) # recent birth_year -> Entry
  expect_equal(classify_pre_scaling_var(0, NA, 2000), 1) # missing growth, old firm -> Missing info
})

test_that("classify_pre_scaling_var: Entry tier requires a non-missing, post-2011 birth_year", {
  expect_equal(classify_pre_scaling_var(0, NA, 2011), 1) # exactly 2011 does not qualify (> 2011 required)
  # both grvar3y and birth_year missing: tier 1 also requires birth_year <= 2011
  # (Stata-definite-FALSE for a missing birth_year, same stata_num reasoning as
  # above), so - like the classify_scaling_var gap above - this row is
  # genuinely left unclassified by the source's own rules.
  expect_true(is.na(classify_pre_scaling_var(0, NA, NA)))
})
