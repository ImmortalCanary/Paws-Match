USE paws_match;
SET NAMES utf8mb4;

-- Einzige Quelle fuer Vorschlagsregeln; Prozeduren und Ausgabe lesen nur hieraus.
CREATE OR REPLACE VIEW matching_vorschlaege AS
SELECT
    s.tier_id,
    s.interessent_id,
    s.tiername,
    ta.name AS tierart,
    st.id AS standort_id,
    st.name AS standort,
    sb.name AS standort_bezirk,
    s.pseudonym,
    ib.name AS interessenten_bezirk,
    s.eignung,
    s.tierstatus,
    s.match_prozent,
    s.datenabdeckung_prozent,
    'Alle harten Kriterien erfuellt; Score aus den gewichteten Teilpassungen.' AS begruendung
FROM matching_score s
JOIN tier t ON t.id = s.tier_id
JOIN tierart ta ON ta.id = t.tierart_id
JOIN standort st ON st.id = t.standort_id
JOIN bezirk sb ON sb.id = st.bezirk_id
JOIN interessent i ON i.id = s.interessent_id
LEFT JOIN bezirk ib ON ib.id = i.bezirk_id
WHERE s.eignung = 'geeignet'
  AND s.tierstatus = 'verfuegbar'
  AND s.interessent_aktiv = 1
  AND s.gewichtung_vollstaendig = 1
  AND s.match_prozent >= 50.0;
