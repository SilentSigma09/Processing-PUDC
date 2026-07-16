# Script de validation et d'assertions du pipeline PUDC
# Garantit que le pipeline s'arrete en cas d'incoherence structurelle ou statistique majeure.


source(file.path("cleansurvey", "config.R"))

cli::cli_h1("Validation des bases et assertions QA")

required_files <- c(
  file.path(OUTPUT_PATH, "Individus.csv"),
  file.path(OUTPUT_PATH, "Menages.csv")
)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  cli::cli_abort(c(
    "Fichiers de sortie manquants.",
    "x" = paste(missing_files, collapse = "\n")
  ))
}

df_ind <- readr::read_csv(file.path(OUTPUT_PATH, "Individus.csv"), show_col_types = FALSE)
df_hh  <- readr::read_csv(file.path(OUTPUT_PATH, "Menages.csv"), show_col_types = FALSE)

assert_columns <- function(df, cols, label) {
  missing_cols <- setdiff(cols, names(df))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "Colonnes requises absentes dans {label}.",
      "x" = paste(missing_cols, collapse = ", ")
    ))
  }
}

assert_rate <- function(rate, low, high, label) {
  if (is.nan(rate) || is.na(rate) || rate < low || rate > high) {
    cli::cli_abort("{label} hors bornes attendues : {round(rate * 100, 2)}% ; bornes [{low * 100}% - {high * 100}%].")
  }
  cli::cli_alert_success("{label} coherent : {round(rate * 100, 2)}%.")
}

# --- 1. Assertions structurelles ---
assert_columns(
  df_hh,
  c("interview__key", "region", "milieu", "eau_amelioree", "nb_pieces",
    "score_actifs", "index_richesse_pca"),
  "Menages.csv"
)
assert_columns(
  df_ind,
  c("interview__key", "sexe", "age", "lien_cm", "enfant_cible", "malnutrition",
    "pb_enfant", "oedeme_enfant"),
  "Individus.csv"
)

if (any(is.na(df_hh$interview__key) | df_hh$interview__key == "")) {
  cli::cli_abort("Erreur critique : interview__key contient des valeurs manquantes dans Menages.csv.")
}
if (any(is.na(df_ind$interview__key) | df_ind$interview__key == "")) {
  cli::cli_abort("Erreur critique : interview__key contient des valeurs manquantes dans Individus.csv.")
}

duplicate_keys <- df_hh %>%
  count(interview__key) %>%
  filter(n > 1)
if (nrow(duplicate_keys) > 0) {
  cli::cli_abort("Erreur critique : interview__key contient des doublons dans Menages.csv.")
}
cli::cli_alert_success("Assertion validee : interview__key est unique dans Menages.csv.")

orphan_ind <- sum(!df_ind$interview__key %in% df_hh$interview__key, na.rm = TRUE)
if (orphan_ind > 0) {
  cli::cli_abort("Erreur critique : {orphan_ind} individu(s) ne sont rattaches a aucun menage.")
}
cli::cli_alert_success("Assertion validee : tous les individus sont rattaches a un menage.")

hh_without_ind <- sum(!df_hh$interview__key %in% df_ind$interview__key, na.rm = TRUE)
if (hh_without_ind > 0) {
  cli::cli_alert_warning("{hh_without_ind} menage(s) n'ont aucun individu dans le roster.")
}

heads_by_hh <- df_ind %>%
  filter(lien_cm == 1) %>%
  count(interview__key, name = "n_heads")
multi_heads <- sum(heads_by_hh$n_heads > 1, na.rm = TRUE)
missing_heads <- sum(!df_hh$interview__key %in% heads_by_hh$interview__key)
if (multi_heads > 0) {
  cli::cli_alert_warning("{multi_heads} menage(s) ont plusieurs chefs de menage declares.")
}
if (missing_heads > 0) {
  cli::cli_alert_warning("{missing_heads} menage(s) n'ont aucun chef de menage declare.")
}

# --- 2. Assertions de modalites et de completude ---
invalid_sex <- sum(!is.na(df_ind$sexe) & !df_ind$sexe %in% c(1, 2))
if (invalid_sex > 0) {
  cli::cli_abort("Erreur critique : {invalid_sex} valeur(s) de sexe hors modalites attendues {1, 2}.")
}
cli::cli_alert_success("Assertion validee : modalites de sexe coherentes.")

invalid_milieu <- sum(!is.na(df_hh$milieu) & !df_hh$milieu %in% c(1, 2))
if (invalid_milieu > 0) {
  cli::cli_abort("Erreur critique : {invalid_milieu} valeur(s) de milieu hors modalites attendues {1, 2}.")
}
cli::cli_alert_success("Assertion validee : modalites de milieu coherentes.")

invalid_age <- sum(!is.na(df_ind$age) & (df_ind$age < PARAMS$age_min | df_ind$age > PARAMS$age_max))
if (invalid_age > 0) {
  cli::cli_abort("Erreur critique : {invalid_age} age(s) hors bornes [{PARAMS$age_min}, {PARAMS$age_max}].")
}
cli::cli_alert_success("Assertion validee : ages dans les bornes metier.")

key_vars_hh <- c("region", "milieu", "eau_amelioree", "score_actifs", "index_richesse_pca")
key_vars_ind <- c("sexe", "age", "lien_cm")
missing_rates <- c(
  sapply(key_vars_hh, function(v) mean(is.na(df_hh[[v]]))),
  sapply(key_vars_ind, function(v) mean(is.na(df_ind[[v]])))
)
high_missing <- missing_rates[missing_rates > 0.50]
if (length(high_missing) > 0) {
  cli::cli_alert_warning("Variables cles avec plus de 50% de valeurs manquantes : {paste(names(high_missing), collapse = ', ')}.")
}

# --- 3. Assertions statistiques et de coherence ---
water_rate <- mean(df_hh$eau_amelioree == 1, na.rm = TRUE)
assert_rate(water_rate, 0.05, 0.99, "Taux d'acces a l'eau potable amelioree")

malnut_rate <- mean(df_ind$malnutrition == 1, na.rm = TRUE)
if (!is.nan(malnut_rate) && malnut_rate > 0.30) {
  cli::cli_abort("Erreur critique : taux de malnutrition anormalement eleve ({round(malnut_rate * 100, 2)}% > 30%). Verifier les codes manquants 000/999.")
}
valid_muac <- sum(!is.na(df_ind$pb_enfant))
if (valid_muac == 0) {
  cli::cli_alert_warning("Alerte methodologique : aucune mesure MUAC valide n'est disponible.")
}

if (all(is.na(df_hh$index_richesse_pca))) {
  cli::cli_abort("Erreur critique : index_richesse_pca est entierement manquant.")
}
if (sd(df_hh$index_richesse_pca, na.rm = TRUE) == 0) {
  cli::cli_abort("Erreur critique : index_richesse_pca n'a aucune variance.")
}
cli::cli_alert_success("Assertion validee : index de richesse ACP exploitable.")

asset_diag <- file.path(OUTPUT_PATH, "qa_asset_diag.csv")
asset_raw <- file.path(OUTPUT_PATH, "qa_actifs_raw.rds")
if (!file.exists(asset_diag) || !file.exists(asset_raw)) {
  cli::cli_alert_warning("Diagnostics d'actifs manquants : qa_asset_diag.csv ou qa_actifs_raw.rds.")
} else {
  cli::cli_alert_success("Diagnostics d'actifs presents pour le rapport QAQC.")
}

cli::cli_h1("Toutes les assertions critiques ont ete validees.")

