-- -----------------------------------------------------------------------------
-- Densité de médecins généralistes des 13 régions métropolitaines
-- On ADDITIONNE les généralistes et les habitants des départements de chaque
-- région, PUIS on divise. Faire la moyenne des densités départementales serait
-- faux : la Lozère pèserait autant que le Nord.
-- Paramètre : :annee
-- -----------------------------------------------------------------------------
SELECT t.code_region,
       r.libelle                                         AS region,
       SUM(m.mg_total)                                   AS mg_total,
       SUM(a.pop_total)                                  AS population,
       100000.0 * SUM(m.mg_total) / SUM(a.pop_total)     AS densite_mg,
       100.0 * SUM(m.mg_60_plus) / SUM(m.mg_total)       AS part_mg_60_plus_pct
FROM territoires t
JOIN medecins        m ON m.code = t.code AND m.annee = :annee
JOIN population_ages a ON a.code = t.code AND a.annee = :annee
JOIN territoires     r ON r.code = t.code_region
WHERE t.niveau = 'departement'
  AND t.code_region <> '97'          -- France métropolitaine
GROUP BY t.code_region, r.libelle
ORDER BY densite_mg DESC;
