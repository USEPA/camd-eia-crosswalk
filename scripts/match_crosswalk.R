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

# Load necessary functions
source("scripts/functions/function_crosswalk_match.R")
source("scripts/functions/function_modifier.R")

# Set up year dimensions
crosswalk_year <- 2018
earliest_retirement_year <- 2010

# Load data -------
eia_raw <- readRDS(glue::glue("data/raw_data/epa/{crosswalk_year}/epa_raw.RDS"))
epa_raw <- readRDS(glue::glue("data/raw_data/eia/{crosswalk_year}/eia_raw.RDS"))

# Set up raw data 
eia_boiler <- eia_raw$boiler
eia_generator <- eia_raw$generator

# Get manual matches and excluded CAMD units from manual match file
manual_match_cols <- c("numeric", "text", "text", "numeric", "text", "text")

unit_manual_matches <-
  read_excel(
    "manual_matches.xlsx",
    sheet = "unit_manual_matches",
    range = cell_cols("A:F"),
    col_types = manual_match_cols,
    trim_ws = TRUE
  )
unit_manual_excluded <-
  read_excel(
    "manual_matches.xlsx",
    sheet = "unit_manual_excluded",
    range = cell_cols("A:C"),
    col_types = head(manual_match_cols, n = 3),
    trim_ws = TRUE
  )

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
  select(EIA_PLANT_ID, CAMD_PLANT_ID)

# Turn tibble into named character vector for recode() function
plant_id_replacements <- plant_id_replacements %>% deframe()

# For plants in the replacement tibble, add the new plant code and flag the record
# The !!! operator forces-splice the named character vector of plant code corrections
# meaning that they each become one argument to the recode function instead of one character vector as an arugment
# i.e. recode(c(a="1", b="2", c="3")) becomes recode(a="1", b="2", c="3")
eia_generator <- eia_generator %>%
  mutate(
    MOD_EIA_PLANT_ID = recode(EIA_PLANT_ID, !!!plant_id_replacements),
    PLANT_ID_CHANGE_FLAG = ifelse(EIA_PLANT_ID != MOD_EIA_PLANT_ID, 1, 0)
  )

eia_boiler <- eia_boiler %>%
  mutate(
    MOD_EIA_PLANT_ID = recode(EIA_PLANT_ID, !!!plant_id_replacements),
    PLANT_ID_CHANGE_FLAG = ifelse(EIA_PLANT_ID != MOD_EIA_PLANT_ID, 1, 0)
  )

rm(plant_id_replacements)
rm(egrid_crosswalk_cols)

## Constants used in the following steps
plant_boiler_gen_match <-
  c(
    "CAMD_PLANT_ID" = "MOD_EIA_PLANT_ID",
    "MOD_CAMD_UNIT_ID" = "MOD_EIA_BOILER_ID",
    "MOD_CAMD_GENERATOR_ID" = "MOD_EIA_GENERATOR_ID"
  )

plant_boiler_match <-
  c(
    "CAMD_PLANT_ID" = "MOD_EIA_PLANT_ID",
    "MOD_CAMD_UNIT_ID" = "MOD_EIA_BOILER_ID"
  )

plant_generator_match <-
  c(
    "CAMD_PLANT_ID" = "MOD_EIA_PLANT_ID",
    "MOD_CAMD_GENERATOR_ID" = "MOD_EIA_GENERATOR_ID"
  )

# Step 1: Match CAMD to EIA 3_1_Generator data set (retired and operational generators) -------
generator_step_string <- "3_1_Generator (generators) match on plant and gen IDs  Step 1"

camd_eia_gen_crosswalk <-
  get_manual_matches(
    unit_manual_matches,
    unit_manual_excluded,
    camd_unit,
    eia_generator,
    eia_by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")
  )

camd_eia_gen_crosswalk <- camd_eia_gen_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_gen_crosswalk),
      get_unmatched(eia_generator, camd_eia_gen_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")),
      by = plant_generator_match,
      str_glue("{generator_step_string}a: Exact match")
    )
  )

camd_eia_gen_crosswalk <- camd_eia_gen_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_gen_crosswalk) %>%
        mutate(across(c(MOD_CAMD_GENERATOR_ID), mod_identifiers_special_char)),
      get_unmatched(eia_generator, camd_eia_gen_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")) %>%
        mutate(across(c(MOD_EIA_GENERATOR_ID), mod_identifiers_special_char)),
      by = plant_generator_match,
      str_glue("{generator_step_string}b: Modify IDs; remove special chars")
    )
  )

