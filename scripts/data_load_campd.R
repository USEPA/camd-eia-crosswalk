## -------------------------------
##
## Data load CAMPD
## 
## Purpose: 
## 
## This section imports the unit and generator data from the CAMPD API. 
## A CAMPD API key is required and can be obtained easily by signing up at the 
## (https://www.epa.gov/airmarkets/field-audit-checklist-tool-fact-api#signup). # fix this
## 
##
## -------------------------------

if (api_key == "YOUR_API_KEY") {
  stop("You must provide a FACT API key")
}

response <-
  GET(str_glue(
    "https://api.epa.gov/FACT/1.0/facilities?api_key={api_key}"
  ))

# If something is wrong with the request, fail gracefully
stop_for_status(response, content(response)$error$message)

camd_plants_json <- content(response, as = "text") %>%
  enter_object("data") # Top level json object that is an array of all the plants/oris

camd_plants <- camd_plants_json %>%
  gather_array() %>%
  spread_all()

camd_combustion_units <- camd_plants %>%
  enter_object("units") %>%
  gather_array() %>%
  spread_all()

# Filter CAMD data to filter out units that started operating after EIA data year
# Filter out units that retired before earliest_retirement_year value
camd_combustion_units <- camd_combustion_units %>%
  filter((status == "OPR" &
            ymd(as.Date(statusDate)) <= str_glue("{eia_860_year}-12-31")) |
           (status %in% c("RET", "LTCS") &
              ymd(as.Date(statusDate)) >= str_glue("{earliest_retirement_year}-01-01")))

# Get the unit and generator IDs
camd_generators <- camd_combustion_units %>%
  enter_object("generators") %>%
  gather_array() %>%
  spread_all() %>%
  select(
    orisCode,
    unitId,
    generatorId,
    nameplateCapacity
  ) %>%
  as_tibble()

# Get the primary fuel description for each unit
camd_fuels <- camd_combustion_units %>%
  enter_object("fuels") %>%
  gather_array() %>%
  spread_all() %>%
  subset(indicatorDescription == "Primary") %>%
  select(
    orisCode,
    unitId,
    fuelDesc
  ) %>%
  as_tibble()

# Joining unit and generator ID with fuel into a complete units table
camd_unit <- camd_combustion_units %>%
  as_tibble() %>%
  left_join(camd_generators,
            by = c("orisCode", "unitId")
  ) %>%
  left_join(camd_fuels,
            by = c("orisCode", "unitId")
  ) %>%
  select(
    CAMD_PLANT_ID = "orisCode",
    CAMD_FACILITY_NAME = "name",
    CAMD_STATE = state.abbrev,
    CAMD_LATITUDE = geographicLocation.latitude,
    CAMD_LONGITUDE = geographicLocation.longitude,
    CAMD_UNIT_ID = "unitId",
    MOD_CAMD_UNIT_ID = "unitId",
    CAMD_FUEL_TYPE = "fuelDesc",
    CAMD_GENERATOR_ID = "generatorId",
    MOD_CAMD_GENERATOR_ID = "generatorId",
    CAMD_NAMEPLATE_CAPACITY = "nameplateCapacity",
    CAMD_STATUS = "status",
    CAMD_STATUS_DATE = "statusDate"
  ) %>%
  mutate(CAMD_RETIRE_YEAR = ifelse(CAMD_STATUS != "OPR", year(ymd(
    as.Date(CAMD_STATUS_DATE)
  )), 0)) %>%
  arrange(CAMD_PLANT_ID, CAMD_UNIT_ID)

# Clean up
rm(camd_plants_json)
rm(camd_plants)
rm(camd_fuels)
rm(camd_generators)
rm(camd_combustion_units)
rm(response)