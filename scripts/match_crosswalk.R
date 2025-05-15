## -------------------------------
##
## Match crosswalk
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
source("scripts/functions/function_match_crosswalk.R")
source("scripts/functions/function_modifier.R")
source("scripts/functions/function_check_params.R")

# Set up year dimensions
params <- check_params()

# Load data -------
eia_raw <- readRDS(glue::glue("data/raw_data/eia/{params$crosswalk_year}/eia_raw.RDS"))
epa_raw <- readRDS(glue::glue("data/raw_data/epa/{params$crosswalk_year}/epa_raw.RDS"))

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

## Constants used in the following steps
plant_boiler_gen_match <- 
  c(
    "epa_plant_id" = "mod_eia_plant_id", 
    "mod_epa_unit_id" = "mod_eia_boiler_id", # change from CAMD to EPA
    "mod_epa_generator_id" = "mod_eia_generator_id"
  )

plant_boiler_match <-
  c(
    "epa_plant_id" = "mod_eia_plant_id",
    "mod_epa_unit_id" = "mod_eia_boiler_id"
  )

plant_generator_match <-
  c(
    "epa_plant_id" = "mod_eia_plant_id",
    "mod_epa_generator_id" = "mod_eia_generator_id"
  )

# Step 1: Match EPA to EIA 3_1_Generator data set (retired and operational generators) -------
generator_step_string <- "3_1_Generator (generators) match on plant and gen IDs  Step 1"

epa_eia_gen_crosswalk <-
  get_manual_matches(
    unit_manual_matches,
    unit_manual_excluded,
    epa_unit,
    eia_generator,
    eia_by = c("eia_plant_id", "eia_generator_id")
  )

epa_eia_gen_crosswalk <- epa_eia_gen_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk),
      get_unmatched(eia_generator, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")),
      by = plant_generator_match,
      str_glue("{generator_step_string}a: Exact match")
    )
  )

epa_eia_gen_crosswalk <- epa_eia_gen_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk) %>%
        mutate(across(c(mod_epa_generator_id), mod_identifiers_special_char)), # modify
      get_unmatched(eia_generator, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")) %>%
        mutate(across(c(mod_eia_generator_id), mod_identifiers_special_char)), # modify
      by = plant_generator_match,
      str_glue("{generator_step_string}b: Modify IDs; remove special chars")
    )
  )

epa_eia_gen_crosswalk <- epa_eia_gen_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk) %>%
        mutate(across(c(mod_epa_generator_id), mod_to_numeric)), # modify
      get_unmatched(eia_generator, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")) %>%
        mutate(across(c(mod_eia_generator_id), mod_to_numeric)), # modify
      by = plant_generator_match,
      str_glue("{generator_step_string}c: Modify IDs; convert to numeric")
    )
  )

epa_eia_gen_crosswalk <- epa_eia_gen_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk) %>%
        mutate(across(c(mod_epa_generator_id), mod_identifiers_leading_letters)), # modify
      get_unmatched(eia_generator, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")) %>%
        mutate(across(c(mod_eia_generator_id), mod_identifiers_leading_letters)), # modify
      by = plant_generator_match,
      str_glue("{generator_step_string}d: Modify IDs; remove leading letters")
    )
  )

generator_match_summary <- epa_eia_gen_crosswalk %>%
  group_by(match_type) %>%
  mutate(match_type = as.character(match_type)) %>%
  summarize(
    match_count = n(),
    duplicate_count = match_count - n_distinct(epa_plant_id, epa_unit_id, epa_generator_id)
  ) %>%
  mutate(cumulative_count = cumsum(match_count), .after = match_count) %>%
  mutate(
    cumulative_duplicates = cumsum(duplicate_count),
    unmatched = nrow(epa_unit) - cumulative_count + cumulative_duplicates
  )

## Step 2: Match EPA to EIA 6_1_EnviroAssoc (boilers and generators) data set
generator_step_string <- "3_1_Generator (generators) match on plant and gen IDs  Step 1"

epa_eia_gen_crosswalk <-
  get_manual_matches(
    unit_manual_matches,
    unit_manual_excluded,
    epa_unit,
    eia_generator,
    eia_by = c("eia_plant_id", "eia_generator_id")
  )

epa_eia_gen_crosswalk <- epa_eia_gen_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk),
      get_unmatched(eia_generator, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")),
      by = plant_generator_match,
      str_glue("{generator_step_string}a: Exact match")
    )
  )

