## -------------------------------
##
## Modifier functions
## 
## Purpose: 
## 
## This file contains all modifier functions required for crosswalk matching
##
##
## -------------------------------

# The modifier functions for modifying unit identifiers, such as unit ID/boiler ID and/or generator ID

#' Function to convert all strings in modified generator and combustion unit identifiers to uppercase and remove whitespace and special characters
#'
#' @param x A string to modify
#'
#' @return A string translated to all uppercase characters with all characters besides alphanumeric removed, including spaces
#'
#' @examples
#' mod_identifiers_special_char("**Alpha Numeric123-")
#' mod_identifiers_special_char("    a,b,c,1,3,&")

mod_identifiers_special_char <- function(x) {
  # str_replace_all uses "\\W" (uppercase) to represent non alphanumeric characters, including whitespace
  return(str_to_upper(str_replace_all(x, "\\W", "")))
}


#' Function to convert numbers represented as strings to numeric type
#'
#' @param x A string to modify as a numeric type
#'
#' @return A number converted from the input string. If not possible to convert to numeric type, return original string
#'
#' @examples
#' mod_to_numeric("0001")
#' mod_to_numeric("00.12300")
#' mod_to_numeric("ABC1")

mod_to_numeric <- function(x) {
  number <- as.numeric(x)
  ifelse(!is.na(number), number, x)
}


#' Function to remove leading letters in modified generator and combustion unit identifiers
#'
#' @param x A string to modify
#'
#' @return A string with leading characters removed leaving only a trailing number or number-letter combo
#'
#' @examples
#' mod_identifiers_leading_letters("GEN1A")
#' mod_identifiers_leading_letters("HSRVG1")
#' mod_identifiers_leading_letters("1234AGEN2")
#' mod_identifiers_leading_letters("123ABC")

mod_identifiers_leading_letters <- function(x) {
  
  # str_extract uses "\\d" and "[:alpha:]"" to represent numbers and letters, respectively
  # Extract numbers and number-letter combinations at the end of the identifier
  number <- str_extract(x, "\\d+$")
  number_letter <- str_extract(x, "\\d+[:alpha:]+$")
  mod_value <- ifelse(!is.na(number), as.numeric(number), if_else(!is.na(number_letter), number_letter, x))
  
  return(mod_value)
}
