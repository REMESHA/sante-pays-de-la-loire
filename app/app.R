# =============================================================================
# Application Shiny - Indicateurs de santé et de démographie
# Départements des Pays de la Loire (données Insee et DREES)
# Lancement : shiny::runApp("app")
# =============================================================================

library(shiny)
library(bslib)
library(DT)
library(tidyr)
# En local : fonctions du projet ; sur shinyapps.io : copie placée dans app/
source(if (file.exists("fonctions.R")) "fonctions.R" else "../R/fonctions.R",
       local = TRUE)

# ---- Données (chargées une fois au démarrage) --------------------------------
annee_min <- 2010
series    <- requete("06_series_pays_de_la_loire.sql", annee_debut = annee_min)
annees    <- sort(unique(series$annee))
fond      <- fond_departements()

indicateurs <- c(
  "Espérance de vie des femmes (ans)"         = "esp_vie_femmes",
  "Espérance de vie des hommes (ans)"         = "esp_vie_hommes",
  "Part des 75 ans ou plus (%)"               = "part_75_plus_pct",
  "Taux brut de mortalité (‰)"                = "taux_mortalite_pm",
  "Taux brut de natalité (‰)"                 = "taux_natalite_pm",
  "Indicateur conjoncturel de fécondité"      = "icf",
  "Médecins généralistes pour 100 000 hab."   = "densite_mg",
  "Généralistes de 60 ans ou plus (%)"        = "part_mg_60_plus_pct"
)
# Sens de lecture de la palette : TRUE si une valeur élevée est favorable
favorable_si_eleve <- c(esp_vie_femmes = TRUE, esp_vie_hommes = TRUE,
                        part_75_plus_pct = NA, taux_mortalite_pm = FALSE,
                        taux_natalite_pm = NA, icf = NA,
                        densite_mg = TRUE, part_mg_60_plus_pct = FALSE)

# Période couverte par chaque indicateur : les médecins (DREES) commencent en
# 2012 ; pour l'état civil, la dernière année publiée (2025) est provisoire
periode <- function(code) {
  if (code %in% c("densite_mg", "part_mg_60_plus_pct")) c(2012, 2026)
  else c(annee_min, 2024)
}

libelle_indic <- function(code) names(indicateurs)[indicateurs == code]
decimales <- function(code) if (code == "icf") 2 else 1
fmt <- function(x, d = 1) {
  if (length(x) == 0 || all(is.na(x))) return("—")
  formatC(x, format = "f", digits = d, decimal.mark = ",")
}

# ---- Interface ---------------------------------------------------------------
ui <- page_sidebar(
  title = "Santé et démographie — Pays de la Loire",
  theme = bs_theme(version = 5, bootswatch = "cosmo", primary = "#1F3A5F"),
  sidebar = sidebar(
    width = 300,
    selectInput("indic", "Indicateur", choices = indicateurs),
    sliderInput("annee", "Année", min = annee_min, max = 2024,
                value = 2024, step = 1, sep = ""),
    radioButtons("echelle", "Carte",
                 choices = c("Pays de la Loire" = "region",
                             "France métropolitaine" = "france")),
    hr(),
    downloadButton("telecharger", "Télécharger les données (CSV)"),
    tags$small(class = "text-muted mt-3 d-block",
      "Sources : Insee, état civil et estimations de population ;",
      "DREES, répertoire RPPS (médecins).",
      "Taux bruts non standardisés sur l'âge.")
  ),
  layout_columns(
    fill = FALSE,
    value_box("Pays de la Loire", textOutput("vb_region"),
              theme = "primary"),
    value_box("France", textOutput("vb_france"),
              theme = "secondary"),
    value_box("Écart entre départements", textOutput("vb_ecart"),
              textOutput("vb_ecart_detail"), theme = "light")
  ),
  layout_columns(
    col_widths = c(6, 6),
    card(card_header(textOutput("titre_carte")),
         plotOutput("carte", height = "380px")),
    card(card_header(textOutput("titre_courbe")),
         plotOutput("courbe", height = "380px"))
  ),
  card(card_header("Tableau des valeurs"), DTOutput("tableau"))
)

