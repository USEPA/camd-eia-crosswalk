## -------------------------------
##
## Import FRS data 
## 
## Purpose: 
## 
## This file includes all necessary functions to include FRS data in the crosswalk
##
## -------------------------------

library(stringr)
library(httr)
library(jsonlite)
library(purrr)
library(dplyr)


include_frs <- function(crosswalk_df) { 
  
  #' @name include_frs
  #' 
  #' Adds FRS IDs to EPA-EIA crosswalk output
  #' 
  #' @param crosswalk_df Crosswalk dataframe 
  #' @return Croswalk dataframe with new column "frs_id" for each EPA plant id if one exists 
  
  require(dplyr)
  require(stringr)
  require(readr)
  
  if(!dir.exists("data/raw_data/frs")){
    dir.create("data/raw_data/frs", recursive = TRUE)
  }
  
  if(!file.exists("data/raw_data/frs/frs_ids.csv")) {
    
    message(str_glue("Obtaining FRS IDs. This may take several minutes.\n{timestamp(quiet=TRUE)}"))
    system.time(
      frs <- 
        crosswalk_df %>%
        select(epa_plant_id) %>% 
        distinct(epa_plant_id) %>%
        mutate(frs_id = purrr::map_dbl(epa_plant_id, get_frs_id)) %>%
        write_csv("data/raw_data/frs/frs_ids.csv")
    )
    message(str_glue("{timestamp(quiet=TRUE)}\nFinished obtaining FRS IDs. Writing to data/raw_data/frs/frs_ids.csv"))
  } else {
    frs <- read_csv("data/raw_data/frs/frs_ids.csv")
  }
  
  crosswalk_with_frs <- 
    crosswalk_df %>%
    left_join(frs, by = "epa_plant_id") %>%
    relocate(frs_id, .before = match_type_gen)
  
  return(crosswalk_with_frs)
}
