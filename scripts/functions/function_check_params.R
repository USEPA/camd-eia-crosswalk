## -------------------------------
##
## Check params function
## 
## Purpose: 
## 
## This file contains the function that is for checking params variables
##
## -------------------------------

check_params <- function() {
  
  #' @name check_params
  #' 
  #' Create list params that contains all necessary crosswalk parameters
  #' and check that the input variables match acceptable responses.
  #' 
  #' @return list params
  #' Example: params <- check_params()
  
  # check if parameters for crosswalk data year need to be defined
  # this is only necessary when running the script outside of r_epa_eia_crosswalk.qmd
  # user will be prompted to input parameters in the console if params does not exist
  
  if(exists("params")) {
    
    if("crosswalk_year" %in% names(params) & "earliest_retirement_year" %in% names(params) & 
        "include_FRS" %in% names(params) & "include_NEEDS" %in% names(params)) { # if all params exist, do not redefine
      print("All necessary parameters are already defined.") 
    } else if(!("crosswalk_year" %in% names(params))) {  # if params() is defined, but crosswalk_year is not, define it here 
      params$crosswalk_year <- readline(prompt = "Input crosswalk_year: ")
      params$crosswalk_year <- as.character(params$crosswalk_year) 
    } else if(!("earliest_retirement_year" %in% names(params))) {  # if params() is defined, but earliest_retirement_year is not, define it here 
      params$earliest_retirement_year <- readline(prompt = "Input earliest_retirement_year: ")
      params$earliest_retirement_year <- as.character(params$earliest_retirement_year) 
    } else if(!("include_FRS" %in% names(params))) {  # if params() is defined, but include_FRS is not, define it here 
      params$include_FRS <- readline(prompt = "Input include_FRS (TRUE/FALSE): ")
    } else if(!("include_NEEDS" %in% names(params))) {  # if params() is defined, but include_NEEDS is not, define it here 
      params$include_NEEDS <- readline(prompt = "Input include_NEEDS (TRUE/FALSE): ")
    }
  } else { 
    params <- list()
    params$crosswalk_year <- readline(prompt = "Input crosswalk_year: ")
    params$crosswalk_year <- as.character(params$crosswalk_year)
    params$earliest_retirement_year <- readline(prompt = "Input earliest_retirement_year: ")
    params$earliest_retirement_year <- as.character(params$earliest_retirement_year)
    params$include_FRS <- readline(prompt = "Input include_FRS (TRUE/FALSE): ")
    params$include_NEEDS <- readline(prompt = "Input include_NEEDS (TRUE/FALSE): ")
  }
  
  # valid eGRID years (update this every crosswalk year to include latest year)
  valid_year_inputs <- c(1996:2023) # flag if this is correct for crosswalk
  
  if(!(params$crosswalk_year %in% valid_year_inputs)) {
    print("The input for params$crosswalk_year is not one of the valid responses. Please input a year within the range of 1996-2023.")
    return(check_params()) # restart function for new inputs
  }
  
  if(!(params$earliest_retirement_year %in% valid_year_inputs)) {
    print("The input for params$earliest_retirement_year is not one of the valid responses. Please input a year within the range of 1996-2023.")
    return(check_params()) # restart function for new inputs
  }
  
  if(!(params$include_FRS %in% c(TRUE, FALSE))) {
    print("The input for params$include_FRS is not one of the valid responses. Please input TRUE or FALSE.")
    return(check_params()) # restart function for new inputs
  }
  
  if(!(params$include_NEEDS %in% c(TRUE, FALSE))) {
    print("The input for params$include_NEEDS is not one of the valid responses. Please input TRUE or FALSE.")
    return(check_params()) # restart function for new inputs
  }

  return(params)
}
