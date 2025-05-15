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

output_crosswalk <- function(epa_eia_crosswalk, only_mismatch = FALSE, agg_level = c("plant")) {
  
  # Create/modify xlsx workbook and worksheet to add text format to cells, preventing Excel from
  # changing some GENIDs and UNIT_IDs to dates and other automatic formatting issues
  if (!file.exists("epa_eia_crosswalk.xlsx")) {
    wb <- createWorkbook()
  } else {
    wb <- loadWorkbook("epa_eia_crosswalk.xlsx")
    # must remove worksheet to replace the data
    removeWorksheet(wb, "epa_eia_crosswalk")
  }
  
  addWorksheet(wb, "epa_eia_crosswalk")
  
  # The numFmt = TEXT specifies text format for the cells,
  # thus avoiding the automatic conversion to dates
  # (e.g. 6-1 and 1-1 wont be converted to Jun-1, Jan-1) when "GENERAL" format is used
  textstyle <- createStyle(fontName = "Calibri", fontSize = 11, numFmt = "TEXT")
  
  writeDataTable(wb = wb, sheet = "epa_eia_crosswalk", x = camd_eia_crosswalk)
  
  addStyle(
    wb = wb, sheet = "epa_eia_crosswalk",
    rows = 1:nrow(epa_eia_crosswalk), cols = 1:ncol(epa_eia_crosswalk),
    style = textstyle, gridExpand = TRUE
  )
  
  saveWorkbook(wb, "epa_eia_crosswalk.xlsx", overwrite = TRUE)
  
  # For a more accessible document, output csv, but if used in Excel, some GENIDs will be
  # interpreted as dates and leading zeros will be removed causing issues.
  write_excel_csv(epa_eia_crosswalk,
                  "epa_eia_crosswalk.csv",
                  col_names = TRUE,
                  na = ""
  )
  
}
