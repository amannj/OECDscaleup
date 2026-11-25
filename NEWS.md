# OECDscaleup (development version)

## Faster, with less memory

- The output stages copy only the columns they use. In particular,
  `compute_contribution()` no longer carries all of `accounts_indicators`
  through its balanced (firm x year) panel. Group statistics broadcast to
  firms use `collapse` instead of `stats::ave()`, the approximate medians
  and dominance shares use partial sorts, the trade panel groups by integer
  ids instead of pasted keys, and `run_scaleup_pipeline()` drops the raw
  input once the panel is built. Every output is unchanged (checked byte for
  byte on all reproduction scenarios, synthetic and real). On the real
  national panels used for validation the pipelines run 2.2 to 3 times
  faster, and the peak R heap is 20 to 50 % lower; the largest panel (5.7 GB
  of indicators in memory) now takes 14 minutes instead of 42 and peaks at
  19 GB instead of 32 GB.

## Stata bugs fixed

Each fix changes results relative to the Stata code (and to git tag
`stata-parity-v1_3`); the change was checked to be limited to what the fix
should touch.

- S1 Jump filter: in a spike such as 20-200-20 (or a dip), the spike year
  is now blanked; Stata blanked the year after it. The 20-employee floor is
  applied to the average over the year before, the spike and the year
  after. This changes employment/turnover early on, so all outputs move.
- S2 `ind_a38`: NACE divisions 69-75 are now grouped as D69T71, D72 and
  D73T75 instead of the aggregate D68T82, which is not an A38 group (68 stays
  D68, 77-82 stay D77T82).
- S3 Small-region aggregation (AT, CA, HU, IT, NL, ES, RO): a TL1 region
  with no small TL2 region is no longer merged (Stata treated its missing
  share as +infinity). A TL1 whose TL2 regions are all small but have no
  HGET10 firm is still merged.
- S4 Predictor types: a scaler with a missing (or small-cell) quartile of
  MFP, physical assets or average wage stays "Missing info" (9) or "<50
  year-sector N" (50). Stata let Transformational/Expansionist (5/6), which
  require that none of the three is in the top quartile, overwrite them.
- S5 Contribution: of Stata's analysis years (2014, 2017, 2019, 2020,
  2021), only those whose t-3 lies inside the panel are used. A panel
  starting after 2011 no longer gets a 2014 window without t-3 data, where
  every firm counted as an entrant. The years themselves are those the
  documentation specifies.
- S6 Predictor regressions are estimated only on firms that can be scalers
  under the dependent variable (its high-growth pool: 10+ employees at t-3,
  growth known) and have fewer than 250 employees at t-3. Stata used every
  firm present at t-3, so micro and 250+ firms counted as non-scalers.
- S7 TL3 regions with typology ".." (no typology) now have a missing
  `typology_UR`; Stata reported them as a sixth group "..". They still count
  in all other breakdowns and totals.
- S8 Raw data with both `age_cat` and `birth_year` (Stata stopped with an
  error): `birth_year` now drives age, entry and `L3age`; the supplied
  `age_cat` is kept as the age category. An all-missing `birth_year` column
  counts as absent.
- S9 Size boundaries follow the documented definitions, consistently:
  employers with fewer than 250 employees at t-3 (0 < L3employment < 250;
  Stata 1-249) for the characteristics and persistence samples, and fewer
  than 10 for micro (0 < L3employment < 10) for both the micro scalers
  (Stata 1 to < 10) and their comparison pool (Stata 1-9). Firms with
  fractional FTE such as 0.5, 9.5 or 249.5 are no longer left out, and a
  micro scaler always has its comparison pool.
- S11 The predictors documentation now says that the "Strategic
  (productivity)" type uses the MFP *level* at t-3 (as the code always did,
  like the capital and wage types); the Stata documentation said
  "productivity growth".
- S12 The never-applying floor for negative MFP is removed (MFP is an
  exponential, so never negative). Labour share stays labour costs over
  turnover, as documented. No result changes.
- S13, S14 The two Stata crashes (an unlabelled `age_cat`; no regression
  year in the panel, which also lost desc_predictors) never occurred in R;
  tests now pin that.
- S15 `tech_grad`: divisions that Stata left without a group are assigned:
  58-60 and 63 to Advanced services, 77 to Other services tradable, 90-94
  and 96 to Other services non-tradable. 01-03, 64-66 and 84 stay
  unclassified, as in Stata.
