# Script pour pré-remplir automatiquement les dictionnaires avec les variables cibles du PUDC
# Génère les fichiers _filled.csv à partir des _init.csv et de var_mapping.csv

if (!require(pacman)) install.packages("pacman")
pacman::p_load(here, dplyr, readr, cli, purrr)

# Charger la configuration
source(here::here("cleansurvey", "config.R"))

cli::cli_h1("Pré-remplissage Automatique des Dictionnaires via var_mapping.csv")

# Lire le fichier de mapping externe (Tâche B)
mapping_file <- file.path(AUX_FILE_PATH, "var_mapping.csv")
if (!file.exists(mapping_file)) {
  cli::cli_abort("Erreur : Le fichier de mapping {mapping_file} est introuvable !")
}
var_mappings <- readr::read_csv(mapping_file, comment = "#", show_col_types = FALSE)

# Fonction pour appliquer le mapping dynamique
apply_mapping <- function(dict_df, table_name) {
  # Filtrer les mappings correspondant à la table courante
  table_mappings <- var_mappings %>%
    filter(table == table_name)
  
  # Faire une jointure pour mettre à jour keep, var_new, label_new
  dict_df <- dict_df %>%
    left_join(
      table_mappings %>% select(var_orig, m_var_new = var_new, m_keep = keep, m_label_new = label_new),
      by = "var_orig"
    ) %>%
    mutate(
      keep = ifelse(!is.na(m_keep), m_keep, "no"),
      var_new = ifelse(!is.na(m_var_new), m_var_new, var_orig),
      label_new = ifelse(!is.na(m_label_new), m_label_new, label_orig)
    ) %>%
    select(-starts_with("m_"))
  
  return(dict_df)
}

# --- 1. DICTIONNAIRE INDIVIDUS (S1_INFOS_MEMBRES) ---
ind_dict_path <- file.path(AUX_FILE_PATH, "dictionary_S1_INFOS_MEMBRES_init.csv")
if (file.exists(ind_dict_path)) {
  cli::cli_alert_info("Mise à jour du dictionnaire Individus...")
  ind_dict <- readr::read_csv(ind_dict_path, show_col_types = FALSE)
  ind_dict <- apply_mapping(ind_dict, "S1_INFOS_MEMBRES")
  readr::write_csv(ind_dict, file.path(AUX_FILE_PATH, "dictionary_S1_INFOS_MEMBRES_filled.csv"))
  cli::cli_alert_success("Dictionnaire Individus pré-rempli.")
}

# --- 2. DICTIONNAIRE MÉNAGES (PUDC) ---
hh_dict_path <- file.path(AUX_FILE_PATH, "dictionary_PUDC_init.csv")
if (file.exists(hh_dict_path)) {
  cli::cli_alert_info("Mise à jour du dictionnaire Ménages...")
  hh_dict <- readr::read_csv(hh_dict_path, show_col_types = FALSE)
  hh_dict <- apply_mapping(hh_dict, "PUDC")
  
  # Garder la logique de boucle sur S2_Q7__1..15 (biens) et S5_Q1__0..14 (revenus) comme requis (Tâche B)
  hh_dict <- hh_dict %>%
    mutate(
      # Possède biens
      is_bien = grepl("^S2_Q7__[1-9]$|^S2_Q7__1[0-5]$", var_orig),
      keep = ifelse(is_bien, "yes", keep),
      var_new = ifelse(is_bien, gsub("S2_Q7__", "possede_bien_", var_orig), var_new),
      label_new = ifelse(is_bien, gsub("S2_Q7__", "Possède équipement type ", var_orig), label_new),
      
      # Sources de revenus
      is_revenu = grepl("^S5_Q1__(0|[1-9]|1[0-4])$", var_orig),
      keep = ifelse(is_revenu, "yes", keep),
      var_new = ifelse(is_revenu, gsub("S5_Q1__", "source_revenu_", var_orig), var_new),
      label_new = ifelse(is_revenu, gsub("S5_Q1__", "Revenu issu de la source ", var_orig), label_new)
    ) %>%
    select(-is_bien, -is_revenu)
  
  readr::write_csv(hh_dict, file.path(AUX_FILE_PATH, "dictionary_PUDC_filled.csv"))
  cli::cli_alert_success("Dictionnaire Ménages pré-rempli.")
}

# --- 3. AUTRES MODULES (CHOCS SPECIFIQUES) ---
chocs_dict_path <- file.path(AUX_FILE_PATH, "dictionary_S7_INFOS_CHOCS_init.csv")
if (file.exists(chocs_dict_path)) {
  cli::cli_alert_info("Mise à jour du dictionnaire Chocs...")
  chocs_dict <- readr::read_csv(chocs_dict_path, show_col_types = FALSE)
  chocs_dict <- apply_mapping(chocs_dict, "S7_INFOS_CHOCS")
  readr::write_csv(chocs_dict, file.path(AUX_FILE_PATH, "dictionary_S7_INFOS_CHOCS_filled.csv"))
  cli::cli_alert_success("Dictionnaire Chocs pré-rempli.")
}

cli::cli_h1("Pré-remplissage via mapping externe terminé !")
