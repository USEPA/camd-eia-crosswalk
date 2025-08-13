## -------------------------------
##
## Import NEEDS
## 
## Purpose: 
## 
## This file imports NEEDS data to include with the crosswalk
## 
## 
## -------------------------------

# Load libraries -----------------
library(dplyr)
library(readxl)

# Download NEEDS from EPA's website ------------------

if(!dir.exists("data/raw_data/needs")){
  dir.create("data/raw_data/needs", recursive = TRUE)
}

needs_path <- "data/raw_data/needs/needs_v6_november_2018_reference_case_0.xlsx"
needs_url <- "https://www.epa.gov/sites/default/files/2019-10/needs_v6_november_2018_reference_case_0.xlsx"

download.file(
  url = needs_url, 
  destfile = needs_path)

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

# Filter NEEDS boilers
needs_boilers <- needs %>%
  filter(needs_type == "B") %>%
  select(-needs_type)

# Filter NEEDS generators 
needs_generators <- 
  needs %>%
  filter(needs_type == "G") %>%
  mutate(needs_generator_id = needs_unit_id) %>%
  select(-needs_type, -needs_unit_id)

epa_eia_crosswalk <-
  epa_eia_crosswalk %>% 
  left_join(
    needs_generators,
    by = c("eia_plant_id" = "needs_plant_id", "eia_generator_id" = "needs_generator_id")
  ) %>%
  mutate(needs_unique_g_id = needs_unique_id) %>%
  select(-needs_unique_id)

epa_eia_crosswalk <-
  epa_eia_crosswalk %>% 
  left_join(
    needs_boilers,
    by = c("eia_plant_id" = "needs_plant_id", "eia_boiler_id" = "needs_unit_id")
  ) %>%
  mutate(needs_unique_b_id = needs_unique_id) %>%
  select(-needs_unique_id)

epa_eia_crosswalk <-
  epa_eia_crosswalk %>%
  mutate(needs_unique_id = if_else(is.na(needs_unique_b_id), needs_unique_g_id, needs_unique_b_id)) %>%
  select(-needs_unique_b_id, -needs_unique_g_id)

epa_eia_crosswalk <- epa_eia_crosswalk %>%
  relocate(needs_unique_id, .before = match_type_gen)
