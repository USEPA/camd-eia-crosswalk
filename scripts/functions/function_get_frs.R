## -------------------------------
##
## Import FRS data 
## 
## Purpose: 
## 
## This file includes all necessary functions to include FRS data in the crosswalk
##
## -------------------------------

get_frs_id <- function(plant_id) {
  
  #' @name get_frs_id
  #' 
  #' Function to get FRS ID for plant_id provided across each program system specified.
  #' 
  #' @param plant_id the plant_id to get FRS data for 
  #' @returns FRS IDs based on specified program IDs for 
  
  # Program system acronyms to include in FRS API query
  systems <- c("EIA-860", "CAMDBS", "EGRID")
  
  for (sys in systems) {
    id <- get_frs_id_sys(plant_id, sys)
    if (!is.na(id)) {
      return(id)
    }
  }
  return(NA)
}


get_frs_id_sys <- function(plant_id, sys) {
  
  #' @name get_frs_id_sys
  #' 
  #' Queries FRS API and returns FRS ID given plant ID and program system acronym
  #' 
  #' @param plant_id EIA or EPA plant_id 
  #' @param sys FRS program system acronym 
  #' @return FRS ID
  
  require(stringr)
  require(httr)
  require(jsonlite)
  require(purrr)
  
  frs_endpoint <-
    str_glue("https://ofmpub.epa.gov/frs_public2/frs_rest_services.get_facilities?pgm_sys_acrnm={sys}&pgm_sys_id={plant_id}&output=JSON")
  
  response <- GET(frs_endpoint)
  
  text_json <-
    str_replace_all(suppressMessages(content(response, as = "text")), "[\\r\\n\\t]+", "")
  
  raw_json <- fromJSON(text_json)
  
  if(length(pluck(raw_json, 1, "FRSFacility")) == 0) {
    return(NA)
  }
  frs_id <- pluck(raw_json, 1, "FRSFacility", "RegistryId")
  
  print(glue::glue("Success for {plant_id}"))
  
  return(as.numeric(frs_id))
}
