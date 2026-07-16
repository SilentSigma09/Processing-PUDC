# Fonctions generiques pour le nettoyage de donnees.

load_required_packages(c("dplyr", "haven", "labelled", "readr", "stringr", "cli"))

apply_var_dictionary <- function(df, dict_path) {
  if (!file.exists(dict_path)) {
    cli::cli_abort("Le dictionnaire specifie est introuvable : {dict_path}")
  }

  dict <- readr::read_csv(dict_path, show_col_types = FALSE)

  dict_to_keep <- dict %>%
    filter(tolower(keep) %in% c("yes", "oui", "1", "true"))

  vars_in_df <- intersect(dict_to_keep$var_orig, names(df))

  if (length(vars_in_df) == 0) {
    cli::cli_alert_warning("Aucune variable du dictionnaire n'a ete trouvee dans le dataframe.")
    return(data.frame())
  }

  df_filtered <- df %>% select(all_of(vars_in_df))

  for (i in seq_len(nrow(dict_to_keep))) {
    v_orig <- dict_to_keep$var_orig[i]
    v_new  <- dict_to_keep$var_new[i]
    l_new  <- dict_to_keep$label_new[i]

    if (v_orig %in% names(df_filtered)) {
      if (!is.na(v_new) && v_new != "") {
        names(df_filtered)[names(df_filtered) == v_orig] <- v_new
        v_current <- v_new
      } else {
        v_current <- v_orig
      }

      if (!is.na(l_new) && l_new != "") {
        labelled::var_label(df_filtered[[v_current]]) <- l_new
      }
    }
  }

  cli::cli_alert_success("Dictionnaire applique. {ncol(df_filtered)} variables conservees.")
  df_filtered
}

detect_outliers <- function(x, multiplier = 1.5) {
  if (!is.numeric(x)) return(rep(FALSE, length(x)))
  qnt <- quantile(x, probs = c(.25, .75), na.rm = TRUE)
  spread <- multiplier * IQR(x, na.rm = TRUE)
  x < (qnt[1] - spread) | x > (qnt[2] + spread)
}

message("Fonctions utilitaires chargees.")

