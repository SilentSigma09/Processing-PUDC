# Fichier de configuration globale
# Définition des chemins dynamiques pour le projet PUDC

# On utilise here() pour garantir que les chemins fonctionnent peu importe où le projet est ouvert
if (!require(pacman)) install.packages("pacman")
pacman::p_load(here, yaml)

# Définition des chemins
PROJECT_ROOT <- here::here()

# Dossiers de données
DATA_PATH      <- file.path(PROJECT_ROOT, "data")
INPUT_PATH     <- file.path(DATA_PATH, "input")
AUX_FILE_PATH  <- file.path(DATA_PATH, "aux_file")
OUTPUT_PATH    <- file.path(DATA_PATH, "output")

# Dossiers du pipeline
CLEAN_SURVEY_PATH <- file.path(PROJECT_ROOT, "cleansurvey")
EXPLORATION_PATH  <- file.path(CLEAN_SURVEY_PATH, "1_data_exploration")
CLEAN_MERGE_PATH  <- file.path(CLEAN_SURVEY_PATH, "2_clean_and_merge")
QAQC_PATH         <- file.path(CLEAN_SURVEY_PATH, "9_qaqc")

# Chargement des paramètres métier (Tâche D)
PARAMS <- yaml::read_yaml(file.path(CLEAN_SURVEY_PATH, "params.yaml"))

message("Configuration chargée avec succès.")
