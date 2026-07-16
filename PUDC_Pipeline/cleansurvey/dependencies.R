# Dependances R du pipeline PUDC.
# Utilisation conseillee (depuis la racine PUDC_Pipeline) :
#   Rscript cleansurvey/dependencies.R
# ou, depuis une session R :
#   source("cleansurvey/dependencies.R")
#   install_missing_packages()
#
# Les packages sont installes dans PUDC_Pipeline/renv_lib (bibliotheque
# locale du projet), pas dans la bibliotheque globale de R. Cela evite les
# conflits quand une autre session R a deja charge certains packages.
# config.R ajoute automatiquement cette bibliotheque a .libPaths().
#
# Pour un gel complet de l'environnement, executer ensuite :
#   renv::init()
#   renv::snapshot()

PUDC_PACKAGES <- c(
  "caret",
  "cli",
  "dplyr",
  "DT",
  "ggplot2",
  "haven",
  "here",
  "htmltools",
  "knitr",
  "labelled",
  "mice",
  "MissMech",
  "naniar",
  "pacman",
  "readr",
  "rmarkdown",
  "scales",
  "sf",
  "stringr",
  "tidyr",
  "yaml"
)

# Localise le dossier renv_lib quel que soit le repertoire de travail.
pudc_local_lib <- function() {
  here <- normalizePath(getwd(), winslash = "/")
  cands <- c(
    file.path(here, "renv_lib"),
    file.path(dirname(here), "PUDC_Pipeline", "renv_lib")
  )
  ok <- cands[dir.exists(cands)]
  if (length(ok) > 0) ok[1] else cands[1]
}

install_missing_packages <- function(packages = PUDC_PACKAGES) {
  if (is.null(getOption("repos")) || !is.character(getOption("repos")) ||
      any(grepl("@CRAN@", getOption("repos"), fixed = TRUE))) {
    options(repos = "https://cloud.r-project.org")
  }

  lib <- pudc_local_lib()
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(lib, .libPaths()))

  missing <- packages[!vapply(packages, function(p)
    requireNamespace(p, quietly = TRUE), logical(1))]
  if (length(missing) == 0) {
    message("Toutes les dependances R sont deja installees.")
    return(invisible(TRUE))
  }

  message("Installation de : ", paste(missing, collapse = ", "), " dans ", lib)
  install.packages(missing, lib = lib, type = "both",
                   dependencies = c("Depends", "Imports", "LinkingTo"))
  invisible(TRUE)
}

# Permet d'executer le script directement : Rscript cleansurvey/dependencies.R
if (sys.nframe() == 0 && !interactive()) {
  install_missing_packages()
}

