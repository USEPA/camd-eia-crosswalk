## -------------------------------
##
## Include NEEDS
## 
## Purpose: 
## 
## This file has a function to import NEEDS data and include it in the crosswalk
## 
## -------------------------------

# Load libraries and functions ------------------
library(dplyr)
library(readxl)
library(readr)

# Load necessary functions
source("scripts/functions/function_check_valid_url.R")
source("scripts/functions/function_check_params.R")
source("scripts/functions/function_save_data.R")

# Set up year parameters
if (!exists("params")) {
  params <- check_params()
} else {
  print("Crosswalk parameters are already defined.")
}

# Load data ---------------------------
## Crosswalk data ------------------

epa_eia_matched <- read_rds(glue::glue("data/outputs/{params$crosswalk_year}/epa_eia_match.RDS")) 

eia_matched <- # NEEDS is matched to EIA data. Pull out EIA columns only. 
  epa_eia_matched$epa_eia_crosswalk %>% 
  select(contains("eia"))

## NEEDS ------------------

if(!dir.exists("data/raw_data/needs")){
  dir.create("data/raw_data/needs", recursive = TRUE)
}

needs_path <- "data/raw_data/needs/needs_v6_november_2018_reference_case_0.xlsx"
needs_url <- "https://www.epa.gov/sites/default/files/2019-10/needs_v6_november_2018_reference_case_0.xlsx"

if(check_valid_url(needs_url)) { # download NEEDS from EPA's website
  download.file(
    url = needs_url, 
    destfile = needs_path)
} else { 
  print("NEEDS data URL does not exist. Check and update the URL.")}


# Load in NEEDS data 
needs <-
  read_excel(
    needs_path,
    sheet = "NEEDS v6_Active",
    range = cell_cols("B:E")
  ) %>%
  select(
    needs_unique_id = UniqueID_Final,
    needs_plant_id = `ORIS Plant Code`,
    needs_unit_id = `Unit ID`,
    needs_type = `Boiler/Generator/Committed Unit`
  )

# Filter NEEDS boilers ------------------------
needs_boilers <- 
  needs %>%
  filter(needs_type == "B") %>%
  select(-needs_type)

# Filter NEEDS generators --------------------
needs_generators <- 
  needs %>%
  filter(needs_type == "G") %>%
  mutate(needs_generator_id = needs_unit_id) %>%
  select(-needs_type, -needs_unit_id)

# Join NEEDS generators and boilers to EIA data ----------------------
eia_needs_generators <-
  eia_matched %>% 
  left_join(
    needs_generators,
    by = c("eia_plant_id" = "needs_plant_id", "eia_generator_id" = "needs_generator_id")
  ) %>%
  mutate(needs_unique_g_id = needs_unique_id) %>%
  select(-needs_unique_id)

eia_needs_boilers_generators <-
  eia_needs_generators %>% 
  left_join(
    needs_boilers,
    by = c("eia_plant_id" = "needs_plant_id", "eia_boiler_id" = "needs_unit_id")
  ) %>%
  mutate(needs_unique_b_id = needs_unique_id) %>%
  select(-needs_unique_id)

# Prepare data for export ---------------------
eia_needs <-
  eia_needs_boilers_generators %>%
  mutate(needs_unique_id = if_else(is.na(needs_unique_b_id), needs_unique_g_id, needs_unique_b_id)) %>%
  select(-needs_unique_b_id, -needs_unique_g_id) %>% 
  distinct()

# Export data -----------------------------

save_data(eia_needs, "data/outputs", "eia_needs_match.RDS")

