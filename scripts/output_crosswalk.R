## -------------------------------
##
## Output crosswalk functions
## 
## Purpose: 
## 
## This file contains all matching functions required for exporting and saving
## crosswalk file data
##
## -------------------------------

# Load libraries and functions -----------------
library(openxlsx)
library(dplyr)
library(tidyr)

# Load necessary functions
source("scripts/functions/function_check_params.R")
source("scripts/functions/function_output_crosswalk.R")

# Set up year parameters
if (!exists("params")) {
  params <- check_params()
} else {
  print("Crosswalk parameters are already defined.")
}

# check for params$diffs_only and params$agg_level
if(!("diffs_only" %in% names(params))) {  # if params() is defined, but diffs_only is not, define it here 
  params$diffs_only <- readline(prompt = "Input diffs_only: ") } 

if(!("agg_level" %in% names(params))) {  # if params() is defined, but agg_level is not, define it here 
  params$agg_level <- readline(prompt = "Input agg_level: ")
  params$agg_level <- as.character(params$agg_level) 
}

# Load data ----------------------------

epa_eia_crosswalk <- 
  read_rds(glue::glue("data/outputs/{params$crosswalk_year}/epa_eia_match.RDS"))$epa_eia_crosswalk

if(params$include_FRS == TRUE) { 
  epa_frs <- 
    read_rds(glue::glue("data/outputs/{params$crosswalk_year}/epa_frs_match.RDS"))
}

if(params$include_NEEDS == TRUE) { 
  eia_needs <- 
    read_rds(glue::glue("data/outputs/{params$crosswalk_year}/eia_needs_match.RDS"))
}

# Merge datasets where applicable -----------------------

if(params$include_FRS == TRUE) { 
  epa_eia_crosswalk <- 
    epa_eia_crosswalk %>% 
    full_join(epa_frs) %>% 
    relocate(frs_id, .before = match_type_gen)}

if(params$include_NEEDS == TRUE) { 
  epa_eia_crosswalk <- 
    epa_eia_crosswalk %>% 
    full_join(eia_needs) %>% 
    relocate(frs_id, .before = match_type_gen)}

# Format and output crosswalk ---------------------

output_crosswalk(epa_eia_crosswalk, params$agg_level, params$diffs_only)
