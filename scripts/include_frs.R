## -------------------------------
##
## Import FRS data 
## 
## Purpose: 
## 
## This file includes all necessary functions to include FRS data in the crosswalk
##
## -------------------------------

# Load libraries and functions ---------------------
library(stringr)
library(httr)
library(jsonlite)
library(purrr)
library(dplyr)
library(readr)

# Load necessary functions
source("scripts/functions/function_check_params.R")
source("scripts/functions/function_save_data.R")
source("scripts/functions/function_get_frs.R")

# Set up year parameters
if (!exists("params")) {
  params <- check_params()
} else {
  print("Crosswalk parameters are already defined.")
}

# Load data ------------------------------
## Crosswalk data ----------------------------

epa_eia_matched <- read_rds(glue::glue("data/outputs/{params$crosswalk_year}/epa_eia_match.RDS")) 

epa_matched <- 
  epa_eia_matched$epa_eia_crosswalk %>% # FRS is matched to EPA data. Pull out EPA columns only. 
  select(contains("epa"))

## FRS data -----------------------------

# check if directory exists
if(!dir.exists("data/raw_data/frs")){
  dir.create("data/raw_data/frs", recursive = TRUE)
}

# check if FRS data already is downloaded
if(!file.exists("data/raw_data/frs/frs_ids.csv")) {
  
  message(str_glue("Obtaining FRS IDs. This may take several minutes.\n{timestamp(quiet=TRUE)}"))
  system.time(
    frs <- 
      epa_matched %>%
      select(epa_plant_id) %>% 
      distinct(epa_plant_id) %>%
      mutate(frs_id = purrr::map_dbl(epa_plant_id, get_frs_id)) %>%
      write_csv("data/raw_data/frs/frs_ids.csv")
  )
  message(str_glue("{timestamp(quiet=TRUE)}\nFinished obtaining FRS IDs. Writing to data/raw_data/frs/frs_ids.csv"))
} else {
  frs <- read_csv("data/raw_data/frs/frs_ids.csv")
}

epa_frs <- 
  epa_matched %>% 
  left_join(frs, by = c("epa_plant_id")) %>% 
  distinct()

# Export data -----------------------------

save_data(epa_frs, "data/outputs", "epa_frs_match.RDS")

