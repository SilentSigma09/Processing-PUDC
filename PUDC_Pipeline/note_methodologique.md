# Note methodologique - Pipeline de donnees PUDC

**Projet :** Traitement et analyse des donnees PUDC  
**Perimetre actif :** bases Menages et Individus  
**Derniere mise a jour :** 15 juillet 2026

## 1. Objectif

Le pipeline R `cleansurvey/` automatise la transformation des exports Survey Solutions du PUDC en deux bases analytiques finales :

- `data/output/Menages.csv`
- `data/output/Individus.csv`

Il produit aussi un rapport de controle qualite et des diagnostics intermediaires pour documenter la qualite des donnees.

## 2. Architecture

Le pipeline suit une logique metadata-driven :

- `cleansurvey/run_all.R` orchestre toutes les etapes.
- `cleansurvey/config.R` centralise les chemins.
- `cleansurvey/params.yaml` centralise les seuils, codes manquants et classifications metier.
- `data/aux_file/var_mapping.csv` definit les variables a conserver, renommer et harmoniser.
- `cleansurvey/utils.R` contient les fonctions reutilisables.

Cette structure permet de modifier le mapping ou les parametres sans reecrire le coeur du code R.

## 3. Donnees utilisees

Les donnees brutes sont des exports Survey Solutions au format Stata (`.dta`). Le pipeline actif utilise principalement :

- `PUDC.dta` : base menages ;
- `S1_INFOS_MEMBRES.dta` : roster individus ;
- `S7_INFOS_CHOCS.dta` : chocs, lorsque disponible ;
- les autres modules lorsque le mapping les mobilise.

Les sources Commune/PUDCCOM et les shapefiles sont conservees dans le dossier, mais ne sont pas integrees au coeur du nettoyage menages-individus. Les shapefiles sont toutefois mobilises dans le rapport RMarkdown pour les cartes regionales.

## 4. Nettoyage des valeurs manquantes

Les codes Survey Solutions de non-reponse ou de valeur invalide sont recodes en `NA` a partir de `params.yaml`. Cela concerne notamment les codes tels que `000`, `999`, `##N/A##` et autres codes reserves.

Cette etape est essentielle pour eviter de transformer des codes de non-reponse en valeurs numeriques reelles, par exemple un perimetre brachial `000` interprete comme une mesure valide.

## 5. Indicateurs construits

### Eau potable amelioree

L'indicateur `eau_amelioree` est construit selon les codes definis dans `params.yaml`, en s'inspirant du standard JMP OMS/UNICEF.

### Malnutrition

La cible nutritionnelle est definie sur les enfants de 6 a 59 mois. Le pipeline controle la disponibilite du MUAC (`pb_enfant`). Dans cette base, les mesures MUAC exploitables sont absentes ; l'indicateur de malnutrition repose donc principalement sur la declaration d'oedemes et doit etre interprete avec prudence.

### Richesse et actifs

Le pipeline construit :

- un score simple de possession d'actifs ;
- un diagnostic de completude des actifs ;
- une imputation MICE des actifs manquants ;
- un index de richesse par ACP ;
- des quintiles de richesse par milieu.

Les fichiers `qa_asset_diag.csv` et `qa_actifs_raw.rds` sont conserves pour le QAQC et la tracabilite.

### Chocs

Lorsque `S7_INFOS_CHOCS_renamed.csv` existe, les chocs sont agreges au niveau menage afin de calculer `nb_chocs`.

## 6. Validation automatique

Le script `2_clean_and_merge/3_validate.R` agit comme une barriere de qualite. Il verifie notamment :

- la presence des colonnes essentielles ;
- l'unicite de `interview__key` dans la base menages ;
- le rattachement des individus a un menage ;
- les menages sans roster individu ;
- les chefs de menage absents ou multiples ;
- les modalites attendues de `sexe` et `milieu` ;
- les bornes d'age ;
- le taux d'acces a l'eau potable ;
- un taux de malnutrition anormalement eleve ;
- l'existence et la variance de l'index de richesse ACP ;
- la presence des diagnostics d'actifs.

Les erreurs critiques interrompent le pipeline.

## 7. Rapports et sorties

Les sorties principales sont :

- `Menages.csv`
- `Individus.csv`
- `QAQC_Report.txt`
- `QAQC_Report.html`
- `QAQC_Report.docx`
- `qa_asset_diag.csv`
- `qa_actifs_raw.rds`

Le rapport QAQC decrit les statistiques globales, les variables demographiques, les conditions de logement, les services, les actifs, les chocs, la malnutrition et les fichiers produits.

## 8. Limites

Les principales limites actuelles sont :

- absence de poids d'echantillonnage dans les traitements ;
- MUAC non exploitable ;
- bases Commune/PUDCCOM non integrees aux sorties finales ;
- environnement R pas encore fige par `renv.lock`, meme si les dependances sont documentees dans `cleansurvey/dependencies.R`.

## 9. Recommandations

Pour une version totalement reproductible :

1. Executer le pipeline depuis `PUDC_Pipeline/`.
2. Verifier que `PIPELINE_ERROR.txt` n'existe pas apres l'execution.
3. Initialiser `renv` et enregistrer un `renv.lock`.
4. Completer le mapping si les modules Commune ou shapefiles doivent entrer dans les bases finales.
