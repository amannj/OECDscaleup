# Input data: base_financials and plants_RAW

OECD project on SME scaling up. For information: <scaleup@oecd.org>,
<juergen.amann@oecd.org>.

This article describes the firm-level input data of the scale-up
pipeline
([`run_scaleup_pipeline()`](https://amannj.github.io/OECDscaleup/reference/run_scaleup_pipeline.md)):
what each variable should contain, how high a priority it has, and what
the package does with it. The trade package’s extra input is described
in
[`vignette("input-trade-data")`](https://amannj.github.io/OECDscaleup/articles/input-trade-data.md).
The same information is in the package dataset `variable_dictionary`
([`?variable_dictionary`](https://amannj.github.io/OECDscaleup/reference/variable_dictionary.md)),
for use in code.

Before a run, `check_inputs(cfg)` checks the files in `input_dir`
against this dictionary: what would stop the build, what looks wrong or
will be lost, and what the build will do to the data. Its report holds
counts, shares and years only, never firm records, so it can be shared
with the OECD team.

## Files

The pipeline reads its inputs from `config$input_dir`, as `.dta` files.
`<CT>` is the two-letter country code given to
[`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

| File | Content | Needed |
|----|----|----|
| `base_financials_<CT>.dta` | Firm-level panel: one row per firm and year, basic variables with a standard naming structure and no derived indices (growth rates and the like) | always |
| `plants_RAW_<CT>.dta` | Establishment-level data: one row per plant and year | optional (gives `multiplant`) |
| `tl3_typology.dta` | OECD regional typology of TL3 regions | not needed: replaces the package’s `tl3_typology` |
| `exchange_rates.dta` | Annual average euro exchange rates | not needed: replaces the package’s `exchange_rates` |

The regional typology and the exchange rates ship with the package (see
[Reference data](#reference-data) below). A `tl3_typology.dta` or
`exchange_rates.dta` in the input folder replaces them; remove such
files from earlier rounds to use the package’s current tables.
[`check_inputs()`](https://amannj.github.io/OECDscaleup/reference/check_inputs.md)
says which tables are used.

## General rules

1.  **Missing values** are coded `.` in numeric variables and `"."` in
    string variables. The package also reads an empty string as missing.
2.  **Money variables are in EUR thousand**, at current (nominal)
    prices. Values in national currency are converted to euros with the
    Eurostat annual average exchange rates
    ([ERT_BIL_EUR_A](https://ec.europa.eu/eurostat/databrowser/view/ERT_BIL_EUR_A/default/table?lang=en)).
    A panel delivered in euros is declared with
    `config_scaleup(financials_unit = "EUR")`, and the build divides the
    money variables (column “Cleaning” below) by 1000. The build stops
    if the median turnover per employee of firms with 10 to 49 employees
    does not fit EUR thousand (above 5,000 or below 1).
3.  **Sector codes** follow NACE Rev. 2 or NACE Rev. 2.1 (or ISIC
    Rev. 4), not ISIC Rev. 3 or NACE Rev. 1.1. The revision is declared
    with `config_scaleup(nace_revision = "2")` or `"2.1"`. A panel that
    switches from Rev. 2 to Rev. 2.1 gives the first Rev. 2.1 year as
    `nace_rev21_from`. The build checks the section letters against the
    divisions for the declared revision, stops on a mismatch, and
    converts Rev. 2.1 codes to Rev. 2, for which the sector rules are
    written.
4.  **Regions** are codes of the OECD territorial classification: TL2
    and TL3 regions, which are the NUTS 2 and NUTS 3 regions in EU
    countries. The classification is declared with
    `config_scaleup(tl_classification =)`: `"TL2024"` (the default;
    NUTS 2024) or `"TL2021"` (NUTS 2021). It selects the regional
    typology used for the urban/rural breakdown;
    [`check_inputs()`](https://amannj.github.io/OECDscaleup/reference/check_inputs.md)
    reports how many of the region codes are found in each.
5.  **`year`** is the calendar year the data refer to, not the year the
    accounts were filed. A firm appears at most once per year.

## Priorities

- **Must-have**: the pipeline does not run without it, or its core
  indicators depend on it.
- **Nice-to-have, first order**: used for important breakdowns and
  indicators; please supply it if it is available.
- **Nice-to-have, second order**: supply it if it is easy to.

The priority is the OECD’s request to the data providers. What the
package itself needs is in the second table of each section: some
variables are derived when absent (`age`, `exit`), and some are
collected for future work and not used yet.

## base_financials

### What to supply

| Variable | Priority | Definition | Format and coding | Source (SBS code) | Notes |
|:---|:---|:---|:---|:---|:---|
| `idf` | must-have | unique firm-level identifier | numeric | BR |  |
| `year` | must-have | calendar year the data refer to | numeric |  | Make sure it is not the year in which the balance sheet was filed. |
| `birth_year` | must-have | year of incorporation (or, alternatively, of start of activities) | numeric | BD |  |
| `age` | nice-to-have, second order | firm age | numeric | BD |  |
| `exit` | nice-to-have, second order | indicator of a year when the company terminates operations | numeric; 1 = in the exit year, 0 = other years from the entry year / birth year | BR |  |
| `exit_acq` | nice-to-have, first order | indicator of a year when the company terminates operations under its current legal identifier because it is acquired by domestic or foreign investors | numeric; 1 = in the acquisition year, 0 = other years from the entry year / birth year | BR |  |
| `exit_close` | nice-to-have, first order | indicator of a year when the company ceased its operations (i.e. closed) | numeric; 1 = in the closure year, 0 = other years from the entry year / birth year | BR |  |
| `sector_3d` | must-have | core sector, 3 digits, NACE Rev. 2 or Rev. 2.1 (or ISIC Rev. 4); not ISIC Rev. 3 or NACE Rev. 1.1 | numeric | BR | Declare the revision in config_scaleup(nace_revision = ); a panel that switches from Rev. 2 to Rev. 2.1 also gives nace_rev21_from (the first Rev. 2.1 year). |
| `sector_2d` | must-have | core sector, 2 digits (division), NACE Rev. 2 or Rev. 2.1 (or ISIC Rev. 4); not ISIC Rev. 3 or NACE Rev. 1.1 | numeric | BR | Declare the revision in config_scaleup(nace_revision = ); a panel that switches from Rev. 2 to Rev. 2.1 also gives nace_rev21_from (the first Rev. 2.1 year). |
| `sector_1d` | must-have | core sector, section letter, NACE Rev. 2 or Rev. 2.1 (or ISIC Rev. 4); not ISIC Rev. 3 or NACE Rev. 1.1 | string (letter) | BR | Declare the revision in config_scaleup(nace_revision = ); a panel that switches from Rev. 2 to Rev. 2.1 also gives nace_rev21_from (the first Rev. 2.1 year). |
| `region_2d` | must-have | TL2 region code (the NUTS 2 code for EU countries), of the declared TL classification | string | BR | Declare the classification in config_scaleup(tl_classification = ): “TL2024” (the default; NUTS 2024 for EU countries) or “TL2021” (NUTS 2021). |
| `region_3d` | nice-to-have, first order | TL3 region code (the NUTS 3 code for EU countries), of the declared TL classification | string | BR | Declare the classification in config_scaleup(tl_classification = ): “TL2024” (the default; NUTS 2024 for EU countries) or “TL2021” (NUTS 2021). |
| `employment` | must-have | full-time equivalent (FTE) number of persons employed | numeric | SBS (220103) | If FTE is not available, the headcount (SBS code 220102) can be used. Persons employed exclude owners and self-employed. |
| `turnover` | must-have | total sales or revenues in current prices, or value of output | numeric | SBS (250301) |  |
| `exp_revenues_goods` | nice-to-have, second order | value of exports of goods | numeric | ITGS |  |
| `exp_revenues_services` | nice-to-have, second order | value of exports of services | numeric | ITSS |  |
| `labour_costs` | nice-to-have, first order | total gross wages including social contributions | numeric | SBS (220301 + 220302 + 220303) |  |
| `operating_costs` | nice-to-have, second order | expenses that arise in the course of the ordinary activities of the firm. Source: income statement. See p. 8 of the ERICA methodological note for the items included. | numeric |  |  |
| `services_costs` | nice-to-have, first order | expenses relating to external supplies and services in the period. Source: income statement. | numeric |  | See Table A1.1 of the BACH paper. |
| `depr_amort` | nice-to-have, first order | depreciation and amortisation of tangible and intangible assets recognised in the period. Source: income statement. | numeric |  | See Table A1.1 of the BACH paper. |
| `interest_costs` | nice-to-have, first order | interest on financial debts, including financing costs recognised in the period. Source: income statement. | numeric |  | See Table A1.1 of the BACH paper. |
| `intangible_fixed_assets` | nice-to-have, second order | intangible fixed assets at net book value: brands, patents, copyrights, licences, etc. | numeric |  | See Table A1.2 of the BACH paper. |
| `tangible_fixed_assets` | nice-to-have, first order | property, plant and equipment from the balance sheet, at net book value | numeric |  | See Table A1.2 of the BACH paper. |
| `fixed_assets` | nice-to-have, second order | tangible_fixed_assets + intangible_fixed_assets + financial fixed assets | numeric |  | See Table A1.2 of the BACH paper. |
| `current_assets` | nice-to-have, first order | cash, inventory and other assets expected to be converted to cash within a year. Source: balance sheet. | numeric |  | See Table A1.2 of the BACH paper for the types of current assets. |
| `total_assets` | nice-to-have, first order | fixed assets + current assets | numeric |  |  |
| `loans` | nice-to-have, first order | current and non-current amounts owed to credit institutions. Source: balance sheet. | numeric |  | See Table A1.3 of the BACH paper. |
| `total_liabilities` | nice-to-have, first order | total liabilities from the balance sheet | numeric |  | See Table A1.3 of the BACH paper. |
| `gross_profit` | nice-to-have, second order | profit (loss) before tax. Source: income statement. | numeric |  | See p. 10 of the ERICA methodological note for the items included. |
| `profit_after_tax` | nice-to-have, second order | profit (loss) after tax from continuing operations (before non-controlling interests). Source: income statement. | numeric |  |  |
| `added_value` | nice-to-have, first order | value of gross output (or sales if gross output is not available) less intermediate inputs | numeric | SBS (250401) |  |
| `cash_flow` | nice-to-have, second order | cash flows from operating, investing or financing activities. Source: cash flow statement. | numeric |  | See p. 27 of the ERICA methodological note. |
| `independent` | nice-to-have, first order | affiliation status | numeric; 1 = independent, 0 = affiliate | EuroGroups register | An independent company is not part of a domestic or foreign business group, i.e. its ultimate owner is not another company or a business entity owning several companies. Countries typically follow slightly different approaches in defining this variable. |
| `uco` | nice-to-have, first order | country in which the ultimate owner of the business group is headquartered (ultimate country of ownership) | string | IFATS | Two-letter country code, e.g. SE for Sweden; NSOs typically use this variable in Foreign Affiliates Statistics (FATS). |

### What the package does with it

| Variable | The package needs it | What the package does with it | Cleaning |
|:---|:---|:---|:---|
| `idf` | required | Firm key. A firm may appear only once per year: the build stops on duplicate (idf, year) pairs. |  |
| `year` | required | Panel year. Years below the 1st or above the 99th percentile of all firm-years are dropped. Growth is measured over t-3 to t. |  |
| `birth_year` | required unless age_cat is supplied | Gives age (year - birth_year), the age classes (0-5, 6-10, 11+ years) and entry. A firm’s earliest birth_year over its years is used. Firms born after 2011 form the ‘Entry’ group of the pre-scaling classification (compute_persistence(), evolutions). |  |
| `age` | optional | Computed as year - birth_year when absent; negative ages are set to missing. |  |
| `exit` | optional | When absent, a firm exits in its last year in the panel (unless that is the last panel year). Used by compute_contribution() (jobs lost by exits) and compute_persistence(). |  |
| `exit_acq` | optional | compute_persistence(): a scaler acquired in the scaling year or the two years after it is classed ‘Acquisition’ instead of by its later growth. |  |
| `exit_close` | not used | Not used yet. Together with exit_acq it would separate closures from acquisitions among exits. |  |
| `sector_3d` | required | Group 58.2 (software publishing) is Advanced services in tech_grad. Rev. 2.1 groups are converted to Rev. 2 (95.3 to 45.2). |  |
| `sector_2d` | required | Sector groups (tech_grad) and OECD STAN A38 industries (ind_a38). Divisions 01-03, 64-66, 84 and 97-99 (agriculture, finance, public administration, households) are left out. Quartiles of the predictors are taken within division and year. |  |
| `sector_1d` | required | Checked against the division for the declared revision (the build stops on a mismatch). Used to leave out sections A, K, O, T, U (Rev. 2 letters) only where the division is missing. Section L (real estate) is flagged. |  |
| `region_2d` | required | Regional breakdown (L3region_2d) and region dummies of the predictor regressions. In countries with small regions (country_patches\$aggregate_small_regions), small NUTS2 regions are merged into their NUTS1 region. Region x sector group cells (reg_techgrad). |  |
| `region_3d` | optional | Joined to the OECD TL3 regional typology of the declared classification (the package’s tl3_typology, unless a tl3_typology.dta is in the input folder) to give the urban/rural breakdown typology_UR (access to cities). |  |
| `employment` | required | Employment growth and the high-growth flags (HGE), size classes (0-9, 10-19, 20-49, 50-99, 100-249, 250+), employment creation (compute_contribution()), labour productivity. Implausible one-year spikes and dips are set to missing. Scaler analysis (run_scaler_analysis()): the top-scaler ranking and the employment thresholds of the SME and mid-cap definitions. | negatives set to missing |
| `turnover` | required | Turnover growth and the high-growth flags (HGT), turnover creation, labour productivity (turnover per employee), labour share. Implausible one-year spikes and dips are set to missing. Non-euro countries: converted to national currency (exchange_rates.dta) for growth. The build checks that turnover per employee fits EUR thousand. Scaler analysis: the top-scaler ranking and the turnover ceilings of the EU SME and small mid-cap definitions. | money variable; negatives set to missing |
| `exp_revenues_goods` | not used | Cleaned and rescaled with the other money variables and kept in the panel; no output uses it (the trade package uses trade_RAW instead). | money variable; negatives set to missing |
| `exp_revenues_services` | not used | Cleaned and rescaled with the other money variables and kept in the panel; no output uses it. | money variable; negatives set to missing |
| `labour_costs` | optional | Labour share (labour_costs / turnover), average wage, the weights of multi-factor productivity (MFP), and gross profit in compute_predictors(). compute_predictors() needs it. | money variable; negatives set to missing |
| `operating_costs` | not used | Cleaned and rescaled and kept in the panel; no output uses it. | money variable; negatives set to missing |
| `services_costs` | not used | Cleaned and rescaled and kept in the panel; no output uses it. | money variable; negatives set to missing |
| `depr_amort` | optional | Investment (capex = change in tangible fixed assets + depreciation) for the financial-dependence ratio findep_rat4. | money variable; negatives set to missing |
| `interest_costs` | optional | Financial-dependence ratio findep_rat3 (interest_costs / total_liabilities). | money variable; negatives set to missing |
| `intangible_fixed_assets` | not used | Cleaned and rescaled and kept in the panel; no output uses it. | money variable; negatives set to missing |
| `tangible_fixed_assets` | optional | Capital intensity (phys_assets = tangible_fixed_assets / turnover), the capital input of MFP, investment for findep_rat4. compute_predictors() needs it. | money variable; negatives set to missing |
| `fixed_assets` | not used | Cleaned and rescaled and kept in the panel; no output uses it. | money variable; negatives set to missing |
| `current_assets` | optional | Financial-dependence ratio findep_rat1 (current_assets / total_assets). | money variable; negatives set to missing |
| `total_assets` | optional | Financial-dependence ratios findep_rat1 and findep_rat2. Scaler analysis: the balance-sheet ceilings of the EU SME and small mid-cap definitions; without it, a firm below the employment threshold but with turnover above the ceiling has no status under those definitions. | money variable; negatives set to missing |
| `loans` | not used | Cleaned and rescaled and kept in the panel; no output uses it. | money variable; negatives set to missing |
| `total_liabilities` | optional | Financial-dependence ratios findep_rat2 (total_liabilities / total_assets) and findep_rat3. | money variable; negatives set to missing |
| `gross_profit` | not used | Rescaled with the other money variables. compute_predictors() replaces it by added_value - labour_costs, so a supplied value is not used. | money variable |
| `profit_after_tax` | not used | Kept in the panel as supplied (not rescaled); no output uses it. |  |
| `added_value` | optional | Labour productivity (labour_prod = log value added per employee), MFP, gross profit. compute_predictors() needs it. | money variable; negatives set to missing |
| `cash_flow` | optional | Financial-dependence ratio findep_rat4 ((capex - cash_flow) / capex). | money variable |
| `independent` | optional | Breakdown (L3independent) and share of independent firms in the characteristics and persistence tables; a breakdown and a regressor in compute_predictors(). Scaler analysis: a breakdown and a covariate of the mid-cap hazard model (the EU definitions add up linked enterprises, the data are firm-level). |  |
| `uco` | optional | foreign_owned = 1 when uco is a country other than the country of the data (config_scaleup(country = )); a breakdown and a share in the tables. |  |

### Other columns the package reads

These are not part of the dictionary, but `base_financials` may carry
them:

- `age_cat`: the age class instead of `birth_year`, coded 0 (0-5 years),
  6 (6-10 years) and 11 (11 years or more). With both supplied,
  `birth_year` is used for age and entry and the supplied `age_cat` is
  kept as the age class.
- `number_plants`, `multiplant`: if already present in `base_financials`
  (from an earlier run), they are kept for the firm-years without
  records in `plants_RAW`.
- `consolidation_code`: the type of accounts (codes as in Orbis). Where
  present, the scaler analysis
  ([`run_scaler_analysis()`](https://amannj.github.io/OECDscaleup/reference/run_scaler_analysis.md))
  gives a mid-cap status only to unconsolidated accounts (`U1`, `U2`).
- `country`: dropped.

## plants_RAW

The plant file is optional. Without it there is no `multiplant`
indicator and the tables have no breakdown by single- and multi-plant
firms.

### What to supply

| Variable | Priority | Definition | Format and coding | Source (SBS code) | Notes |
|:---|:---|:---|:---|:---|:---|
| `idf` | must-have | unique firm-level identifier | numeric |  | Allows the data to be joined with base_financials. |
| `idp` | must-have | unique plant-level identifier | numeric |  | It should not change if a plant is acquired by a new firm. |
| `year` | must-have | calendar year | numeric |  |  |
| `p_region_2d` | nice-to-have, second order | plant location, TL2 (NUTS 2) code, same classification as region_2d | string |  |  |
| `p_region_3d` | nice-to-have, second order | plant location, TL3 (NUTS 3) code, same classification as region_3d | string |  |  |
| `hq` | nice-to-have, second order | indicator of whether a plant is the firm’s headquarters | numeric; 1 = the plant is the firm’s headquarters, 0 = not the headquarters |  |  |

### What the package does with it

| Variable | The package needs it | What the package does with it | Cleaning |
|:---|:---|:---|:---|
| `idf` | required (if the file is supplied) | Links plants to firms. |  |
| `idp` | required (if the file is supplied) | number_plants = distinct plants of a firm in a year; multiplant = 1 with more than one plant, a breakdown (L3multiplant) and a share in the tables. |  |
| `year` | required (if the file is supplied) | Plants are counted per firm and year. |  |
| `p_region_2d` | not used | Not used. |  |
| `p_region_3d` | not used | Not used. |  |
| `hq` | not used | Not used. |  |

## Reference data

Two reference tables ship with the package and are updated with it:

- `tl3_typology`: the OECD regional typology of small (TL3) regions,
  from the OECD territorial correspondence table ([OECD geographical
  definitions](https://www.oecd.org/en/data/datasets/oecd-geographical-definitions.html),
  <http://oe.cd/geostats>). The package uses its access-to-cities
  typology (large metropolitan, metropolitan, near a metropolitan area,
  near a small or medium city, remote) for the urban/rural breakdown, in
  the classification declared with `tl_classification`.
- `exchange_rates`: annual average euro exchange rates for the non-euro
  countries (Canada, Denmark, Croatia, Hungary, Romania). Turnover is
  converted to national currency before growth is computed, so that
  growth rates do not move with the exchange rate.

| Package version | Regional typology (`tl3_typology`) | Exchange rates (`exchange_rates`) |
|----|----|----|
| **0.2.0.9000** (current) | OECD territorial correspondence table TL2024, **version of 20 November 2026**: TL2024 (default) and TL2021 | **2008-2025**: Eurostat `ert_bil_eur_a` (update of 8 July 2026); Croatia: ECB annual averages to 2022, the fixed conversion rate 7.53450 from 2023 (euro adoption) |
| 0.1.0 | OECD TL2021 typology | 2008-2022 |

The OECD revises the typology within a version of the classification: in
the version of 20 November 2026, the access-to-cities typology of
non-metropolitan regions in EU countries and of non-EU countries was
still being updated, and Türkiye has no access-to-cities typology.
Between TL2021 and TL2024 the TL3 codes changed in Germany, Finland, the
United Kingdom, Latvia, the Netherlands, Norway and Portugal, and the
typology changed for about 200 regions, so the urban/rural breakdown can
differ from version 0.1.0. Details:
[`?tl3_typology`](https://amannj.github.io/OECDscaleup/reference/tl3_typology.md),
[`?exchange_rates`](https://amannj.github.io/OECDscaleup/reference/exchange_rates.md).

## Sources and references

Sources: BR = business register; BD = business demography; SBS =
structural business statistics; ITGS = international trade in goods
statistics; ITSS = international trade in services statistics; IFATS =
inward foreign affiliates statistics.

- BACH Working Group (2015), *The Bank for the Accounts of Companies
  Harmonized (BACH) database*, ECB Statistics Paper No. 11:
  <https://www.ecb.europa.eu/pub/pdf/scpsps/ecbsp11.en.pdf>.
- ERICA Working Group (2018), *ERICA methodological note*:
  <https://www.eccbso.org/system/files/inline-files/Doc3.4_ERICAWG_ERICA%20methodological%20note_2018_F.pdf>.
- The SBS codes are from Eurostat (2021), *Methodological manual on
  European structural business statistics, 2021 edition*:
  <https://ec.europa.eu/eurostat/documents/3859598/13985433/KS-GQ-21-016-EN-N.pdf/e9410e2b-eba1-7a09-554b-dff3ac1df6bf?t=1639751446385>.
