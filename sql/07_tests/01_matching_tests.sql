USE paws_match;
SET NAMES utf8mb4;
SET SESSION group_concat_max_len = 65535;

SELECT COUNT(*) AS anzahl_gewichte
FROM matching_gewichtung;

SELECT tier_id, interessent_id
FROM matching_kriterien
GROUP BY tier_id, interessent_id
HAVING COUNT(*) <> 9
    OR COUNT(DISTINCT kriterium) <> 9;

SELECT *
FROM matching_kriterien
WHERE passung < 0 OR passung > 1;

SELECT *
FROM matching_score
WHERE (eignung = 'ausgeschlossen' AND (match_prozent IS NULL OR match_prozent <> 0))
   OR (eignung = 'pruefung_offen' AND match_prozent IS NOT NULL)
   OR (eignung = 'geeignet'
       AND gewichtung_vollstaendig = 1
       AND match_prozent IS NULL)
   OR match_prozent < 0
   OR match_prozent > 100
   OR datenabdeckung_prozent < 0
   OR datenabdeckung_prozent > 100;

SELECT *
FROM matching_score
ORDER BY interessent_id, match_prozent DESC, tier_id;

SELECT *
FROM matching_entscheidung
ORDER BY interessent_id, tier_id;
