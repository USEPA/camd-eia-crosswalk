## -------------------------------
##
## Output crosswalk
## 
## Purpose: 
## 
## This file produces crosswalk export depending on inputs
## 
##
## -------------------------------

source("scripts/functions/function_output_crosswalk.R")

# clean data
clean_cols <- c(
  "epa_retire_year",
  "eia_retire_year")

epa_eia_crosswalk_4 <- epa_eia_crosswalk_3 %>%
                       mutate(across(all_of(clean_cols),
                                     ~na_if(.x, 0)))

# plant ver - select epa_plant_id epa_plant_name, eia_plant_id eia_plant_name


output_crosswalk(epa_eia_crosswalk_4, agg_level = params$output_agg, diffs_only = params$diffs_only)




