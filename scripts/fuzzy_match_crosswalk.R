## -------------------------------
##
## Fuzzy match crosswalk
## 
## Purpose: 
## Match unmatched EPA units to EIA data using additional matching steps.
## These matches are potential matches that need to be reviewed.
## 
## Authors:
##    Madeline Zhang, Abt Global
##
## -------------------------------

# Load libraries
library(stringdist)
library(fuzzyjoin)
library(stringr)
library(openxlsx)
library(readr)
library(dplyr)

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

eia_generator_modified <-
  read_rds(glue::glue("data/outputs/{params$crosswalk_year}/eia_generator_modified.RDS"))

eia_boiler_modified <-
  read_rds(glue::glue("data/outputs/{params$crosswalk_year}/eia_boiler_modified.RDS"))

eia_heat <- 
  read_rds(glue::glue("data/raw_data/eia/{params$crosswalk_year}/eia_raw.RDS"))$heat

### Algorithmic Matching ----
# select out unmatched EPA units
epa_to_match <-
  matched_crosswalk %>%
  filter(str_detect(match_type_gen, "EPA Unmatched") | str_detect(match_type_boiler, "EPA Unmatched")) %>%
  select(epa_plant_id,
         epa_facility_name,
         epa_unit_id, 
         epa_generator_id,
         epa_nameplate_capacity,
         epa_heat_input_mmbtu,
         epa_prime_mover,
         mod_epa_unit_id,
         mod_epa_generator_id,
         epa_latitude,
         epa_longitude) %>%
  filter(!is.na(epa_generator_id)) # exclude units where generator_id is NA

# EIA data that was matched in "match_crosswalk.R"
matched_crosswalk_2 <-
  matched_crosswalk %>%
  filter(!str_detect(match_type_gen, "EPA Unmatched") | !str_detect(match_type_boiler, "EPA Unmatched")) %>%
  select(contains("eia"))

# prep EIA data 
eia_to_match <- 
  eia_boiler_modified %>% # EIA boiler data
  select(eia_plant_id,
         eia_generator_id,
         eia_boiler_id,
         mod_eia_plant_id,
         mod_eia_generator_id,
         mod_eia_boiler_id,
         eia_latitude,
         eia_longitude) %>%
  # join EIA generator data (has nameplate capacity)
  full_join(eia_generator_modified, 
            by = c("eia_plant_id",
                   "eia_generator_id",
                   "mod_eia_plant_id", 
                   "mod_eia_generator_id")) %>%
  mutate(eia_latitude = coalesce(eia_latitude.x, eia_latitude.y),
         eia_longitude = coalesce(eia_longitude.x, eia_longitude.y)) %>%
  select(-c(eia_latitude.x, eia_latitude.y, 
            eia_longitude.x, eia_longitude.y)) %>%
  # join EIA heat input data
  full_join(eia_heat %>% select(-c(eia_plant_name, eia_plant_state)),
            by = c("eia_plant_id",
                   "eia_boiler_id",
                   "eia_fuel_type")) %>%
  # anti-join of matches that are already in the match crosswalk
  anti_join(matched_crosswalk_2)

# epa_eia_matched_plant_id: Direct match on plant ID 
epa_eia_matched_plant_id <- left_join(epa_to_match, 
                            eia_to_match, 
                            by = c("epa_plant_id" = "mod_eia_plant_id")) %>% 
                            rename(plant_id = epa_plant_id) # rename to just plant_id

# match_step1: Matching for nameplate capacity (range: +/-5%)
match_step1 <- epa_eia_matched_plant_id %>%
               mutate(nameplate_capacity_pct_diff = abs(epa_nameplate_capacity - eia_nameplate_capacity) / # calculate percent difference for nameplate capacity
                                                    pmin(abs(epa_nameplate_capacity), abs(eia_nameplate_capacity)),
                      nameplate_capacity_match = ifelse(nameplate_capacity_pct_diff > 0.05 | is.na(nameplate_capacity_pct_diff), FALSE, TRUE))


# match_step2: Matching for heat_input (range: +/-200%)
match_step2 <- match_step1 %>%
               mutate(heat_input_pct_diff = abs(epa_heat_input_mmbtu - eia_heat_input_mmbtu) / # calculate percent difference for heat_input
                                            pmin(abs(epa_heat_input_mmbtu), abs(eia_heat_input_mmbtu)),
                      heat_input_match = ifelse(heat_input_pct_diff > 2 | is.na(heat_input_pct_diff), FALSE, TRUE))

# match_step3: Matching for prime_mover
match_step3 <- match_step2 %>%
               mutate(prime_mover_match = ifelse(epa_prime_mover == eia_prime_mover | epa_prime_mover == eia_unit_type, TRUE, FALSE))


# end_matches: Resulting matches where at least one match step is TRUE
end_matches <- match_step3 %>%
               mutate(match_count = rowSums(across(c("nameplate_capacity_match", "heat_input_match", "prime_mover_match")) == TRUE)) %>%
               filter(match_count > 0) %>% 
               relocate(mod_epa_generator_id, 
                        mod_eia_generator_id, 
                        mod_epa_unit_id, 
                        mod_eia_boiler_id, .after = last_col())

