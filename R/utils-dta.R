# Storage types of the variables in a Stata .dta file.
#
# haven::read_dta() returns every numeric column as an R double and does not
# say how Stata stored it. That matters where the Stata code changes a value in
# place: `replace v = v/1000` keeps a `float` variable `float` (the result is
# rounded to single precision), promotes `byte`/`int` to `float`, and `long` to
# `double` (checked against Stata 19.5).

#' Stata storage type of every variable in a .dta file
#'
#' Reads only the file header (formats 113-115 and 117-119, i.e. Stata 8 and
#' later). Returns `NULL` for anything it cannot parse, so callers fall back to
#' treating every numeric column as `double`.
#'
#' @param path Path to a `.dta` file.
#' @return A named character vector (names = variable names), values
#'   `"byte"`, `"int"`, `"long"`, `"float"`, `"double"` or `"str"`; or `NULL`.
#' @noRd
dta_storage_types <- function(path) {
  if (!file.exists(path)) return(NULL)
  tryCatch(read_dta_types(path), error = function(e) NULL)
}

read_dta_types <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))
  head <- readBin(con, "raw", 1024)
  if (length(head) < 120) return(NULL)
  u16 <- function(b, endian) readBin(b, "integer", 1, size = 2, signed = FALSE, endian = endian)
  u32 <- function(b, endian) { v <- readBin(b, "integer", 1, size = 4, endian = endian); if (v < 0) v + 2^32 else v }

  if (head[1] == as.raw(0x3c)) { # "<stata_dta>": formats 117-119
    at <- function(tag) grepRaw(tag, head, fixed = TRUE)[1]
    release <- as.integer(rawToChar(head[(at("<release>") + 9):(at("</release>") - 1)]))
    if (!release %in% 117:119) return(NULL)
    endian <- if (rawToChar(head[(at("<byteorder>") + 11):(at("<byteorder>") + 13)]) == "MSF") "big" else "little"
    k_at <- at("<K>") + 3
    k <- if (release == 119) u32(head[k_at:(k_at + 3)], endian) else u16(head[k_at:(k_at + 1)], endian)
    map_at <- at("<map>") + 5
    off <- function(i) { # i-th 8-byte offset of the map
      b <- head[(map_at + 8 * (i - 1)):(map_at + 8 * i - 1)]
      lo <- u32(if (endian == "little") b[1:4] else b[5:8], endian)
      hi <- u32(if (endian == "little") b[5:8] else b[1:4], endian)
      lo + hi * 2^32
    }
    seek(con, off(3) + nchar("<variable_types>"))
    codes <- readBin(con, "integer", k, size = 2, signed = FALSE, endian = endian)
    name_len <- if (release == 117) 33 else 129
    seek(con, off(4) + nchar("<varnames>"))
    names_raw <- readBin(con, "raw", k * name_len)
    type <- c("65526" = "double", "65527" = "float", "65528" = "long",
              "65529" = "int", "65530" = "byte")[as.character(codes)]
  } else { # formats 113-115: fixed 109-byte header, then typlist and varlist
    release <- as.integer(head[1])
    if (!release %in% 113:115) return(NULL)
    endian <- if (head[2] == as.raw(1)) "big" else "little"
    k <- u16(head[5:6], endian)
    seek(con, 109)
    codes <- as.integer(readBin(con, "raw", k))
    name_len <- 33
    names_raw <- readBin(con, "raw", k * name_len)
    type <- c("255" = "double", "254" = "float", "253" = "long",
              "252" = "int", "251" = "byte")[as.character(codes)]
  }
  if (length(codes) != k || length(names_raw) != k * name_len) return(NULL)
  type[is.na(type)] <- "str"
  nm <- vapply(seq_len(k), function(i) {
    b <- names_raw[((i - 1) * name_len + 1):(i * name_len)]
    end <- match(as.raw(0), b, nomatch = name_len + 1) - 1
    if (end == 0) "" else rawToChar(b[seq_len(end)])
  }, character(1))
  Encoding(nm) <- "UTF-8"
  stats::setNames(unname(type), nm)
}

#' Storage type Stata leaves after `replace v = <non-integer expression>`
#'
#' @param type Original storage types (as from `dta_storage_types()`); `NA`
#'   or unknown means `double`.
#' @return `"float"` or `"double"` for each element.
#' @noRd
stata_replace_type <- function(type) {
  ifelse(!is.na(type) & type %in% c("byte", "int", "float"), "float", "double")
}
