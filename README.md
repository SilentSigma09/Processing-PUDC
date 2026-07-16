# Projet Traitement Analyse - Pipeline PUDC

Ce dépôt contient un pipeline de **traitement et d'analyse de données d'enquête**
pour le projet **PUDC** (Programme d'Urgence pour la Croissance et le Développement
des Communes), basé sur des données **Survey Solutions** (fichiers Stata `.dta`).

## Objectif global

Le pipeline transforme des bases brutes d'enquête en **bases propres et analysables**
(ménages + individus) et produit un **rapport de contrôle qualité (QAQC)**. Il calcule
notamment :

- le **score de possession d'actifs** et un **indice de richesse (ACP)** par ménage,
  avec imputation des actifs manquants via **MICE** (méthode logreg) ;
- le **quintile de richesse** par milieu (méthode DHS) ;
- l'**accès à l'eau potable améliorée** (standard JMP) ;
- le **nombre de sources de revenus** ;
- un indicateur de **malnutrition infantile** (MUAC / œdèmes) pour les enfants 6-59 mois.

Le tout est piloté par des **fichiers de configuration** (dictionnaires, mapping,
seuils métier) pour limiter les modifications de code.

## Structure du dépôt

```
Projet_Traitement_Analyse/
├── BASES BRUTES/            # Fichiers .dta Survey Solutions d'origine
└── PUDC_Pipeline/          # Cœur du pipeline
    ├── cleansurvey/        # Scripts R et configuration
    │   ├── run_all.R       # Script maître (orchestration)
    │   ├── config.R        # Chemins, chargement des packages, .libPaths()
    │   ├── utils.R         # Fonctions génériques (dictionnaires, outliers)
    │   ├── dependencies.R  # Installation des packages R (→ renv_lib/)
    │   ├── params.yaml     # Seuils métier, codes manquants, classification JMP
    │   ├── 1_data_exploration/   # Génération + pré-remplissage des dictionnaires
    │   ├── 2_clean_and_merge/     # Nettoyage, indicateurs, fusion, validation
    │   └── 9_qaqc/               # Génération du rapport de qualité
    ├── data/
    │   ├── input/          # Fichiers .dta utilisés par le pipeline
    │   ├── aux_file/       # Dictionnaires, var_mapping.csv
    │   ├── output/         # Bases finales + rapports (Menages.csv, Individus.csv, QAQC_Report.txt)
    │   └── shapefile/      # Fichiers géographiques (GADM Sénégal)
    ├── renv_lib/          # Bibliothèque R locale (packages installés, ignorée par git)
    ├── note_methodologique.md
    └── walkthrough.md      # Détail technique du pipeline
```

## Comment lancer le pipeline

Le pipeline **doit être exécuté depuis le dossier `PUDC_Pipeline/`** (les chemins
sont relatifs : `cleansurvey/...`).

### 1. Installer les packages R (une seule fois)

```powershell
cd PUDC_Pipeline
& "C:\Program Files\R\R-4.3.3\bin\Rscript.exe" cleansurvey/dependencies.R
```

Les packages sont installés dans `PUDC_Pipeline/renv_lib/` (bibliothèque locale du
projet), pas dans la bibliothèque globale de R - `config.R` l'ajoute automatiquement
à `.libPaths()`. Cela évite les conflits quand une autre session R a déjà chargé
certains packages. Le package **mice** (imputation) est notamment installé ici.

### 2. Lancer le pipeline

```powershell
cd PUDC_Pipeline
& "C:\Program Files\R\R-4.3.3\bin\Rscript.exe" cleansurvey/run_all.R
```

Le script maître exécute successivement :
1. Génération des dictionnaires initiaux depuis les `.dta` ;
2. Pré-remplissage et application du mapping (`var_mapping.csv`) ;
3. Nettoyage des bases ménages/individus et calcul des indicateurs ;
4. Fusion, consolidation et validation (assertions QA) ;
5. Génération du rapport QAQC.

### 3. Sorties

- `data/output/Menages.csv` et `data/output/Individus.csv` : bases finales ;
- `data/output/QAQC_Report.txt` : rapport de contrôle qualité (statistiques,
  diagnostic des données manquantes, malnutrition, etc.) ;
- `data/output/PIPELINE_ERROR.txt` : créé uniquement en cas d'échec.

> **Note** : le rendu HTML/Word du rapport QAQC nécessite **pandoc**
> (`pandoc >= 1.12.3`). S'il est absent, le pipeline génère quand même le rapport
> texte et affiche un avertissement non bloquant. Installer pandoc depuis
> https://pandoc.org/install.html pour activer ce rendu.

## Configuration

Tous les seuils métier (âges valides, codes manquants Survey Solutions, classification
JMP de l'eau, seuil MUAC, codes des actifs/revenus) sont centralisés dans
`cleansurvey/params.yaml`. Ajuster ce fichier suffit pour faire évoluer les règles
sans toucher aux scripts.

## Prérequis

- **R 4.3.x** (testé avec R 4.3.3) ;
- accès à CRAN (`https://cloud.r-project.org`) pour l'installation des packages ;
- (optionnel) **pandoc** pour le rendu HTML/Word du rapport QAQC.
