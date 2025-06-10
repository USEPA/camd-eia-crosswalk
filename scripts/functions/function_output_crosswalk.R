## -------------------------------
##
## Output crosswalk functions
## 
## Purpose: 
## 
## This file contains all matching functions required for exporting and saving
## crosswalk file data
##
## -------------------------------

output_crosswalk <- function(epa_eia_crosswalk, agg_level, unmatch_only = FALSE) {
  
  field_description_labels <-
    c("sequence_number"             = "Row number assigned to each observation. Included for purposes of sorting to original order.",
      "epa_state"                   = "The state where the facility is located in EPA's data.",
      "epa_facility_name"           = "The name of the facility in EPA's data.",
      "epa_plant_id"                = "The unique ID (also known as ORIS code/ORISPL code) of the facility in EPA's data. (EPA key)",
      "epa_unit_id"                 = "The unique ID for a combustion unit at a facility in EPA's data. (EPA key)",
      "epa_generator_id"            = "The unique ID for a generator at a facility in EPA's data. (EPA key)",
      "epa_nameplate_capacity"      = "The maximum rated output of the generator in EPA's data, prime mover, or other electric power production equipment under specific conditions designated by the manufacturer. Expressed in MW.",
      "epa_fuel_type"               = "The primary fuel type for the unit in EPA's data.",
      "epa_latitude"                = "The latitude of the facility in CAMD's data.",
      "epa_longitude"               = "The longitude of the facility in EPA's data.",
      "epa_status"                  = "The status of the unit in EPA's data. Either OPR (Operating), LTCS (Long-term cold storage), or RET (Retired).",
      "epa_status_date"             = "The date on which the status of the unit last changed in CAMD's data. For example, the date on which the unit changed from operating to retired.",
      "epa_retire_year"             = "The year in which the unit retired in EPA's data.",
      "mod_epa_unit_id"             = "The resulting EPA unit ID used to create a match between EPA and EIA. It may be the same as the original if it was matched without modifications.",
      "mod_epa_generator_id"        = "The resulting EPA generator ID used to create a match between EPA and EIA. It may be the same as the original if it was matched without modifications.",
      "eia_state"                   = "The state where the facility is located in EIA's data.",
      "eia_plant_name"              = "The name of the facility in EIA's data.",
      "eia_plant_id"                = "The unique ID of the facility in EIA's data. (EIA key)",
      "eia_generator_id"            = "The unique ID for a generator at a facility in EIA's data. (EIA key)",
      "eia_nameplate_capacity"      = "The highest value on the generator nameplate in megawatts rounded to the nearest tenth. Expressed in MW.",
      "eia_boiler_id"               = "The unique ID for a steam boiler unit at a facility in EIA's data. (EIA key)",
      "eia_unit_type"               = glue::glue("The prime mover (devices-e.g., gas turbine, steam turbine-that convert fuels to electrical energy via a generator) for an EIA unit. See reference table 2 in EIA-860 LayoutY{params$crosswalk_year}.xlsx or https://www.epa.gov/sites/production/files/2017-01/egrid_code_lookup.xlsx"),
      "eia_fuel_type"               = "The primary fuel type for the unit in EIA's data.",
      "eia_latitude"                = "The latitude of the facility in EIA's data.",
      "eia_longitude"               = "The longitude of the facility in EIA's data.",
      "eia_retire_year"             = "The year in which the unit retired in EIA's data.",
      "plant_id_change_flag"        = "A flag to indicate whether the EIA Plant ID was changed to match a EPA ORIS Code according to a list of known discrepancies between EPA ORIS code and EIA Plant ID. The list is linked in the README.",
      "mod_eia_plant_id"            = "The resulting EIA plant ID used to create a match between EPA and EIA before any matching occurs. See \"plant_id_manual_matches\" sheet within the manual matches file.",
      "mod_eia_boiler_id"           = "The resulting EIA boiler ID used to create a match between EPA and EIA during Step 2. It may be the same as the original if it was matched without modifications.",
      "mod_eia_generator_id_boiler" = "The resulting EIA generator ID used to create a match between EPA and EIA during Step 2. It may be the same as the original if it was matched without modifications.",
      "mod_eia_generator_id_gen"    = "The resulting EIA generator ID used to create a match between EPA and EIA during Step 1, matching EPA generators to EIA generators on EPA and EIA plant and generator IDs. It may be the same as the original if it was matched without modifications.",
      "match_type_gen"              = "The type of match made during Step 1, matching EPA generators to EIA generators on EPA and EIA plant and generator IDs. Any applied modifier sub-steps are also indicated in this field.",
      "match_type_boiler"           = "The type of match made during Step 2, matching EPA units and generators to EIA boilers and generators on EPA and EIA plant, unit/boiler, and generator IDs. Any applied modifier sub-steps are also indicated in this field.")
  
  field_col_names <- names(field_description_labels)
  field_col_desc <- unname(field_description_labels)
  
  field_desc_df <- data.frame("Column Name" = field_col_names, "Description" = field_col_desc)
  colnames(field_desc_df) <- c("Column Name", "Description")
  
  # define which columns to groupby by aggregation level
  agg_groupby_cols <-
    c("epa_state",
      "epa_facility_name",
      "epa_plant_id")
      # "epa_latitude",
      # "epa_longitude",
      # "eia_state",
      # "eia_plant_name",
      # "eia_plant_id",
      # "eia_latitude",
      # "eia_longitude")
  
  if (agg_level == "plant") {
    agg_groupby_cols <-
      agg_groupby_cols
  } else if (agg_level == "generator") {
    agg_groupby_cols <-
      c(agg_groupby_cols,
        "epa_generator_id",
        "mod_epa_generator_id")
  } else if (agg_level == "unit") {
    agg_groupby_cols <-
      c(agg_groupby_cols,
        "epa_generator_id",
        "epa_unit_id",
        "mod_epa_generator_id",
        "mod_epa_unit_id")
  }
  
  # define which columns to concatenate text by aggregation level
  agg_concat_cols <-
    c("epa_status",
      "epa_status_date",
      "epa_latitude",
      "epa_longitude",
      "epa_fuel_type",
      "epa_retire_year",
      "eia_state",
      "eia_plant_name",
      "eia_latitude",
      "eia_longitude",
      "eia_fuel_type",
      "eia_retire_year",
      "eia_plant_id",
      "eia_generator_id",
      "eia_boiler_id",
      "eia_unit_type",
      "plant_id_change_flag",
      "mod_eia_plant_id",
      "mod_eia_boiler_id", 
      "mod_eia_generator_id_boiler",
      "mod_eia_generator_id_gen",
      "match_type_gen",
      "match_type_boiler")
  
  if (agg_level == "plant") {
    agg_concat_cols <-
      c(agg_concat_cols,
        "epa_generator_id",
        "epa_unit_id",
        "mod_epa_generator_id",
        "mod_epa_unit_id")
  } else if (agg_level == "generator") {
    agg_concat_cols <-
      c(agg_concat_cols,
        "epa_unit_id",
        "mod_epa_unit_id")
  } else if (agg_level == "unit") {
    agg_concat_cols <-
      agg_concat_cols
  }
  
  # define which columns to sum
  agg_sum_cols <-
    c("epa_nameplate_capacity",
      "eia_nameplate_capacity")
  
  if (agg_level != "plant") {
    epa_eia_crosswalk <- epa_eia_crosswalk %>%
      group_by(pick(all_of(agg_groupby_cols))) %>%
      summarize(across(all_of(agg_concat_cols), ~paste(unique(.x), collapse = ", ")),
                across(all_of(agg_sum_cols), ~sum(.x, na.rm = TRUE))) %>%
      ungroup() %>%
      mutate(sequence_number = row_number()) %>%
      select(field_col_names)
  }

  
  if (agg_level == "plant") {
    epa_eia_crosswalk <- epa_eia_crosswalk %>%
                         select(epa_plant_id,
                                epa_facility_name, 
                                eia_plant_id,
                                eia_plant_name,
                                plant_id_change_flag) %>%
                         distinct()
  }
  
  if (unmatch_only) {
    if (agg_level != "plant") {
      epa_eia_crosswalk <- epa_eia_crosswalk %>%
        filter(!(str_detect(match_type_gen, "Exact match|Manual Match") | str_detect(match_type_boiler, "Exact match|Manual Match")))
    } else {
      epa_eia_crosswalk <- epa_eia_crosswalk %>%
                           filter(plant_id_change_flag != "0") %>%
                           select(-plant_id_change_flag)
    }

    file_name <- glue::glue("data/outputs/epa_eia_crosswalk_{agg_level}_unmatched.xlsx")
    file_name_csv <- glue::glue("data/outputs/epa_eia_crosswalk_{agg_level}_unmatched.csv")
  } else {
    file_name <- glue::glue("data/outputs/epa_eia_crosswalk_{agg_level}.xlsx")
    file_name_csv <- glue::glue("data/outputs/epa_eia_crosswalk_{agg_level}.csv")
  }
  
  # Create/modify xlsx workbook and worksheet to add text format to cells, preventing Excel from
  # changing some GENIDs and UNIT_IDs to dates and other automatic formatting issues
  if (!file.exists(file_name)) {
    wb <- createWorkbook()
  } else {
    wb <- loadWorkbook(file_name)
    # must remove worksheet to replace the data
    removeWorksheet(wb, "field_descriptions")
    removeWorksheet(wb, "epa_eia_crosswalk")
  }

  addWorksheet(wb, "field_descriptions")
  addWorksheet(wb, "epa_eia_crosswalk")

  # The numFmt = TEXT specifies text format for the cells,
  # thus avoiding the automatic conversion to dates
  # (e.g. 6-1 and 1-1 wont be converted to Jun-1, Jan-1) when "GENERAL" format is used
  textstyle <- createStyle(fontName = "Calibri", fontSize = 11, numFmt = "TEXT")

  writeDataTable(wb = wb, sheet = "field_descriptions", x = field_desc_df)

  addStyle(
    wb = wb, sheet = "field_descriptions",
    rows = 1:nrow(field_desc_df), cols = 1:ncol(field_desc_df),
    style = textstyle, gridExpand = TRUE
  )

  writeDataTable(wb = wb, sheet = "epa_eia_crosswalk", x = epa_eia_crosswalk)

  addStyle(
    wb = wb, sheet = "epa_eia_crosswalk",
    rows = 1:nrow(epa_eia_crosswalk), cols = 1:ncol(epa_eia_crosswalk),
    style = textstyle, gridExpand = TRUE
  )

  setColWidths(wb, sheet = "field_descriptions", cols = 1, widths = 27.29)
  setColWidths(wb, sheet = "field_descriptions", cols = 2, widths = 236.14)

  saveWorkbook(wb, file_name, overwrite = TRUE)

  print(glue::glue("{file_name} saved successfully."))

  # For a more accessible document, output csv, but if used in Excel, some GENIDs will be
  # interpreted as dates and leading zeros will be removed causing issues.
  write_excel_csv(epa_eia_crosswalk,
                  file_name_csv,
                  col_names = TRUE,
                  na = ""
  )

  print(glue::glue("{file_name_csv} saved successfully."))
}
