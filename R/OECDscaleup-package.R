#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom dplyr %>%
## usethis namespace: end
NULL

# .data and := are rlang/dplyr NSE conventions (used throughout for tidy
# evaluation and dynamic column names), not literal undefined globals -
# this is the standard, widely-used suppression for R CMD check's static
# analysis, which cannot otherwise tell the two apart.
utils::globalVariables(c(".data", ":=", "variable_dictionary", "tl3_typology"))
