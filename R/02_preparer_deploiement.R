# =============================================================================
# 02_preparer_deploiement.R
# shinyapps.io ne déploie que le dossier app/ : on y copie la base, les requêtes
# SQL, le fond de carte et les fonctions partagées.
# =============================================================================
dir.create("app/data", showWarnings = FALSE)
dir.create("app/data-raw", showWarnings = FALSE)
dir.create("app/sql", showWarnings = FALSE)

invisible(file.copy("data/indicateurs_sante.sqlite", "app/data/", overwrite = TRUE))
invisible(file.copy("data-raw/departements.geojson", "app/data-raw/", overwrite = TRUE))
invisible(file.copy(list.files("sql", full.names = TRUE), "app/sql/", overwrite = TRUE))
invisible(file.copy("R/fonctions.R", "app/fonctions.R", overwrite = TRUE))

message("Dossier app/ prêt pour rsconnect::deployApp(\"app\")")
