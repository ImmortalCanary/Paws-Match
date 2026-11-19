-- MatchingAusgabe.sql
-- Ausgabeabfrage auf Basis der bisherigen Drei-Kriterien-Score-Logik.
-- Kein vollständiges Neun-Kriterien-Matching.
-- Voraussetzung: Basis-Views und korrigierte MatchingBegruendungen.sql sind installiert.
-- Beispiel: Interessent 17; für die Tierheim-Sicht den WHERE-Filter
-- durch WHERE m.tier_id = 16 ersetzen.
-- Mindestscore 50 ist nur ein Beispiel für diese Ausgabe.
-- Nur lesend; noch nicht in MySQL getestet.
USE paws_match;

SELECT
    m.tier_id,
    m.interessent_id,
    m.tiername,
    m.pseudonym,
    m.tierstatus,
    m.eignung,
    CASE
        WHEN m.eignung = 'ausgeschlossen' THEN 0
        WHEN m.eignung = 'pruefung_offen' THEN NULL
        ELSE m.match_prozent
    END AS MatchProzent,
    m.datenabdeckung_prozent AS DatenabdeckungProzent,
    CASE
        WHEN m.eignung = 'geeignet'
            THEN 'Die bisher geprüften harten Kriterien sind erfüllt.'
        ELSE b.`begründungen`
    END AS Begruendung,
    CASE
        WHEN m.tierstatus <> 'verfuegbar'
            THEN 'Tier ist aktuell nicht verfügbar'
        WHEN m.eignung = 'ausgeschlossen'
            THEN 'Kein Vorschlag: Ausschlusskriterium'
        WHEN m.eignung = 'pruefung_offen'
            THEN 'Kein Vorschlag: Angaben prüfen'
        WHEN m.match_prozent IS NULL
            THEN 'Kein Vorschlag: Score nicht berechenbar'
        WHEN m.match_prozent < 50
            THEN 'Kein Vorschlag: unter dem Beispiel-Mindestscore'
        ELSE 'Als Vorschlag anzeigen'
    END AS Vorschlagsstatus
FROM v_match_score m
JOIN v_match_begruendungen b
    ON b.tier_id = m.tier_id
   AND b.interessent_id = m.interessent_id
WHERE m.interessent_id = 17
ORDER BY
    CASE
        WHEN m.eignung = 'geeignet'
         AND m.tierstatus = 'verfuegbar'
         AND m.match_prozent >= 50
        THEN 0
        ELSE 1
    END,
    MatchProzent DESC,
    m.tier_id;
