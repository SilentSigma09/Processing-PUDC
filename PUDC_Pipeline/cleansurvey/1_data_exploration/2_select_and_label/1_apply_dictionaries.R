# Script pour appliquer les dictionnaires remplis aux données brutes
# Renomme, filtre et type les variables d'intérêt

# Charger la configuration et les utilitaires
source(file.path("cleansurvey", "config.R"))
source(file.path("cleansurvey", "utils.R"))
load_required_packages(c("dplyr", "haven", "readr", "cli"))

cli::cli_h1("Application des Dictionnaires")

# Fonction pour charger et appliquer un dictionnaire à une table d'enquête
process_table <- function(table_name) {
  raw_file  <- file.path(INPUT_PATH,    paste0(table_name, ".dta"))
  dict_file <- file.path(AUX_FILE_PATH, paste0("dictionary_", table_name, "_filled.csv"))

  if (!file.exists(raw_file)) {
    cli::cli_alert_warning("Le fichier brut {table_name}.dta n'existe pas dans input.")
    return(NULL)
  }

  if (!file.exists(dict_file)) {
    cli::cli_alert_warning("Le dictionnaire rempli pour {table_name} n'existe pas.")
    return(NULL)
  }

  cli::cli_alert_info("Application du dictionnaire sur : {table_name}...")

  # Lecture de la base de données brute
  df_raw <- haven::read_dta(raw_file)

  # Application du dictionnaire
  df_renamed <- apply_var_dictionary(df_raw, dict_file)

  # Sauvegarde dans data/ au format CSV renommé
  out_file <- file.path(DATA_PATH, paste0(table_name, "_renamed.csv"))
  readr::write_csv(df_renamed, out_file)

  cli::cli_alert_success("Table renommée sauvegardée : {basename(out_file)}")
}

# Appliquer sur les trois tables cibles
process_table("PUDC")
process_table("S1_INFOS_MEMBRES")
process_table("S7_INFOS_CHOCS")

cli::cli_h1("Application terminée !")
