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

# Set up API and API key ----------

# Read API key from text file
api_key <- read_lines("api_keys/epa_api_key.txt")

# Set up year dimensions
crosswalk_year <- 2018
earliest_retirement_year <- 2010

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
camd_json <- fromJSON(rawToChar(response$content))

# S3 bucket url base + s3Path (in get request) = the full path to the files
bucket_url_base <- 'https://api.epa.gov/easey/bulk-files/'
               
facility_path <- 
  camd_json %>% 
  unnest(cols = metadata) %>% 
  filter(year == crosswalk_year, # flag: check if this is okay
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
    retirement_year = ifelse(operating_status != "Operating", year(ymd(as.Date(commercial_operation_date))), 0), 
    year = as.character(year),  # summing nameplate capacity from associated generators
    mod_unit_id = unit_id) %>%
  select(-"nameplate_capacity_char") %>% 
  tidyr::unnest(cols = generator_ids) %>%
  mutate(mod_generator_id = generator_ids) %>%
  rename(generator_id = generator_ids) %>%
  arrange(generator_id, unit_id)

# Clean up
rm(camd_json)
rm(response)

## Saving EPA data 
epa_file_path <- "data/raw_data/epa"
epa_file_name <- "epa_raw.RDS"

save_output_data(facility_df, epa_file_path, epa_file_name)
