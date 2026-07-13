# Note Méthodologique — Pipeline de Données PUDC

**Auteur :** Groupe de Projet (ENSAE Paris)  
**Date :** 13 juillet 2026  
**Version du Pipeline :** v1.2 (Optimisée, Metadata-Driven & Validée)

---

## 1. Contexte et Source des Données
Cette note méthodologique documente le traitement de la base de données de l'enquête du **Programme d'Urgence de Développement Communautaire (PUDC)** au Sénégal (milieu rural). 
La base brute est issue d'une collecte réalisée sous l'outil **Survey Solutions**, exportée sous le format Stata (`PUDC_6_STATA_ApprovedByHeadquarters`). Elle est constituée de deux modules principaux représentant :
*   **1 686 ménages** observés (base `PUDC.dta`).
*   **14 609 membres/individus** (base `S1_INFOS_MEMBRES.dta`).

L'objectif du pipeline R (`cleansurvey/`) est d'automatiser le renommage, le nettoyage des non-réponses, le recodage des indicateurs clés (accès à l'eau, statut nutritionnel, indice de richesse), la fusion robuste des tables, et le contrôle qualité des fichiers finaux.

---

## 2. Architecture Technique et Reproductibilité

Le pipeline adopte une approche **metadata-driven** basée sur une configuration externe. Cela évite d'éditer le code R lors des changements de rounds d'enquête ou d'évolution des normes :
*   **Dictionnaires et Mapping externe** : Les sélections et renommages des variables cibles sont entièrement déclarés dans le fichier [var_mapping.csv](file:///c:/Users/USER/Documents/ENSAE/ISE3/traitements%20des%20donn%C3%A9es%20statistiques/Projet_Traitement_Analyse/PUDC_Pipeline/data/aux_file/var_mapping.csv). Le pipeline s'y réfère dynamiquement pour harmoniser et renommer les tables.
*   **Paramètres centralisés** : Les constantes, les codes de valeurs manquantes, et les classifications métier sont stockés dans le fichier de configuration [params.yaml](file:///c:/Users/USER/Documents/ENSAE/ISE3/traitements%20des%20donn%C3%A9es%20statistiques/Projet_Traitement_Analyse/PUDC_Pipeline/cleansurvey/params.yaml).
*   **Protocole de reproduction (un clic)** : Pour reproduire intégralement et de zéro le pipeline, il suffit d'exécuter le script maître [run_all.R](file:///c:/Users/USER/Documents/ENSAE/ISE3/traitements%20des%20donn%C3%A9es%20statistiques/Projet_Traitement_Analyse/PUDC_Pipeline/cleansurvey/run_all.R). Ce script orchestre la génération et le pré-remplissage des dictionnaires de variables, l'application des mappings, le nettoyage des fichiers bruts, la fusion, et le contrôle d'assertions de qualité.

---

## 3. Conventions de Codage de la Base
Pour faciliter l'exploitation ultérieure des tables finales [Individus.csv](file:///c:/Users/USER/Documents/ENSAE/ISE3/traitements%20des%20donn%C3%A9es%20statistiques/Projet_Traitement_Analyse/PUDC_Pipeline/data/output/Individus.csv) et [Menages.csv](file:///c:/Users/USER/Documents/ENSAE/ISE3/traitements%20des%20donn%C3%A9es%20statistiques/Projet_Traitement_Analyse/PUDC_Pipeline/data/output/Menages.csv), les conventions suivantes sont appliquées :
*   **Clé de jointure unique** : `interview__key` identifie le ménage de manière unique dans les deux bases.
*   **Chef de Ménage (CM)** : Identifié au niveau individuel par `lien_cm == 1` dans le roster des membres.
*   **Genre de l'individu** : Variable `sexe` codée en binaire (`1 = Masculin`, `2 = Féminin`).
*   **Milieu de résidence** : Variable `milieu` codée en binaire (`1 = Rural`, `2 = Urbain`).
*   **Cible nutritionnelle (MUAC)** : La cible officielle d'évaluation du Périmètre Brachial est restreinte aux enfants âgés de **6 à 59 mois**.

---

## 4. Choix Méthodologiques de Traitement des Données

### A. Gestion des Non-Réponses Survey Solutions
Les codes par défaut de non-réponse de l'outil de collecte (`"000"`, `"999"`, `"##N/A##"`, etc.) ont été interceptés et recodés en valeurs manquantes standard (`NA`). Cette étape évite les biais de calcul (ex: traiter un code `"000"` comme une mesure de 0 mm pour un enfant).

### B. Indicateur d'Accès à l'Eau Potable (Standard JMP UNICEF/OMS)
Conformément aux directives du *Joint Monitoring Programme* (JMP) de l'UNICEF et de l'OMS :
*   **Inclusion** des sources dites améliorées : Robinets (intérieurs, publics, voisins), puits protégés, ainsi que les forages motorisés et à pompe manuelle (très fréquents au Sénégal rural).
*   **Exclusion** des eaux en bouteille (code `9`) et des vendeurs d'eau (code `10`) par manque d'information sur la qualité de leur source secondaire. 
*   *Note de robustesse* : Ces codes exclus (9 et 10) comptent 0 observation dans cette base de données, le taux d'accès s'établit de manière exacte et vérifiée à **47,27 %** (797 ménages desservis sur 1 686).

### C. Construction du Wealth Index par ACP (Méthodologie DHS)
En complément du score d'actifs linéaire et non pondéré (`score_actifs` allant de 0 à 15), un **Index de Richesse par Analyse en Composantes Principales (ACP)** a été calculé (colonne `index_richesse_pca`) conformément aux méthodologies des *Demographic and Health Surveys* (DHS) :
*   L'indice est extrait sur la première composante principale de la matrice de possession de 15 biens d'équipements. 
*   Il présente une forte corrélation positive avec le score d'actifs linéaire ($r = 0,88$).
*   L'axe factoriel est mathématiquement centré (moyenne égale à 0) avec une distribution s'étendant de $-1,3$ à $11,92$ ($\sigma = 1,56$).
*   Les 87 ménages sans données d'actifs ont été imputés à 0 (owns = 0) par défaut afin d'assurer le calcul de l'ACP pour toute la base.

### D. Contrôle des Valeurs Aberrantes (Outliers)
*   **Nombre de pièces** : La détection statistique par écart interquartile (IQR) a mis en évidence **61 ménages atypiques** possédant entre 11 et 22 pièces (pouvant être des concessions familiales ou des erreurs de saisie). Ces enregistrements sont conservés dans la base mais flaggués dans la colonne `nb_pieces_outlier`.
*   **Âge** : Aucun filtre IQR n'a été appliqué sur l'âge pour éviter de faux positifs sur les personnes âgées valides (76 à 95 ans). Seule la borne métier logique (`age > 120` ans) est utilisée pour invalider une saisie.

---

## 5. Contrôle Qualité Automatisé (QA Assertions Gate)
Le script [3_validate.R](file:///c:/Users/USER/Documents/ENSAE/ISE3/traitements%20des%20donn%C3%A9es%20statistiques/Projet_Traitement_Analyse/PUDC_Pipeline/cleansurvey/2_clean_and_merge/3_validate.R) agit comme une barrière de validation automatique. Le pipeline est stoppé (`stop`) si l'une des assertions de cohérence structurelle échoue :
*   **Unicité** de l'identifiant ménage `interview__key` dans la base Ménages.
*   **Intégrité référentielle** : Tous les individus de la base Roster doivent être rattachés à un ménage existant.
*   **Plages logiques** : Le taux d'accès à l'eau potable améliorée doit être compris dans l'intervalle `[5% - 99%]`.
*   **Garde anti-bug sur la malnutrition** : Si le taux de malnutrition aiguë calculé dépasse le seuil critique de 30 %, le pipeline avorte automatiquement (ce qui évite de propager en production le biais de codage `"000" -> 0` initialement présent).

---

## 6. Limites et Qualité des Données
Lors des analyses secondaires ou de la restitution orale, les réserves suivantes doivent être prises en compte :
1.  **Absence de saisie MUAC (Périmètre Brachial)** : Aucune mesure physique de MUAC n'est renseignée dans la base d'origine (100 % de valeurs manquantes `"000"`/`"999"`). Le taux de malnutrition calculé de **1,75 %** (30 cas sur 1 721 enfants de 6 à 59 mois) repose uniquement sur la déclaration d'œdèmes et n'est pas assimilable à une mesure GAM/SAM globale.
2.  **Imputation de l'ACP** : L'imputation par `0` des actifs manquants pour 87 ménages induit un biais en les classant artificiellement au bas de l'index de richesse.
3.  **Problèmes d'intégrité de l'enquête** :
    *   **91 ménages orphelins** (5,4 % de l'échantillon) ne disposent d'aucun chef de ménage déclaré dans le roster des membres.
    *   **88 ménages** présents dans la base `PUDC` ne possèdent aucun individu répertorié dans le roster des membres (`S1_INFOS_MEMBRES`).
