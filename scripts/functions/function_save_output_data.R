## -------------------------------
##
## Save output data
## 
## Purpose: 
## 
## This function saves RDS output datasets in the output 
## folder by first checking if directories exist and creating 
## them where necessary.
##
## Additional notes
##
##      Emma Russell, Abt Global
##
## -------------------------------

save_output_data <- function(data, output_folder_path, filename){
  
  #' save_output_data
  #' 
  #' Function to save RDS data in the output file and 
  #' create directories when necessary
  #' 
  #' @param data Dataset variable name to save
  #' @param output_folder String name of output folder to save to
  #' @param filename String name of new file being saved
  #' 
  #' @return Saves the RDS dataset in {output_folder_path}/{crosswalk_year}
  #'         directory
  #'         
  #' @examples 
  #' # Save PM2.5 plant file
  #' save_output_data(pm_plant_formatted, "1_production_model", "pm_plant_file.RDS")

  
  # create save directories if they don't exist
  if(dir.exists(glue::glue("{output_folder_path}"))) {
    print(glue::glue("Folder {output_folder_path} already exists."))
  } else {
    dir.create(glue::glue("{output_folder_path}"))
  }
  
  if(dir.exists(glue::glue("{output_folder_path}/{crosswalk_year}"))) {
    print(glue::glue("Folder {output_folder_path}/{crosswalk_year} already exists."))
  } else {
    dir.create(glue::glue("{output_folder_path}/{crosswalk_year}"))
  }
  
  print(glue::glue("Saving {filename} to folder {output_folder_path}/{crosswalk_year}"))
  
  # save file
  write_rds(data, glue::glue("{output_folder_path}/{crosswalk_year}/{filename}"))
  
  # check if file is successfully written to folder
  if(file.exists(glue::glue("{output_folder_path}/{crosswalk_year}/{filename}"))){
    print(glue::glue("File {filename} successfully written to folder {output_folder_path}/{crosswalk_year}"))
  } else {
    print(glue::glue("File {filename} failed to write to folder."))
  }
}