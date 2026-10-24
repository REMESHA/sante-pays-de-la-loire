# =============================================================================
# run_all.R - reconstruit tout le projet en une commande
#   Rscript run_all.R
# =============================================================================
# Le fichier DREES complet (70 Mo) n'est pas versionné : l'extrait CSV l'est.
# On ne refait l'extraction que si le fichier complet est présent.
if (file.exists("data-raw/medecins_rpps_2012_2026.xlsx")) {
  source("R/00_extraire_medecins.R")   # fichier DREES -> petit extrait CSV
}
source("R/01_import_insee.R")          # fichiers Insee + extrait DREES -> base SQLite
# Rapport HTML autonome (package quarto si installé, sinon la commande quarto)
if (requireNamespace("quarto", quietly = TRUE)) {
  quarto::quarto_render("rapport/rapport.qmd")
} else {
  system2("quarto", c("render", "rapport/rapport.qmd"))
}
dir.create("docs", showWarnings = FALSE)
invisible(file.copy("rapport/rapport.html", "docs/index.html", overwrite = TRUE))  # GitHub Pages
source("R/02_preparer_deploiement.R")  # copie des fichiers pour shinyapps.io
