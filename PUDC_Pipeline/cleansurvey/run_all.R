# Script maitre
# Orchestration du pipeline complet PUDC.

rm(list = ls())
gc()

source(file.path("cleansurvey", "config.R"))
source(file.path("cleansurvey", "utils.R"))

cli::cli_h1("Demarrage du pipeline PUDC")

# Supprimer l'ancien rapport d'erreur au debut d'une nouvelle execution.
# S'il reapparait, il correspondra donc au run courant.
error_file <- file.path(OUTPUT_PATH, "PIPELINE_ERROR.txt")
if (file.exists(error_file)) file.remove(error_file)

run_scripts_in_dir <- function(directory) {
  scripts <- list.files(directory, pattern = "\\.R$", full.names = TRUE, ignore.case = TRUE)

  if (length(scripts) == 0) {
    cli::cli_alert_warning("Aucun script R trouve dans : {basename(directory)}")
    return(invisible(NULL))
  }

  cli::cli_alert_info("Execution des scripts dans : {basename(directory)}")
  for (s in scripts) {
    cli::cli_ul("Execution de : {basename(s)}")
    tryCatch({
      source(s, echo = FALSE)
    }, error = function(e) {
      if (!dir.exists(OUTPUT_PATH)) dir.create(OUTPUT_PATH, recursive = TRUE)

      sink(error_file)
      cat("=========================================================\n")
      cat("          RAPPORT D'ERREUR DU PIPELINE PUDC              \n")
      cat(paste("Date/Heure :", Sys.time(), "\n"))
      cat("=========================================================\n\n")
      cat(paste("Script en echec :", basename(s), "\n"))
      cat(paste("Chemin complet  :", s, "\n\n"))
      cat("--- MESSAGE D'ERREUR DE R ---\n")
      cat(e$message, "\n\n")
      cat("---------------------------------------------------------\n")
      cat("CONSEIL : verifiez les valeurs aberrantes dans les donnees\n")
      cat("brutes, les dependances R, ou la syntaxe de var_mapping.csv.\n")
      cat("=========================================================\n")
      sink()

      cli::cli_h1("ECHEC DU PIPELINE")
      cli::cli_alert_danger("Erreur dans le script : {basename(s)}")
      cli::cli_alert_danger("Message : {e$message}")
      cli::cli_alert_info("Rapport detaille genere dans : {error_file}")
      stop(e)
    })
  }
}

run_scripts_in_dir(file.path(EXPLORATION_PATH, "1_get_initial_dict"))
run_scripts_in_dir(file.path(EXPLORATION_PATH, "2_select_and_label"))
run_scripts_in_dir(CLEAN_MERGE_PATH)
run_scripts_in_dir(file.path(QAQC_PATH, "1_survey_data_qaqc"))

cli::cli_h1("Pipeline termine avec succes.")

