## -------------------------------
##
## Create EPA-EIA crosswalk matches
## 
## Purpose: 
## 
## This file matches EPA to EIA data using direct matches and modified ID matches
##
## -------------------------------

# Load libraries and functions ----------------------

# Load libraries
library(dplyr)
library(readr)
library(tibble)
library(stringr)
library(readxl)
library(purrr)

# Load necessary functions
source("scripts/functions/function_match_crosswalk.R")
source("scripts/functions/function_modify_crosswalk.R")
source("scripts/functions/function_check_params.R")
source("scripts/functions/function_save_output_data.R")

# Set up year dimensions
if (!exists("params")) {
  params <- check_params()
} else {
  print("Crosswalk parameters are already defined.")
}


match_crosswalk <- function() { 
  
  #' @name match_crosswalk
  #' 
  #' Matches crosswalk using direct matches and modified ID matches. 
  #' 
  #' @returns EPA-EIA crosswalk dataframe 
  
  # Require libraries and load functions ------
  require(dplyr)
  require(readr)
  require(tibble)
  require(stringr)
  require(readxl)
  require(purrr) 
  
  # Load data -----------------
  
  eia <- read_rds(glue::glue("data/raw_data/eia/{params$crosswalk_year}/eia_raw.RDS"))
  epa_unit <- read_rds(glue::glue("data/raw_data/epa/{params$crosswalk_year}/epa_raw.RDS"))
  
  # Set up data.frames necessary
  eia_boiler <- eia$boiler
  eia_generator <- eia$generator
  
  # Get manual matches and excluded EPA units from manual match file ---------------
  
  manual_match_cols <- c("numeric", "text", "text", "numeric", "text", "text")
  
  unit_manual_matches <-
    read_excel(
      "manual_matches.xlsx",
      sheet = "unit_manual_matches",
      range = cell_cols("A:F"),
      col_types = manual_match_cols,
      trim_ws = TRUE
    ) %>% janitor::clean_names()
  
  unit_manual_excluded <-
    read_excel(
      "manual_matches.xlsx",
      sheet = "unit_manual_excluded",
      range = cell_cols("A:C"),
      col_types = head(manual_match_cols, n = 3),
      trim_ws = TRUE
    ) %>% janitor::clean_names()
  
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
    janitor::clean_names() %>%
    select(eia_plant_id, epa_plant_id)
  
  # Turn tibble into named character vector for recode() function
  plant_id_replacements <- plant_id_replacements %>% deframe()
  
  # For plants in the replacement tibble, add the new plant code and flag the record
  # The !!! operator forces-splice the named character vector of plant code corrections
  # meaning that they each become one argument to the recode function instead of one character vector as an arugment
  # i.e. recode(c(a="1", b="2", c="3")) becomes recode(a="1", b="2", c="3")
  eia_generator_modified <- 
    eia_generator %>%
    mutate(
      mod_eia_plant_id = recode(eia_plant_id, !!!plant_id_replacements),
      plant_id_change_flag = ifelse(eia_plant_id != mod_eia_plant_id, 1, 0)
    )
  
  eia_boiler_modified <- 
    eia_boiler %>%
    mutate(
      mod_eia_plant_id = recode(eia_plant_id, !!!plant_id_replacements),
      plant_id_change_flag = ifelse(eia_plant_id != mod_eia_plant_id, 1, 0)
    )
  
  ## Constants used in the following steps
  plant_boiler_gen_match <- 
    c(
      "epa_plant_id" = "mod_eia_plant_id", 
      "mod_epa_unit_id" = "mod_eia_boiler_id", 
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
  
  # Step 1: Match EPA to EIA 3_1_Generator data set (retired and operational generators) ------------------
  
  generator_step_string <- "3_1_Generator (generators) match on plant and gen IDs Step 1"
  
  epa_eia_gen_crosswalk <-
    get_manual_matches(
      unit_manual_matches,
      unit_manual_excluded,
      epa_unit,
      eia_generator_modified,
      eia_by = c("eia_plant_id", "eia_generator_id")
    )
  
  epa_eia_gen_crosswalk_2 <- 
    epa_eia_gen_crosswalk %>%
    bind_rows(
      match_epa_eia_units(
        get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk),
        get_unmatched(eia_generator_modified, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")),
        by = plant_generator_match,
        str_glue("{generator_step_string}a: Exact match")
      )
    )
  
  epa_eia_gen_crosswalk_3 <- 
    epa_eia_gen_crosswalk_2 %>%
    bind_rows(
      match_epa_eia_units(
        get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk_2) %>%
          mutate(across(c(mod_epa_generator_id), mod_identifiers_special_char)), # modify
        get_unmatched(eia_generator_modified, epa_eia_gen_crosswalk_2, by = c("eia_plant_id", "eia_generator_id")) %>%
          mutate(across(c(mod_eia_generator_id), mod_identifiers_special_char)), # modify
        by = plant_generator_match,
        str_glue("{generator_step_string}b: Modify IDs; remove special chars")
      )
    )
  
  epa_eia_gen_crosswalk_4 <- 
    epa_eia_gen_crosswalk_3 %>%
    bind_rows(
      match_epa_eia_units(
        get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk_3) %>%
          mutate(across(c(mod_epa_generator_id), mod_to_numeric)), # modify
        get_unmatched(eia_generator_modified, epa_eia_gen_crosswalk_3, by = c("eia_plant_id", "eia_generator_id")) %>%
          mutate(across(c(mod_eia_generator_id), mod_to_numeric)), # modify
        by = plant_generator_match,
        str_glue("{generator_step_string}c: Modify IDs; convert to numeric")
      )
    )
  
  epa_eia_gen_crosswalk_5 <- 
    epa_eia_gen_crosswalk_4 %>%
    bind_rows(
      match_epa_eia_units(
        get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk_4) %>%
          mutate(across(c(mod_epa_generator_id), mod_identifiers_leading_letters)), # modify
        get_unmatched(eia_generator_modified, epa_eia_gen_crosswalk_4, by = c("eia_plant_id", "eia_generator_id")) %>%
          mutate(across(c(mod_eia_generator_id), mod_identifiers_leading_letters)), # modify
        by = plant_generator_match,
        str_glue("{generator_step_string}d: Modify IDs; remove leading letters")
      )
    )
  
  generator_match_summary <- 
    epa_eia_gen_crosswalk_5 %>%
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
  
  # Step 2: Match EPA to EIA 6_1_EnviroAssoc (boilers and generators) data set ----
  
  boiler_step_string <- "6_1_EnviroAssoc (boilers and generators) match on plant, boiler, and gen IDs Step 2"
  
  epa_eia_boiler_crosswalk <-
    get_manual_matches(
      # Because we are getting manual matches from the boiler file, we
      # will exclude manual matches without a boiler
      unit_manual_matches %>% filter(!is.na(eia_boiler_id)),
      unit_manual_excluded,
      epa_unit,
      eia_boiler_modified,
      eia_by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id")
    )
  
  epa_eia_boiler_crosswalk_2 <- 
    epa_eia_boiler_crosswalk %>%
    bind_rows(
      match_epa_eia_units(
        get_epa_unmatched(epa_unit, epa_eia_boiler_crosswalk),
        get_unmatched(eia_boiler_modified, epa_eia_boiler_crosswalk, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id")),
        by = plant_boiler_gen_match,
        str_glue("{boiler_step_string}a: Exact match")
      )
    )
  
  epa_eia_boiler_crosswalk_3 <- 
    epa_eia_boiler_crosswalk_2 %>%
    bind_rows(
      match_epa_eia_units(
        get_epa_unmatched(epa_unit, epa_eia_boiler_crosswalk_2) %>%
          mutate(across(c(mod_epa_unit_id, mod_epa_generator_id), mod_identifiers_special_char)), # modify
        get_unmatched(eia_boiler_modified, epa_eia_boiler_crosswalk_2, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id")) %>%
          mutate(across(c(mod_eia_boiler_id, mod_eia_generator_id), mod_identifiers_special_char)), # modify
        by = plant_boiler_gen_match,
        str_glue("{boiler_step_string}b: Modify IDs; remove special chars")
      )
    )
  
  epa_eia_boiler_crosswalk_4 <- epa_eia_boiler_crosswalk_3 %>%
    bind_rows(
      match_epa_eia_units(
        get_epa_unmatched(epa_unit, epa_eia_boiler_crosswalk_3) %>%
          mutate(across(c(mod_epa_unit_id, mod_epa_generator_id), mod_to_numeric)), # modify
        get_unmatched(eia_boiler_modified, epa_eia_boiler_crosswalk_3, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id")) %>%
          mutate(across(c(mod_eia_boiler_id, mod_eia_generator_id), mod_to_numeric)), # modify
        by = plant_boiler_gen_match,
        str_glue("{boiler_step_string}c: Modify IDs; convert to numeric")
      )
    )
  
  epa_eia_boiler_crosswalk_5 <- 
    epa_eia_boiler_crosswalk_4 %>%
    bind_rows(
      match_epa_eia_units(
        get_epa_unmatched(epa_unit, epa_eia_boiler_crosswalk_4) %>%
          mutate(across(c(mod_epa_unit_id, mod_epa_generator_id), mod_identifiers_leading_letters)), # modify
        get_unmatched(eia_boiler_modified, epa_eia_boiler_crosswalk_4, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id")) %>%
          mutate(across(c(mod_eia_boiler_id, mod_eia_generator_id), mod_identifiers_leading_letters)), # modify
        by = plant_boiler_gen_match,
        str_glue("{boiler_step_string}d: Modify IDs; remove leading letters")
      )
    )
  
  boiler_match_summary <- 
    epa_eia_boiler_crosswalk_5 %>%
    group_by(match_type) %>%
    mutate(match_type = as.character(match_type)) %>%
    summarize(
      match_count = n(),
      duplicate_count = match_count - n_distinct(epa_plant_id, epa_unit_id, epa_generator_id)
    ) %>%
    mutate(cumulative_count = cumsum(match_count), .after = match_count, 
           cumulative_duplicates = cumsum(duplicate_count),
           unmatched = nrow(epa_unit) - cumulative_count + cumulative_duplicates
    )
  
  # Step 3: Join data sets from Step 1 and Step 2 to have a set of comprehensive matches that have all EPA identifiers and all EIA identifiers where they exist. ----
  
  epa_eia_crosswalk <- 
    epa_eia_gen_crosswalk_5 %>%
    # We needed the manual matches/unmatched in the gen/boiler crosswalks to keep them out of the process,
    # but now we need to pull them out to join the two crosswalks, since their inclusion creates duplicates in this
    # left_join.
    filter(str_detect(match_type, "Manual", negate = TRUE)) %>%
    # Need to remove the boiler_id from the generator matches, since it was added with the manual matches.
    # Only the manual matches have a boiler ID at this point.
    select(-eia_boiler_id) %>%
    left_join(
      epa_eia_boiler_crosswalk_5 %>%
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
        eia_generator_modified,
        eia_by = c("eia_plant_id", "eia_generator_id")
      ) %>%
        # Set the match_type_gen/boiler to the match_type from get_manual_matches
        mutate(
          match_type_gen = match_type,
          match_type_boiler = match_type,
        )
    )
  
  # columns in the output
  final_crosswalk_cols <- 
      c(
      "epa_state",
      "epa_facility_name",
      "epa_plant_id",
      "epa_unit_id",
      "epa_generator_id",
      "epa_nameplate_capacity",
      "epa_fuel_type",
      "epa_latitude",
      "epa_longitude",
      "epa_status",
      "epa_status_date",
      "epa_retire_year",
      "mod_epa_unit_id",
      "mod_epa_generator_id",
      "eia_state",
      "eia_plant_name",
      "eia_plant_id",
      "eia_generator_id",
      "eia_nameplate_capacity",
      "eia_boiler_id",
      "eia_unit_type",
      "eia_fuel_type",
      "eia_latitude",
      "eia_longitude",
      "eia_retire_year",
      "plant_id_change_flag",
      "mod_eia_plant_id",
      "mod_eia_boiler_id",
      "mod_eia_generator_id_boiler",
      "mod_eia_generator_id_gen",
      "match_type_gen",
      "match_type_boiler"
    ) 
  
  epa_eia_crosswalk_2 <- 
    epa_eia_crosswalk %>%
    select(any_of(final_crosswalk_cols)) %>%
    arrange(epa_plant_id, epa_unit_id, epa_generator_id)
  
  # Check unmatched EPA units ----------------
  
  epa_unmatched <- # identify which EPA units do not match to EIA data 
    get_epa_unmatched(epa_unit, epa_eia_crosswalk_2) %>%
    arrange(epa_plant_id, epa_unit_id, epa_generator_id)
  
  eia_gen_unmatched <- get_unmatched(eia_generator_modified, epa_eia_crosswalk_2, by = c("eia_plant_id", "eia_generator_id"))
  eia_boiler_unmatched <- get_unmatched(eia_boiler_modified, epa_eia_crosswalk_2, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id"))
  
  # pull in EPA plants that are known to not be in EIA data from the eGRID production model
  # these units will remain unmatched, but with a known reason and will therefore not be included in future matching steps
  # this is a step performed in eGRID, these plants have been confirmed to not be in EIA data 
  
  epa_plants_not_in_eia <- 
    read_csv("https://raw.githubusercontent.com/USEPA/egrid/refs/heads/main/data/static_tables/epa_plants_to_delete.csv") %>% 
    janitor::clean_names() 
  
  epa_unconnected_grid <- 
    epa_plants_not_in_eia %>% 
    filter(str_detect(notes, "^These plants do not connect to the grid"))
  
  epa_plants_not_in_eia_other <- 
    epa_plants_not_in_eia %>% 
    filter(!str_detect(notes, "^These plants do not connect to the grid"))
  
  epa_unmatched_2 <- 
    epa_unmatched %>%
    mutate(
      match_type_gen = case_when(facility_id %in% epa_unconnected_grid$oris_code ~ "EPA Unmatched: this plant is not connected to the grid and is not in EIA data",
                                 TRUE ~ "EPA Unmatched"),
      match_type_boiler = case_when(facility_id %in% epa_unconnected_grid$oris_code ~ "EPA Unmatched: this plant is not connected to the grid and is not in EIA data",
                                    TRUE ~ "EPA Unmatched")
    )
  
  # Bind the unmatched EPA units to the result  
  # flag: change this to be editable in params to include or not include outputs
  epa_eia_crosswalk_3 <- 
    epa_eia_crosswalk_2 %>%
    bind_rows(epa_unmatched_2 %>% select(any_of(final_crosswalk_cols))) %>%
    arrange(epa_plant_id, epa_unit_id, epa_generator_id) %>%
    mutate(
      sequence_number = row_number(),
      .before= epa_state
    )
  
  match_crosswalk_returns <- list("epa_eia_crosswalk" = epa_eia_crosswalk_3, 
                                  "generator_match_summary" = generator_match_summary,
                                  "boiler_match_summary" = boiler_match_summary)
  
  return(match_crosswalk_returns)
}

# Call function and create crosswalk ----------------------

epa_eia_match_crosswalk <- match_crosswalk() 
