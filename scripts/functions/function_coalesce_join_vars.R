## -------------------------------
##
## Coalesce joined variables
## 
## Purpose: 
## 
## This file coalesce two variables and identify non-missing (NA) values
##
## Authors:  
##      Sean Bock, Abt Global
##
## -------------------------------


coalesce_join_vars <- function(df) {
  
  #' coalesce_join_vars
  #' 
  #' Custom function to coalesce .x and .y variables. Some units have NA values in one source for a variable that matches. This function identifies the non-missing values and keeps those after join.
  
  #' @param df A dataframe with .x and .y variables, following a join.
  #' @return A dataframe with reduced columns
  #' @examples
  #' coalesce_join_vars(df)
  
  df %>%
    mutate(across(ends_with(".x"), ~ coalesce(., get(str_replace(cur_column(), ".x$", ".y"))))) %>% # take .x column and find corresponding .y column and coalesce values. ".x$" ensures that ".x" is at the end of column name
    rename_with(~ str_replace(., ".x$", ""), ends_with(".x")) %>% 
    select(-ends_with(".y"))
}
