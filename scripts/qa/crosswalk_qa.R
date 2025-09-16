## -------------------------------
##
## Crosswalk QA
##
## Purpose: 
## 
## Purpose
## 
## Additional notes
##
##  Emma Russell, Abt Global
## -------------------------------

# Load libraries -----
library(dplyr)
library(readr)
library(readxl)
library(stringr)

# Define Crosswalk year parameter ----------------
# define parameter year if no one is currently assigned using prompted user input
if (exists("params")) {
  if ("crosswalk_year" %in% names(params)) { # if params() and params$crosswalk_year exist, do not re-define
    print("Crosswalk year parameter is already defined.")
  } else { # if params() is defined, but crosswalk_year is not, define it here
    params$crosswalk_year <- readline(prompt = "Input crosswalk_year: ")
    params$crosswalk_year <- as.character(params$crosswalk_year)
  }
} else { # if params() and crosswalk_year are not defined, define them here
  params <- list()
  params$crosswalk_year <- readline(prompt = "Input crosswalk_year: ")
  params$crosswalk_year <- as.character(params$crosswalk_year)
}

print("CROSSWALK QA IN PROGRESS")

# Create save directory for QA outputs -----

if(dir.exists("data/outputs/qa")) {
  print("Folder qa already exists.")
}else{
  dir.create("data/outputs/qa")
}

if(dir.exists(glue::glue("data/outputs/qa/{params$crosswalk_year}"))) {
  print(glue::glue("Folder qa/{params$crosswalk_year} already exists."))
}else{
  dir.create(glue::glue("data/outputs/qa/{params$crosswalk_year}"))
}

# set directory for saving files 
save_dir <- glue::glue("data/outputs/qa/{params$crosswalk_year}/")

## Create function to save file differences -----
save_diffs <- function(datacheck) {
  if(nrow(datacheck) > 0) {
    write_csv(datacheck, paste0(save_dir, deparse(substitute(datacheck)), ".csv")) }
}

# Import Previous version of EPA-EIA Crosswalk ------

# check for file presence and load if file exists
if(file.exists("epa_eia_crosswalk.csv")) {
    crosswalk_old <- read_csv("epa_eia_crosswalk.csv",
                                  col_names = TRUE) %>%
      select(-sequence_number)
} else {
  stop(glue::glue("Crosswalk original output 'epa_eia_crosswalk.csv' does not exist and is required for QA. \n Skipping crosswalk QA."))
}

# Import New version of EPA-EIA Crosswalk -----
if(file.exists("data/outputs/2018/epa_eia_crosswalk_2018.csv")) {
  crosswalk_new <- read_csv("data/outputs/2018/epa_eia_crosswalk_2018.csv",
                            col_names = TRUE)
} else {
  stop(glue::glue("Crosswalk updated output 'data/outputs/2018/epa_eia_crosswalk_2018.csv' does not exist and is required for QA. \n Please run r_epa_eia_crosswalk.qmd to obtain."))
}

# Find differences in columns present ----
cols_missing_new <-
  setdiff(names(crosswalk_old), names(crosswalk_new)) %>%
  print()

cols_missing_old <-
  setdiff(names(crosswalk_new), names(crosswalk_old)) %>%
  print()

# Difference checks ------
## EPA unit presence --------
# EPA units in New not in Old
check_missing_units_old <- 
  crosswalk_new %>% 
  anti_join(crosswalk_old, by = c("epa_plant_id", "epa_unit_id")) %>% 
  filter(!is.na(epa_unit_id)) %>%
  select(epa_plant_id, epa_unit_id, epa_generator_id, eia_plant_id, eia_boiler_id,  eia_generator_id)
save_diffs(check_missing_units_old)

# EPA units in Old not in New
# currently have 102 additional in the old but none of them have been matched
check_missing_units_new <- 
  crosswalk_old %>% 
  anti_join(crosswalk_new, by = c("epa_plant_id", "epa_unit_id")) %>% 
  filter(!is.na(epa_unit_id)) %>%
  select(epa_plant_id, epa_unit_id, epa_generator_id, eia_plant_id, eia_boiler_id,  eia_generator_id) %>% distinct()
save_diffs(check_missing_units_new)

## Column-by-column Comparisons -----

# combine two datasets by EPA data for comparison 
join_cols <- c("epa_plant_id", "epa_unit_id", "epa_generator_id")
crosswalk_comparison <-
  crosswalk_new %>%
  inner_join(crosswalk_old, by = join_cols, suffix = c("_new", "_old"))

# identify columns to compare
columns <- setdiff(intersect(names(crosswalk_new), names(crosswalk_old)), join_cols)

# loop through columns and compare
for(column in columns) {
  col_new <- paste0(column, "_new")
  col_old <- paste0(column, "_old")
  
  # check for column differences
  check_column <-
    crosswalk_comparison %>%
    filter(mapply(identical, get(col_new), get(col_old)) == FALSE) %>%
    select(epa_unit_id, epa_plant_id, epa_generator_id, col_new, col_old) %>%
    distinct()
  
  # check if differences are due to NA values
  check_na <-
    check_column %>%
    count(new = is.na(get(col_new)), old = is.na(get(col_old))) %>%
    filter(new == TRUE | old == TRUE)
  
  # check for column differences despite order of join
  check_column_normalized <-
    check_column %>%
    filter(!is.na(get(col_new)), !is.na(get(col_old))) %>%
    rowwise() %>%
    mutate(
      unordered_pair = paste(sort(c(get(col_old), get(col_new))), collapse = "_")
    ) %>%
    ungroup() %>%
    select(-col_new, -col_old) %>% distinct() %>%
    group_by(!!!syms(join_cols)) %>%
    filter(n() > 1)
  
  # select data to store in saved csv
  check_column_save <-
    check_column %>%
    inner_join(check_column_normalized, by = join_cols) %>%
    select(-unordered_pair)
  
  # assign data to variable for evaluation if desired
  assign(glue::glue("check_{column}"), check_column_save)
  
  # print and save differences  
  if(nrow(check_column_normalized) > 0)  {
    print(glue::glue("RESULTS: {column} has {nrow(check_column)} differences"))
    write_csv(check_column_save, glue::glue("{save_dir}check_{column}.csv"))
    }

}
