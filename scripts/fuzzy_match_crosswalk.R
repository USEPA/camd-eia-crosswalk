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

# Load in libraries
library(stringdist)
library(fuzzyjoin)
library(stringr)
library(openxlsx)


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
