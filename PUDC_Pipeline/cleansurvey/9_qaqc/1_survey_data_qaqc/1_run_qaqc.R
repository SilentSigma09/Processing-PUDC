# Script pour generer le rapport QAQC apres traitement des bases.


source(file.path("cleansurvey", "config.R"))

cli::cli_h1("Generation du rapport QAQC")

df_ind <- readr::read_csv(file.path(OUTPUT_PATH, "Individus.csv"), show_col_types = FALSE)
df_hh  <- readr::read_csv(file.path(OUTPUT_PATH, "Menages.csv"), show_col_types = FALSE)

pct <- function(x, digits = 2) round(mean(x, na.rm = TRUE) * 100, digits)
safe_mean <- function(x, digits = 2) round(mean(x, na.rm = TRUE), digits)

asset_diag_path <- file.path(OUTPUT_PATH, "qa_asset_diag.csv")
asset_raw_path <- file.path(OUTPUT_PATH, "qa_actifs_raw.rds")
asset_diag <- if (file.exists(asset_diag_path)) readr::read_csv(asset_diag_path, show_col_types = FALSE) else NULL
asset_raw <- if (file.exists(asset_raw_path)) readRDS(asset_raw_path) else NULL

report_path <- file.path(OUTPUT_PATH, "QAQC_Report.txt")
sink(report_path)

cat("=========================================================\n")
cat("             RAPPORT QAQC - PROJET PUDC                 \n")
cat(paste("Date de generation :", Sys.time(), "\n"))
cat("=========================================================\n\n")

cat("--- 1. STATISTIQUES GLOBALES ---\n")
cat(paste("Nombre total de menages observes :", nrow(df_hh), "\n"))
cat(paste("Nombre total d'individus observes :", nrow(df_ind), "\n"))
cat(paste("Taille moyenne du menage :", round(nrow(df_ind) / nrow(df_hh), 2), "personnes\n"))
sans_cm <- sum(is.na(df_hh$cm_age))
cat(paste("Menages sans chef declare dans le roster :", sans_cm, "(", round(sans_cm / nrow(df_hh) * 100, 2), "%)\n"))
hh_without_ind <- sum(!df_hh$interview__key %in% df_ind$interview__key)
cat(paste("Menages sans individu rattache :", hh_without_ind, "\n\n"))

cat("--- 2. STRUCTURE DEMOGRAPHIQUE ---\n")
cat(paste("Proportion de femmes :", pct(df_ind$sexe == 2), "%\n"))
cat(paste("Age moyen des membres :", safe_mean(df_ind$age), "ans\n"))
cat(paste("Proportion d'enfants de moins de 5 ans :", pct(df_ind$age < 5), "%\n\n"))

cat("--- 3. LOGEMENT, SERVICES ET ACTIFS ---\n")
cat(paste("Menages avec acces a une eau potable amelioree (JMP) :", pct(df_hh$eau_amelioree == 1), "%\n"))
cat(paste("Nombre moyen de pieces par menage :", safe_mean(df_hh$nb_pieces), "\n"))
cat(paste("Outliers detectes sur le nombre de pieces :", sum(df_hh$nb_pieces_outlier, na.rm = TRUE), "\n"))
cat(paste("Score moyen de possession d'actifs :", safe_mean(df_hh$score_actifs), "\n"))
if ("index_richesse_pca" %in% names(df_hh)) {
  cat(paste("Index richesse ACP - moyenne :", safe_mean(df_hh$index_richesse_pca),
            "| min :", round(min(df_hh$index_richesse_pca, na.rm = TRUE), 2),
            "| max :", round(max(df_hh$index_richesse_pca, na.rm = TRUE), 2),
            "| ecart-type :", round(sd(df_hh$index_richesse_pca, na.rm = TRUE), 2), "\n"))
}
if ("index_richesse_pca_sd" %in% names(df_hh)) {
  cat(paste("Incertitude moyenne liee a l'imputation MICE :", safe_mean(df_hh$index_richesse_pca_sd), "\n"))
}
cat("\n")

cat("--- 4. DIAGNOSTIC DES DONNEES MANQUANTES ---\n")
if (!is.null(asset_diag)) {
  cat(paste("Menages avec au moins un actif manquant avant imputation :",
            sum(asset_diag$asset_any_na == 1, na.rm = TRUE),
            "(", pct(asset_diag$asset_any_na == 1), "%)\n"))
}
if (!is.null(asset_raw)) {
  asset_missing <- sort(colMeans(is.na(asset_raw)), decreasing = TRUE)
  cat("Variables d'actifs les plus incompletes :\n")
  top_missing <- head(asset_missing, 5)
  for (nm in names(top_missing)) {
    cat(paste(" -", nm, ":", round(top_missing[[nm]] * 100, 2), "% NA\n"))
  }
}
cat("\n")

cat("--- 5. CHOCS ET VULNERABILITE ---\n")
if ("choc_subi" %in% names(df_hh)) {
  cat(paste("Menages declarant au moins un choc :", pct(df_hh$choc_subi == 1), "%\n"))
}
if ("nb_chocs" %in% names(df_hh)) {
  cat(paste("Nombre moyen de chocs subis par menage :", safe_mean(df_hh$nb_chocs), "\n"))
}
cat("\n")

cat("--- 6. MALNUTRITION ---\n")
if ("malnutrition" %in% names(df_ind)) {
  valid_muac <- sum(!is.na(df_ind$pb_enfant))
  cat(paste("Enfants 6-59 mois cibles :", sum(df_ind$enfant_cible, na.rm = TRUE), "\n"))
  cat(paste("Mesures MUAC valides :", valid_muac, "\n"))
  cat(paste("Taux de malnutrition calcule :", pct(df_ind$malnutrition == 1), "%\n"))
  if (valid_muac == 0) {
    cat("Note methodologique : le taux repose sur la declaration d'oedemes ; le MUAC n'a pas ete collecte de facon exploitable.\n")
  }
}

cat("\n--- 7. FICHIERS DE SORTIE ---\n")
output_files <- c("Menages.csv", "Individus.csv", "qa_asset_diag.csv", "qa_actifs_raw.rds")
for (f in output_files) {
  cat(paste(" -", f, ":", ifelse(file.exists(file.path(OUTPUT_PATH, f)), "present", "manquant"), "\n"))
}

cat("\n=========================================================\n")

sink()

cli::cli_alert_success("Rapport QAQC texte genere : {report_path}")
cat(readLines(report_path), sep = "\n")

rmd_path <- file.path(QAQC_PATH, "1_survey_data_qaqc", "QAQC_Report.Rmd")
if (requireNamespace("rmarkdown", quietly = TRUE) && file.exists(rmd_path)) {
  cli::cli_alert_info("Rendu du rapport RMarkdown (HTML puis Word)...")
  tryCatch({
    rmarkdown::render(
      rmd_path,
      output_format = "html_document",
      output_dir = OUTPUT_PATH,
      quiet = TRUE,
      envir = new.env(parent = globalenv())
    )
    rmarkdown::render(
      rmd_path,
      output_format = "word_document",
      output_dir = OUTPUT_PATH,
      quiet = TRUE,
      envir = new.env(parent = globalenv())
    )
  }, error = function(e) {
    cli::cli_alert_warning("Rendu RMarkdown impossible : {e$message}")
  })
}

cli::cli_h1("Fin de la generation QAQC.")

