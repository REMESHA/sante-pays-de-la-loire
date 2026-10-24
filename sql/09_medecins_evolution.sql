-- -----------------------------------------------------------------------------
-- Évolution annuelle des médecins généralistes depuis :annee_debut
-- Départements des Pays de la Loire, région, France métropolitaine.
-- La population de chaque territoire est la somme de celle de ses départements :
-- les totaux des régions fusionnées n'existent pas avant 2015 dans les fichiers.
-- -----------------------------------------------------------------------------
WITH pop AS (
  -- un département : sa population ; une région : la somme de ses départements
  SELECT t.code, a.annee, a.pop_total
  FROM population_ages a JOIN territoires t ON t.code = a.code
  WHERE t.niveau IN ('departement', 'france_metro')
  UNION ALL
  SELECT t.code_region AS code, a.annee, SUM(a.pop_total) AS pop_total
  FROM population_ages a JOIN territoires t ON t.code = a.code
  WHERE t.niveau = 'departement'
  GROUP BY t.code_region, a.annee
)
SELECT t.code, t.libelle, t.niveau, m.annee,
       m.mg_total,
       100000.0 * m.mg_total / p.pop_total AS densite_mg,
       100.0 * m.mg_60_plus / m.mg_total   AS part_mg_60_plus_pct
FROM medecins m
JOIN territoires t ON t.code = m.code
JOIN pop         p ON p.code = m.code AND p.annee = m.annee
WHERE (t.code_region = '52' OR t.code = 'FM') AND m.annee >= :annee_debut
ORDER BY t.code, m.annee;
