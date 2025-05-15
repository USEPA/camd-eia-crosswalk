## -------------------------------
##
## Import FRS
## 
## Purpose: 
## 
## This file imports FRS data to include with the crosswalk
## 
##
## -------------------------------


# FRS API functions
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

get_frs_id_sys <- function(plant_id, sys) {
  frs_endpoint <-
    str_glue(
      "https://ofmpub.epa.gov/frs_public2/frs_rest_services.get_facilities?pgm_sys_acrnm={sys}&pgm_sys_id={plant_id}&output=JSON"
    )
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

if(!file.exists("data/FRS_ids.csv")) {
  message(str_glue("Obtaining FRS IDs. This may take several minutes.\n{timestamp(quiet=TRUE)}"))
  system.time(
    frs <- camd_eia_crosswalk %>%
      distinct(CAMD_PLANT_ID) %>%
      mutate(FRS_ID = map_dbl(CAMD_PLANT_ID, get_frs_id)) %>%
      write_csv("data/FRS_ids.csv")
  )
  message(str_glue("{timestamp(quiet=TRUE)}\nFinished obtaining FRS IDs. Writing to data/FRS_ids.csv"))
} else {
  frs <- read_csv("data/FRS_ids.csv")
}

epa_eia_crosswalk <- epa_eia_crosswalk %>%
  left_join(frs, by = "epa_plant_id") %>%
  relocate(frs_id, .before = match_type_gen)