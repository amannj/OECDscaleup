#' NACE Rev. 2 / Rev. 2.1: check the sector codes and bring them to Rev. 2
#'
#' The pipeline's sector rules (the sectors left out, the technology and A38
#' groupings) are written for NACE Rev. 2. NACE Rev. 2.1 (Commission Delegated
#' Regulation (EU) 2023/137, statistics from reference year 2025) adds a
#' section and shifts the section letters from K on, and abolishes division
#' 45. Fed into Rev. 2 rules unchanged, Rev. 2.1 codes leave out ICT,
#' administrative and other services and keep finance and public
#' administration.
#'
#' `config$nace_revision` declares the revision of the input (with
#' `config$nace_rev21_from` for a panel that switches). This function
#' * stops, with counts per year (no records), when a section letter does not
#'   belong to its division under the declared revision, when a Rev. 2.1 year
#'   has division 45, or a Rev. 2 year has section V;
#' * converts Rev. 2.1 years to Rev. 2: letters from the division (or, without
#'   a division, shifted back: Rev. 2.1 K and J -> J, L -> K, ..., V -> U), and
#'   repair of motor vehicles (group 95.3) back to 45.2. Two Rev. 2.1 moves
#'   cannot be undone at three digits and stay where Rev. 2.1 puts them: the
#'   sale of motor vehicles (in 46 and 47) and the development of building
#'   projects (68.12, in real estate). Both stay in the same broad groups except
#'   building development (construction in Rev. 2).
#'
#' @param data `base_financials` after the column checks.
#' @param config A `scaleup_config`.
#' @return `data` with Rev. 2 codes in `sector_1d`, `sector_2d`, `sector_3d`.
#' @noRd
nace_to_rev2 <- function(data, config) {
  yr <- as.double(data$year)
  rev21 <- if (identical(config$nace_revision, "2.1")) {
    rep(TRUE, nrow(data))
  } else if (!is.null(config$nace_rev21_from)) {
    !is.na(yr) & yr >= config$nace_rev21_from
  } else {
    rep(FALSE, nrow(data))
  }
  s1 <- as.character(data$sector_1d)
  s1[s1 %in% c(".", "")] <- NA_character_
  s2 <- as.double(data$sector_2d)

  expected <- ifelse(rev21, nace_section(s2, "2.1"), nace_section(s2, "2"))
  mismatch <- !is.na(s1) & !is.na(s2) & !is.na(expected) & s1 != expected
  div45 <- rev21 & s2 %in% 45
  letter_v <- !rev21 & s1 %in% "V"
  bad <- mismatch | div45 | letter_v
  if (any(bad)) {
    by_year <- tapply(bad, yr, sum)
    by_year <- by_year[by_year > 0]
    declared <- if (identical(config$nace_revision, "2.1")) "NACE Rev. 2.1 in every year" else if (is.null(config$nace_rev21_from)) {
      "NACE Rev. 2 in every year"
    } else sprintf("NACE Rev. 2 before %d and Rev. 2.1 from %d", config$nace_rev21_from, config$nace_rev21_from)
    rlang::abort(
      c(
        sprintf("The sector codes do not match the declared revision (%s).", declared),
        "*" = sprintf("Firm-years whose sector_1d does not belong to their sector_2d: %d.", sum(mismatch)),
        "*" = sprintf("Firm-years with division 45 in a Rev. 2.1 year: %d; with section V in a Rev. 2 year: %d.",
                      sum(div45), sum(letter_v)),
        "*" = sprintf("By year: %s.", paste(names(by_year), by_year, sep = ": ", collapse = ", ")),
        "i" = paste("Example of the difference: division 62 (computer programming) is section J in Rev. 2 and K in",
                    "Rev. 2.1. Set `nace_revision` (and `nace_rev21_from`) in config_scaleup() to the revision the data use.")
      ),
      class = "OECDscaleup_data_error"
    )
  }
  if (!any(rev21)) return(data)

  s3 <- as.double(data$sector_3d)
  repair <- rev21 & s2 %in% 95 & s3 %in% 953
  s2[repair] <- 45
  s3[repair] <- 452
  has2 <- rev21 & !is.na(s2)
  s1[has2] <- nace_section(s2[has2], "2")
  back <- c(stats::setNames(LETTERS[1:10], LETTERS[1:10]), K = "J", stats::setNames(LETTERS[11:21], LETTERS[12:22]))
  only1 <- rev21 & is.na(s2) & !is.na(s1)
  s1[only1] <- unname(back[s1[only1]])

  set <- has2 | only1 # Rev. 2 years, and Rev. 2.1 letters without a division or letter, stay as they came
  data$sector_1d[set] <- s1[set]
  data$sector_2d[repair] <- 45
  data$sector_3d[repair] <- 452
  data
}

