# Script de validation et d'assertions du pipeline PUDC
# Garantit que le pipeline s'arrête en cas d'incohérence statistique majeure

if (!require(pacman)) install.packages("pacman")
pacman::p_load(here, dplyr, readr, cli)

# Charger la configuration
source(here::here("cleansurvey", "config.R"))

cli::cli_h1("Validation des Bases et Assertions QA")

# Charger les bases finales
df_ind <- readr::read_csv(file.path(OUTPUT_PATH, "Individus.csv"), show_col_types = FALSE)
df_hh  <- readr::read_csv(file.path(OUTPUT_PATH, "Menages.csv"), show_col_types = FALSE)

# --- 1. ASSERTIONS STRUCTURELLES ---

# A. Unicité de l'identifiant ménage dans la base Ménages
duplicate_keys <- df_hh %>% 
  count(interview__key) %>% 
  filter(n > 1)

if (nrow(duplicate_keys) > 0) {
  cli::cli_abort("Erreur critique : L'identifiant interview__key contient des doublons dans la base Ménages !")
} else {
  cli::cli_alert_success("Assertion validée : interview__key est unique dans la base Ménages.")
}

# B. Correspondance des clés Individus -> Ménages
orphan_ind <- sum(!df_ind$interview__key %in% df_hh$interview__key, na.rm = TRUE)
if (orphan_ind > 0) {
  cli::cli_abort("Erreur critique : {orphan_ind} individu(s) ne sont rattachés à aucun ménage de la base Ménages !")
} else {
  cli::cli_alert_success("Assertion validée : Tous les individus sont bien rattachés à un ménage.")
}


# --- 2. ASSERTIONS STATISTIQUES ET DE COHÉRENCE ---

# C. Taux de malnutrition aiguë aberrant (Biais C1 de Survey Solutions)
# Un taux de malnutrition > 30% sur toute une population indique un biais d'imputation ou une erreur de calcul
if ("malnutrition" %in% names(df_ind)) {
  valid_muac <- sum(!is.na(df_ind$pb_enfant))
  malnut_rate <- mean(df_ind$malnutrition == 1, na.rm = TRUE)
  
  if (!is.nan(malnut_rate) && malnut_rate > 0.30) {
    cli::cli_abort("Erreur critique : Taux de malnutrition aiguë détecté anormalement élevé ({round(malnut_rate * 100, 2)}% > 30%). Vérifier les codes manquants 000/999.")
  }
  
  # Alerte si les données MUAC physiques sont totalement absentes (comme sur ce round)
  if (valid_muac == 0) {
    cli::cli_alert_warning("Alerte Méthodologique : Le Périmètre Brachial (MUAC) n'a jamais été saisi (0 mesure valide).")
  }
}

# D. Taux d'accès à l'eau améliorée hors des limites logiques
water_rate <- mean(df_hh$eau_amelioree == 1, na.rm = TRUE)
if (!is.nan(water_rate) && (water_rate < 0.05 | water_rate > 0.99)) {
  cli::cli_abort("Erreur critique : Le taux d'accès à l'eau potable ({round(water_rate * 100, 2)}%) est en dehors de la plage logique [5% - 99%].")
} else {
  cli::cli_alert_success("Assertion validée : Le taux d'accès à l'eau potable ({round(water_rate * 100, 2)}%) est cohérent.")
}

cli::cli_h1("Toutes les assertions structurelles ont été validées avec succès !")
