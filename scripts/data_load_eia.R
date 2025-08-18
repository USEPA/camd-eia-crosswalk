## -------------------------------
##
## Data load EIA
## 
## Purpose: 
## 
## This section downloads and imports data from EIA-860 for the year specified above. 
## To manually download the data from EIA, visit the [EIA-860 data](https://www.eia.gov/electricity/data/eia860/). 
## Select and download the latest year's ZIP file on the right-hand-side of the page. 
## The files used in this analysis are "3_1_Generator_Y{year}.xlsx" and "6_1_EnviroAssoc_Y{year}.xlsx", 
## with "2___Plant_Y{year}.xlsx" to get lat/long.
## 
##
## -------------------------------

# Load libraries -----
library(tidyverse)
library(lubridate)
library(httr)
library(tidyjson)
library(jsonlite)
library(readxl)
library(openxlsx)
library(purrr)
library(stringr)

# Load necessary functions -----
source("scripts/functions/function_save_output_data.R")
source("scripts/functions/function_check_params.R")

# Set up year dimensions -----
if (!exists("params")) {
  params <- check_params()
} else {
  print("Crosswalk parameters are already defined.")
}

# Define file download locations for EIA forms ----
url <- c("860" = str_glue("https://www.eia.gov/electricity/data/eia860/archive/xls/eia860{params$crosswalk_year}.zip"),
         "923" = str_glue("https://www.eia.gov/electricity/data/eia923/archive/xls/f923_{params$crosswalk_year}.zip"))

# Download EIA Files ------
forms <- c("860", "923")
for (form in forms) {
  
  # set data file names and locations
  data_file <- url[[form]]
  data_file_try2 <- stringr::str_replace(data_file, "/archive", "")
  data_destination <- glue::glue("data/raw_data/eia/{params$crosswalk_year}/{form}/")
  data_path <- paste0(data_destination,glue::glue("eia{form}{params$crosswalk_year}.zip"))

  # check if EIA form folder exists
  if(dir.exists(data_destination)) {
    print(glue::glue("Folder {data_destination} already exists."))
  } else {
    dir.create(data_destination, recursive = TRUE)
  }
  
  # download file .zip file
  download.file(data_file, data_path)
  
  # unzip .zip file
  tryCatch({
    
    # try to unzip downloaded file
    unzip(zipfile = data_path, exdir = data_destination)
    
  }, warning = function(w) {
    
    # if warning exists, download backup url and unzip
    download.file(data_file_try2, data_path)
    unzip(zipfile = data_path, exdir = data_destination)
  })
}


# Get EIA-860 Data -----

dir_860 <- str_glue("data/raw_data/eia/{params$crosswalk_year}/860/")

# Get plant location data
eia_plant <-
  read_excel(
    str_glue("{dir_860}2___Plant_Y{params$crosswalk_year}.xlsx"),
    sheet = "Plant",
    range = cell_cols("C:K"),
    skip = 1,
    trim_ws = TRUE
  ) %>%
  select(
    eia_plant_id = "Plant Code",
    eia_latitude = "Latitude",
    eia_longitude = "Longitude"
  )

# Get boiler ID
eia_boiler <-
  read_excel(
    str_glue("{dir_860}6_1_EnviroAssoc_Y{params$crosswalk_year}.xlsx"),
    sheet = "Boiler Generator",
    range = cell_cols("C:F"),
    skip = 1,
    trim_ws = TRUE
  ) %>%
  select(
    eia_plant_id = "Plant Code",
    eia_generator_id = "Generator ID",
    eia_boiler_id = "Boiler ID",
    mod_eia_boiler_id = "Boiler ID",
    mod_eia_generator_id = "Generator ID"
  ) %>%
  inner_join(eia_plant, by = c("eia_plant_id"))

# Create a consolidated list of all units (retired and operating)
eia_gen_opr <- # Operating units
  read_excel(
    str_glue("{dir_860}3_1_Generator_Y{params$crosswalk_year}.xlsx"),
    sheet = "Operable",
    range = cell_cols("C:AH"),
    skip = 1,
    trim_ws = TRUE
  ) %>%
  select(-"Planned Retirement Month", -"Planned Retirement Year") %>%
  mutate("Retirement Year" = 0)

eia_gen_ret <- # Retired units
  read_excel(
    str_glue("{dir_860}3_1_Generator_Y{params$crosswalk_year}.xlsx"),
    sheet = "Retired and Canceled",
    range = cell_cols("C:AH"),
    skip = 1,
    trim_ws = TRUE
  ) %>%
  select(-"Retirement Month") %>%
  relocate("Retirement Year", .after = "Energy Source 1") %>%
  filter(`Retirement Year` >= params$earliest_retirement_year)

eia_generator <- rbind(eia_gen_opr, eia_gen_ret) %>%
  select(
    eia_plant_id = "Plant Code",
    eia_plant_name = "Plant Name",
    eia_state = "State",
    eia_generator_id = "Generator ID",
    mod_eia_generator_id = "Generator ID",
    eia_unit_type = "Prime Mover",
    eia_nameplate_capacity = "Nameplate Capacity (MW)",
    eia_fuel_type = "Energy Source 1",
    eia_retire_year = "Retirement Year"
  ) %>%
  # Filter out renewable unit types https://www.epa.gov/sites/production/files/2017-01/egrid_code_lookup.xlsx
  filter(!(eia_unit_type %in% c("BA", "CE", "CP", "FC", "FW", "HA", "HY", "PS", "PV", "WS", "WT")))


# Add lat and long 
eia_generator <- eia_generator %>%
  inner_join(eia_plant, by = c("eia_plant_id"))

# Clean up
rm(eia_gen_opr)
rm(eia_gen_ret)
rm(eia_plant)


# Creating list of necessary data -----
eia_raw <- list(boiler = eia_boiler, 
                generator = eia_generator)

# Saving EIA data -----
eia_file_path <- "data/raw_data/eia"
eia_file_name <- "eia_raw.RDS"

save_output_data(eia_raw, eia_file_path, eia_file_name)


