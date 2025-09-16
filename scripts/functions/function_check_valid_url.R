## -------------------------------
##
## Check valid URL
## 
## Purpose: 
## 
## This function checks if a URL is valid, 
## typically to then download data using a URL
##
## Authors:
##    Teagan Goforth, Abt Global
##
## -------------------------------


check_valid_url <- function(url) {
  #' check_valid_url
  #'
  #' Function to check if the URL is valid
  
  #' @param url URL to check
  #' @return Boolean if URL is valid (TRUE) or invalid (FALSE)
  
  status <- httr::HEAD(url)$all_headers[[1]]$status == "200"
  
  return(status)
}