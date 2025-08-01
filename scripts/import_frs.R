## -------------------------------
##
## Import FRS data 
## 
## Purpose: 
## 
## This file imports FRS data to include with the crosswalk
## 
## Authors: 
##    Madeline Zhang, Abt Global
##
## -------------------------------

# FRS API functions

# this function returns FRS IDs based on specified program IDs
get_frs_id <- function(plant_id) {
  # The FRS database has the most information based on the EIA-860
  systems <- c("EIA-860", "CAMDBS", "EGRID")
  for (sys in systems) {
    id <- get_frs_id_sys(plant_id, sys)
    if (!is.na(id)) {
      return(id)
    }
  }
  return(NA)
}

# this function downloads FRS data from their API
get_frs_id_sys <- function(plant_id, sys) {
  frs_endpoint <-
    str_glue(
      "https://ofmpub.epa.gov/frs_public2/frs_rest_services.get_facilities?pgm_sys_acrnm={sys}&pgm_sys_id={plant_id}&output=JSON"
    )
  
  frs_endpoint <-
    str_glue("https://frsquerypre-api.epa.gov/facilityiptquery/v1/FRS/QueryProgramFacility?programSystemAcronym={sys}&programSystemId={plant_id}&output=JSON")
  
  response <- GET(frs_endpoint)
  text_json <-
    str_replace_all(suppressMessages(content(response, as = "text")), "[\\r\\n\\t]+", "")
  raw_json <- fromJSON(text_json)
  if (length(pluck(raw_json, 1, "FRSFacility")) == 0) {
    return(NA)
  }
  frs_id <- pluck(raw_json, 1, "FRSFacility", "RegistryId")
  
  return(as.numeric(frs_id))
}

# get frs ids sheet
# download.file(url, destfile, method = "auto")
# https://ordsext.epa.gov/FLA/www3/state_files/national_combined.zip
# unzip and open up NATIONAL_ORGANIZATIONAL_FILE (using unzip)
# filter to EIA-860, CAMDBS, EGRID

# TG (8/1/2025): flagging for this to be clarified and resolved
# figure out how to only keep one ... delete the rest? 
# filter and reduce memory usage
 
if(!file.exists("data/FRS_ids.csv")) {
  message(str_glue("Obtaining FRS IDs. This may take several minutes.\n{timestamp(quiet=TRUE)}"))
  system.time(
    frs <- epa_eia_crosswalk %>%
      distinct(epa_plant_id) %>%
      mutate(frs_id = purrr::map_dbl(epa_plant_id, get_frs_id)) %>%
      write_csv("data/FRS_ids.csv")
  )
  message(str_glue("{timestamp(quiet=TRUE)}\nFinished obtaining FRS IDs. Writing to data/FRS_ids.csv"))
} else {
  frs <- read_csv("data/FRS_ids.csv")
}

epa_eia_crosswalk <- epa_eia_crosswalk %>%
  left_join(frs, by = "epa_plant_id") %>%
  relocate(frs_id, .before = match_type_gen)
