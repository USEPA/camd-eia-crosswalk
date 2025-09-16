## -------------------------------
##
## Data load from EPA CAM API
## 
## Purpose: 
## 
## This section imports the unit and generator data from the EPA CAM API. 
## A CAM API key is required and can be obtained easily by signing up at the 
## (https://www.epa.gov/power-sector/cam-api-portal#/api-key-signup). 
##
## Authors: 
##    Madeline Zhang, Abt Global
##
## -------------------------------

# Load libraries --------
library(dplyr)
library(readr)
library(tidyr)
library(stringr)
library(lubridate)
library(httr)
library(tidyjson)
library(jsonlite)

# Load necessary functions ----------------
source("scripts/functions/function_save_data.R")
source("scripts/functions/function_check_params.R")
source("scripts/functions/function_coalesce_join_vars.R")

# Set parameters ------------------------
if (!exists("params")) {
  params <- check_params()
} else {
  print("Crosswalk parameters are already defined.")
}

# Set up Query API ----------

# Read API key from text file
if(file.exists("api_keys/epa_api_key.txt")) { 
  api_key <- read_lines("api_keys/epa_api_key.txt")
} else{ 
  stop("You must provide an API key. See README with instructions in how to obtain one.")}

# Call API using API key
response <-
  GET(glue::glue(
    "https://api.epa.gov/easey/camd-services/bulk-files?API_KEY={api_key}" # EPA/CAM API 
  ))

# If something is wrong with the request, fail gracefully
stop_for_status(response, content(response)$error$message)

# Create unit type crosswalk -----

unit_abbs <- # abbreviation crosswalk for unit types 
  c(
    "Arch-fired boiler" = "AF",
    "Bubbling fluidized bed boiler" = "BFB",
    "Cyclone boiler" = "C",
    "Cell burner boiler" = "CB",
    "Combined cycle" = "CC",
    "Circulating fluidized bed boiler" = "CFB",
    "Combustion turbine" = "CT",
    "Dry bottom wall-fired boiler" = "DB",
    "Dry bottom turbo-fired boiler" = "DTF",
    "Dry bottom vertically-fired boiler" = "DVF",
    "Internal combustion engine" = "ICE",
    "Integrated gasification combined cycle" = "IGC",
    "Cement Kiln" = "KLN",
    "Other boiler" = "OB",
    "Other turbine" = "OT",
    "Pressurized fluidized bed boiler" = "PFB",
    "Process Heater" = "PRH",
    "Stoker" = "S",
    "Tangentially-fired" = "T",
    "Wet bottom wall-fired boiler" = "WBF",
    "Wet bottom turbo-fired boiler" = "WBT",
    "Wet bottom vertically-fired boiler" = "WVF"
  )

## Get facility data --------
epa_json <- fromJSON(rawToChar(response$content))

# S3 bucket url base + s3Path (in get request) = the full path to the files
bucket_url_base <- 'https://api.epa.gov/easey/bulk-files/'
               
facility_path <- 
  epa_json %>% 
  unnest(cols = metadata) %>% 
  filter(year == params$crosswalk_year, 
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
    # update unit type format to match EIA formatting
    unit_type = str_replace(unit_type, "\\(.*?\\)", "") %>% str_trim(), # removing notes about start dates and getting rid of extra white space
    unit_type_abb = recode(unit_type, !!!unit_abbs), # recoding values based on lookup table
    retirement_year = ifelse(operating_status != "Operating", year(ymd(as.Date(commercial_operation_date))), 0), # switch from OPR to Operating - adjust in new version?
    year = as.character(year)) %>%  
  tidyr::unnest_longer(col = c("generator_ids", "nameplate_capacity_char"), keep_empty = TRUE) %>% # unnest generator IDs and nameplate capacity
  mutate(mod_epa_unit_id = unit_id,
         mod_epa_generator_id = generator_ids) %>%
  distinct() %>% 
  mutate(nameplate_capacity = as.numeric(nameplate_capacity_char)) %>% 
  select(-"nameplate_capacity_char") %>% 
  rename(epa_state = state,
         epa_plant_id = facility_id,
         epa_facility_name = facility_name,
         epa_plant_id = facility_id,
         epa_unit_id = unit_id,
         epa_latitude = latitude,
         epa_longitude = longitude,
         epa_fuel_type = primary_fuel_type,
         epa_unit_id = unit_id,
         epa_fuel_type = primary_fuel_type,
         epa_generator_id = generator_ids,
         epa_nameplate_capacity = nameplate_capacity, 
         epa_status = operating_status,
         epa_generator_id = generator_ids,
         epa_prime_mover = unit_type_abb,
         epa_retire_year = retirement_year,
         epa_status_date = commercial_operation_date) %>%
  arrange(epa_generator_id, epa_unit_id)

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

# clean emissions data
emissions_data_clean <- 
  emissions_data %>% 
  rename_with(tolower) %>% # this protects NOx rates from getting split with clean_names()
  janitor::clean_names() %>% 
  mutate(year = as.character(year(date))) %>% # extracting year from date
  # select heat input and unit type alongside unit descriptors
  select(year, epa_plant_id = facility_id, epa_unit_id = unit_id, epa_fuel_type = primary_fuel_type, heat_input_mmbtu) %>%
  mutate(across(where(is.character), ~ str_replace_all(.x, "\\|", ","))) %>% # fix for issue in API where there are a mix of pipes and commas in some character values
  # group by and sum annual heat input
  group_by(pick(-c(heat_input_mmbtu))) %>%
  summarize(epa_heat_input_mmbtu = sum(heat_input_mmbtu, na.rm = TRUE)) %>%
  ungroup() %>%
  distinct()

## Combine EPA data together -----
epa_data_combined <- 
  facility_df %>% 
  left_join(emissions_data_clean,
            by = c("epa_plant_id", "epa_unit_id", "epa_fuel_type")) %>% 
  coalesce_join_vars() %>% 
  arrange(epa_plant_id, epa_unit_id)

# Clean up
rm(epa_json)
rm(response)

## Saving EPA data 
epa_file_path <- "data/raw_data/epa"
epa_file_name <- "epa_raw.RDS"

save_data(facility_df, epa_file_path, epa_file_name)
