USE paws_match;
SET NAMES utf8mb4;
SET SESSION group_concat_max_len = 65535;

CREATE TABLE matching_gewichtung (
    kriterium ENUM('Tierart', 'Aktivitaet', 'Zeit', 'Wohnsituation', 'Erfahrung',
                   'Vertraeglichkeit', 'Budget', 'Charakter', 'Naehe') PRIMARY KEY,
    gewicht DECIMAL(6,2) NOT NULL,
    CONSTRAINT ck_matching_gewicht CHECK (gewicht > 0)
) ENGINE = InnoDB;

INSERT INTO matching_gewichtung (kriterium, gewicht) VALUES
    ('Tierart', 20), ('Aktivitaet', 15), ('Zeit', 15), ('Wohnsituation', 15),
    ('Erfahrung', 10), ('Vertraeglichkeit', 10), ('Budget', 5),
    ('Charakter', 5), ('Naehe', 5);

CREATE VIEW matching_kriterien AS
WITH basis AS (
    SELECT
        d.tier_id, d.interessent_id,
        CASE WHEN d.eignung = 'geeignet' THEN 1.0 ELSE NULL END AS mindest_passung,
        CASE WHEN t.aktivitaet BETWEEN 1 AND 5 AND i.aktivitaet BETWEEN 1 AND 5
             THEN 1.0 - ABS(t.aktivitaet - i.aktivitaet) / 4.0 ELSE NULL END AS aktivitaet_passung,
        CASE WHEN EXISTS(SELECT 1 FROM interessent_charakter ic WHERE ic.interessent_id = i.id)
              AND EXISTS(SELECT 1 FROM tier_charakter tc WHERE tc.tier_id = t.id)
             THEN (SELECT COUNT(*) FROM interessent_charakter ic
                   JOIN tier_charakter tc ON tc.charakter_id = ic.charakter_id
                   WHERE ic.interessent_id = i.id AND tc.tier_id = t.id) * 1.0
                  / NULLIF((SELECT COUNT(*) FROM interessent_charakter ic WHERE ic.interessent_id = i.id), 0)
             ELSE NULL END AS charakter_passung,
        CASE WHEN EXISTS(SELECT 1 FROM interessent_standort isp WHERE isp.interessent_id = i.id AND isp.standort_id = t.standort_id)
             THEN 1.0
             WHEN NULLIF(TRIM(i.bezirk), '') IS NOT NULL AND NULLIF(TRIM(s.bezirk), '') IS NOT NULL
             THEN CASE WHEN i.bezirk = s.bezirk THEN 1.0 ELSE 0.0 END
             WHEN EXISTS(SELECT 1 FROM interessent_standort isp WHERE isp.interessent_id = i.id)
             THEN 0.0 ELSE NULL END AS naehe_passung
    FROM matching_entscheidung d
    JOIN tier t ON t.id = d.tier_id
    JOIN interessent i ON i.id = d.interessent_id
    JOIN standort s ON s.id = t.standort_id
)
SELECT tier_id, interessent_id, 'Tierart' AS kriterium, mindest_passung AS passung FROM basis
UNION ALL SELECT tier_id, interessent_id, 'Aktivitaet', aktivitaet_passung FROM basis
UNION ALL SELECT tier_id, interessent_id, 'Zeit', mindest_passung FROM basis
UNION ALL SELECT tier_id, interessent_id, 'Wohnsituation', mindest_passung FROM basis
UNION ALL SELECT tier_id, interessent_id, 'Erfahrung', mindest_passung FROM basis
UNION ALL SELECT tier_id, interessent_id, 'Vertraeglichkeit', mindest_passung FROM basis
UNION ALL SELECT tier_id, interessent_id, 'Budget', mindest_passung FROM basis
UNION ALL SELECT tier_id, interessent_id, 'Charakter', charakter_passung FROM basis
UNION ALL SELECT tier_id, interessent_id, 'Naehe', naehe_passung FROM basis;

CREATE VIEW matching_score AS
WITH gewichtung AS (
    SELECT COUNT(*) AS anzahl_gewichte, SUM(gewicht) AS gesamtgewicht
    FROM matching_gewichtung
), punkte AS (
    SELECT k.tier_id, k.interessent_id,
           SUM(CASE WHEN k.passung IS NOT NULL THEN k.passung * g.gewicht ELSE 0 END) AS punkte,
           SUM(CASE WHEN k.passung IS NOT NULL THEN g.gewicht ELSE 0 END) AS erfasstes_gewicht
    FROM matching_kriterien k
    LEFT JOIN matching_gewichtung g ON g.kriterium = k.kriterium
    GROUP BY k.tier_id, k.interessent_id
), basispunkte AS (
    SELECT p.tier_id, p.interessent_id, p.punkte, p.erfasstes_gewicht,
           70.0 + p.punkte AS skalierte_punkte
    FROM punkte p
)
SELECT
    d.tier_id, d.interessent_id, d.tiername, d.pseudonym, d.tierstatus,
    d.tier_verfuegbar, d.interessent_aktiv, d.eignung, d.ausschlussgruende,
    d.offene_pruefungen,
    (g.anzahl_gewichte = 9 AND g.gesamtgewicht > 0) AS gewichtung_vollstaendig,
    CASE WHEN d.eignung = 'ausgeschlossen' THEN 0
         WHEN d.eignung = 'pruefung_offen' THEN NULL
         WHEN g.anzahl_gewichte <> 9 OR g.gesamtgewicht IS NULL OR g.gesamtgewicht <= 0 THEN NULL
         ELSE ROUND(100.0 * b.skalierte_punkte / (70.0 + g.gesamtgewicht), 1) END AS match_prozent,
    CASE WHEN d.eignung = 'geeignet' AND g.anzahl_gewichte = 9 AND g.gesamtgewicht > 0
         THEN ROUND(100.0 * b.erfasstes_gewicht / g.gesamtgewicht, 1)
         ELSE NULL END AS datenabdeckung_prozent
FROM matching_entscheidung d
JOIN basispunkte b ON b.tier_id = d.tier_id AND b.interessent_id = d.interessent_id
CROSS JOIN gewichtung g;
