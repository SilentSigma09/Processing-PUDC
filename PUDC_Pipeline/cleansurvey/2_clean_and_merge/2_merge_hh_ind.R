# Script pour consolider et fusionner les bases Individus et Ménages
# Produit les deux bases finales dans data/output/

# Charger la configuration
source(file.path("cleansurvey", "config.R"))
load_required_packages(c("dplyr", "readr", "cli"))

cli::cli_h1("Consolidation et Fusions Finales")

# Charger les bases intermédiaires nettoyées
df_ind <- readr::read_csv(file.path(DATA_PATH, "S1_INFOS_MEMBRES_clean.csv"), show_col_types = FALSE)
df_hh  <- readr::read_csv(file.path(DATA_PATH, "PUDC_clean.csv"),             show_col_types = FALSE)

# --- 1. CONSOLIDATION DE LA BASE INDIVIDUS ---
# Fusionner la base Individus avec les variables géographiques du Ménage (Région, Département, Milieu)
df_ind_final <- df_ind %>%
  left_join(
    df_hh %>% select(interview__key, region, departement, milieu),
    by = "interview__key"
  )

# Sauvegarde de la base Individus finale
if (!dir.exists(OUTPUT_PATH)) dir.create(OUTPUT_PATH, recursive = TRUE)
readr::write_csv(df_ind_final, file.path(OUTPUT_PATH, "Individus.csv"))
cli::cli_alert_success("Base finale INDIVIDUS sauvegardée ({nrow(df_ind_final)} individus).")

# --- 2. CONSOLIDATION DE LA BASE MÉNAGES ---

# 2.A. Contrôles de cohérence sur le Chef de Ménage (CM)
n_chef <- df_ind %>%
  filter(lien_cm == 1) %>%
  count(interview__key)

duplicate_heads <- sum(n_chef$n > 1)
missing_heads   <- sum(!df_hh$interview__key %in% n_chef$interview__key)

if (duplicate_heads > 0)
  cli::cli_alert_warning("{duplicate_heads} ménage(s) ont plus d'un chef de ménage déclaré !")
if (missing_heads > 0)
  cli::cli_alert_warning("{missing_heads} ménage(s) n'ont aucun chef de ménage déclaré dans le roster !")

# 2.B. Récupérer les caractéristiques du CM de manière robuste
# (max 1 CM par ménage pour éviter la duplication des lignes ménages)
df_cm <- df_ind %>%
  filter(lien_cm == 1) %>%
  group_by(interview__key) %>%
  slice(1) %>%   # En cas de doublons accidentels, on ne garde qu'un seul chef
  ungroup() %>%
  select(
    interview__key,
    cm_sexe           = sexe,
    cm_age            = age,
    cm_scolarise      = scolarise,
    cm_niveau_etudes  = niveau_etudes,
    cm_occupation     = occupation
  )

# 2.C. Fusionner les infos du CM et d'autres agrégations au niveau Ménage
df_hh_final <- df_hh %>%
  left_join(df_cm, by = "interview__key")

# 2.D. Agrégation des chocs (s'il y a des lignes par choc dans S7_INFOS_CHOCS)
chocs_file <- file.path(DATA_PATH, "S7_INFOS_CHOCS_renamed.csv")
if (file.exists(chocs_file)) {
  df_chocs <- readr::read_csv(chocs_file, show_col_types = FALSE)

  # On ne met PAS choc_subi dans summarise pour éviter le conflit de colonne
  # si df_hh_final possède déjà une colonne choc_subi (dplyr renommerait en .x/.y)
  df_chocs_agg <- df_chocs %>%
    group_by(interview__key) %>%
    summarise(nb_chocs = n(), .groups = "drop")

  df_hh_final <- df_hh_final %>%
    # Supprimer choc_subi existant éventuel avant la jointure pour éviter le doublon
    select(-any_of("choc_subi")) %>%
    left_join(df_chocs_agg, by = "interview__key") %>%
    mutate(
      nb_chocs  = ifelse(is.na(nb_chocs), 0L, nb_chocs),
      choc_subi = ifelse(nb_chocs > 0, 1L, 0L)
    )
} else {
  cli::cli_alert_warning("Fichier S7_INFOS_CHOCS_renamed.csv absent. Variables chocs mises à 0.")
  df_hh_final <- df_hh_final %>%
    mutate(nb_chocs = 0L, choc_subi = 0L)
}

# Sauvegarde de la base Ménages finale
readr::write_csv(df_hh_final, file.path(OUTPUT_PATH, "Menages.csv"))
cli::cli_alert_success("Base finale MÉNAGES sauvegardée ({nrow(df_hh_final)} ménages).")

cli::cli_h1("Pipeline de fusion terminé !")
