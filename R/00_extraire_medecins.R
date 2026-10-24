# =============================================================================
# 00_extraire_medecins.R
# Extraction des effectifs de médecins depuis le fichier DREES
# « La démographie des professionnels de santé - Médecins RPPS 2012-2026 ».
#
# Le fichier complet pèse plus de 70 Mo (300 000 lignes) : trop lourd pour
# GitHub. Ce script en extrait les seules lignes utiles dans un petit CSV,
# versionné avec le projet. Il n'est à relancer que si la DREES publie une
# nouvelle édition.
#
# Entrée  : data-raw/medecins_rpps_2012_2026.xlsx (non versionné, à télécharger
#           sur data.drees.solidarites-sante.gouv.fr)
# Sortie  : data-raw/medecins_rpps_extrait.csv
# =============================================================================

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(stringr)
})

fichier <- "data-raw/medecins_rpps_2012_2026.xlsx"

# -----------------------------------------------------------------------------
# Codes territoriaux : on reproduit le format Insee "REG-DEP" de la base
#   département 044 de la région 52  -> "5244"
#   Corse-du-Sud (02A, région 94)    -> "942A"
#   outre-mer (971...)               -> "971"
#   région                           -> "52"
#   France entière / métropolitaine  -> "FR" / "FM"
# -----------------------------------------------------------------------------
coder_territoire <- function(df) {
  df |>
    mutate(
      reg = substr(region, 1, 2),
      dep = str_trim(substr(departement, 1, 3)),
      code = case_when(
        dep == "999" ~ NA_character_,                        # COM, étranger
        str_detect(dep, "^97") ~ dep,                        # outre-mer
        dep != "000" ~ paste0(reg, substr(dep, 2, 3)),       # métropole
        reg == "00" & str_starts(territoire, "0") ~ "FR",
        reg == "00" & str_starts(territoire, "1") ~ "FM",
        reg %in% c("01", "02", "03", "04", "06", "99") ~ NA_character_,  # régions DROM, COM
        reg == "00" ~ NA_character_,                         # DROM, COM agrégés
        TRUE ~ reg                                           # région métropolitaine
      )
    ) |>
    filter(!is.na(code))
}

# Passage au format long : une ligne par territoire et par année
en_long <- function(df, prefixe) {
  df |>
    pivot_longer(starts_with(prefixe), names_to = "annee", values_to = "valeur") |>
    mutate(annee  = as.integer(str_remove(annee, prefixe)),
           valeur = suppressWarnings(as.numeric(valeur)))  # "ND" et "." -> NA
}

# -----------------------------------------------------------------------------
# 1. Effectifs
# -----------------------------------------------------------------------------
eff <- read_excel(fichier, sheet = "Effectifs", col_types = "text") |>
  select(territoire:sexe, starts_with("effectif_")) |>
  filter(specialites == "00-Ensemble", sexe == "0-Ensemble") |>
  coder_territoire() |>
  en_long("effectif_")

ages_60_plus <- c("08-entre 60 et 64 ans", "09-entre 65 et 69 ans",
                  "10-entre 70 et 74 ans", "11- 75 ans et plus")

effectifs <- eff |>
  summarise(
    # tous médecins, toutes spécialités
    med_total  = sum(valeur[specialites_agregees == "00-Ensemble" &
                            exercice == "0-Ensemble" &
                            tranche_age == "00-Ensemble"]),
    # médecins généralistes, tous modes d'exercice
    mg_total   = sum(valeur[specialites_agregees == "1-Médecine générale" &
                            exercice == "0-Ensemble" &
                            tranche_age == "00-Ensemble"]),
    # généralistes à exercice exclusivement libéral
    mg_liberal = sum(valeur[specialites_agregees == "1-Médecine générale" &
                            exercice == "1-Libéral" &
                            tranche_age == "00-Ensemble"]),
    # généralistes de 60 ans ou plus (départs en retraite à venir)
    mg_60_plus = sum(valeur[specialites_agregees == "1-Médecine générale" &
                            exercice == "0-Ensemble" &
                            tranche_age %in% ages_60_plus]),
    .by = c(code, annee)
  )

# -----------------------------------------------------------------------------
# 2. Densités publiées par la DREES (servent uniquement de contrôle)
# -----------------------------------------------------------------------------
dens <- read_excel(fichier, sheet = "Densités", col_types = "text") |>
  select(territoire:sexe, starts_with("densite_")) |>
  filter(specialites_agregees == "1-Médecine générale",
         specialites == "00-Ensemble", exercice == "0-Ensemble",
         tranche_age == "00-Ensemble", sexe == "0-Ensemble") |>
  coder_territoire() |>
  en_long("densite_") |>
  select(code, annee, mg_densite_drees = valeur)

extrait <- left_join(effectifs, dens, by = c("code", "annee")) |>
  arrange(code, annee)

write.csv(extrait, "data-raw/medecins_rpps_extrait.csv", row.names = FALSE,
          fileEncoding = "UTF-8")

message("Extrait écrit : ", nrow(extrait), " lignes, ",
        n_distinct(extrait$code), " territoires, années ",
        min(extrait$annee), "-", max(extrait$annee))