# Save output data
# library(openxlsx)
# write.xlsx(end_matches, 'crosswalk_potential_matches_to_review.xlsx')


# wb <- createWorkbook()
# addWorksheet(wb, "without_prev_match")
# writeData(wb, sheet = "without_prev_match", x = end_matches)
# addWorksheet(wb, "with_prev_match")
# writeData(wb, sheet = "with_prev_match", x = end_matches)
# saveWorkbook(wb, "crosswalk_potential_matches_to_review.xlsx")

### Fuzzy Matching Using ID Strings ----
# create matching strings
# these can be edited in order to adjust for different inputs/dataframes
# currently set to EPA-EIA Boiler Crosswalk
# eia_matching <- epa_eia_boiler_crosswalk_5 %>%
#                 mutate(eia_match_string = paste(state,
#                                                 facility_name,
#                                                 mod_eia_boiler_id,
#                                                 mod_eia_generator_id,
#                                                 nameplate_capacity,
#                                                 eia_latitude,
#                                                 eia_longitude,
#                                                 sep = "_")) %>%
#                 select(state, facility_name, mod_eia_boiler_id, mod_eia_generator_id, nameplate_capacity, eia_latitude, eia_longitude, eia_match_string)
# 
#                 # eia_generator_modified %>%
#                 # mutate(eia_match_string = paste(eia_state,
#                 #                                 eia_plant_name, 
#                 #                                 mod_eia_boiler_id,
#                 #                                 mod_eia_generator_id, 
#                 #                                 eia_nameplate_capacity, 
#                 #                                 eia_latitude, 
#                 #                                 eia_longitude,
#                 #                                 sep = "_"))
# 
# # create a matching string for fuzzy matching
# epa_matching <- #epa_eia_boiler_crosswalk_5 %>%
#                 epa_eia_crosswalk_3 %>%
#                 # mutate
#                 filter(match_type_gen == "EPA Unmatched") %>%
#                 mutate(epa_match_string = paste(epa_state,
#                                                 epa_facility_name, 
#                                                 mod_epa_unit_id, 
#                                                 mod_epa_generator_id, 
#                                                 epa_nameplate_capacity, 
#                                                 epa_latitude, 
#                                                 epa_longitude,
#                                                 sep = "_"))
# 
# # match the entire string 
# direct <- inner_join(epa_matching, eia_matching, by = c("epa_match_string" = "eia_match_string")) # comes up with none
# 
# # Levenshtein distance 
# # max distance = 10
# lv10 <- stringdist_join(
#   
#             x = epa_matching,
#             y = eia_matching,
#             by = c("epa_match_string" = "eia_match_string"),
#             mode = "left",
#             max_dist = 10,
#             method = "lv", # calculate Levenshtein distance 
#             distance_col = "dist",
#             ignore_case = TRUE) %>%
#         relocate(eia_match_string, .after=epa_match_string)
# 
# # max distance = 15 
# lv15 <- stringdist_join(
#   
#   x = epa_matching,
#   y = eia_matching,
#   by = c("epa_match_string" = "eia_match_string"),
#   mode = "left",
#   max_dist = 15,
#   method = "lv", # calculate Levenshtein distance 
#   distance_col = "dist",
#   ignore_case = TRUE) %>%
#   relocate(eia_match_string, .after=epa_match_string)
# 
# # Full Damerau-Levenshtein distance
# # max distance = 10
# dl10 <- stringdist_join(
#   
#   x = epa_matching,
#   y = eia_matching,
#   by = c("epa_match_string" = "eia_match_string"),
#   mode = "left",
#   max_dist = 10,
#   method = "dl", 
#   distance_col = "dist",
#   ignore_case = TRUE) %>%
#   relocate(eia_match_string, .after=epa_match_string)
# 
# # max distance = 15
# dl15 <- stringdist_join(
#   
#   x = epa_matching,
#   y = eia_matching,
#   by = c("epa_match_string" = "eia_match_string"),
#   mode = "left",
#   max_dist = 15,
#   method = "dl", 
#   distance_col = "dist",
#   ignore_case = TRUE) %>%
#   relocate(eia_match_string, .after=epa_match_string)
# # test %>% filter(!is.na(dist)) %>% count()
# dl15 %>% filter(!is.na(dist)) %>% count()
# 
# 
# # Save data frame to Excel - 
# wb <- createWorkbook()
# addWorksheet(wb, "Direct Match")
# writeData(wb, sheet = "Direct Match", x = direct)
# addWorksheet(wb, "LV10")
# writeData(wb, sheet = "LV10", x = lv10)
# addWorksheet(wb, "LV15")
# writeData(wb, sheet = "LV15", x = lv15)
# addWorksheet(wb, "DL10")
# writeData(wb, sheet = "DL10", x = dl10)
# addWorksheet(wb, "DL15")
# writeData(wb, sheet = "DL15", x = dl15)
# saveWorkbook(wb, "fuzzy_matching_test1.xlsx")