epa_eia_gen_crosswalk <- epa_eia_gen_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk) %>%
        mutate(across(c(mod_epa_generator_id), mod_identifiers_special_char)), #modify
      get_unmatched(eia_generator, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")) %>%
        mutate(across(c(mod_eia_generator_id), mod_identifiers_special_char)), # modify
      by = plant_generator_match,
      str_glue("{generator_step_string}b: Modify IDs; remove special chars")
    )
  )

epa_eia_gen_crosswalk <- epa_eia_gen_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk) %>%
        mutate(across(c(mod_epa_generator_id), mod_to_numeric)), # modify
      get_unmatched(eia_generator, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")) %>%
        mutate(across(c(mod_eia_generator_id), mod_to_numeric)), # modify
      by = plant_generator_match,
      str_glue("{generator_step_string}c: Modify IDs; convert to numeric")
    )
  )

epa_eia_gen_crosswalk <- epa_eia_gen_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk) %>%
        mutate(across(c(mod_epa_generator_id), mod_identifiers_leading_letters)), # modify
      get_unmatched(eia_generator, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")) %>%
        mutate(across(c(mod_eia_generator_id), mod_identifiers_leading_letters)), # modify
      by = plant_generator_match,
      str_glue("{generator_step_string}d: Modify IDs; remove leading letters")
    )
  )

generator_match_summary <- epa_eia_gen_crosswalk %>%
  group_by(match_type) %>%
  mutate(match_type = as.character(match_type)) %>%
  summarize(
    match_count = n(),
    duplicate_count = match_count - n_distinct(epa_plant_id, epa_unit_id, epa_generator_id)
  ) %>%
  mutate(cumulative_count = cumsum(match_count), .after = match_count) %>%
  mutate(
    cumulative_duplicates = cumsum(duplicate_count),
    unmatched = nrow(epa_unit) - cumulative_count + cumulative_duplicates
  )

## Step 2: Match EPA to EIA 6_1_EnviroAssoc (boilers and generators) data set

boiler_step_string <- "6_1_EnviroAssoc (boilers and generators) match on plant, boiler, and gen IDs Step 2"

epa_eia_boiler_crosswalk <-
  get_manual_matches(
    # Because we are getting manual matches from the boiler file, we
    # will exclude manual matches without a boiler
    unit_manual_matches %>% filter(!is.na(eia_boiler_id)),
    unit_manual_excluded,
    epa_unit,
    eia_boiler,
    eia_by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id")
  )

epa_eia_boiler_crosswalk <- epa_eia_boiler_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_boiler_crosswalk),
      get_unmatched(eia_boiler, epa_eia_boiler_crosswalk, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id")),
      by = plant_boiler_gen_match,
      str_glue("{boiler_step_string}a: Exact match")
    )
  )

epa_eia_boiler_crosswalk <- epa_eia_boiler_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_boiler_crosswalk) %>%
        mutate(across(c(mod_epa_unit_id, mod_epa_generator_id), mod_identifiers_special_char)), # modify
      get_unmatched(eia_boiler, epa_eia_boiler_crosswalk, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id")) %>%
        mutate(across(c(mod_eia_boiler_id, mod_eia_generator_id), mod_identifiers_special_char)), # modify
      by = plant_boiler_gen_match,
      str_glue("{boiler_step_string}b: Modify IDs; remove special chars")
    )
  )

epa_eia_boiler_crosswalk <- epa_eia_boiler_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_boiler_crosswalk) %>%
        mutate(across(c(mod_epa_unit_id, mod_epa_generator_id), mod_to_numeric)), # modify
      get_unmatched(eia_boiler, epa_eia_boiler_crosswalk, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id")) %>%
        mutate(across(c(mod_eia_boiler_id, mod_eia_generator_id), mod_to_numeric)), # modify
      by = plant_boiler_gen_match,
      str_glue("{boiler_step_string}c: Modify IDs; convert to numeric")
    )
  )

