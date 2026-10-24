-- -----------------------------------------------------------------------------
-- Séries annuelles de tous les indicateurs : départements des Pays de la Loire,
-- région et France, depuis :annee_debut (alimente les courbes de l'application)
-- La table de population sert de base (elle couvre toutes les années) ; les
-- autres indicateurs sont joints avec LEFT JOIN et valent NULL hors de leur
-- période de publication.
-- -----------------------------------------------------------------------------
SELECT t.code, t.libelle, t.niveau, a.annee,
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
JOIN population_ages a       ON a.code  = t.code
LEFT JOIN mortalite       m  ON m.code  = t.code AND m.annee  = a.annee
LEFT JOIN natalite        n  ON n.code  = t.code AND n.annee  = a.annee
LEFT JOIN medecins        md ON md.code = t.code AND md.annee = a.annee
WHERE (t.code_region = '52' OR t.code = 'FR') AND a.annee >= :annee_debut
ORDER BY t.code, a.annee;
