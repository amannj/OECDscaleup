# Top scalers: the fastest-growing high-growth firms

New analysis. Ranks the high-growth scalers of each year by how much
they grew over the 3-year window t-3..t and describes the fastest ones,
in the format of
[`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md).

## Usage

``` r
compute_top_scalers(
  config,
  accounts_indicators,
  cutoffs = c(top50 = 50, p1 = 0.01, p5 = 0.05, p10 = 0.1, p25 = 0.25),
  joint_growth = FALSE
)
```

## Arguments

- config:

  A `scaleup_config` from
  [`config_scaleup()`](https://amannj.github.io/OECDscaleup/reference/config_scaleup.md).

- accounts_indicators:

  The output of
  [`build_accounts_indicators()`](https://amannj.github.io/OECDscaleup/reference/build_accounts_indicators.md)
  (with the trade columns when built with a trade panel: then
  `L3exporter` is a breakdown too).

- cutoffs:

  Named cut-offs: values \>= 1 are a number of firms, values below 1 a
  share of the ranked scalers.

- joint_growth:

  If `TRUE`, rank only scalers whose other variable also grew over
  t-3..t (turnover for employment scalers, employment for turnover
  scalers).
  [`run_scaler_analysis()`](https://amannj.github.io/OECDscaleup/reference/run_scaler_analysis.md)
  reports both versions.

## Value

A tibble.

## Details

**Population.** Scalers as in the package, 20 % definition: employment
scalers (`HGE20`) are ranked by employment indices, turnover scalers
(`HGT20`) by turnover indices; firms with 10 to fewer than 250 employees
at t-3, from the fourth panel year on (as in
[`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md)).
Growth driven by an acquisition (`acquisition == 1`) is excluded; a
missing `acquisition` flag does not exclude the firm.

**Indices** (x = employment or turnover):

- `rel`: relative growth, x / L3x - 1 (same ranking as the CAGR);

- `abs`: absolute growth, x - L3x;

- `bs`: Birch-Schreyer, (x - L3x) \* x / L3x.

**Ranking.** Within each year (one country per run). Ties on the index
are broken by a second, then a third index: rel -\> abs -\> bs, abs -\>
rel -\> bs, bs -\> abs -\> rel. Firms still tied share the better rank,
so every firm tied at a cut-off is included.

**Cut-offs.** `top50` = rank \<= 50; `p1`, `p5`, `p10`, `p25` = rank \<=
the share times the number of ranked scalers that year, rounded up (at
least 1). Every cut-off is reported for every cell; nothing is blanked.

**Output.** One row per (year, sample, category, group). `sample` is
`<scaler>_<index>_<cutoff>` (e.g. `HGE20_rel_p10`) or `<scaler>_ranked`
for all ranked scalers. Columns as in
[`compute_characteristics()`](https://amannj.github.io/OECDscaleup/reference/compute_characteristics.md)
(firm count, approximate medians, means, ownership shares, optional
dominance), plus:

- `n_ranked`, `rank_cutoff`: scalers ranked that year and the rank
  cut-off;

- `S3pos_employment`, `S3pos_turnover`: the cell's gross 3-year creation
  (sum of the positive x - L3x);

- `share_creation_employment`, `share_creation_turnover`: that creation
  over the gross creation of all firms in the same year and group
  (entrants count with their whole size, as in
  [`compute_contribution()`](https://amannj.github.io/OECDscaleup/reference/compute_contribution.md);
  the group is taken at t-3, else at t).