epa_eia_boiler_crosswalk <- epa_eia_boiler_crosswalk %>%
  bind_rows(
    match_epa_eia_units(
      get_epa_unmatched(epa_unit, epa_eia_boiler_crosswalk) %>%
        mutate(across(c(mod_epa_unit_id, mod_epa_generator_id), mod_identifiers_leading_letters)), # modify
      get_unmatched(eia_boiler, epa_eia_boiler_crosswalk, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id")) %>%
        mutate(across(c(mod_eia_boiler_id, mod_eia_generator_id), mod_identifiers_leading_letters)), # modify
      by = plant_boiler_gen_match,
      str_glue("{boiler_step_string}d: Modify IDs; remove leading letters")
    )
  )

boiler_match_summary <- epa_eia_boiler_crosswalk %>%
  group_by(match_type) %>%
  mutate(match_type = as.character(match_type)) %>%
  summarize(
    match_count = n(),
    duplicate_count = match_count - n_distinct(epa_plant_id, epa_unit_id, epa_generator_id)
  ) %>%
  mutate(cumulative_count = cumsum(match_count), .after = match_count) %>%
  mutate(
    cumulative_duplicates = cumsum(duplicate_count),
    unmatched = nrow(epa_unit) - cumulative_count + cumulative_duplicates
  )

## Step 3: Join data sets from Step 2 and Step 3 to have a set of comprehensive matches that have all EPA identifiers and all EIA identifiers where they exist.
epa_eia_crosswalk <- epa_eia_gen_crosswalk %>%
  # We needed the manual matches/unmatched in the gen/boiler crosswalks to keep them out of the process,
  # but now we need to pull them out to join the two crosswalks, since their inclusion creates duplicates in this
  # left_join.
  filter(str_detect(match_type, "Manual", negate = TRUE)) %>%
  # Need to remove the boiler_id from the generator matches, since it was added with the manual matches.
  # Only the manual matches have a boiler ID at this point.
  select(-eia_boiler_id) %>%
  left_join(
    epa_eia_boiler_crosswalk %>%
      filter(str_detect(match_type, "Manual", negate = TRUE)) %>%
      select(
        epa_plant_id,
        epa_unit_id,
        epa_generator_id,
        eia_plant_id,
        eia_boiler_id,
        mod_eia_boiler_id,
        eia_generator_id,
        mod_eia_generator_id,
        match_type
      ),
    by = c(
      "epa_plant_id",
      "epa_unit_id",
      "epa_generator_id",
      "eia_plant_id",
      "eia_generator_id"
    ),
    suffix = c("_gen", "_boiler")
  ) %>%
  # And now we add the manual matches/unmatched back to the crosswalk
  bind_rows(
    get_manual_matches(
      unit_manual_matches,
      unit_manual_excluded,
      epa_unit,
      # The generator file is sufficient here, because we just need the facility info
      # and this will pull in all the manual matches, since generator ID is required in the manual matches file.
      eia_generator,
      eia_by = c("eia_plant_id", "eia_generator_id")
    ) %>%
      # Set the MATCH_TYPE_GEN/BOILER to the MATCH_TYPE from get_manual_matches
      mutate(
        match_type_gen = match_type,
        match_type_boiler = match_type,
      )
  ) %>%
  select(
    epa_state,
    epa_facility_name,
    epa_plant_id,
    epa_unit_id,
    epa_generator_id,
    epa_nameplate_capacity,
    epa_fuel_type,
    epa_latitude,
    epa_longitude,
    epa_status,
    epa_status_date,
    epa_retire_year,
    mod_epa_unit_id,
    mod_epa_generator_id,
    eia_state,
    eia_plant_name,
    eia_plant_id,
    eia_generator_id,
    eia_nameplate_capacity,
    eia_boiler_id,
    eia_unit_type,
    eia_fuel_type,
    eia_latitude,
    eia_longitude,
    eia_retire_year,
    plant_id_change_flag,
    mod_eia_plant_id,
    mod_eia_boiler_id,
    mod_eia_generator_id_boiler,
    mod_eia_generator_id_gen,
    match_type_gen,
    match_type_boiler
  ) %>%
  arrange(epa_plant_id, epa_unit_id, epa_generator_id)

## Get unmatched after all steps
epa_unmatched <- get_epa_unmatched(epa_unit, epa_eia_crosswalk) %>%
  arrange(epa_plant_id, epa_unit_id, epa_generator_id)
eia_gen_unmatched <- get_unmatched(eia_generator, epa_eia_crosswalk, by = c("eia_plant_id", "eia_generator_id"))
eia_boiler_unmatched <- get_unmatched(eia_boiler, epa_eia_crosswalk, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id"))

epa_unmatched <- epa_unmatched %>%
  mutate(
    match_type_gen = "EPA Unmatched",
    match_type_boiler = "EPA Unmatched"
  )

# Bind the unmatched EPA units to the result
epa_eia_crosswalk <- epa_eia_crosswalk %>%
  bind_rows(epa_unmatched) %>%
  arrange(epa_plant_id, epa_unit_id, epa_generator_id) %>%
  mutate(
    sequence_number = row_number(),
    .before= epa_state
  )
