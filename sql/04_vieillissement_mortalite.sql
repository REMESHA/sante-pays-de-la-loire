-- -----------------------------------------------------------------------------
-- Part des 75 ans ou plus et taux brut de mortalité, tous départements
-- Sert à montrer que le taux BRUT de mortalité reflète d'abord la structure
-- par âge de la population : il ne doit pas être comparé tel quel entre
-- territoires (une standardisation sur l'âge serait nécessaire).
-- -----------------------------------------------------------------------------
SELECT t.code, t.code_dep, t.libelle, t.code_region,
       CASE WHEN t.code_region = '52' THEN 'Pays de la Loire'
            ELSE 'Autres départements' END     AS groupe,
       ROUND(100.0 * a.pop_75_plus / a.pop_total, 2) AS part_75_plus_pct,
       m.taux_mortalite_pm
FROM territoires t
JOIN population_ages a ON a.code = t.code AND a.annee = :annee
JOIN mortalite       m ON m.code = t.code AND m.annee = :annee
WHERE t.niveau = 'departement'
  AND t.code_region <> '97'   -- France métropolitaine
;