# ---- Serveur -----------------------------------------------------------------
server <- function(input, output, session) {

  annee_choisie <- reactive(input$annee)

  # Le curseur s'adapte à la période de l'indicateur choisi
  observeEvent(input$indic, {
    p <- periode(input$indic)
    updateSliderInput(session, "annee", min = p[1], max = p[2],
                      value = min(max(input$annee, p[1]), p[2]))
  })

  donnees_annee <- reactive({
    filter(series, annee == annee_choisie()) |>
      mutate(valeur = .data[[input$indic]])
  })

  carte_annee <- reactive({
    requete("05_carte_departements.sql", annee = annee_choisie()) |>
      mutate(valeur = .data[[input$indic]])
  })

  output$vb_region <- renderText({
    fmt(filter(donnees_annee(), code == "52")$valeur, decimales(input$indic))
  })
  output$vb_france <- renderText({
    fmt(filter(donnees_annee(), code == "FR")$valeur, decimales(input$indic))
  })
  output$vb_ecart <- renderText({
    d <- filter(donnees_annee(), niveau == "departement", !is.na(valeur))
    if (nrow(d) == 0) return("—")
    fmt(max(d$valeur) - min(d$valeur), decimales(input$indic))
  })

  output$vb_ecart_detail <- renderText({
    d <- filter(donnees_annee(), niveau == "departement", !is.na(valeur))
    if (nrow(d) == 0) return("")
    paste0("de ", d$libelle[which.min(d$valeur)], " (min.) à ",
           d$libelle[which.max(d$valeur)], " (max.)")
  })

  output$titre_courbe <- renderText({
    paste("Évolution depuis", periode(input$indic)[1])
  })

  output$titre_carte <- renderText({
    paste0(libelle_indic(input$indic), " en ", annee_choisie())
  })

  output$carte <- renderPlot({
    geo <- left_join(fond, carte_annee(), by = "code_dep")
    sens <- favorable_si_eleve[[input$indic]]
    direction <- if (isFALSE(sens)) -1 else 1

    if (input$echelle == "region") {
      geo <- filter(geo, code_dep %in% departements_pdl)
      centres <- suppressWarnings(st_point_on_surface(geo))
      xy <- st_coordinates(centres)
      p <- ggplot(geo) +
        geom_sf(aes(fill = valeur), colour = "white", linewidth = 0.7) +
        annotate("label", x = xy[, 1], y = xy[, 2],
                 label = paste0(geo$nom_dep, "\n", fmt(geo$valeur, 1)),
                 size = 3.4, label.size = 0, fill = "white", lineheight = 0.9)
    } else {
      contour_pdl <- st_union(filter(geo, code_dep %in% departements_pdl))
      p <- ggplot(geo) +
        geom_sf(aes(fill = valeur), colour = "white", linewidth = 0.15) +
        geom_sf(data = contour_pdl, fill = NA, colour = "#1F3A5F",
                linewidth = 0.9)
    }
    # Densité de médecins : échelle plafonnée à 220 (Hautes-Alpes, Paris
    # au-delà), sinon deux départements écrasent toutes les nuances
    plafond <- if (input$indic == "densite_mg") c(NA, 220) else NULL
    p +
      scale_fill_distiller(palette = "Blues", direction = direction,
                           name = NULL, limits = plafond,
                           oob = scales::squish) +
      theme_void(base_size = 12) +
      theme(legend.position = "right")
  })

  output$courbe <- renderPlot({
    p <- periode(input$indic)
    d <- mutate(series, valeur = .data[[input$indic]]) |>
      filter(!is.na(valeur), annee >= p[1])
    ggplot(d, aes(annee, valeur, colour = libelle,
                  linewidth = niveau != "departement")) +
      geom_vline(xintercept = annee_choisie(), linetype = "dashed",
                 colour = "grey60") +
      geom_line() +
      scale_colour_manual(values = couleurs_territoires, name = NULL) +
      scale_linewidth_manual(values = c(`FALSE` = 0.6, `TRUE` = 1.3),
                             guide = "none") +
      labs(x = NULL, y = libelle_indic(input$indic),
           caption = if (max(d$annee) > p[2])
             paste(max(d$annee), ": données provisoires") else NULL) +
      theme_ors(base_size = 12) +
      guides(colour = guide_legend(nrow = 2))
  })

  tableau <- reactive({
    donnees_annee() |>
      transmute(Territoire = libelle, `Année` = annee,
                Population = pop_total,
                `Espérance de vie F` = esp_vie_femmes,
                `Espérance de vie H` = esp_vie_hommes,
                `Part 75 ans + (%)` = part_75_plus_pct,
                `Mortalité brute (‰)` = taux_mortalite_pm,
                `Natalité brute (‰)` = taux_natalite_pm,
                ICF = icf,
                `Généralistes /100 000` = densite_mg,
                `Généralistes 60 ans + (%)` = part_mg_60_plus_pct)
  })

  output$tableau <- renderDT({
    datatable(tableau(), rownames = FALSE,
              options = list(dom = "t", pageLength = 10, ordering = FALSE),
              class = "compact stripe") |>
      formatRound("Population", digits = 0, mark = " ") |>
      formatRound(c("Espérance de vie F", "Espérance de vie H",
                    "Mortalité brute (‰)", "Natalité brute (‰)",
                    "Part 75 ans + (%)", "Généralistes /100 000",
                    "Généralistes 60 ans + (%)"), digits = 1, dec.mark = ",") |>
      formatRound("ICF", digits = 2, dec.mark = ",")
  })

  output$telecharger <- downloadHandler(
    filename = function() paste0("indicateurs_pdl_", annee_choisie(), ".csv"),
    content  = function(f) write.csv2(tableau(), f, row.names = FALSE,
                                      fileEncoding = "UTF-8")
  )
}

shinyApp(ui, server)
