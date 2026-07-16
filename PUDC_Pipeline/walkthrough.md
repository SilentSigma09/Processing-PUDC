# Walkthrough - Pipeline de traitement PUDC

Ce document resume le fonctionnement du pipeline `cleansurvey/` et les livrables produits dans `data/output/`.

## 1. Execution generale

Le script maitre est `cleansurvey/run_all.R`. Il execute les phases suivantes dans l'ordre :

1. Generation des dictionnaires initiaux depuis les fichiers Stata.
2. Pre-remplissage des dictionnaires et application du mapping.
3. Nettoyage des bases menages et individus.
4. Fusion, consolidation et validation.
5. Generation du rapport QAQC.

En cas d'echec, le pipeline cree `data/output/PIPELINE_ERROR.txt`. Ce fichier est supprime au debut d'une nouvelle execution ; s'il existe apres un run, il correspond donc au run courant.

## 2. Sources et entrees

Les fichiers bruts Survey Solutions sont conserves dans `BASES BRUTES/`. Le pipeline actif travaille sur les copies placees dans :

- `data/input/` : fichiers `.dta`, questionnaire et modules d'enquete.
- `data/aux_file/` : dictionnaires, mapping et fichiers auxiliaires.
- `cleansurvey/params.yaml` : seuils metier, codes manquants, classifications JMP.

Les bases Commune/PUDCCOM existent dans les sources brutes mais ne sont pas encore integrees au pipeline menages-individus actif.

## 3. Traitement metadata-driven

Le pipeline utilise les dictionnaires pour decider quelles variables conserver, renommer et documenter. Le fichier central est :

- `data/aux_file/var_mapping.csv`

Cette approche limite les changements directement dans les scripts R lorsque les noms de variables evoluent.

## 4. Nettoyage et indicateurs

Le script `2_clean_and_merge/1_clean_hh_ind.R` applique les traitements principaux :

- recodage des codes manquants Survey Solutions ;
- nettoyage des ages et variables numeriques ;
- indicateur d'eau potable amelioree selon les codes JMP ;
- detection des outliers du nombre de pieces ;
- calcul du score d'actifs ;
- diagnostic des actifs manquants ;
- imputation MICE des actifs ;
- construction de l'index de richesse par ACP ;
- calcul des quintiles de richesse ;
- indicateur de malnutrition, avec alerte sur l'absence de MUAC exploitable.

## 5. Fusion et validation

Le script `2_clean_and_merge/2_merge_hh_ind.R` produit :

- `data/output/Individus.csv`
- `data/output/Menages.csv`

Il ajoute aussi les caracteristiques du chef de menage et agrege les chocs depuis `S7_INFOS_CHOCS_renamed.csv` quand ce fichier existe.

Le script `2_clean_and_merge/3_validate.R` verifie maintenant :

- presence des colonnes essentielles ;
- unicite de `interview__key` dans `Menages.csv` ;
- rattachement des individus aux menages ;
- menages sans individu ;
- chefs de menage absents ou multiples ;
- modalites de sexe et milieu ;
- bornes d'age ;
- taux d'acces a l'eau potable ;
- taux de malnutrition suspect ;
- existence et variance de l'index ACP ;
- presence des diagnostics d'actifs.

## 6. QAQC et livrables

Le QAQC produit :

- `QAQC_Report.txt`
- `QAQC_Report.html`
- `QAQC_Report.docx`
- `qa_asset_diag.csv`
- `qa_actifs_raw.rds`

Le rapport texte inclut les statistiques globales, la structure demographique, les indicateurs de logement/services, le diagnostic des donnees manquantes, les chocs, la malnutrition et la liste des sorties attendues.

## 7. Volets presents mais non actifs dans le coeur du pipeline

- `data/shapefile/` : utilise par le rapport RMarkdown pour les cartes regionales, pas par le nettoyage principal.
- `BASES BRUTES/.../COMMUNE/PUDCCOM` : source disponible mais non integree aux sorties finales actuelles.

## 8. Dependances

La liste des packages R attendus est documentee dans `cleansurvey/dependencies.R`. Pour figer completement l'environnement, utiliser `renv::init()` puis `renv::snapshot()` depuis `PUDC_Pipeline/`.
