-- -----------------------------------------------------------------------------
-- Valeurs de tous les indicateurs par département pour une année donnée
-- (alimente les cartes ; la géométrie est jointe dans R via le code département)
-- LEFT JOIN : une année sans décès ou sans médecins publiés garde ses autres
-- indicateurs (les médecins commencent en 2012, la mortalité s'arrête en 2025).
-- -----------------------------------------------------------------------------
SELECT t.code, t.code_dep, t.libelle, t.code_region,
       a.pop_total,
       ROUND(100.0 * a.pop_75_plus / a.pop_total, 2) AS part_75_plus_pct,
       m.taux_mortalite_pm,
       m.esp_vie_femmes,
       m.esp_vie_hommes,
       n.taux_natalite_pm,
       n.icf,
       100000.0 * md.mg_total / a.pop_total      AS densite_mg,
       100.0 * md.mg_60_plus / md.mg_total       AS part_mg_60_plus_pct
FROM territoires t
JOIN population_ages a       ON a.code  = t.code AND a.annee  = :annee
LEFT JOIN mortalite       m  ON m.code  = t.code AND m.annee  = :annee
LEFT JOIN natalite        n  ON n.code  = t.code AND n.annee  = :annee
LEFT JOIN medecins        md ON md.code = t.code AND md.annee = :annee
WHERE t.niveau = 'departement';