camd_eia_gen_crosswalk <- camd_eia_gen_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_gen_crosswalk) %>%
        mutate(across(c(MOD_CAMD_GENERATOR_ID), mod_to_numeric)),
      get_unmatched(eia_generator, camd_eia_gen_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")) %>%
        mutate(across(c(MOD_EIA_GENERATOR_ID), mod_to_numeric)),
      by = plant_generator_match,
      str_glue("{generator_step_string}c: Modify IDs; convert to numeric")
    )
  )

camd_eia_gen_crosswalk <- camd_eia_gen_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_gen_crosswalk) %>%
        mutate(across(c(MOD_CAMD_GENERATOR_ID), mod_identifiers_leading_letters)),
      get_unmatched(eia_generator, camd_eia_gen_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")) %>%
        mutate(across(c(MOD_EIA_GENERATOR_ID), mod_identifiers_leading_letters)),
      by = plant_generator_match,
      str_glue("{generator_step_string}d: Modify IDs; remove leading letters")
    )
  )

generator_match_summary <- camd_eia_gen_crosswalk %>%
  group_by(MATCH_TYPE) %>%
  mutate(MATCH_TYPE = as.character(MATCH_TYPE)) %>%
  summarize(
    MATCH_COUNT = n(),
    DUPLICATE_COUNT = MATCH_COUNT - n_distinct(CAMD_PLANT_ID, CAMD_UNIT_ID, CAMD_GENERATOR_ID)
  ) %>%
  mutate(CUMULATIVE_COUNT = cumsum(MATCH_COUNT), .after = MATCH_COUNT) %>%
  mutate(
    CUMULATIVE_DUPLICATES = cumsum(DUPLICATE_COUNT),
    UNMATCHED = nrow(camd_unit) - CUMULATIVE_COUNT + CUMULATIVE_DUPLICATES
  )

## Step 2: Match CAMD to EIA 6_1_EnviroAssoc (boilers and generators) data set
generator_step_string <- "3_1_Generator (generators) match on plant and gen IDs  Step 1"

camd_eia_gen_crosswalk <-
  get_manual_matches(
    unit_manual_matches,
    unit_manual_excluded,
    camd_unit,
    eia_generator,
    eia_by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")
  )

camd_eia_gen_crosswalk <- camd_eia_gen_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_gen_crosswalk),
      get_unmatched(eia_generator, camd_eia_gen_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")),
      by = plant_generator_match,
      str_glue("{generator_step_string}a: Exact match")
    )
  )

camd_eia_gen_crosswalk <- camd_eia_gen_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_gen_crosswalk) %>%
        mutate(across(c(MOD_CAMD_GENERATOR_ID), mod_identifiers_special_char)),
      get_unmatched(eia_generator, camd_eia_gen_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")) %>%
        mutate(across(c(MOD_EIA_GENERATOR_ID), mod_identifiers_special_char)),
      by = plant_generator_match,
      str_glue("{generator_step_string}b: Modify IDs; remove special chars")
    )
  )

camd_eia_gen_crosswalk <- camd_eia_gen_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_gen_crosswalk) %>%
        mutate(across(c(MOD_CAMD_GENERATOR_ID), mod_to_numeric)),
      get_unmatched(eia_generator, camd_eia_gen_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")) %>%
        mutate(across(c(MOD_EIA_GENERATOR_ID), mod_to_numeric)),
      by = plant_generator_match,
      str_glue("{generator_step_string}c: Modify IDs; convert to numeric")
    )
  )

camd_eia_gen_crosswalk <- camd_eia_gen_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_gen_crosswalk) %>%
        mutate(across(c(MOD_CAMD_GENERATOR_ID), mod_identifiers_leading_letters)),
      get_unmatched(eia_generator, camd_eia_gen_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")) %>%
        mutate(across(c(MOD_EIA_GENERATOR_ID), mod_identifiers_leading_letters)),
      by = plant_generator_match,
      str_glue("{generator_step_string}d: Modify IDs; remove leading letters")
    )
  )

generator_match_summary <- camd_eia_gen_crosswalk %>%
  group_by(MATCH_TYPE) %>%
  mutate(MATCH_TYPE = as.character(MATCH_TYPE)) %>%
  summarize(
    MATCH_COUNT = n(),
    DUPLICATE_COUNT = MATCH_COUNT - n_distinct(CAMD_PLANT_ID, CAMD_UNIT_ID, CAMD_GENERATOR_ID)
  ) %>%
  mutate(CUMULATIVE_COUNT = cumsum(MATCH_COUNT), .after = MATCH_COUNT) %>%
  mutate(
    CUMULATIVE_DUPLICATES = cumsum(DUPLICATE_COUNT),
    UNMATCHED = nrow(camd_unit) - CUMULATIVE_COUNT + CUMULATIVE_DUPLICATES
  )

