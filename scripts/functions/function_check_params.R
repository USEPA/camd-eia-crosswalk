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
  
  #' check_params
  #' 
  #' Create list params that contains crosswalk_year and 
  #' and check that the input variables match acceptable responses.
  #' 
  #' @return list params
  #' Example: params <- check_params()
  
  # check if parameters for eGRID data year need to be defined
  # this is only necessary when running the script outside of egrid_master.qmd
  # user will be prompted to input parameters in the console if params does not exist
  
  if (exists("params")) {
    
    if ("crosswalk_year" %in% names(params) & "earliest_retirement_year" %in% names(params)) { # if params(), params$crosswalk_year, and params$earliest_retirement_year exist, do not re-define
      print("Crosswalk year and earliest retirement year parameters are already defined.") 
    } else if (!("crosswalk_year" %in% names(params))) {  # if params() is defined, but crosswalk_year is not, define it here 
      params$crosswalk_year <- readline(prompt = "Input crosswalk_year: ")
      params$crosswalk_year <- as.character(params$crosswalk_year) 
    } else if (!("earliest_retirement_year" %in% names(params))) {  # if params() is defined, but earliest_retirement_year is not, define it here 
      params$earliest_retirement_year <- readline(prompt = "Input earliest_retirement_year: ")
      params$earliest_retirement_year <- as.character(params$earliest_retirement_year) 
    }
  } else { # if params(), eGRID_year, temporal_res are not defined, define them here
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

  
  # valid temporal_res inputs
  # temporal_res_inputs <- c("annual", "monthly")
  # 
  # if (!(params$temporal_res %in% temporal_res_inputs)) {
  #   print("The input for params$temporal_res is not one of the valid responses. Please input either annual, monthly, daily, or hourly.")
  #   return(check_params()) # restart function for new inputs
  # }
  
  return(params)
}