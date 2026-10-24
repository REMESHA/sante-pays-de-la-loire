# =============================================================================
# 01_import_insee.R
# Import et mise en forme des fichiers Insee "Données départementales et
# régionales - État civil et estimations de population" (édition 2025/2026),
# puis chargement dans une base SQLite.
#
# Entrée  : data-raw/*.xlsx (un onglet par année, 1975 -> dernière année)
# Sortie  : data/indicateurs_sante.sqlite
#
# Auteur  : Guy Darcy Remesha
# =============================================================================

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(DBI)
  library(RSQLite)
})

dir_raw <- "data-raw"
dir_out <- "data"
dir.create(dir_out, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Outils de lecture
# -----------------------------------------------------------------------------

# Les fichiers Insee ont un en-tête sur plusieurs lignes et des notes en bas de
# page. On lit l'onglet sans en-tête et on garde uniquement les lignes dont la
# 2e colonne est un code territorial valide :
#   - "5244"  : région (52) + département (44)
#   - "52"    : région
#   - "971"   : département d'outre-mer (code à 3 chiffres)
#   - "FM"/"FR" : France métropolitaine / France entière
lire_onglet <- function(fichier, onglet, noms_valeurs) {
  brut <- suppressMessages(
    read_excel(file.path(dir_raw, fichier), sheet = onglet,
               col_names = FALSE, col_types = "text")
  )
  names(brut) <- paste0("c", seq_along(brut))

  brut |>
    mutate(code = str_trim(c2)) |>
    filter(str_detect(code, "^(\\d{2}|97\\d|\\d{2}[0-9AB]{2}|FM|FR)$")) |>
    select(libelle = c1, code, num_range("c", 3:(2 + length(noms_valeurs)))) |>
    set_names(c("libelle", "code", noms_valeurs)) |>
    mutate(
      annee   = as.integer(onglet),
      libelle = str_squish(libelle),
      across(all_of(noms_valeurs), ~ suppressWarnings(as.numeric(.x)))
    )
}

# Onglets "années" uniquement (on ignore les onglets de synthèse)
onglets_annees <- function(fichier) {
  keep(excel_sheets(file.path(dir_raw, fichier)), ~ str_detect(.x, "^\\d{4}$"))
}

lire_fichier <- function(fichier, noms_valeurs) {
  map_dfr(onglets_annees(fichier), ~ lire_onglet(fichier, .x, noms_valeurs))
}

# -----------------------------------------------------------------------------
# 1. Population annuelle et composantes de l'évolution (DEP1)
# -----------------------------------------------------------------------------
pop <- lire_fichier(
  "1_Pop_annu_compo_evol_depreg.xlsx",
  c("pop_1janv", "pop_1janv_suivant", "pop_moyenne", "naissances", "deces",
    "solde_naturel", "variation_totale", "taux_var_naturelle_pm",
    "variation_totale_pct")
)

# -----------------------------------------------------------------------------
# 2. Population au 1er janvier par grands groupes d'âges (DEP2) - ensemble
# -----------------------------------------------------------------------------
ages <- lire_fichier(
  "2_Pop1janv_grands_grages_depreg.xlsx",
  c("pop_total", "pop_0_14", "pop_15_19", "pop_20_59", "pop_60_64",
    "pop_65_74", "pop_75_plus")
)

# -----------------------------------------------------------------------------
# 3. Naissances, natalité, fécondité (DEP3)
# -----------------------------------------------------------------------------
natalite <- lire_fichier(
  "3_Naissances_natalite_fecondite_depreg.xlsx",
  c("naissances", "taux_natalite_pm", "icf", "age_moyen_accouchement")
)

# -----------------------------------------------------------------------------
# 4. Décès, mortalité, espérance de vie (DEP4)
# -----------------------------------------------------------------------------
mortalite <- lire_fichier(
  "4_Deces_mortalite_espvie_depreg.xlsx",
  c("deces", "taux_mortalite_pm", "esp_vie_femmes", "esp_vie_hommes")
)

# -----------------------------------------------------------------------------
# 5. Mortalité infantile (DEP5)
# -----------------------------------------------------------------------------
infantile <- lire_fichier(
  "5_Mortalite_infantile_depreg.xlsx",
  c("deces_moins_1an", "deces_moins_7j", "deces_moins_28j",
    "deces_post_neonatal", "tx_mortalite_infantile", "tx_neonatal_precoce",
    "tx_neonatal", "tx_post_neonatal")
)

# -----------------------------------------------------------------------------
# Référentiel des territoires
# -----------------------------------------------------------------------------
territoires <- bind_rows(pop, ages, natalite, mortalite) |>
  filter(annee >= 2016) |>
  distinct(code, libelle) |>
  group_by(code) |>
  slice(1) |>
  ungroup() |>
  mutate(
    niveau = case_when(
      code == "FR" ~ "france",
      code == "FM" ~ "france_metro",
      nchar(code) == 2 ~ "region",
      str_detect(code, "^97\\d$") ~ "departement",
      TRUE ~ "departement"
    ),
    code_region = if_else(niveau %in% c("region", "departement"),
                          substr(code, 1, 2), NA_character_),
    code_dep = case_when(
      niveau != "departement" ~ NA_character_,
      nchar(code) == 3 ~ code,                 # outre-mer : 971, 972...
      TRUE ~ substr(code, 3, 4)
    ),
    libelle = if_else(code == "FR", "France", libelle)
  )

# -----------------------------------------------------------------------------
# Harmonisation des codes sur les régions actuelles
# Jusqu'en 2014, l'Insee code les départements avec les ANCIENNES régions
# (avant la fusion de 2016) : la Côte-d'Or est "2621" (Bourgogne) en 2012,
# puis "2721" (Bourgogne-Franche-Comté). Sans correction, ces départements ne
# se joignent pas au référentiel pour les années anciennes.
# On recode donc chaque département avec sa région actuelle, et on retire les
# totaux des anciennes régions, qui n'ont plus d'équivalent.
# -----------------------------------------------------------------------------
code_actuel <- territoires |>
  filter(niveau == "departement", nchar(code) == 4) |>
  select(code_dep, code_harmonise = code)

harmoniser <- function(df) {
  df |>
    mutate(code_dep = if_else(nchar(code) == 4, substr(code, 3, 4), NA_character_)) |>
    left_join(code_actuel, by = "code_dep") |>
    mutate(code = coalesce(code_harmonise, code)) |>
    select(-code_dep, -code_harmonise) |>
    filter(code %in% territoires$code)   # retire les anciennes régions
}

pop       <- harmoniser(pop)
ages      <- harmoniser(ages)
natalite  <- harmoniser(natalite)
mortalite <- harmoniser(mortalite)
infantile <- harmoniser(infantile)

# Contrôle : chaque année doit compter le même nombre de départements
nb_dep <- ages |>
  semi_join(filter(territoires, niveau == "departement"), by = "code") |>
  count(annee)
stopifnot(all(nb_dep$n[nb_dep$annee >= 2014] == 101),
          all(nb_dep$n[nb_dep$annee < 2014] == 100))  # Mayotte : estimations dès 2014

# -----------------------------------------------------------------------------
# 6. Médecins (DREES, répertoire RPPS) : extrait préparé par 00_extraire_medecins.R
# -----------------------------------------------------------------------------
medecins <- read.csv(file.path(dir_raw, "medecins_rpps_extrait.csv"),
                     colClasses = c(code = "character"), encoding = "UTF-8") |>
  as_tibble()

# Les années les plus récentes sont provisoires dans les fichiers Insee
derniere_annee <- function(df) max(df$annee)
statut <- tibble(
  table = c("population", "population_ages", "natalite", "mortalite",
            "mortalite_infantile", "medecins"),
  derniere_annee = c(derniere_annee(pop), derniere_annee(ages),
                     derniere_annee(natalite), derniere_annee(mortalite),
                     derniere_annee(infantile), derniere_annee(medecins)),
  remarque = c(rep("dernière année provisoire", 4), "données définitives",
               "effectifs au 1er janvier (RPPS)")
)

# -----------------------------------------------------------------------------
# Écriture dans SQLite
# -----------------------------------------------------------------------------
sans_libelle <- function(df) select(df, -libelle)

fichier_db <- file.path(dir_out, "indicateurs_sante.sqlite")
if (file.exists(fichier_db)) invisible(file.remove(fichier_db))
con <- dbConnect(SQLite(), fichier_db)

dbWriteTable(con, "territoires",         territoires)
dbWriteTable(con, "population",          sans_libelle(pop))
dbWriteTable(con, "population_ages",     sans_libelle(ages))
dbWriteTable(con, "natalite",            sans_libelle(natalite))
dbWriteTable(con, "mortalite",           sans_libelle(mortalite))
dbWriteTable(con, "mortalite_infantile", sans_libelle(infantile))
dbWriteTable(con, "medecins",            medecins)
dbWriteTable(con, "metadonnees",         statut)

# Index pour accélérer les jointures territoire x année
for (t in c("population", "population_ages", "natalite", "mortalite",
            "mortalite_infantile", "medecins")) {
  dbExecute(con, sprintf("CREATE INDEX idx_%s ON %s (code, annee)", t, t))
}

# Contrôles simples de cohérence ----------------------------------------------
controle <- dbGetQuery(con, "
  SELECT p.annee,
         SUM(CASE WHEN t.niveau = 'departement' AND t.code_region = '52'
                  THEN p.pop_1janv END)                 AS somme_departements,
         MAX(CASE WHEN p.code = '52' THEN p.pop_1janv END) AS total_region
  FROM population p
  JOIN territoires t ON t.code = p.code
  WHERE p.annee >= 2020
  GROUP BY p.annee
")
stopifnot(all(controle$somme_departements == controle$total_region))

# Médecins : la somme des départements doit égaler le total régional ----------
controle_med <- dbGetQuery(con, "
  SELECT m.annee,
         SUM(CASE WHEN t.niveau = 'departement' AND t.code_region = '52'
                  THEN m.mg_total END)                     AS somme_departements,
         MAX(CASE WHEN m.code = '52' THEN m.mg_total END)  AS total_region
  FROM medecins m
  JOIN territoires t ON t.code = m.code
  GROUP BY m.annee
")
stopifnot(all(controle_med$somme_departements == controle_med$total_region))

# Médecins : notre densité doit retrouver celle publiée par la DREES ----------
# (effectif au 1er janvier / population Insee au 1er janvier x 100 000)
controle_dens <- dbGetQuery(con, "
  SELECT m.code, m.annee,
         100000.0 * m.mg_total / a.pop_total AS densite_calculee,
         m.mg_densite_drees
  FROM medecins m
  JOIN population_ages a ON a.code = m.code AND a.annee = m.annee
")
ecart_max <- max(abs(controle_dens$densite_calculee -
                     controle_dens$mg_densite_drees) /
                 controle_dens$mg_densite_drees)
message("Densité de généralistes : écart maximal avec la DREES = ",
        round(100 * ecart_max, 2), " %")
if (ecart_max > 0.01) {
  warning("Écart supérieur à 1 % avec les densités DREES : vérifier les populations")
}

message("Base créée : ", fichier_db)
message("Tables : ", paste(dbListTables(con), collapse = ", "))
dbDisconnect(con)
