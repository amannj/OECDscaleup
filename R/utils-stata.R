# Stata storage / arithmetic semantics needed for bug-for-bug parity.
#
# Verified against Stata 19.5 output on the synthetic reproduction datasets
# (see the reproduction harness kept outside this repository).

#' Value of a Stata `gen` expression (default storage type `float`)
#'
#' Stata turns every out-of-range arithmetic result into missing: `x/0`,
#' `0/0`, `ln(0)`, `ln(-1)` and overflow are all `.`. R instead yields
#' `Inf`, `-Inf` or `NaN`. Stata's `gen` also stores the result as a 4-byte
#' `float` unless a type is given, which matters wherever the stored value is
#' later compared with a threshold: with integer employment, `8/10 > 0.8` is
#' `FALSE` in double precision, but `TRUE` once `0.8` is stored as the float
#' `0.800000011920929`.
#'
#' @param x A numeric vector (the expression, evaluated in double precision as Stata does).
#' @return `x` rounded to single precision, with non-finite values set to `NA`.
#' @noRd
stata_float <- function(x) {
  x <- as.double(x)
  ok <- is.finite(x)
  out <- rep(NA_real_, length(x))
  if (any(ok)) {
    out[ok] <- readBin(writeBin(x[ok], raw(), size = 4), "double", size = 4, n = sum(ok))
  }
  out[!is.finite(out)] <- NA_real_ # float overflow is missing in Stata too
  out
}

#' Value of a Stata expression kept in double precision
#'
#' As `stata_float()` but without the float rounding: for `replace` on a
#' variable that is already `double`, or for values Stata only ever holds in
#' a double scalar (`r()` results, `collapse` outputs).
#'
#' @param x A numeric vector.
#' @return `x` with non-finite values set to `NA`.
#' @noRd
stata_double <- function(x) {
  x <- as.double(x)
  x[!is.finite(x)] <- NA_real_
  x
}

#' Stata's power operator `x^y`
#'
#' Stata evaluates `x^y` as `exp(y * ln(x))`, not with a correctly rounded
#' `pow()`: `8^(1/3)` is `1.9999999999999998` in Stata but `2` in R, and
#' `1.331^(1/3) - 1` is `0.09999999999999987` in Stata but
#' `0.10000000000000009` in R. That flips the 10% / 20% high-growth flags of
#' firms growing at exactly 10% / 20% a year. Checked bit for bit against
#' Stata 19.5 on 200,000 values: identical in 99.5% of cases, within 1 ulp
#' in the rest (differences between the two maths libraries).
#'
#' @param x,y Numeric vectors.
#' @return `exp(log(x) * y)`, with non-finite results set to `NA` (Stata missing).
#' @noRd
stata_pow <- function(x, y) {
  stata_double(suppressWarnings(exp(log(x) * y)))
}

#' Stata's `round(x, y)`: `x` rounded in units of `y`
#'
#' Evaluated as `floor(x / y + 0.5) * y`, bit-identical to Stata 19.5 on
#' 100,000 values including 50,000 exact halves. Multiplying by `1 / y`
#' instead (as [round_half_up()] does) differs in the last bit and so at
#' exact halves: `round(0.04375, 0.0001)` is `0.0437` in Stata.
#'
#' @param x Numeric vector.
#' @param y Rounding unit.
#' @return Numeric vector.
#' @noRd
stata_round <- function(x, y) {
  floor(x / y + 0.5) * y
}

#' Codes Stata's `encode` would assign
#'
#' `encode` numbers the distinct non-missing strings `1, 2, ...` in byte
#' (C-locale) sort order, which is not R's default locale-aware `sort()`.
#' Empty strings are Stata's string missing and get no code. If a value label
#' with the new variable's name already exists in memory, `encode` extends it:
#' strings it already covers keep their code, new ones are appended after its
#' largest code (this happens to `typology_UR`, whose label arrives with the
#' `tl3_typology.dta` merge).
#'
#' @param x A character vector.
#' @param existing Optional named numeric vector (label -> code) already defined.
#' @return A named numeric vector: names are the strings, values their codes.
#' @noRd
stata_encode_levels <- function(x, existing = NULL) {
  x <- sort(unique(x[!is.na(x) & x != ""]), method = "radix")
  if (is.null(existing) || !length(existing)) return(stats::setNames(as.double(seq_along(x)), x))
  new <- setdiff(x, names(existing))
  c(existing, stats::setNames(max(existing) + as.double(seq_along(new)), new))
}

#' Stata's `encode` as a labelled numeric vector
#'
#' @param x A character vector.
#' @param codes The code table, from `stata_encode_levels()`; defaults to `x`'s own.
#' @return A `haven_labelled` double vector.
#' @noRd
stata_encode <- function(x, codes = stata_encode_levels(x)) {
  haven::labelled(unname(codes[x]), labels = codes)
}