- S16 Rescaling to thousands (PT, ES, RO, SI, HU) now includes `cash_flow`
  and `gross_profit`, so financial-dependency ratio 4 no longer mixes units.
- S17 A firm with an empty region code gets a missing region-sector pair
  (`reg_techgrad`). Stata excluded only `"."`, so an empty region formed a
  pseudo-region `_<sector group>`. Such firms still count in all other
  breakdowns and totals.

## Trade package

- New: the firm-level trade extension (Stata trade package v1.0,
  `MASTER_OECD_trade.do`). `run_trade_pipeline()` reads `trade_RAW_<CT>.dta`
  next to `base_financials_<CT>.dta` and writes
  `trade_accounts_indicators_<CT>.dta` and
  `n16_trade_characteristics_p1/p2_<CT>.csv`. The steps are
  `build_trade_panel()` (transactions to a firm-year panel),
  `build_trade_accounts_indicators()` (`n0_2`: the panel build of the second
  package, an earlier version of it, with exporter/importer flags,
  first-time exporters, heavy/light exporting scalers, `sector_exporter`
  and `digit_sect`) and `compute_trade_characteristics()` (`n1_6`).
- `n0_2` is a modified copy of `n0_1`, so both run through one shared body;
  the trade differences (PT-only rescaling, no region aggregation, no
  `reg_techgrad`, no `D68T82`, ...) are switched on by the trade panel.
- At git tag `trade-parity-v1_0` the trade code reproduces the Stata code
  including its bugs; two of them make Stata stop, and R stops with the
  same cause: trade data without import (or export) rows and non-numeric
  product codes. Merged into the fixes: the Stata bugs fixed above apply to
  the trade outputs too, wherever the trade package shares the code (S1,
  S7-S9, S15, S16), and the trade-specific bugs below are fixed.

### Trade package bugs fixed

- T1 Units: the trade build rescales the financials for the same countries
  as the base package (PT, ES, RO, SI, HU; the Stata trade package did PT
  only, so the trade outputs of ES, RO, SI and HU mixed EUR with EUR
  thousand), including the export-revenue variables. The unit of
  `trade_value` is a setting, `config_scaleup(trade_value_unit =)`: `"EUR"`
  (divided by 1000) or `"EUR thousand"`; by default EUR for PT and HU, as
  the Stata code assumed. The 1-thousand product threshold (T7) then always
  applies to EUR thousand.
- T2 A firm in the trade file that only imports has export value 0 (a
  non-exporter), and one that only exports has import value 0; Stata left
  the value missing, so import-only firms dropped out of the
  exporter/non-exporter comparison and the share of importers among
  exporters was computed over two-way traders only. Values that were
  missing in the raw data stay missing.
- T3 First-time exporters (`y4_exporter`): a firm that already exports in
  its first observed year may have exported before the data start, so
  while that year lies in t-3..t it is now missing (unknown) instead of a
  first-time exporter, unless that year is the firm's entry year. Stata
  counted every firm exporting in the first data year as new, which
  strongly overstated the share in the early years.
- T4 Trade data without import rows (or without export rows) no longer
  stop the run (Stata stopped at `rename trade_value1`). That flow is then
  unknown for every firm: its variables are missing, non-traders included.
- T5 Products are told apart by their 6-character code as a string. Stata
  converted it to a number without `force`: a code with letters (e.g. a
  confidential code) stopped the run, and codes differing only in leading
  zeros were counted as one product.
- T6 EU partners are counted by the EU membership of each year: the United
  Kingdom (`GB` or `UK`) up to and including 2020, Croatia from 2013. Stata
  used the EU-27 of 2020 in every year.
- HGX (heavy exporting scalers) keeps `>=` half the HGT growth threshold,
  as the code always did; the documentation's "more than 50 %" is the
  same in practice and is now worded "at least half".

## Verified against Stata

Outputs were compared with the original Stata code (package version 1.3)
run in Stata 19.5, on 9 synthetic scenarios built to hit every branch and on
one full national firm-level dataset (confidential). All 9 output tables
match in every scenario (rows, keys, labels and counts exact; other values
within a relative 1e-4). The R code now reproduces the Stata code
*including its known bugs* (git tag `stata-parity-v1_3`); fixing those is a
separate step, see "Known issues inherited from the Stata code" below.
Two Stata crashes are not reproduced: R completes where Stata stops (S13,
S14). Translation errors found and corrected:

