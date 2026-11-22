-- Uebersicht fuer ein Profil: alle Tiere mit Eignung, Score und warum es (k)einen Vorschlag gibt.
USE paws_match;
SET NAMES utf8mb4;
SET SESSION group_concat_max_len = 65535;

SET @interessent_id = 17;

SELECT
    s.tier_id, s.interessent_id, s.tiername, s.pseudonym, s.tierstatus,
    s.eignung, s.match_prozent, s.datenabdeckung_prozent,
    CASE
        WHEN v.tier_id IS NOT NULL THEN 'Als Vorschlag anzeigen'
        WHEN s.eignung = 'ausgeschlossen' THEN 'Kein Vorschlag: Ausschlusskriterium'
        WHEN s.eignung = 'pruefung_offen' THEN 'Kein Vorschlag: Angaben pruefen'
        WHEN s.tier_verfuegbar = 0 THEN 'Kein Vorschlag: Tier nicht verfuegbar'
        WHEN s.interessent_aktiv = 0 THEN 'Kein Vorschlag: Interessentenprofil inaktiv'
        WHEN s.gewichtung_vollstaendig = 0 THEN 'Kein Vorschlag: Gewichtung unvollstaendig'
        ELSE 'Kein Vorschlag: Mindestscore nicht erreicht'
    END AS vorschlagsstatus,
    s.ausschlussgruende, s.offene_pruefungen
FROM matching_score s
LEFT JOIN matching_vorschlaege v
    ON v.tier_id = s.tier_id AND v.interessent_id = s.interessent_id
WHERE s.interessent_id = @interessent_id
ORDER BY
    CASE WHEN v.tier_id IS NOT NULL THEN 0 ELSE 1 END,
    s.match_prozent DESC,
    s.tier_id;
