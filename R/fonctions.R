# =============================================================================
# fonctions.R - fonctions partagées par le rapport Quarto et l'application Shiny
# =============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(sf)
  library(ggplot2)
})

# Racine du projet : fonctionne depuis la racine, rapport/ ou app/
racine_projet <- function() {
  for (d in c(".", "..", "../..")) {
    if (file.exists(file.path(d, "data", "indicateurs_sante.sqlite"))) {
      return(normalizePath(d))
    }
  }
  stop("Base introuvable : lancer d'abord R/01_import_insee.R")
}

connexion <- function() {
  dbConnect(SQLite(), file.path(racine_projet(), "data",
                                "indicateurs_sante.sqlite"))
}

# Exécute un fichier SQL du dossier sql/ avec des paramètres nommés
# Exemple : requete("01_tableau_synthese.sql", annee = 2024)
requete <- function(fichier, ...) {
  con <- connexion()
  on.exit(dbDisconnect(con))
  sql <- paste(readLines(file.path(racine_projet(), "sql", fichier),
                         encoding = "UTF-8"), collapse = "\n")
  params <- list(...)
  if (length(params) == 0) dbGetQuery(con, sql)
  else dbGetQuery(con, sql, params = params)
}

# Fond de carte des départements (France métropolitaine, version simplifiée)
fond_departements <- function() {
  st_read(file.path(racine_projet(), "data-raw", "departements.geojson"),
          quiet = TRUE) |>
    rename(code_dep = code, nom_dep = nom)
}

departements_pdl <- c("44", "49", "53", "72", "85")

# Thème graphique sobre, commun à toutes les figures
theme_ors <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title       = element_text(face = "bold", colour = "#1F3A5F"),
      plot.subtitle    = element_text(colour = "grey35"),
      plot.caption     = element_text(colour = "grey45", size = rel(0.8),
                                      hjust = 0),
      panel.grid.minor = element_blank(),
      legend.position  = "bottom"
    )
}

source_insee <- paste(
  "Source : Insee, statistiques d'état civil et estimations de population",
  "(Données départementales et régionales, 2026)."
)

source_drees <- paste0(
  "Sources : DREES, répertoire RPPS (démographie des professionnels de santé, 2026) ;\n",
  "Insee, estimations de population."
)

# Palette : départements de la région + repères région / France
couleurs_territoires <- c(
  "Loire-Atlantique" = "#1b9e77", "Maine-et-Loire" = "#d95f02",
  "Mayenne" = "#7570b3", "Sarthe" = "#e7298a", "Vendée" = "#66a61e",
  "Pays de la Loire" = "#1F3A5F", "France" = "grey40"
)
