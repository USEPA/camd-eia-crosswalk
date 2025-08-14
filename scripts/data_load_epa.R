## -------------------------------
##
## Data load CAMPD
## 
## Purpose: 
## 
## This section imports the unit and generator data from the CAMPD API. 
## A CAMPD API key is required and can be obtained easily by signing up at the 
## (https://www.epa.gov/airmarkets/field-audit-checklist-tool-fact-api#signup). # fix this
## 
##
## -------------------------------

# Load libraries --------
library(tidyverse)
library(lubridate)
library(httr)
library(tidyjson)
library(jsonlite)
library(readxl)
library(openxlsx)
library(purrr)

# Load necessary functions
source("scripts/functions/function_save_output_data.R")
source("scripts/functions/function_check_params.R")
source("scripts/functions/function_coalesce_join_vars.R")

# Set up API and API key ----------

# Read API key from text file
api_key <- read_lines("api_keys/epa_api_key.txt")

# Set up year dimensions
if (!exists("params")) {
  params <- check_params()
} else {
  print("Crosswalk parameters are already defined.")
}

if (api_key == "YOUR_API_KEY") { # flag: default to this in epa_api_key.txt file
  stop("You must provide a EPA API key")
}

# Call API using API key
response <-
  GET(str_glue(
    "https://api.epa.gov/easey/camd-services/bulk-files?API_KEY={api_key}" # EPA/CAMPD API 
  ))

# If something is wrong with the request, fail gracefully
stop_for_status(response, content(response)$error$message)

## Get facility data --------
epa_json <- fromJSON(rawToChar(response$content))

# S3 bucket url base + s3Path (in get request) = the full path to the files
bucket_url_base <- 'https://api.epa.gov/easey/bulk-files/'
               
facility_path <- 
  epa_json %>% 
  unnest(cols = metadata) %>% 
  filter(year == params$crosswalk_year, # flag: check if this is okay
         dataType == "Facility") %>% 
  pull(s3Path)

# Clean up variable names and variable 
facility_df <- 
  read_csv(paste0(bucket_url_base,facility_path)) %>% 
  rename_with(tolower) %>% # this protects NOx rates from getting split with clean_names()
  janitor::clean_names() %>% 
  mutate(
    generator_ids = str_extract_all(associated_generators_nameplate_capacity_mwe, "\\S+(?= \\()"), # extracting associated generators
    nameplate_capacity_char = (str_extract_all(associated_generators_nameplate_capacity_mwe, "(?<=\\()\\d+(\\.\\d+)?(?=\\))")), # extracting nameplate capacity values
    associated_generators = purrr::map_chr(generator_ids, ~ paste(.x, collapse = ", ")), # pasting together associated generators
    nameplate_capacity = purrr::map_dbl(nameplate_capacity_char, ~ sum(as.numeric(.x), na.rm = TRUE)),
    retirement_year = ifelse(operating_status != "Operating", year(ymd(as.Date(commercial_operation_date))), 0), # switch from OPR to Operating - adjust in new version?
    year = as.character(year)) %>%  # summing nameplate capacity from associated generators) 
  select(-"nameplate_capacity_char") %>% 
  tidyr::unnest(cols = generator_ids) %>%
  mutate(epa_plant_id = facility_id,
         epa_facility_name = facility_name,
         epa_state = state,
         epa_latitude = latitude,
         epa_longitude = longitude,
         epa_unit_id = unit_id,
         mod_epa_unit_id = unit_id,
         epa_fuel_type = primary_fuel_type,
         epa_generator_id = generator_ids,
         mod_epa_generator_id = generator_ids,
         epa_nameplate_capacity = nameplate_capacity, 
         epa_retire_year = retirement_year,
         epa_status = operating_status,
         epa_status_date = commercial_operation_date) %>%
  rename(generator_id = generator_ids) %>%
  arrange(generator_id, unit_id)

## Get emissions data -----
emissions_files <-
  epa_json %>% 
  tidyr::unnest(cols = metadata) %>% 
  filter(dataType == "Emissions",
         dataSubType == "Daily",
         year == params$crosswalk_year,
         !is.na(quarter)) %>% # this identifies quarterly aggregations
  mutate(file_path = paste0(bucket_url_base,s3Path)) 

# now iterating over each file path and binding into one dataframe.
emissions_data <- 
  purrr::map_df(emissions_files$file_path, ~ read_csv(.x))

# identify columns to sum when cleaning emissions data
cols_to_sum <- 
  c("operating_time_count",
    "sum_of_the_operating_time",
    "gross_load_mwh",
    "steam_load_1000_lb",
    "so2_mass_short_tons",
    "so2_rate_lbs_mmbtu",
    "co2_mass_short_tons",
    "co2_rate_short_tons_mmbtu",
    "nox_mass_short_tons",
    "nox_rate_lbs_mmbtu",
    "heat_input_mmbtu")

# creating map to recode numeric monthly values to names for emissions data
month_name_map <- 
  tolower(month.name) %>% 
  purrr::set_names(1:12)

# specifying ozone months (May - September)
ozone_months <- tolower(month.name)[5:9]

# clean emissions data
emissions_data_clean <- 
  emissions_data %>% 
  rename_with(tolower) %>% # this protects NOx rates from getting split with clean_names()
  janitor::clean_names() %>% 
  mutate(year = as.character(year(date)), # extracting year from date
         month = as.character(month(date)), # extracting month from date
         month = recode(month, !!!month_name_map)) %>% # updating month to name
  select(-date) %>%
  mutate(across(where(is.character), ~ str_replace_all(.x, "\\|", ","))) %>% # SB 6/4/2024: Temporary fix for issue in API where there are a mix of pipes and commas in some character values
  group_by(pick(-c(all_of(cols_to_sum)))) %>% 
  summarize(across(all_of(cols_to_sum), ~ sum(.x, na.rm = TRUE))) %>% # aggregating to monthly values first
  ungroup() %>% 
  group_by(facility_id, unit_id, primary_fuel_type, unit_type) %>% 
  mutate(reporting_months = paste(month, collapse = ", "), # creating column with list of reporting months 
         reporting_frequency = if_else(grepl("january|february|march|october|november|december", # filtering out non-ozone season reporting months, excluding april
                                             reporting_months), "Q", "OS")) %>% # assigning reporting frequency 
  group_by(pick(-all_of(cols_to_sum), -c(month, reporting_months, reporting_frequency))) %>% 
  mutate(across(all_of(cols_to_sum), ~ sum(.x, na.rm = TRUE), .names = "{.col}_annual"), # calculating annual emissions
         across(all_of(cols_to_sum), ~ sum(.x[month %in% ozone_months], na.rm = TRUE), .names = "{.col}_ozone")) %>% # now calculating ozone month emissions
  select(-month) %>% # removing month so distinct() will aggregate to unit level
  select(-all_of(cols_to_sum), reporting_months, reporting_frequency) %>% 
  rename_with(.cols = contains("_annual"), # removing annual suffix
              .fn = ~ str_remove(.x, "_annual")) %>% 
  ungroup() %>% 
  distinct() # removing duplicate rows that aren't needed after ozone calculation

## Combine EPA data together -----
epa_data_combined <- 
  facility_df %>% 
  left_join(emissions_data_clean,
            by = c("facility_id", "unit_id", "primary_fuel_type")) %>% 
  coalesce_join_vars() %>% 
  arrange(facility_id, unit_id)


# Clean up
rm(epa_json)
rm(response)

## Saving EPA data 
epa_file_path <- "data/raw_data/epa"
epa_file_name <- "epa_raw.RDS"

save_output_data(epa_data_combined, epa_file_path, epa_file_name)
