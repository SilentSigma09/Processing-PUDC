# Fichier utilitaire
# Fonctions génériques pour le nettoyage de données (metadata-driven)

if (!require(pacman)) install.packages("pacman")
pacman::p_load(dplyr, haven, labelled, readr, stringr, cli)

# 1. Fonction pour appliquer le dictionnaire de variables
apply_var_dictionary <- function(df, dict_path) {
  if (!file.exists(dict_path)) {
    cli::cli_abort("Le dictionnaire spécifié est introuvable : {dict_path}")
  }
  
  dict <- readr::read_csv(dict_path, show_col_types = FALSE)
  
  # Ne garder que les variables qui ont 'keep' = 'yes' ou 'oui'
  dict_to_keep <- dict %>%
    filter(tolower(keep) %in% c("yes", "oui", "1", "true"))
  
  # Vérifier que les variables existent dans le df
  vars_in_df <- intersect(dict_to_keep$var_orig, names(df))
  
  if(length(vars_in_df) == 0) {
    cli::cli_alert_warning("Aucune variable du dictionnaire n'a été trouvée dans le dataframe.")
    return(data.frame())
  }
  
  # Filtrer le dataframe
  df_filtered <- df %>% select(all_of(vars_in_df))
  
  # Renommer et labéliser
  for (i in 1:nrow(dict_to_keep)) {
    v_orig <- dict_to_keep$var_orig[i]
    v_new  <- dict_to_keep$var_new[i]
    l_new  <- dict_to_keep$label_new[i]
    
    if (v_orig %in% names(df_filtered)) {
      # Renommer si var_new n'est pas NA
      if (!is.na(v_new) && v_new != "") {
        names(df_filtered)[names(df_filtered) == v_orig] <- v_new
        v_current <- v_new
      } else {
        v_current <- v_orig
      }
      
      # Appliquer le label si label_new n'est pas NA
      if (!is.na(l_new) && l_new != "") {
        labelled::var_label(df_filtered[[v_current]]) <- l_new
      }
    }
  }
  
  cli::cli_alert_success("Dictionnaire appliqué. {ncol(df_filtered)} variables conservées.")
  return(df_filtered)
}

# 2. Fonction scalable pour détecter les outliers (ex: bornes interquartiles)
detect_outliers <- function(x, multiplier = 1.5) {
  if (!is.numeric(x)) return(rep(FALSE, length(x)))
  qnt <- quantile(x, probs=c(.25, .75), na.rm = TRUE)
  H <- multiplier * IQR(x, na.rm = TRUE)
  outliers <- x < (qnt[1] - H) | x > (qnt[2] + H)
  return(outliers)
}

message("Fonctions utilitaires chargées.")
