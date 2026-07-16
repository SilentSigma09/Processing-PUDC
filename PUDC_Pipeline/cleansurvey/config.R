# Configuration globale du pipeline PUDC.

# Bibliotheque locale du projet (packages installes via install_mice.R /
# cleansurvey/dependencies.R dans PUDC_Pipeline/renv_lib). On l'ajoute en
# tete de .libPaths() pour qu'elle soit trouvee avant la bibliotheque
# utilisateur, sans touched a l'installation globale de R.
candidate_libs <- c(
  file.path(normalizePath(getwd(), winslash = "/"), "renv_lib"),
  file.path(dirname(normalizePath(getwd(), winslash = "/")), "PUDC_Pipeline", "renv_lib")
)
local_lib <- candidate_libs[dir.exists(candidate_libs)]
if (length(local_lib) == 0) {
  local_lib <- candidate_libs[1]
} else {
  local_lib <- local_lib[1]
}
if (dir.exists(local_lib)) {
  .libPaths(c(local_lib, .libPaths()))
}

load_required_packages <- function(packages, auto_install = TRUE) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    if (auto_install) {
      msg <- paste("Packages R manquants :", paste(missing, collapse = ", "),
                   "- installation automatique...")
      if (requireNamespace("cli", quietly = TRUE)) {
        cli::cli_alert_warning(msg)
      } else {
        message(msg)
      }
      repos_opt <- getOption("repos")
      if (is.null(repos_opt) || !is.character(repos_opt) ||
          any(grepl("@CRAN@", repos_opt, fixed = TRUE))) {
        options(repos = "https://cloud.r-project.org")
      }
      utils::install.packages(missing, lib = local_lib,
                               dependencies = c("Depends", "Imports", "LinkingTo"))
      missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
    }
    if (length(missing) > 0) {
      stop(
        "Packages R manquants : ", paste(missing, collapse = ", "),
        ". Installez-les avec cleansurvey/dependencies.R ou restaurez renv.lock.",
        call. = FALSE
      )
    }
  }

  invisible(lapply(packages, function(pkg) {
    suppressPackageStartupMessages(
      library(pkg, character.only = TRUE)
    )
  }))
}

load_required_packages(c("yaml"))

PROJECT_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (basename(PROJECT_ROOT) == "cleansurvey") {
  PROJECT_ROOT <- dirname(PROJECT_ROOT)
}

DATA_PATH      <- file.path(PROJECT_ROOT, "data")
INPUT_PATH     <- file.path(DATA_PATH, "input")
AUX_FILE_PATH  <- file.path(DATA_PATH, "aux_file")
OUTPUT_PATH    <- file.path(DATA_PATH, "output")

CLEAN_SURVEY_PATH <- file.path(PROJECT_ROOT, "cleansurvey")
EXPLORATION_PATH  <- file.path(CLEAN_SURVEY_PATH, "1_data_exploration")
CLEAN_MERGE_PATH  <- file.path(CLEAN_SURVEY_PATH, "2_clean_and_merge")
QAQC_PATH         <- file.path(CLEAN_SURVEY_PATH, "9_qaqc")

PARAMS <- yaml::read_yaml(file.path(CLEAN_SURVEY_PATH, "params.yaml"))

message("Configuration chargee avec succes.")

