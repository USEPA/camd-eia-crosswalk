## -------------------------------
##
## Fuzzy match crosswalk
## 
## Purpose: 
## 
## 
## 
##
## -------------------------------

# Load libraries
library(stringdist)
library(fuzzyjoin)
library(stringr)
library(openxlsx)
library(readr)
library(dplyr)

# flag to include potential matches 
# number of true/false flags (to include)

# Load necessary functions
source("scripts/functions/function_check_params.R")

# Set up year parameters
if (!exists("params")) {
  params <- check_params()
} else {
  print("Crosswalk parameters are already defined.")
}

# Load in modified and cleaned data
matched_crosswalk <- 
  read_rds(glue::glue("data/outputs/{params$crosswalk_year}/epa_eia_match.RDS"))$epa_eia_crosswalk

# select out unmatched 
epa_to_match <-
  matched_crosswalk %>%
  filter(str_detect(match_type_gen, "EPA Unmatched") | str_detect(match_type_boiler, "EPA Unmatched")) %>%
  select(epa_plant_id,
         epa_facility_name,
         epa_unit_id, 
         epa_generator_id,
         epa_nameplate_capacity,
         epa_heat_input_mmbtu,
         mod_epa_unit_id,
         mod_epa_generator_id,
         epa_latitude,
         epa_longitude)

# prep EIA data 
eia_to_match <- 
  # eia_generator_modified %>%
  eia_boiler_modified %>%
  select(eia_plant_id,
         # eia_plant_name,
         eia_generator_id,
         eia_boiler_id,
         # eia_nameplate_capacity,
         mod_eia_plant_id,
         mod_eia_generator_id,
         mod_eia_boiler_id,
         eia_latitude,
         eia_longitude)

# add heat input into crosswalk
# sheet eia860 - matching boiler and generator
# first merge to eia boiler data
eia_heat_matching <- 
  eia$heat %>%
  left_join(eia_boiler_modified,
            by = c("eia_plant_id", 
                   "eia_boiler_id")) %>%
  left_join(eia_generator_modified, #),
            by = c("eia_plant_id",
                   "eia_generator_id",
                   "eia_prime_mover" = "eia_unit_type",
                   "eia_fuel_type"))

# match_step1: Direct match between plant ID, generation ID, and unit/boiler ID
match_step1 <- left_join(epa_to_match, 
                         eia_to_match, 
                         by = c("epa_plant_id" = "eia_plant_id")) %>%
                                # "mod_epa_generator_id" = "mod_eia_generator_id",
                                # "mod_epa_unit_id" = "mod_eia_boiler_id")) %>%
               mutate(match_step1 = ifelse(is.na(mod_eia_plant_id), FALSE, TRUE))

# match_step2: 

# matching for nameplate capacity
epa_eia_to_match_2 <-
  epa_eia_to_match %>%
  filter(!is.na(epa_nameplate_capacity)) %>%
  fuzzy_join(
    eia_nameplate_matching,
    by = c("epa_nameplate_capacity" = "eia_nameplate_capacity"),
    match_fun = function(x,y) {
    abs(x - y) / pmin(abs(x), abs(y)) <= 0.05}
  ) %>%
  mutate(plant_id_dist = stringdist(epa_plant_id, eia_plant_id, method = "lv")) %>%
  slice_min(plant_id_dist, n = 2) %>%
  mutate(match_type = "Nameplate Capacity Fuzzy Match")
  




# fuel type map
# "Pipeline Natural Gas" = "NG"
# "Coal" = "BIT"
# fuel types are different between the two types, making it difficult to match up
view_fuel_types <- epa_eia_crosswalk_3 %>%
                   select(epa_fuel_type, eia_fuel_type) %>%
                   distinct()