## Step 2: Match CAMD to EIA 6_1_EnviroAssoc (boilers and generators) data set
```{r}

boiler_step_string <- "6_1_EnviroAssoc (boilers and generators) match on plant, boiler, and gen IDs Step 2"

camd_eia_boiler_crosswalk <-
  get_manual_matches(
    # Because we are getting manual matches from the boiler file, we
    # will exclude manual matches without a boiler
    unit_manual_matches %>% filter(!is.na(EIA_BOILER_ID)),
    unit_manual_excluded,
    camd_unit,
    eia_boiler,
    eia_by = c("EIA_PLANT_ID", "EIA_BOILER_ID", "EIA_GENERATOR_ID")
  )

camd_eia_boiler_crosswalk <- camd_eia_boiler_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_boiler_crosswalk),
      get_unmatched(eia_boiler, camd_eia_boiler_crosswalk, by = c("EIA_PLANT_ID", "EIA_BOILER_ID", "EIA_GENERATOR_ID")),
      by = plant_boiler_gen_match,
      str_glue("{boiler_step_string}a: Exact match")
    )
  )

camd_eia_boiler_crosswalk <- camd_eia_boiler_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_boiler_crosswalk) %>%
        mutate(across(c(MOD_CAMD_UNIT_ID, MOD_CAMD_GENERATOR_ID), mod_identifiers_special_char)),
      get_unmatched(eia_boiler, camd_eia_boiler_crosswalk, by = c("EIA_PLANT_ID", "EIA_BOILER_ID", "EIA_GENERATOR_ID")) %>%
        mutate(across(c(MOD_EIA_BOILER_ID, MOD_EIA_GENERATOR_ID), mod_identifiers_special_char)),
      by = plant_boiler_gen_match,
      str_glue("{boiler_step_string}b: Modify IDs; remove special chars")
    )
  )

camd_eia_boiler_crosswalk <- camd_eia_boiler_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_boiler_crosswalk) %>%
        mutate(across(c(MOD_CAMD_UNIT_ID, MOD_CAMD_GENERATOR_ID), mod_to_numeric)),
      get_unmatched(eia_boiler, camd_eia_boiler_crosswalk, by = c("EIA_PLANT_ID", "EIA_BOILER_ID", "EIA_GENERATOR_ID")) %>%
        mutate(across(c(MOD_EIA_BOILER_ID, MOD_EIA_GENERATOR_ID), mod_to_numeric)),
      by = plant_boiler_gen_match,
      str_glue("{boiler_step_string}c: Modify IDs; convert to numeric")
    )
  )

camd_eia_boiler_crosswalk <- camd_eia_boiler_crosswalk %>%
  bind_rows(
    match_camd_eia_units(
      get_camd_unmatched(camd_unit, camd_eia_boiler_crosswalk) %>%
        mutate(across(c(MOD_CAMD_UNIT_ID, MOD_CAMD_GENERATOR_ID), mod_identifiers_leading_letters)),
      get_unmatched(eia_boiler, camd_eia_boiler_crosswalk, by = c("EIA_PLANT_ID", "EIA_BOILER_ID", "EIA_GENERATOR_ID")) %>%
        mutate(across(c(MOD_EIA_BOILER_ID, MOD_EIA_GENERATOR_ID), mod_identifiers_leading_letters)),
      by = plant_boiler_gen_match,
      str_glue("{boiler_step_string}d: Modify IDs; remove leading letters")
    )
  )

boiler_match_summary <- camd_eia_boiler_crosswalk %>%
  group_by(MATCH_TYPE) %>%
  mutate(MATCH_TYPE = as.character(MATCH_TYPE)) %>%
  summarize(
    MATCH_COUNT = n(),
    DUPLICATE_COUNT = MATCH_COUNT - n_distinct(CAMD_PLANT_ID, CAMD_UNIT_ID, CAMD_GENERATOR_ID)
  ) %>%
  mutate(CUMULATIVE_COUNT = cumsum(MATCH_COUNT), .after = MATCH_COUNT) %>%
  mutate(
    CUMULATIVE_DUPLICATES = cumsum(DUPLICATE_COUNT),
    UNMATCHED = nrow(camd_unit) - CUMULATIVE_COUNT + CUMULATIVE_DUPLICATES
  )

## Step 3: Join data sets from Step 2 and Step 3 to have a set of comprehensive matches that have all CAMD identifiers and all EIA identifiers where they exist.
camd_eia_crosswalk <- camd_eia_gen_crosswalk %>%
  # We needed the manual matches/unmatched in the gen/boiler crosswalks to keep them out of the process,
  # but now we need to pull them out to join the two crosswalks, since their inclusion creates duplicates in this
  # left_join.
  filter(str_detect(MATCH_TYPE, "Manual", negate = TRUE)) %>%
  # Need to remove the boiler_id from the generator matches, since it was added with the manual matches.
  # Only the manual matches have a boiler ID at this point.
  select(-EIA_BOILER_ID) %>%
  left_join(
    camd_eia_boiler_crosswalk %>%
      filter(str_detect(MATCH_TYPE, "Manual", negate = TRUE)) %>%
      select(
        CAMD_PLANT_ID,
        CAMD_UNIT_ID,
        CAMD_GENERATOR_ID,
        EIA_PLANT_ID,
        EIA_BOILER_ID,
        MOD_EIA_BOILER_ID,
        EIA_GENERATOR_ID,
        MOD_EIA_GENERATOR_ID,
        MATCH_TYPE
      ),
    by = c(
      "CAMD_PLANT_ID",
      "CAMD_UNIT_ID",
      "CAMD_GENERATOR_ID",
      "EIA_PLANT_ID",
      "EIA_GENERATOR_ID"
    ),
    suffix = c("_GEN", "_BOILER")
  ) %>%
  # And now we add the manual matches/unmatched back to the crosswalk
  bind_rows(
    get_manual_matches(
      unit_manual_matches,
      unit_manual_excluded,
      camd_unit,
      # The generator file is sufficient here, because we just need the facility info
      # and this will pull in all the manual matches, since generator ID is required in the manual matches file.
      eia_generator,
      eia_by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")
    ) %>%
      # Set the MATCH_TYPE_GEN/BOILER to the MATCH_TYPE from get_manual_matches
      mutate(
        MATCH_TYPE_GEN = MATCH_TYPE,
        MATCH_TYPE_BOILER = MATCH_TYPE,
      )
  ) %>%
  select(
    CAMD_STATE,
    CAMD_FACILITY_NAME,
    CAMD_PLANT_ID,
    CAMD_UNIT_ID,
    CAMD_GENERATOR_ID,
    CAMD_NAMEPLATE_CAPACITY,
    CAMD_FUEL_TYPE,
    CAMD_LATITUDE,
    CAMD_LONGITUDE,
    CAMD_STATUS,
    CAMD_STATUS_DATE,
    CAMD_RETIRE_YEAR,
    MOD_CAMD_UNIT_ID,
    MOD_CAMD_GENERATOR_ID,
    EIA_STATE,
    EIA_PLANT_NAME,
    EIA_PLANT_ID,
    EIA_GENERATOR_ID,
    EIA_NAMEPLATE_CAPACITY,
    EIA_BOILER_ID,
    EIA_UNIT_TYPE,
    EIA_FUEL_TYPE,
    EIA_LATITUDE,
    EIA_LONGITUDE,
    EIA_RETIRE_YEAR,
    PLANT_ID_CHANGE_FLAG,
    MOD_EIA_PLANT_ID,
    MOD_EIA_BOILER_ID,
    MOD_EIA_GENERATOR_ID_BOILER,
    MOD_EIA_GENERATOR_ID_GEN,
    MATCH_TYPE_GEN,
    MATCH_TYPE_BOILER
  ) %>%
  arrange(CAMD_PLANT_ID, CAMD_UNIT_ID, CAMD_GENERATOR_ID)

## Get unmatched after all Steps
camd_unmatched <- get_camd_unmatched(camd_unit, camd_eia_crosswalk) %>%
  arrange(CAMD_PLANT_ID, CAMD_UNIT_ID, CAMD_GENERATOR_ID)
eia_gen_unmatched <- get_unmatched(eia_generator, camd_eia_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID"))
eia_boiler_unmatched <- get_unmatched(eia_boiler, camd_eia_crosswalk, by = c("EIA_PLANT_ID", "EIA_BOILER_ID", "EIA_GENERATOR_ID"))

camd_unmatched <- camd_unmatched %>%
  mutate(
    MATCH_TYPE_GEN = "CAMD Unmatched",
    MATCH_TYPE_BOILER = "CAMD Unmatched"
  )

# Bind the unmatched CAMD units to the result
camd_eia_crosswalk <- camd_eia_crosswalk %>%
  bind_rows(camd_unmatched) %>%
  arrange(CAMD_PLANT_ID, CAMD_UNIT_ID, CAMD_GENERATOR_ID) %>%
  mutate(
    SEQUENCE_NUMBER = row_number(),
    .before= CAMD_STATE
  )