#' Section letter of a NACE division, per revision (NA where the division does not exist)
#' @noRd
nace_section <- function(s2, revision = c("2", "2.1")) {
  revision <- match.arg(revision)
  cuts <- if (revision == "2") {
    c(1, 5, 10, 35, 36, 41, 45, 49, 55, 58, 64, 68, 69, 77, 84, 85, 86, 90, 94, 97, 99)
  } else {
    c(1, 5, 10, 35, 36, 41, 46, 49, 55, 58, 61, 64, 68, 69, 77, 84, 85, 86, 90, 94, 97, 99)
  }
  divisions <- c(1:3, 5:33, 35:39, 41:43, 45:47, 49:53, 55:56, 58:66, 68:75, 77:82, 84:88, 90:99)
  if (revision == "2.1") divisions <- setdiff(divisions, 45)
  out <- LETTERS[seq_along(cuts)][findInterval(s2, cuts)]
  out[!s2 %in% divisions] <- NA_character_
  out
}

#' Stop when turnover per employee does not fit EUR thousand
#'
#' After the rescaling of `config$financials_unit = "EUR"`, money is in EUR
#' thousand. Firms with 10-49 employees have a median turnover per employee of
#' about 20-500 (EUR 20,000-500,000) in European data; above 5,000 (EUR 5 m per
#' person) the values are euros, below 1 (EUR 1,000) not EUR thousand either.
#' @noRd
check_financials_unit <- function(data, config) {
  emp <- as.double(data$employment)
  to <- as.double(data$turnover)
  small <- !is.na(emp) & emp >= 10 & emp < 50 & !is.na(to)
  if (sum(small) < 30) return(invisible(NULL)) # too few firms to judge
  per_head <- stats::median(to[small] / emp[small])
  declared <- sprintf("`financials_unit` is \"%s\"%s", config$financials_unit,
                      if (isTRUE(config$financials_unit_default)) " (the default for this country)" else "")
  if (per_head > 5000) {
    rlang::abort(c(
      "Turnover looks like EUR, not EUR thousand.",
      "*" = "Firms with 10-49 employees have a median turnover per employee above 5,000 (EUR 5 m).",
      "i" = paste0(declared, ". Set financials_unit = \"EUR\" in config_scaleup() if the data are in euros.")
    ), class = "OECDscaleup_data_error")
  }
  if (per_head < 1) {
    rlang::abort(c(
      "Turnover looks too small for EUR thousand.",
      "*" = "Firms with 10-49 employees have a median turnover per employee below 1 (EUR 1,000).",
      "i" = paste0(declared, ". The variable dictionary asks for EUR thousand; financials_unit = \"EUR\" divides by 1000.")
    ), class = "OECDscaleup_data_error")
  }
  invisible(NULL)
}

#' Sectors left out of the analysis (Rev. 2 codes): agriculture (01-03), finance (64-66), public
#' administration (84), households (97-98), extraterritorial bodies (99); by division, or by the
#' section letter where the division is missing
#' @noRd
nace_excluded <- function(sector_1d, sector_2d) {
  s2 <- as.double(sector_2d)
  ifelse(!is.na(s2), s2 %in% c(1:3, 64:66, 84, 97:99), sector_1d %in% c("A", "K", "O", "T", "U"))
}
