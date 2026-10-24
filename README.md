# Santé et démographie dans les Pays de la Loire

Indicateurs départementaux d'espérance de vie, de mortalité, de vieillissement et d'accès aux médecins généralistes, à partir des données publiques de l'Insee et de la DREES.

Ce projet personnel reproduit une chaîne complète d'observation de la santé, de la donnée brute à la restitution :

**fichiers Insee et DREES (Excel) → import et contrôles sous R → base SQLite → indicateurs calculés en SQL → rapport Quarto automatisé + application Shiny interactive**

- 📄 **Rapport** : https://github.com/REMESHA/sante-pays-de-la-loire/
- 📊 **Application Shiny** : https://remesha.shinyapps.io/sante-pays-de-la-loire/

## Contenu

| Indicateur | Source | Remarque méthodologique |
|---|---|---|
| Espérance de vie à la naissance, par sexe | Insee DEP4 | Indépendante de la structure par âge : indicateur de comparaison privilégié |
| Taux brut de mortalité | Insee DEP4 | Non standardisé : fortement lié à la part des personnes âgées (r ≈ 0,9) |
| Part des 75 ans ou plus | Insee DEP2 | Vieillissement de la population |
| Mortalité infantile | Insee DEP3, DEP5 | Petits effectifs : taux cumulés sur 3 ans avec intervalle de confiance exact (Poisson) |
| Natalité, fécondité | Insee DEP3 | Dans l'application uniquement |
| Densité de médecins généralistes (pour 100 000 hab.) | DREES, RPPS | Recalculée à partir des effectifs et des populations Insee ; comparaisons départements, régions, départements limitrophes |
| Part des généralistes de 60 ans ou plus | DREES, RPPS | Indicateur des départs en retraite à venir |

Territoires : les cinq départements des Pays de la Loire (Loire-Atlantique, Maine-et-Loire, Mayenne, Sarthe, Vendée), la région et la France ; tous les départements pour les cartes nationales, les rangs et les comparaisons.

## Structure

```
├── data-raw/             fichiers sources Insee (.xlsx), extrait DREES (.csv), fond de carte
├── R/
│   ├── 00_extraire_medecins.R    extrait les lignes utiles du fichier DREES (70 Mo) dans un CSV
│   ├── 01_import_insee.R         lecture des fichiers, harmonisation des codes, contrôles, base SQLite
│   ├── 02_preparer_deploiement.R copie des fichiers nécessaires dans app/ pour shinyapps.io
│   └── fonctions.R               connexion, exécution des requêtes SQL, thème graphique
├── sql/                  requêtes SQL documentées (jointures, fonctions de fenêtre)
├── data/                 base SQLite générée
├── rapport/rapport.qmd   rapport Quarto (tableaux, cartes, graphiques, textes calculés)
├── app/app.R             application Shiny (bslib)
├── docs/index.html       rapport publié (GitHub Pages)
└── run_all.R             reconstruit tout le projet
```

## Points techniques

- **Import robuste** : les fichiers Insee comptent un onglet par année (1975-2025) avec des en-têtes sur plusieurs lignes. Le script ne retient que les lignes portant un code territorial valide et harmonise les codes (métropole, Corse, outre-mer).
- **Harmonisation des codes** : jusqu'en 2014, l'Insee code les départements avec les anciennes régions (avant la fusion de 2016). Le script les recode sur les régions actuelles pour que les séries soient continues.
- **Contrôles de cohérence** : somme des départements égale au total régional (population et médecins), nombre de départements constant, densités recalculées identiques à celles publiées par la DREES (écart maximal 0,01 %). Le script s'arrête en cas d'anomalie.
- **SQL** : fonctions de fenêtre (`RANK() OVER`, `SUM() OVER ... ROWS BETWEEN 2 PRECEDING`) pour les rangs nationaux et les cumuls glissants sur 3 ans ; requêtes paramétrées.
- **Rapport automatisé** : tous les chiffres cités dans le texte sont calculés à partir de la base. Une mise à jour des fichiers Insee met à jour le rapport sans retouche manuelle.
- **Statistique** : intervalles de confiance exacts pour les petits effectifs ; mise en garde sur les taux bruts (une standardisation sur l'âge serait nécessaire pour comparer la mortalité).

## Reproduire

Prérequis : R (≥ 4.3), Quarto, et les packages `readxl`, `dplyr`, `tidyr`, `purrr`, `stringr`, `DBI`, `RSQLite`, `sf`, `ggplot2`, `ggrepel`, `knitr`, `shiny`, `bslib`, `DT`.

```r
install.packages(c("readxl", "dplyr", "tidyr", "purrr", "stringr", "DBI",
                   "RSQLite", "sf", "ggplot2", "ggrepel", "knitr",
                   "shiny", "bslib", "DT"))
```

Depuis la racine du projet :

```r
source("run_all.R")      # base, rapport et préparation de l'application
shiny::runApp("app")     # lancer l'application en local
```

## Sources

- Insee, *Données départementales et régionales — État civil et estimations de population* : https://www.insee.fr/fr/statistiques/8999023
- DREES, *La démographie des professionnels de santé depuis 2012* (fichier « Médecins RPPS 2012-2026 ») : https://data.drees.solidarites-sante.gouv.fr/explore/dataset/la-demographie-des-professionnels-de-sante-depuis-2012/ — le fichier complet (plus de 70 Mo) n'est pas versionné ; seul l'extrait `data-raw/medecins_rpps_extrait.csv` l'est. Pour refaire l'extraction, placer le fichier dans `data-raw/` sous le nom `medecins_rpps_2012_2026.xlsx`.
- Fond de carte des départements : [gregoiredavid/france-geojson](https://github.com/gregoiredavid/france-geojson) (d'après IGN / Insee)

La dernière année publiée par l'Insee est provisoire ; le rapport s'arrête à la dernière année disponible pour l'ensemble des indicateurs.

## Auteur

Guy Darcy Remesha — statisticien
[LinkedIn](https://www.linkedin.com/in/guy-darcy-remesha-07a27819a/) · ORCID 0009-0005-1801-3787
