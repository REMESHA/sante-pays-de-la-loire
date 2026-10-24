-- -----------------------------------------------------------------------------
-- Médecins généralistes par département pour une année donnée
-- Densités pour 100 000 habitants, rang national, évolution depuis :annee_debut
-- et part des généralistes de 60 ans ou plus.
-- Paramètres : :annee (ex. 2026), :annee_debut (ex. 2012)
-- La densité est recalculée ici (effectif au 1er janvier / population Insee au
-- 1er janvier) ; elle retrouve celle publiée par la DREES (contrôle à l'import).
-- -----------------------------------------------------------------------------
WITH base AS (
  SELECT t.code, t.code_dep, t.libelle, t.niveau, t.code_region,
         m.mg_total,
         100000.0 * m.mg_total   / a.pop_total AS densite_mg,
         100000.0 * m.mg_liberal / a.pop_total AS densite_mg_liberal,
         100000.0 * m.med_total  / a.pop_total AS densite_med,
         100.0 * m.mg_60_plus / m.mg_total     AS part_mg_60_plus_pct,
         100000.0 * m0.mg_total / a0.pop_total AS densite_mg_debut
  FROM territoires t
  JOIN medecins        m  ON m.code  = t.code AND m.annee  = :annee
  JOIN population_ages a  ON a.code  = t.code AND a.annee  = :annee
  LEFT JOIN medecins        m0 ON m0.code = t.code AND m0.annee = :annee_debut
  LEFT JOIN population_ages a0 ON a0.code = t.code AND a0.annee = :annee_debut
),
rangs AS (
  SELECT code,
         RANK() OVER (ORDER BY densite_mg DESC) AS rang_densite_mg,
         COUNT(*) OVER ()                       AS nb_departements
  FROM base
  WHERE niveau = 'departement'
)
SELECT b.*,
       ROUND(100.0 * (b.densite_mg - b.densite_mg_debut) / b.densite_mg_debut, 1)
         AS evolution_densite_pct,
       r.rang_densite_mg, r.nb_departements
FROM base b
LEFT JOIN rangs r ON r.code = b.code
ORDER BY CASE b.niveau WHEN 'departement' THEN 1 WHEN 'region' THEN 2 ELSE 3 END,
         b.code;
