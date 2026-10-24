-- -----------------------------------------------------------------------------
-- Évolution de l'espérance de vie à la naissance, par sexe
-- Départements des Pays de la Loire, région et France, depuis :annee_debut.
-- Format long (une ligne par territoire, année et sexe) pour les graphiques.
-- -----------------------------------------------------------------------------
SELECT * FROM (
SELECT t.code, t.libelle, t.niveau, m.annee,
       'Femmes' AS sexe, m.esp_vie_femmes AS esperance_vie
FROM mortalite m
JOIN territoires t ON t.code = m.code
WHERE (t.code_region = '52' OR t.code = 'FR') AND m.annee >= :annee_debut
UNION ALL
SELECT t.code, t.libelle, t.niveau, m.annee,
       'Hommes' AS sexe, m.esp_vie_hommes AS esperance_vie
FROM mortalite m
JOIN territoires t ON t.code = m.code
WHERE (t.code_region = '52' OR t.code = 'FR') AND m.annee >= :annee_debut
)
ORDER BY code, sexe, annee;
