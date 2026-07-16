# Script pour le traitement des valeurs aberrantes/manquantes et le calcul des variables PUDC

# Charger la configuration (qui charge globalement PARAMS à partir de params.yaml)
source(file.path("cleansurvey", "config.R"))
source(file.path("cleansurvey", "utils.R"))
load_required_packages(c("dplyr", "readr", "cli", "mice", "tibble"))

cli::cli_h1("Nettoyage et Calcul des Indicateurs PUDC (Configuration YAML)")

# Fonction pour nettoyer et convertir proprement les colonnes numériques
# en interceptant les codes manquants définis dans params.yaml
clean_num <- function(x) {
  xs <- as.character(x)
  xs[xs %in% PARAMS$ss_missing_codes] <- NA_character_
  # Gère aussi la virgule décimale
  as.numeric(gsub(",", ".", xs))
}

# --- 1. NETTOYAGE ET CALCULS INDIVIDUS (S1_INFOS_MEMBRES) ---
ind_file <- file.path(DATA_PATH, "S1_INFOS_MEMBRES_renamed.csv")
if (file.exists(ind_file)) {
  cli::cli_alert_info("Nettoyage du module Individus...")
  df_ind <- readr::read_csv(ind_file, show_col_types = FALSE)

  # Nettoyage et typage (seuils depuis PARAMS)
  df_ind <- df_ind %>%
    mutate(
      age          = clean_num(age),
      age_enfant   = clean_num(age_enfant),
      pb_enfant    = clean_num(pb_enfant),
      oedeme_enfant = clean_num(oedeme_enfant),

      # Remplacer les âges aberrants par NA
      age = ifelse(age < PARAMS$age_min | age > PARAMS$age_max, NA_real_, age)
    )

  # Calcul de l'indicateur de malnutrition chez les enfants (cible depuis PARAMS)
  df_ind <- df_ind %>%
    mutate(
      # Un enfant est dans la cible de mesure MUAC s'il a l'âge cible
      enfant_cible = !is.na(age_enfant) &
                     age_enfant >= PARAMS$age_target_min_months &
                     age_enfant <= PARAMS$age_target_max_months,

      # Malnutrition = 1 si cible ET (PB < seuil OU présence d'œdèmes)
      malnutrition = dplyr::case_when(
        !enfant_cible                                         ~ NA_real_,
        !is.na(pb_enfant) & pb_enfant < PARAMS$muac_threshold_mm ~ 1,
        !is.na(oedeme_enfant) & oedeme_enfant == 1           ~ 1,
        is.na(pb_enfant) & is.na(oedeme_enfant)              ~ NA_real_,
        TRUE                                                  ~ 0
      )
    )

  # Alerte QAQC sur les mesures valides
  cli::cli_alert_info("MUAC valides : {sum(!is.na(df_ind$pb_enfant))} / total individus : {nrow(df_ind)}")

  # Sauvegarde intermédiaire propre
  readr::write_csv(df_ind, file.path(DATA_PATH, "S1_INFOS_MEMBRES_clean.csv"))
  cli::cli_alert_success("Individus nettoyés.")
}

