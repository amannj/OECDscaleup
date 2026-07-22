# Country-specific data patches

The source Stata pipeline hardcodes three country-list branches inside
`n0_1_accounts_indicators_v2.do` to work around idiosyncrasies of
specific national data sources — these are data-source patches, not
general econometric rules (see `Analysis/stata.md` section 8 and
`Pseudocode/n0_1_accounts_indicators_v2.md` steps 6, 8, 17). They are
kept here as one explicit, documented table instead of scattered
`if (country %in% c(...))` chains, so extending them as more countries
join the project only requires editing this table.

## Usage

``` r
country_patches
```

## Format

A named list with three character vectors:

- rescale_to_thousands:

  Countries whose raw financial variables are not in the package's
  EUR-thousand convention and must be divided by 1000:
  `PT, ES, RO, SI, HU`.

- non_euro:

  Countries whose `turnover` needs converting to national currency via
  `exchange_rates.dta` (used to detect the "20-200-20"
  employment/turnover jump pattern in national-currency terms):
  `DK, HU, RO, CA, HR`.

- aggregate_small_regions:

  Countries where TL2 regions with a thin count of HGET10 scalers get
  coarsened up to the TL1 level: `AT, CA, HU, IT, NL, ES, RO`.
