-- -----------------------------------------------------------------------------
-- Tableau de synthèse : principaux indicateurs pour une année donnée
-- Départements des Pays de la Loire, région, France entière.
-- Paramètre : :annee (ex. 2024)
-- Le rang national classe les départements de France (1 = valeur la plus
-- élevée pour l'espérance de vie, la plus faible pour la mortalité).
-- -----------------------------------------------------------------------------
WITH base AS (
  SELECT t.code, t.libelle, t.niveau, t.code_region,
         a.pop_total,
         ROUND(100.0 * a.pop_75_plus / a.pop_total, 1) AS part_75_plus_pct,
         m.taux_mortalite_pm,
         m.esp_vie_femmes,
         m.esp_vie_hommes
  FROM territoires t
  JOIN population_ages a ON a.code = t.code AND a.annee = :annee
  JOIN mortalite       m ON m.code = t.code AND m.annee = :annee
),
rangs AS (
  SELECT code,
         RANK() OVER (ORDER BY esp_vie_femmes DESC) AS rang_ev_femmes,
         RANK() OVER (ORDER BY esp_vie_hommes DESC) AS rang_ev_hommes,
         COUNT(*) OVER ()                           AS nb_departements
  FROM base
  WHERE niveau = 'departement'
)
SELECT b.code, b.libelle, b.niveau,
       b.pop_total, b.part_75_plus_pct, b.taux_mortalite_pm,
       b.esp_vie_femmes, b.esp_vie_hommes,
       r.rang_ev_femmes, r.rang_ev_hommes, r.nb_departements
FROM base b
LEFT JOIN rangs r ON r.code = b.code
WHERE b.code_region = '52' OR b.code = 'FR'
ORDER BY CASE b.niveau WHEN 'departement' THEN 1 WHEN 'region' THEN 2 ELSE 3 END,
         b.code;