# --- 2. NETTOYAGE MÉNAGES (PUDC) ---
hh_file <- file.path(DATA_PATH, "PUDC_renamed.csv")
if (file.exists(hh_file)) {
  cli::cli_alert_info("Nettoyage du module Ménages...")
  df_hh <- readr::read_csv(hh_file, show_col_types = FALSE)

  # Nettoyage des variables numériques
  df_hh <- df_hh %>%
    mutate(
      nb_pieces  = clean_num(nb_pieces),
      source_eau = clean_num(source_eau),
      milieu     = clean_num(milieu)
    )

  # Détection des outliers sur le nombre de pièces
  df_hh <- df_hh %>%
    mutate(
      nb_pieces_outlier = detect_outliers(nb_pieces),
      nb_pieces = ifelse(
        nb_pieces > quantile(nb_pieces, 0.99, na.rm = TRUE),
        quantile(nb_pieces, 0.99, na.rm = TRUE),
        nb_pieces
      )
    )

  # Calcul du score d'actifs (Somme des biens possédés)
  bien_cols <- names(df_hh)[grep("^possede_bien_", names(df_hh))]
  if (length(bien_cols) > 0) {
    # Matrice brute des actifs (AVANT imputation) pour le diagnostic de complétude
    df_actifs <- df_hh %>% select(all_of(bien_cols))

    # Score d'actifs initial (somme avec na.rm) pour le logit de non-réponse
    df_hh <- df_hh %>%
      mutate(score_actifs = rowSums(df_actifs == 1, na.rm = TRUE))

    # Sauvegarde des diagnostics manquants pour le rapport QAQC
    if (!dir.exists(OUTPUT_PATH)) dir.create(OUTPUT_PATH, recursive = TRUE)
    diag_na <- tibble::tibble(
      interview__key = df_hh$interview__key,
      region         = df_hh$region,
      milieu         = df_hh$milieu,
      score_actifs   = df_hh$score_actifs,
      asset_any_na   = as.integer(apply(is.na(df_actifs), 1, any))
    )
    readr::write_csv(diag_na, file.path(OUTPUT_PATH, "qa_asset_diag.csv"))
    saveRDS(df_actifs, file.path(OUTPUT_PATH, "qa_actifs_raw.rds"))

    # Imputation MICE (logreg binaire) ; repli 0 si échec
    mice_res <- tryCatch({
      m <- mice::mice(df_actifs, method = "logreg", m = 5, maxit = 10, seed = 123, printFlag = FALSE)
      list(imp = m, mat = mice::complete(m, 1))
    }, error = function(e) {
      cli::cli_alert_warning("MICE indisponible, repli 0 : {e$message}")
      df_actifs[is.na(df_actifs)] <- 0
      list(imp = NULL, mat = df_actifs)
    })
    df_actifs_imp <- mice_res$mat
    df_hh$score_actifs <- rowSums(df_actifs_imp == 1, na.rm = FALSE)

    # ACP sur les actifs imputés (variance > 0 uniquement)
    variances  <- apply(df_actifs_imp, 2, var)
    cols_to_use <- bien_cols[variances > 0]

    if (length(cols_to_use) > 1) {
      if (!is.null(mice_res$imp)) {
        # ACP poolée (propagation de l'incertitude MICE)
        pc1_list <- sapply(1:5, function(i)
          prcomp(
            mice::complete(mice_res$imp, i) %>% select(all_of(cols_to_use)),
            scale. = TRUE
          )$x[, 1]
        )
        df_hh$index_richesse_pca    <- rowMeans(pc1_list)
        df_hh$index_richesse_pca_sd <- apply(pc1_list, 1, sd)  # Incertitude due à l'imputation
      } else {
        df_hh$index_richesse_pca <- prcomp(
          df_actifs_imp %>% select(all_of(cols_to_use)), scale. = TRUE
        )$x[, 1]
      }
    } else {
      df_hh$index_richesse_pca <- NA_real_
    }

    # Quintiles de richesse (méthode DHS) calculés par milieu
    df_hh <- df_hh %>%
      group_by(milieu) %>%
      mutate(quintile_richesse = dplyr::ntile(index_richesse_pca, 5)) %>%
      ungroup()
  }

  # Calcul du nombre de sources de revenus distinctes
  rev_cols <- names(df_hh)[grep("^source_revenu_", names(df_hh))]
  if (length(rev_cols) > 0) {
    df_hh <- df_hh %>%
      rowwise() %>%
      mutate(nb_sources_revenu = sum(dplyr::c_across(all_of(rev_cols)) == 1, na.rm = TRUE)) %>%
      ungroup()
  }

  # Recodage eau potable améliorée (Standard JMP, codes depuis PARAMS)
  df_hh <- df_hh %>%
    mutate(eau_amelioree = ifelse(source_eau %in% PARAMS$jmp_improved_codes, 1, 0))

  # Sauvegarde intermédiaire propre
  readr::write_csv(df_hh, file.path(DATA_PATH, "PUDC_clean.csv"))
  cli::cli_alert_success("Ménages nettoyés.")
}

cli::cli_h1("Etape de nettoyage terminée.")
