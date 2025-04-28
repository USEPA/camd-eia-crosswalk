## -------------------------------
##
## Data load EIA
## 
## Purpose: 
## 
## This section downloads and imports data from EIA-860 for the year specified above. 
## To manually download the data from EIA, visit the [EIA-860 data](https://www.eia.gov/electricity/data/eia860/). 
## Select and download the latest year's ZIP file on the right-hand-side of the page. 
## The files used in this analysis are "3_1_Generator_Y{year}.xlsx" and "6_1_EnviroAssoc_Y{year}.xlsx", 
## with "2___Plant_Y{year}.xlsx" to get lat/long.
## 
##
## -------------------------------

# Import plant, generator, and boiler (EnviroAssoc) data from EIA-860 using data year specified in eia_860_year

download.file(
  eia_data_file,
  str_glue("data/eia860{eia_860_year}.zip")
)

unzip(zipfile = str_glue("data/eia860{eia_860_year}.zip"), exdir = "data")

# Get plant location data
eia_plant <-
  read_excel(
    str_glue("data/2___Plant_Y{eia_860_year}.xlsx"),
    sheet = "Plant",
    range = cell_cols("C:K"),
    skip = 1,
    trim_ws = TRUE
  ) %>%
  select(
    EIA_PLANT_ID = "Plant Code",
    EIA_LATITUDE = "Latitude",
    EIA_LONGITUDE = "Longitude"
  )

# Get boiler ID
eia_boiler <-
  read_excel(
    str_glue("data/6_1_EnviroAssoc_Y{eia_860_year}.xlsx"),
    sheet = "Boiler Generator",
    range = cell_cols("C:F"),
    skip = 1,
    trim_ws = TRUE
  ) %>%
  select(
    EIA_PLANT_ID = "Plant Code",
    EIA_GENERATOR_ID = "Generator ID",
    EIA_BOILER_ID = "Boiler ID",
    MOD_EIA_BOILER_ID = "Boiler ID",
    MOD_EIA_GENERATOR_ID = "Generator ID"
  ) %>%
  inner_join(eia_plant, by = c("EIA_PLANT_ID"))

# Create a consolidated list of all units (retired and operating)
eia_gen_opr <- # Operating units
  read_excel(
    str_glue("data/3_1_Generator_Y{eia_860_year}.xlsx"),
    sheet = "Operable",
    range = cell_cols("C:AH"),
    skip = 1,
    trim_ws = TRUE
  ) %>%
  select(-"Planned Retirement Month", -"Planned Retirement Year") %>%
  mutate("Retirement Year" = 0)

eia_gen_ret <- # Retired units
  read_excel(
    str_glue("data/3_1_Generator_Y{eia_860_year}.xlsx"),
    sheet = "Retired and Canceled",
    range = cell_cols("C:AH"),
    skip = 1,
    trim_ws = TRUE
  ) %>%
  select(-"Retirement Month") %>%
  relocate("Retirement Year", .after = "Energy Source 1") %>%
  filter(`Retirement Year` >= earliest_retirement_year)

eia_generator <- rbind(eia_gen_opr, eia_gen_ret) %>%
  select(
    EIA_PLANT_ID = "Plant Code",
    EIA_PLANT_NAME = "Plant Name",
    EIA_STATE = "State",
    EIA_GENERATOR_ID = "Generator ID",
    MOD_EIA_GENERATOR_ID = "Generator ID",
    EIA_UNIT_TYPE = "Prime Mover",
    EIA_NAMEPLATE_CAPACITY = "Nameplate Capacity (MW)",
    EIA_FUEL_TYPE = "Energy Source 1",
    EIA_RETIRE_YEAR = "Retirement Year"
  ) %>%
  # Filter out renewable unit types https://www.epa.gov/sites/production/files/2017-01/egrid_code_lookup.xlsx
  filter(!(EIA_UNIT_TYPE %in% c("BA", "CE", "CP", "FC", "FW", "HA", "HY", "PS", "PV", "WS", "WT")))


# Add lat and long
eia_generator <- eia_generator %>%
  inner_join(eia_plant, by = c("EIA_PLANT_ID"))

# Clean up
rm(eia_gen_opr)
rm(eia_gen_ret)
rm(eia_plant)

