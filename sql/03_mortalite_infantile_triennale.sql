-- -----------------------------------------------------------------------------
-- Mortalité infantile en moyenne glissante sur 3 ans
-- À l'échelle d'un département, les décès avant 1 an se comptent en dizaines :
-- le taux annuel fluctue beaucoup. On cumule donc décès et naissances sur
-- 3 années (n-2 à n) avant de calculer le taux pour 1 000 naissances.
-- -----------------------------------------------------------------------------
WITH annuel AS (
  SELECT i.code, i.annee, i.deces_moins_1an, n.naissances
  FROM mortalite_infantile i
  JOIN natalite n ON n.code = i.code AND n.annee = i.annee
),
cumul AS (
  SELECT code, annee,
         SUM(deces_moins_1an) OVER w AS deces_3ans,
         SUM(naissances)      OVER w AS naissances_3ans,
         COUNT(*)             OVER w AS nb_annees
  FROM annuel
  WINDOW w AS (PARTITION BY code ORDER BY annee
               ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
)
SELECT t.code, t.libelle, t.niveau,
       (c.annee - 2) || '-' || c.annee         AS periode,
       c.annee                                 AS annee_fin,
       c.deces_3ans, c.naissances_3ans,
       ROUND(1000.0 * c.deces_3ans / c.naissances_3ans, 2) AS taux_pour_1000
FROM cumul c
JOIN territoires t ON t.code = c.code
WHERE c.nb_annees = 3
  AND (t.code_region = '52' OR t.code = 'FR')
  AND c.annee >= :annee_debut
ORDER BY t.code, c.annee;
