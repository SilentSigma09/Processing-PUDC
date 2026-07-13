# Script pour extraire les métadonnées et générer les dictionnaires initiaux
# Pour chaque fichier .dta dans data/input, on crée un dictionnaire CSV dans data/aux_file

if (!require(pacman)) install.packages("pacman")
pacman::p_load(here, dplyr, haven, readr, purrr, cli)

# Charger la configuration
source(here::here("cleansurvey", "config.R"))

cli::cli_h1("Génération des Dictionnaires Initiaux")

# Lister tous les fichiers .dta dans le dossier d'entrée
dta_files <- list.files(INPUT_PATH, pattern = "\\.dta$", full.names = TRUE, recursive = TRUE)

if (length(dta_files) == 0) {
  cli::cli_abort("Aucun fichier .dta trouvé dans le dossier : {INPUT_PATH}")
}

# Créer le dossier aux_file s'il n'existe pas
if (!dir.exists(AUX_FILE_PATH)) {
  dir.create(AUX_FILE_PATH, recursive = TRUE)
}

# Fonction pour traiter un fichier et exporter son dictionnaire
generate_dict <- function(file_path) {
  file_name <- basename(file_path)
  table_name <- tools::file_path_sans_ext(file_name)
  
  cli::cli_alert_info("Traitement de {file_name}...")
  
  # Lecture de la base (on ne charge que quelques lignes pour aller très vite)
  df <- haven::read_dta(file_path, n_max = 5)
  
  # Extraction des métadonnées
  var_orig <- names(df)
  
  # Récupérer les labels
  label_orig <- map_chr(var_orig, function(v) {
    lbl <- attr(df[[v]], "label")
    if (is.null(lbl)) return(NA_character_)
    return(as.character(lbl))
  })
  
  # Récupérer les types (classes)
  type_orig <- map_chr(var_orig, function(v) {
    paste(class(df[[v]]), collapse = ", ")
  })
  
  # Récupérer les value labels (modalités) de manière robuste
  val_lbl <- map_chr(var_orig, function(v) {
    vl <- labelled::val_labels(df[[v]])
    if (length(vl) == 0) return(NA_character_)
    paste(paste0(vl, "=", names(vl)), collapse = " | ")
  })
  
  # Création du dictionnaire
  dict <- tibble(
    var_orig   = var_orig,
    var_new    = var_orig,   # Valeur par défaut
    label_new  = label_orig, # Valeur par défaut
    modalities = val_lbl,    # Nouvelle colonne modalities
    type_new   = "",         # Laisser vide pour saisie utilisateur
    keep       = "no",       # Par défaut "no"
    label_orig = label_orig,
    type_orig  = type_orig
  )
  
  # Sauvegarde du dictionnaire
  out_path <- file.path(AUX_FILE_PATH, paste0("dictionary_", table_name, "_init.csv"))
  readr::write_csv(dict, out_path)
  
  cli::cli_alert_success("Dictionnaire sauvegardé : {basename(out_path)}")
}

# Traiter tous les fichiers
walk(dta_files, generate_dict)

cli::cli_h1("Génération terminée !")
