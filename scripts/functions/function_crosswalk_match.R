## -------------------------------
##
## Crosswalk matching functions
## 
## Purpose: 
## 
## This file contains all matching functions required for crosswalk matching
##
##
## -------------------------------

# The match functions for matching units based on plant ID, unit ID/boiler ID, and/or generator ID

#' Get matches between CAMD and EIA data sets using dplyr::inner_join()
#'
#' @param camd_unmatched A data.frame/tibble with unmatched CAMD records to be matched
#' @param eia_unmatched A data.frame/tibble with unmatched EIA records to be matched
#' @param by A named character vector with the columns to be matched between CAMD and EIA (fed to dplyr::inner_join())
#' @param match_type_label A string to label the type of match e.g Step 1d: Modify IDs; remove leading letters
#'
#' @return A tibble with new CAMD-EIA matches
#'
#' @examples
#' match_camd_eia_units(
#'   get_camd_unmatched(camd_unit, camd_eia_gen_crosswalk),
#'   get_unmatched(eia_generator, camd_eia_gen_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")),
#'   by = c("CAMD_PLANT_ID" = "MOD_EIA_PLANT_ID", "MOD_CAMD_GENERATOR_ID" = "MOD_EIA_GENERATOR_ID"),
#'   "Step 1a: Exact match"
#' )
#'
#' match_camd_eia_units(
#'   get_camd_unmatched(camd_unit, camd_eia_gen_crosswalk) %>%
#'     mutate(across(c(MOD_CAMD_GENERATOR_ID), mod_identifiers_special_char)),
#'   get_unmatched(eia_generator, camd_eia_gen_crosswalk, by = c("EIA_PLANT_ID", "EIA_GENERATOR_ID")) %>%
#'     mutate(across(c(MOD_EIA_GENERATOR_ID), mod_identifiers_special_char)),
#'   by = plant_generator_match,
#'   "Step 1b: Modify IDs; remove special chars"
#' )

match_camd_eia_units <- function(camd_unmatched, eia_unmatched, by, match_type_label) {
  
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
  camd_eia_matches <- inner_join(camd_unmatched,
                                 eia_unmatched,
                                 by = by,
                                 keep = TRUE
  ) %>%
    # Restore the columns that are collapsed after join via restore_cols
    mutate(!!!restore_cols, MATCH_TYPE = match_type_label)
  
  return(camd_eia_matches)
}

#' Get manual matches from specified camd and eia data
#'
#' @param manual_matches The data.frame/tibble containing manual matches between camd and eia identifiers
#' @param camd The data.frame/tibble containing CAMD records
#' @param eia  The data.frame/tibble containing EIA records
#'
#' @return A tibble with manual matches including data from both CAMD and EIA
#'
#' @examples
#' camd_eia_gen_crosswalk <-
#'   get_manual_matches(
#'     manual_matches,
#'     manual_excluded,
#'     camd_unit,
#'     eia_generator,
#'     eia_by
#'   )

get_manual_matches <- function(manual_matches, manual_excluded, camd, eia, eia_by) {
  # We use the EIA/CAMD_PLANT_ID instead of MOD_EIA/CAMD_PLANT_ID because manual matches/unmatched will
  # use the identifiers from the source and not from the eGRID PLANT_ID crosswalk.
  
  connection <- inner_join(camd, manual_matches, by = c("CAMD_PLANT_ID", "CAMD_UNIT_ID", "CAMD_GENERATOR_ID"))
  
  if (nrow(connection) < nrow(manual_matches)) {
    warning(paste(c(
      "Warning:", str_glue("{nrow(manual_matches) - nrow(connection)} manual_matches do not match with CAMD\n"),
      paste(format(anti_join(manual_matches, connection, by = c("CAMD_PLANT_ID", "CAMD_UNIT_ID", "CAMD_GENERATOR_ID"))), sep = "\n", collapse = "\n")
    ),
    sep = "\n", collapse = "\n"
    ))
  }
  # Pull out units that create mismatches
  unmatched <- manual_excluded %>%
    inner_join(camd, by = c("CAMD_PLANT_ID", "CAMD_UNIT_ID", "CAMD_GENERATOR_ID")) %>%
    mutate(MATCH_TYPE = "Manual CAMD Excluded")
  
  if (nrow(unmatched) < nrow(manual_excluded)) {
    warning(paste(c(
      "", "Warning:", str_glue("{nrow(manual_excluded) - nrow(unmatched)} manual_excluded do not match with CAMD\n"),
      paste(format(anti_join(manual_excluded, unmatched, by = c("CAMD_PLANT_ID", "CAMD_UNIT_ID", "CAMD_GENERATOR_ID"))), .sep = "", collapse = "\n")
    ), sep = "\n", collapse = "\n"))
  }
  all_manual_matches <- inner_join(connection, eia, by = eia_by) %>%
    mutate(MATCH_TYPE = "Manual Match")
  
  if (nrow(all_manual_matches) < nrow(manual_matches)) {
    warning(paste(c(
      "", "Warning:", str_glue("{nrow(manual_matches) - nrow(all_manual_matches)} manual_matches do not match with EIA\n"),
      paste(format(anti_join(manual_matches, all_manual_matches, by = c("CAMD_PLANT_ID", "CAMD_UNIT_ID", "CAMD_GENERATOR_ID"))), .sep = "", collapse = "\n")
    ),
    sep = "\n", collapse = "\n"
    ))
  }
  
  result <- bind_rows(all_manual_matches, unmatched)
  
  return(result)
}

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
#' get_unmatched(eia_generator, camd_eia_gen_crosswalk)
#' get_unmatched(camd_unit, camd_eia_crosswalk, by = c("CAMD_PLANT_ID", "CAMD_UNIT_ID", "CAMD_GENERATOR_ID"))

get_unmatched <- function(original_data, prev_matches, by = NULL) {
  if (missing(prev_matches) || is.na(prev_matches) || is.null(prev_matches)) {
    return(original_data)
  }
  if (!missing(by) || !is.null(by)) {
    return(anti_join(original_data, prev_matches, by = by))
  }
  anti_join(original_data, prev_matches)
}

# Create a version of get_unmatched with the 'by' argument partially applied for camd and eia
get_camd_unmatched <- partial(get_unmatched, by = c("CAMD_PLANT_ID", "CAMD_UNIT_ID", "CAMD_GENERATOR_ID"))

get_eia_unmatched <- partial(get_unmatched, by = c("EIA_PLANT_ID", "EIA_BOILER_ID", "EIA_GENERATOR_ID"))