- Stata arithmetic: `x/0`, `ln(0)` and `0/0` are missing in Stata, not
  `Inf`/`NaN`. This changed HG flags (turnover 0 at t-3), the p1/p99
  trimming of growth rates and labour productivity, MFP, the acquisition
  flag and the financial-dependency ratios.
- Stata storage: `gen` stores `float`. Reproduced (`stata_float()`) where it
  decides a threshold, e.g. `8/10 > 0.8` is true in Stata.
- Stata's `x^y` is `exp(y * ln(x))`: firms growing at exactly 10%/20% a year
  are not high-growth firms in Stata (`stata_pow()`).
- The HG pool no longer requires the growth ratio to exist.
- `"."` in `sector_1d`/`region_2d` is missing, and never forms a `._<sector>`
  region-sector pair; the `".."` TL3 typology is kept as its own category.
- `L3age` is created (it was missing, so `median_L3age` was absent).
- `log_added_value_emp` is renamed to `labour_prod` as in Stata; the Solow
  intermediates `va sl k slk l sll` are kept.
- Region aggregation reproduces Stata's `share_small > 0.5` with a missing
  share counting as true (Stata bug, reproduced on purpose).
- Approximate medians of growth rates were means: `summarise()` evaluated
  the means first and overwrote the columns (characteristics and
  desc_predictors).
- Transitions/evolutions/desc_predictors write value labels (`FOLLOW`,
  `LEAD`, `type`) as Stata's `export delimited` does; desc_predictors labels
  ALL as "Total".
- Evolutions: `entry_year`/`exit_year` are missing where `entry`/`exit` is.
- Contribution: the p2 table for `exiting` is written once (Stata skips the
  aggregate block when the detail block is empty).
- Regressions: replaced `fixest` with an emulation of `regress, robust`
  (`stata_regress_robust()`): Stata's term names (`0b.L3size_cat`,
  `3.L3region_2d`, `o.x`, `_cons`), base and omitted rows, left-to-right
  collinearity handling, HC1 errors, no regression with fewer than 2
  observations, dominance shares rounded to 4 decimals. Previously any
  warning dropped the model.
- `accounts_indicators_<CT>.dta` is written with Stata's labelled numeric
  categories and `encode` codes (byte order; `typology_UR` extends the label
  that comes with `tl3_typology.dta`).
- `fixest` is no longer a dependency.
- Plant counts: when `base_financials` already holds `number_plants` /
  `multiplant` (Stata saves the plant merge back into it, so a second run
  sees them), the counts from the plants file replace them where a firm-year
  has plant records and the existing values are kept elsewhere, as Stata's
  `merge` does. R produced `.x`/`.y` duplicates and lost `multiplant`. Found
  on real data after the tag; fixed on master.
- Float storage in the rescaling: Stata's `replace v = v/1000` keeps a
  `float` variable `float` (and promotes `byte`/`int` to `float`), so the
  rescaled financials are rounded to single precision when the input file
  stores them as float. `run_scaleup_pipeline()` now reads the storage types
  from the `.dta` header and rounds the same way; `build_accounts_indicators()`
  takes them as `storage_types`. The difference is tiny in the levels but is
  amplified in capex (`findep_rat4`) and the MFP inputs. Found on real data
  after the tag; fixed on master.

## Known issues inherited from the Stata code

Reproduced on purpose at `stata-parity-v1_3`, and all addressed on the
`FixStataBugs` branch (see "Stata bugs fixed" above). Method items were
decided one by one against the package documentation.

- S1 *(fixed, see above)* Jump filter: in a 20-200-20 spike the year after
  the spike is blanked, not the spike.
- S2 *(fixed, see above)* `ind_a38`: `D68T82` is assigned after `D69T71`,
  `D72`, `D73T75`, so divisions 69-75 all end up in `D68T82`.
- S3 *(fixed, see above)* Region aggregation: a missing small-region share
  counts as above 0.5, so large TL1 regions are aggregated too.
- S4 *(fixed, see above)* Predictor types 9 ("missing info") and 50
  ("<50 N") are overwritten by types 5/6.
