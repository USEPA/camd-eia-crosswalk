## -------------------------------
##
## Save data
## 
## Purpose: 
## 
## This function saves objects as RDS files in the specified 
## folder and file path by first checking if directories exist and creating 
## them where necessary.
##
## Authors:
##    Emma Russell, Abt Global
##
## -------------------------------

save_data <- function(data, output_folder_path, filename){
  
  #' @name save_data
  #' 
  #' Function to save data to RDS files in the specified folder and file path,  
  #' create directories when necessary
  #' 
  #' @param data Object name to save
  #' @param output_folder String name of output folder to save to
  #' @param filename String name of new file being saved
  #' 
  #' @return Saves the RDS dataset in {output_folder_path}/{crosswalk_year}
  #'         directory
  #'         
  #' @examples 
  #' # Save EIA-860 data
  #' save_output_data(eia_860_data, "data/raw_data/eia", "eia_860.RDS")

  #create save directories if they don't exist
  if(!dir.exists(glue::glue("{output_folder_path}/{params$crosswalk_year}"))) {
    dir.create(glue::glue("{output_folder_path}/{params$crosswalk_year}"), recursive = TRUE)
  }
  
  print(glue::glue("Saving {filename} to folder {output_folder_path}/{params$crosswalk_year}"))
  
  # save file
  write_rds(data, glue::glue("{output_folder_path}/{params$crosswalk_year}/{filename}"))
  
  # check if file is successfully written to folder
  if(file.exists(glue::glue("{output_folder_path}/{params$crosswalk_year}/{filename}"))){
    print(glue::glue("File {filename} successfully written to folder {output_folder_path}/{params$crosswalk_year}"))
  } else {
    print(glue::glue("File {filename} failed to write to folder."))
  }
}