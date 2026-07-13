# Script pour générer le rapport QAQC après traitement des bases

if (!require(pacman)) install.packages("pacman")
pacman::p_load(here, dplyr, readr, cli)

# Charger la configuration
source(here::here("cleansurvey", "config.R"))

cli::cli_h1("Génération du Rapport QAQC (Version Texte)")

# Charger les bases finales
df_ind <- readr::read_csv(file.path(OUTPUT_PATH, "Individus.csv"), show_col_types = FALSE)
df_hh  <- readr::read_csv(file.path(OUTPUT_PATH, "Menages.csv"), show_col_types = FALSE)

# Créer un rapport textuel
report_path <- file.path(OUTPUT_PATH, "QAQC_Report.txt")
sink(report_path)

cat("=========================================================\n")
cat("            RAPPORT QAQC - PROJET PUDC (OPTIMISÉ)        \n")
cat(paste("Date de génération :", Sys.time(), "\n"))
cat("=========================================================\n\n")

cat("--- 1. STATISTIQUES GLOBALES ---\n")
cat(paste("Nombre total de ménages observés :", nrow(df_hh), "\n"))
cat(paste("Nombre total d'individus observés :", nrow(df_ind), "\n"))
cat(paste("Taille moyenne du ménage :", round(nrow(df_ind)/nrow(df_hh), 2), "personnes\n"))
sans_cm <- sum(is.na(df_hh$cm_age))
cat(paste("Ménages orphelins (sans Chef de Ménage déclaré dans le roster) :", sans_cm, "(", round(sans_cm/nrow(df_hh)*100, 2), "%)\n\n"))

cat("--- 2. STRUCTURE DEMOGRAPHIQUE DE LA POPULATION ---\n")
femmes_prop <- mean(df_ind$sexe == 2, na.rm = TRUE) * 100
cat(paste("Proportion de femmes :", round(femmes_prop, 2), "%\n"))
cat(paste("Age moyen des membres :", round(mean(df_ind$age, na.rm = TRUE), 2), "ans\n"))
cat(paste("Proportion d'enfants de moins de 5 ans :", round(mean(df_ind$age < 5, na.rm = TRUE) * 100, 2), "%\n\n"))

cat("--- 3. CARACTERISTIQUES DU LOGEMENT ET ACCES AUX SERVICES ---\n")
water_improved <- mean(df_hh$eau_amelioree == 1, na.rm = TRUE) * 100
cat(paste("Ménages avec accès à une eau potable améliorée (Standard JMP) :", round(water_improved, 2), "%\n"))
cat(paste("Nombre moyen de pièces par ménage :", round(mean(df_hh$nb_pieces, na.rm = TRUE), 2), "\n"))
pieces_outliers_count <- sum(df_hh$nb_pieces_outlier, na.rm = TRUE)
cat(paste("Nombre d'outliers détectés sur le nombre de pièces :", pieces_outliers_count, "\n"))
cat(paste("Score moyen de possession d'actifs (0-15, non pondéré) :", round(mean(df_hh$score_actifs, na.rm = TRUE), 2), "\n"))
if("index_richesse_pca" %in% names(df_hh)) {
  pca_min <- min(df_hh$index_richesse_pca, na.rm = TRUE)
  pca_max <- max(df_hh$index_richesse_pca, na.rm = TRUE)
  pca_sd  <- sd(df_hh$index_richesse_pca, na.rm = TRUE)
  cat(paste("Index de richesse (ACP) - Min :", round(pca_min, 2), "| Max :", round(pca_max, 2), "| Ecart-Type :", round(pca_sd, 2), "\n"))
}
cat("\n")

cat("--- 4. CHOCS ET VULNERABILITE ---\n")
chocs_prop <- mean(df_hh$choc_subi == 1, na.rm = TRUE) * 100
cat(paste("Ménages déclarant avoir subi au moins un choc :", round(chocs_prop, 2), "%\n"))
if("nb_chocs" %in% names(df_hh)) {
  cat(paste("Nombre moyen de chocs subis par ménage :", round(mean(df_hh$nb_chocs, na.rm = TRUE), 2), "\n"))
}

if("malnutrition" %in% names(df_ind)) {
  valid_muac <- sum(!is.na(df_ind$pb_enfant))
  malnut_prop <- mean(df_ind$malnutrition == 1, na.rm = TRUE) * 100
  cat(paste("Enfants (6-59 mois) cibles pour la malnutrition :", sum(df_ind$enfant_cible, na.rm = TRUE), "\n"))
  cat(paste("Mesures de Périmètre Brachial (MUAC) réelles/valides :", valid_muac, "\n"))
  cat(paste("Taux de malnutrition aiguë détectée chez les enfants éligibles et mesurés :", round(malnut_prop, 2), "%\n"))
  cat("(Note : Si ce taux est NA ou s'il y a 0 mesure valide, cela indique l'absence de saisie MUAC dans l'enquête)\n")
}
cat("\n=========================================================\n")

sink()

cli::cli_alert_success("Rapport QAQC texte généré avec succès dans : {report_path}")
cat(readLines(report_path), sep = "\n")

# Générer les versions RMarkdown (HTML + Word) si rmarkdown est disponible
rmd_path <- here::here("cleansurvey", "9_qaqc", "1_survey_data_qaqc", "QAQC_Report.Rmd")
if (requireNamespace("rmarkdown", quietly = TRUE) && file.exists(rmd_path)) {
  cli::cli_alert_info("Rendu du rapport RMarkdown (HTML + Word)...")
  tryCatch({
    rmarkdown::render(rmd_path, output_format = "all", output_dir = OUTPUT_PATH,
                      quiet = TRUE, envir = new.env(parent = globalenv()))
  }, error = function(e) { cli::cli_alert_warning("Rendu RMarkdown impossible : {e$message}") })
}

cli::cli_h1("Fin de la génération QAQC.")
