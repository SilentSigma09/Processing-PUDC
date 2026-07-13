# Script maître (Master Script)
# Orchestration du pipeline complet PUDC

# Nettoyage de l'environnement
rm(list = ls())
gc()

# 0. Charger la configuration et les utilitaires
source(file.path(here::here(), "cleansurvey", "config.R"))
source(file.path(here::here(), "cleansurvey", "utils.R"))

cli::cli_h1("Démarrage du Pipeline PUDC")

# Fonction pour sourcer tous les fichiers R d'un dossier avec capture d'erreurs
run_scripts_in_dir <- function(directory) {
  scripts <- list.files(directory, pattern = "\\.R$", full.names = TRUE, ignore.case = TRUE)
  if(length(scripts) > 0) {
    cli::cli_alert_info("Exécution des scripts dans : {basename(directory)}")
    for(s in scripts) {
      cli::cli_ul("Exécution de : {basename(s)}")
      tryCatch({
        source(s, echo = FALSE)
      }, error = function(e) {
        # Enregistrement d'un rapport d'erreur
        error_file <- file.path(OUTPUT_PATH, "PIPELINE_ERROR.txt")
        if (!dir.exists(OUTPUT_PATH)) dir.create(OUTPUT_PATH, recursive = TRUE)
        
        sink(error_file)
        cat("=========================================================\n")
        cat("          RAPPORT D'ERREUR DU PIPELINE PUDC              \n")
        cat(paste("Date/Heure :", Sys.time(), "\n"))
        cat("=========================================================\n\n")
        cat(paste("Script en échec :", basename(s), "\n"))
        cat(paste("Chemin complet  :", s, "\n\n"))
        cat("--- MESSAGE D'ERREUR DE R ---\n")
        cat(e$message, "\n\n")
        cat("---------------------------------------------------------\n")
        cat("CONSEIL : Vérifiez les valeurs aberrantes dans vos données\n")
        cat("brutes ou la syntaxe du fichier var_mapping.csv.\n")
        cat("=========================================================\n")
        sink()
        
        # Affichage rouge d'arrêt dans la console
        cli::cli_h1("ÉCHEC DU PIPELINE")
        cli::cli_alert_danger("Erreur dans le script : {basename(s)}")
        cli::cli_alert_danger("Message : {e$message}")
        cli::cli_alert_info("Un rapport détaillé a été généré dans : {error_file}")
        stop(e)
      })
    }
  } else {
    cli::cli_alert_warning("Aucun script R trouvé dans : {basename(directory)}")
  }
}

# 1. PHASE 1 : Exploration (Génération et pré-remplissage des dictionnaires)
run_scripts_in_dir(file.path(EXPLORATION_PATH, "1_get_initial_dict"))

# 2. PHASE 1 (Suite) : Application des dictionnaires
run_scripts_in_dir(file.path(EXPLORATION_PATH, "2_select_and_label"))

# 3. PHASE 2 : Nettoyage, Fusion et Assertions de Validation
run_scripts_in_dir(CLEAN_MERGE_PATH)

# 4. PHASE 3 : QAQC
run_scripts_in_dir(file.path(QAQC_PATH, "1_survey_data_qaqc"))

cli::cli_h1("Pipeline terminé avec succès.")
