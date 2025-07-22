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


library(stringdist)
library(fuzzyjoin)
library(stringr)

# direct match without unit ids


# fuel type map
# "Pipeline Natural Gas" = "NG"
# "Coal" = "BIT"
# fuel types are different between the two types, making it difficult to match up
view_fuel_types <- epa_eia_crosswalk_3 %>%
                   select(epa_fuel_type, eia_fuel_type) %>%
                   distinct()

eia_matching <- eia_generator_modified %>%
                mutate(eia_match_string = paste(eia_plant_name, 
                                                eia_state,
                                                mod_eia_generator_id, 
                                                eia_nameplate_capacity, 
                                                eia_latitude, 
                                                eia_longitude,
                                                sep = "_"))

# create a matching string for fuzzy matching
epa_matching <- epa_eia_crosswalk_3 %>%
                # mutate
                filter(match_type_gen == "EPA Unmatched") %>%
                select(-c(contains("fuel_type"), # remove fuel type since discrepancies
                          contains("year"), # epa does not have retire year
                          contains("status"), # eia does not have status
                          contains("unit_type"), 
                          contains("boiler"),
                          contains("unit"),
                          contains("plant_id")
                          ) 
                          ) %>%
                 mutate(epa_match_string = do.call(paste, c(across(starts_with("epa")), sep = "_"))) %>%
                 select(contains("epa"))
                                     # eia_match_string = do.call(paste, c(across(starts_with("eia")), sep = "_")))

test <- inner_join(epa_matching, eia_matching, by = c("epa_match_string" = "eia_match_string")) # comes up with none


test <- stringdist_join(
  
            x = epa_matching,
            y = eia_matching,
            by = c("epa_match_string" = "eia_match_string"),
            mode = "left",
            max_dist = 10,
            method = "lv", # calculate Levenshtein distance
            distance_col = "dist",
            ignore_case = TRUE)

test %>% filter(!is.na(dist)) %>% count()
