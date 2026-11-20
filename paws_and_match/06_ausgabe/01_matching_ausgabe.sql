USE paws_match;
SET NAMES utf8mb4;

SET @interessent_id = 17;
SET @mindestscore = 50.00;

SELECT
    s.tier_id, s.interessent_id, s.tiername, s.pseudonym, s.tierstatus,
    s.eignung, s.match_prozent, s.datenabdeckung_prozent,
    CASE
        WHEN s.eignung = 'geeignet' AND s.tier_verfuegbar = 1
             AND s.interessent_aktiv = 1 AND s.match_prozent >= @mindestscore
            THEN 'Als Vorschlag anzeigen'
        WHEN s.eignung = 'ausgeschlossen' THEN 'Kein Vorschlag: Ausschlusskriterium'
        WHEN s.eignung = 'pruefung_offen' THEN 'Kein Vorschlag: Angaben pruefen'
        WHEN s.tier_verfuegbar = 0 THEN 'Kein Vorschlag: Tier nicht verfuegbar'
        WHEN s.interessent_aktiv = 0 THEN 'Kein Vorschlag: Interessentenprofil inaktiv'
        ELSE 'Kein Vorschlag: Mindestscore nicht erreicht'
    END AS vorschlagsstatus,
    s.ausschlussgruende, s.offene_pruefungen
FROM matching_score s
WHERE s.interessent_id = @interessent_id
ORDER BY
    CASE WHEN s.eignung = 'geeignet' AND s.tier_verfuegbar = 1
              AND s.interessent_aktiv = 1 AND s.match_prozent >= @mindestscore
         THEN 0 ELSE 1 END,
    s.match_prozent DESC,
    s.tier_id;