- S5 *(fixed, see above)* Contribution: years are hard-coded (2014, 2017,
  2019-2021, as documented); the computed first/last years are unused.
- S6 *(fixed, see above)* Regression samples include firms that are not
  eligible to scale (fewer than 10 employees at t-3, or 250+).
- S7 *(fixed, see above)* Regions with TL3 typology ".." form their own
  category.
- S8 *(fixed, see above)* A user-supplied `age_cat` together with
  `birth_year` fails in Stata (`gen birth_year` on an existing variable).
- S9 *(fixed, see above)* Fractional FTE between 9 and 10 at t-3: such a
  firm can be a micro scaler but is never in the micro comparison pool.
- S10 *(closed)* Output file names differ from the documentation. R
  writes the documented `n13_*` names.
- S11 *(closed, see above)* The documentation calls the productivity type
  "productivity growth"; the code uses the MFP level.
- S12 *(closed, see above)* Labour share is labour costs over turnover, not
  value added (documented choice, kept); the MFP < 0 floor can never apply.
- S13 *(not in R, tested)* Stata crashes when `age_cat` is supplied
  without value labels.
- S14 *(not in R, tested)* Stata crashes when no regression can run,
  losing desc_predictors too.
- S15 *(fixed, see above)* `tech_grad`: divisions 58-60 (except 582), 63,
  77, 90-94 and 96 get no group (nor do 01-03, 64-66 and 84).
- S16 *(fixed, see above)* Rescaling to thousands (PT, ES, RO, SI, HU)
  leaves out `cash_flow`, so financial-dependency ratio 4 mixes thousands
  with units.
- S17 *(fixed, see above)* An empty region code forms a region-sector pair
  `_<sector group>` (only `"."` is excluded).

# OECDscaleup 0.1.0

Initial release: a behaviour-preserving translation of the OECD Scale Up
project's "Second Package" Stata pipeline (`MASTER_OECD_p2.do` and its 5
worker `.do` files, version 1.0, `scaleup@oecd.org`) into R.

## What this release contains

- `config_scaleup()` — replaces the Stata global macros set in
  `MASTER_OECD_p2.do`.
- `build_accounts_indicators()` — translates `n0_1_accounts_indicators_v2.do`.
- `compute_characteristics()` — translates `n1_3_characteristics.do`.
- `compute_persistence()` — translates `n1_3_persistence.do` (transitions +
  evolutions).
- `compute_contribution()` — translates `n1_3_contribution.do`.
- `compute_predictors()` — translates `n1_3_predictors.do`.
- `run_scaleup_pipeline()` — file-I/O orchestrator mirroring
  `MASTER_OECD_p2.do`'s role; every function above it is a pure,
  independently-testable data transformation.
- Bundled reference data `tl3_typology` and `exchange_rates`, carried over
  as-is from the OECD-supplied `.dta` files.
- A documented `country_patches` lookup table replacing the 3 hardcoded
  country-list branches in the original `n0_1_accounts_indicators_v2.do`.

## Translation notes

- Ported from `Pseudocode/*.md` (a structure-preserving intermediate
  representation of the original Stata source), not directly from the `.do`
  files — see that directory for the line-by-line correspondence.
- Several Stata/R semantic gaps were identified and deliberately corrected
  for, each with a dedicated regression test: Stata's non-propagating
  missing-value comparisons (`stata_num()`), `replace ... if` semantics
  under an unresolved condition (`stata_replace()`), Stata's round-half-away-
  from-zero convention (`round_half_up()`), and Stata's percentile algorithm
  (`percentile_stata()`, confirmed equivalent to R's `quantile(type = 2)`).
- The original has no automated test suite; the one existing behavioural
  spec (the confidentiality worked example in the source PDF, §4) informed
  this package's dominance-share tests. Everything else is covered by new
  unit and integration tests built from synthetic fixtures, since the real
  firm microdata this pipeline processes is confidential and never ships
  with the package (see `Analysis/stata.md` and `variable_dictionary_v1.xlsx`
  for the input schema fixtures are built against).
- No `.dlg` dialog files exist in the source package, so no Shiny GUI was
  built (there was nothing to recreate).
- Known residual approximations, not exact-match verified against a live
  Stata run at the time: `statar::xtile()`'s tie-breaking at quartile
  boundaries, and `fixest`'s robust-standard-error small-sample adjustment
  (both since verified or replaced, see the development version above).
