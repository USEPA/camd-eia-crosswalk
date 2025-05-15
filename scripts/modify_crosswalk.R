## -------------------------------
##
## Modify crosswalk
## 
## Purpose: 
## 
## 
## 
##
## -------------------------------

# Load libraries and functions ------
library(tidyverse)
library(lubridate) # Make working with dates easier
library(httr) # Perform HTTP requests (in this case used to get data from FACT API)
library(tidyjson) # Work with json objects in a tidy way. Useful for highly nested objects and "ragged" arrays and/or objects (varying lengths by document)
library(jsonlite)
library(readxl) # Read data from xlsx files via read_excel()
library(openxlsx) # Create and write to formatted xlsx documents
library(purrr) # Use of partial and map functions
library(janitor)

# Load necessary functions
source("scripts/functions/function_crosswalk_match.R")
source("scripts/functions/function_modifier.R")

# Set up year dimensions
crosswalk_year <- 2018
earliest_retirement_year <- 2010

# Load data -------
eia_raw <- readRDS(glue::glue("data/raw_data/eia/{crosswalk_year}/eia_raw.RDS"))
epa_raw <- readRDS(glue::glue("data/raw_data/epa/{crosswalk_year}/epa_raw.RDS"))

# Set up raw data 
eia_boiler <- eia_raw$boiler
eia_generator <- eia_raw$generator

epa_unit <- epa_raw

# Get manual matches and excluded EPA units from manual match file
manual_match_cols <- c("numeric", "text", "text", "numeric", "text", "text")

unit_manual_matches <-
  read_excel(
    "manual_matches.xlsx",
    sheet = "unit_manual_matches",
    range = cell_cols("A:F"),
    col_types = manual_match_cols,
    trim_ws = TRUE
  ) %>% clean_names()
unit_manual_excluded <-
  read_excel(
    "manual_matches.xlsx",
    sheet = "unit_manual_excluded",
    range = cell_cols("A:C"),
    col_types = head(manual_match_cols, n = 3),
    trim_ws = TRUE
  ) %>% clean_names()

rm(manual_match_cols)

# Modify EIA plant code based on eGRID known mismatch list -------
# Get plant identifier corrections from manual match excel sheet
egrid_crosswalk_cols <- c("numeric", "text", "numeric", "text")

plant_id_replacements <-
  read_excel(
    "manual_matches.xlsx",
    sheet = "plant_id_manual_matches",
    range = cell_cols("A:D"),
    col_types = egrid_crosswalk_cols,
    trim_ws = TRUE
  ) %>%
  clean_names() %>%
  select(eia_plant_id, epa_plant_id)

# Turn tibble into named character vector for recode() function
plant_id_replacements <- plant_id_replacements %>% deframe()

# For plants in the replacement tibble, add the new plant code and flag the record
# The !!! operator forces-splice the named character vector of plant code corrections
# meaning that they each become one argument to the recode function instead of one character vector as an arugment
# i.e. recode(c(a="1", b="2", c="3")) becomes recode(a="1", b="2", c="3")
eia_generator <- eia_generator %>%
  mutate(
    mod_eia_plant_id = recode(eia_plant_id, !!!plant_id_replacements),
    plant_id_change_flag = ifelse(eia_plant_id != mod_eia_plant_id, 1, 0)
  )

eia_boiler <- eia_boiler %>%
  mutate(
    mod_eia_plant_id = recode(eia_plant_id, !!!plant_id_replacements),
    plant_id_change_flag = ifelse(eia_plant_id != mod_eia_plant_id, 1, 0)
  )

rm(plant_id_replacements)
rm(egrid_crosswalk_cols)