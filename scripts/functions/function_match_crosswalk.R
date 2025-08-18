## -------------------------------
##
## Crosswalk matching functions
## 
## Purpose: 
## 
## This file contains all matching functions required for crosswalk matching
##
## -------------------------------

# The match functions for matching units based on plant ID, unit ID/boiler ID, and/or generator ID


match_epa_eia_units <- function(epa_unmatched, eia_unmatched, by, match_type_label) {
 
  #' @name match_epa_eia_units
  #' 
  #' Get matches between EPA and EIA data sets using dplyr::inner_join()
  #'
  #' @param epa_unmatched A data.frame/tibble with unmatched EPA records to be matched
  #' @param eia_unmatched A data.frame/tibble with unmatched EIA records to be matched
  #' @param by A named character vector with the columns to be matched between EPA and EIA (fed to dplyr::inner_join())
  #' @param match_type_label A string to label the type of match e.g Step 1d: Modify IDs; remove leading letters
  #'
  #' @return A tibble with new EPA-EIA matches
  #'
  #' @examples
  #' match_epa_eia_units(
  #'   get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk),
  #'   get_unmatched(eia_generator, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")),
  #'   by = c("epa_plant_id" = "mod_eia_plant_id", "mod_epa_generator_id" = "mod_eia_generator_id"),
  #'   "Step 1a: Exact match"
  #' )
  #'
  #' match_epa_eia_units(
  #'   get_epa_unmatched(epa_unit, epa_eia_gen_crosswalk) %>%
  #'     mutate(across(c(mod_epa_generator_id), mod_identifiers_special_char)),
  #'   get_unmatched(eia_generator, epa_eia_gen_crosswalk, by = c("eia_plant_id", "eia_generator_id")) %>%
  #'     mutate(across(c(mod_eia_generator_id), mod_identifiers_special_char)),
  #'   by = plant_generator_match,
  #'   "Step 1b: Modify IDs; remove special chars"
  #' )
  
  # We need to "enframe" the character vector of match_parameters
  # in order to easily pull out the "names" and "values" to be used
  # in restoring columns collapsed by the join
  match_param_tibble <- enframe(by)
  
  # Flip the order of "names" and "values" from the original "by" character vector
  # in order to restore the columns lost by the inner_join
  restore_cols <-
    set_names(
      match_param_tibble$name %>% map(sym),
      match_param_tibble$value
    )
  
  # Inner join the two unmatched data sets
  epa_eia_matches <- inner_join(epa_unmatched,
                                eia_unmatched,
                                by = by,
                                keep = TRUE
  ) %>%
    # Restore the columns that are collapsed after join via restore_cols
    mutate(!!!restore_cols, match_type = match_type_label)
  
  return(epa_eia_matches)
}


get_manual_matches <- function(manual_matches, manual_excluded, epa, eia, eia_by) {
  
  #' @name get_manual_matches
  #' 
  #' Get manual matches from specified EPA and EIA data
  #'
  #' @param manual_matches The data.frame/tibble containing manual matches between EPA and EIA identifiers
  #' @param epa The data.frame/tibble containing EPA records
  #' @param eia  The data.frame/tibble containing EIA records
  #'
  #' @return A tibble with manual matches including data from both EPA and EIA
  #'
  #' @examples
  #' epa_eia_gen_crosswalk <-
  #'   get_manual_matches(
  #'     manual_matches,
  #'     manual_excluded,
  #'     epa_unit,
  #'     eia_generator,
  #'     eia_by
  #'   )
  
  # We use the eia/epa_plant_id instead of mod_eia/epa_plant_id because manual matches/unmatched will
  # use the identifiers from the source and not from the eGRID plant_id crosswalk.
  
  connection <- inner_join(epa, manual_matches, by = c("epa_plant_id", "epa_unit_id", "epa_generator_id"))
  
  if (nrow(connection) < nrow(manual_matches)) {
    warning(paste(c(
      "Warning:", str_glue("{nrow(manual_matches) - nrow(connection)} manual_matches do not match with EPA\n"),
      paste(format(anti_join(manual_matches, connection, by = c("epa_plant_id", "epa_unit_id", "epa_generator_id"))), sep = "\n", collapse = "\n")
    ),
    sep = "\n", collapse = "\n"
    ))
  }
  # Pull out units that create mismatches
  unmatched <- 
    manual_excluded %>%
    inner_join(epa, by = c("epa_plant_id", "epa_unit_id", "epa_generator_id")) %>%
    mutate(match_type = "Manual EPA Excluded")
  
  if (nrow(unmatched) < nrow(manual_excluded)) {
    warning(paste(c(
      "", "Warning:", str_glue("{nrow(manual_excluded) - nrow(unmatched)} manual_excluded do not match with EPA\n"),
      paste(format(anti_join(manual_excluded, unmatched, by = c("epa_plant_id", "epa_unit_id", "epa_generator_id"))), .sep = "", collapse = "\n")
    ), sep = "\n", collapse = "\n"))
  }
  all_manual_matches <- inner_join(connection, eia, by = eia_by) %>%
    mutate(match_type = "Manual Match")
  
  if (nrow(all_manual_matches) < nrow(manual_matches)) {
    warning(paste(c(
      "", "Warning:", str_glue("{nrow(manual_matches) - nrow(all_manual_matches)} manual_matches do not match with EIA\n"),
      paste(format(anti_join(manual_matches, all_manual_matches, by = c("epa_plant_id", "epa_unit_id", "epa_generator_id"))), .sep = "", collapse = "\n")
    ),
    sep = "\n", collapse = "\n"
    ))
  }
  
  result <- bind_rows(all_manual_matches, unmatched)
  
  return(result)
}



get_unmatched <- function(original_data, prev_matches, by = NULL) {
  
  #' @name get_unmatched
  #' 
  #' Get unmatched records from another data.frame or tibble via anti_join
  #'
  #' @param original_data The data.frame/tibble to look for unmatched records
  #' @param prev_matches The data.frame/tibble containing previous matched records from the original data
  #' @param by Optional: A character vector of the columns used to perform the anti_join.
  #'           The set of columns that constitute a unique record in both data.frames/tibbles.
  #'           If omitted, anti_join will use all columns of the same name.
  #'
  #' @return The resulting data.frame/tibble containing unmatched records from the original_data that are not in the prev_matches data.frame/tibble
  #'
  #' @examples
  #' get_unmatched(eia_generator, epa_eia_gen_crosswalk)
  #' get_unmatched(epa_unit, epa_eia_crosswalk, by = c("epa_plant_id", "epa_unit_id", "epa_generator_id"))
  
  if (missing(prev_matches) || (length(prev_matches) == 1 && is.na(prev_matches)) || is.null(prev_matches)) {
    return(original_data)
  }
  if (!missing(by) || !is.null(by)) {
    return(anti_join(original_data, prev_matches, by = by))
  }
  anti_join(original_data, prev_matches)
}

# Create a version of get_unmatched with the 'by' argument partially applied for EPA and EIA
get_epa_unmatched <- partial(get_unmatched, by = c("epa_plant_id", "epa_unit_id", "epa_generator_id"))

get_eia_unmatched <- partial(get_unmatched, by = c("eia_plant_id", "eia_boiler_id", "eia_generator_id"))