# create matching strings
# these can be edited in order to adjust for different inputs/dataframes
# currently set to EPA-EIA Boiler Crosswalk
eia_matching <- epa_eia_boiler_crosswalk_5 %>%
                mutate(eia_match_string = paste(state,
                                                facility_name,
                                                mod_eia_boiler_id,
                                                mod_eia_generator_id,
                                                nameplate_capacity,
                                                eia_latitude,
                                                eia_longitude,
                                                sep = "_")) %>%
                select(state, facility_name, mod_eia_boiler_id, mod_eia_generator_id, nameplate_capacity, eia_latitude, eia_longitude, eia_match_string)

                # eia_generator_modified %>%
                # mutate(eia_match_string = paste(eia_state,
                #                                 eia_plant_name, 
                #                                 mod_eia_boiler_id,
                #                                 mod_eia_generator_id, 
                #                                 eia_nameplate_capacity, 
                #                                 eia_latitude, 
                #                                 eia_longitude,
                #                                 sep = "_"))

# create a matching string for fuzzy matching
epa_matching <- #epa_eia_boiler_crosswalk_5 %>%
                epa_eia_crosswalk_3 %>%
                # mutate
                filter(match_type_gen == "EPA Unmatched") %>%
                mutate(epa_match_string = paste(epa_state,
                                                epa_facility_name, 
                                                mod_epa_unit_id, 
                                                mod_epa_generator_id, 
                                                epa_nameplate_capacity, 
                                                epa_latitude, 
                                                epa_longitude,
                                                sep = "_"))

# match the entire string 
direct <- inner_join(epa_matching, eia_matching, by = c("epa_match_string" = "eia_match_string")) # comes up with none

# Levenshtein distance 
# max distance = 10
lv10 <- stringdist_join(
  
            x = epa_matching,
            y = eia_matching,
            by = c("epa_match_string" = "eia_match_string"),
            mode = "left",
            max_dist = 10,
            method = "lv", # calculate Levenshtein distance 
            distance_col = "dist",
            ignore_case = TRUE) %>%
        relocate(eia_match_string, .after=epa_match_string)

# max distance = 15 
lv15 <- stringdist_join(
  
  x = epa_matching,
  y = eia_matching,
  by = c("epa_match_string" = "eia_match_string"),
  mode = "left",
  max_dist = 15,
  method = "lv", # calculate Levenshtein distance 
  distance_col = "dist",
  ignore_case = TRUE) %>%
  relocate(eia_match_string, .after=epa_match_string)

# Full Damerau-Levenshtein distance
# max distance = 10
dl10 <- stringdist_join(
  
  x = epa_matching,
  y = eia_matching,
  by = c("epa_match_string" = "eia_match_string"),
  mode = "left",
  max_dist = 10,
  method = "dl", 
  distance_col = "dist",
  ignore_case = TRUE) %>%
  relocate(eia_match_string, .after=epa_match_string)

# max distance = 15
dl15 <- stringdist_join(
  
  x = epa_matching,
  y = eia_matching,
  by = c("epa_match_string" = "eia_match_string"),
  mode = "left",
  max_dist = 15,
  method = "dl", 
  distance_col = "dist",
  ignore_case = TRUE) %>%
  relocate(eia_match_string, .after=epa_match_string)
# test %>% filter(!is.na(dist)) %>% count()
dl15 %>% filter(!is.na(dist)) %>% count()


# Save data frame to Excel - 
wb <- createWorkbook()
addWorksheet(wb, "Direct Match")
writeData(wb, sheet = "Direct Match", x = direct)
addWorksheet(wb, "LV10")
writeData(wb, sheet = "LV10", x = lv10)
addWorksheet(wb, "LV15")
writeData(wb, sheet = "LV15", x = lv15)
addWorksheet(wb, "DL10")
writeData(wb, sheet = "DL10", x = dl10)
addWorksheet(wb, "DL15")
writeData(wb, sheet = "DL15", x = dl15)
saveWorkbook(wb, "fuzzy_matching_test1.xlsx")
