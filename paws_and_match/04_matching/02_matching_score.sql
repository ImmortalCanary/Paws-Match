-- Stufe 2: Gewichtung und Score fuer die geeigneten Paare.
USE paws_match;
SET NAMES utf8mb4;
SET SESSION group_concat_max_len = 65535;

-- Katalog der Score-Kategorien. Dadurch steht die Anzahl nicht mehr als Zahl im Code.
CREATE TABLE matching_kategorie (
    name VARCHAR(30) PRIMARY KEY,
    beschreibung VARCHAR(200) NOT NULL
) ENGINE = InnoDB;

INSERT INTO matching_kategorie (name, beschreibung) VALUES
    ('Tierart', 'Tierartwunsch, Wunschgroesse und Wunschalter'),
    ('Aktivitaet', 'Abstand zwischen den Aktivitaetsstufen'),
    ('Zeit', 'Reserve bei Betreuungszeit und Alleinzeit'),
    ('Wohnsituation', 'Reserve bei der Wohnflaeche'),
    ('Erfahrung', 'Erfahrung mit der Tierart ueber dem Minimum'),
    ('Vertraeglichkeit', 'Kinder, Hunde, Katzen und Kleintiere'),
    ('Gesundheit', 'Belastende Gesundheitsmerkmale gegen die Bereitschaft zur Versorgung'),
    ('Alltagsrhythmus', 'Alleinzeit des Tieres gegen die Anwesenheit laut Arbeitsmodell'),
    ('Budget', 'Reserve beim Budget'),
    ('Charakter', 'Anteil der gewuenschten Charakterzuege'),
    ('Naehe', 'Wunschstandort oder gleicher Bezirk');

CREATE TABLE matching_gewichtung (
    kriterium VARCHAR(30) PRIMARY KEY,
    gewicht DECIMAL(6,2) NOT NULL,
    CONSTRAINT fk_matching_gewichtung_kategorie FOREIGN KEY (kriterium) REFERENCES matching_kategorie(name),
    CONSTRAINT ck_matching_gewicht CHECK (gewicht > 0)
) ENGINE = InnoDB;

INSERT INTO matching_gewichtung (kriterium, gewicht) VALUES
    ('Tierart', 20), ('Aktivitaet', 13), ('Zeit', 13), ('Wohnsituation', 13),
    ('Erfahrung', 9), ('Vertraeglichkeit', 9), ('Gesundheit', 7),
    ('Alltagsrhythmus', 5), ('Budget', 4), ('Charakter', 4), ('Naehe', 3);

-- Jede Kategorie bekommt einen Wert zwischen 0 und 1, oder NULL wenn Daten fehlen.
-- Mindestanforderung genau erfuellt = 0,5, doppelt so viel wie noetig = 1,0.
CREATE OR REPLACE VIEW matching_kriterien AS
WITH basis AS (
    SELECT
        t.id AS tier_id,
        i.id AS interessent_id,
        EXISTS(SELECT 1 FROM interessent_tierart it
               WHERE it.interessent_id = i.id AND it.tierart_id = t.tierart_id) AS tierart_passt,
        (SELECT MIN(ABS(g.rang - tg.rang))
         FROM interessent_groesse ig
         JOIN tier_groesse g ON g.id = ig.groesse_id
         WHERE ig.interessent_id = i.id) AS groessen_abstand,
        TIMESTAMPDIFF(MONTH, t.geburtsdatum, CURDATE()) / 12 AS tier_alter,
        i.wunschalter_min, i.wunschalter_max,
        t.aktivitaet AS tier_aktivitaet, i.aktivitaet AS interessent_aktivitaet,
        i.zeit_stunden, t.min_zeit, i.allein_stunden, t.max_allein,
        i.wohnflaeche, t.min_wohnflaeche,
        e.erfahrungslevel, t.min_erfahrung,
        t.kinder_ok, i.kinder, t.hund_ok, i.hund_vorhanden,
        t.katze_ok, i.katze_vorhanden, t.kleintiere_ok, i.kleintiere_vorhanden,
        i.budget, t.monatskosten,
        -- Nur bestaetigte und belastende Merkmale bedeuten echten Mehraufwand.
        (SELECT COUNT(*) FROM tier_gesundheit tgs
         JOIN gesundheitsmerkmal gm ON gm.id = tgs.gesundheitsmerkmal_id
         WHERE tgs.tier_id = t.id AND tgs.bestaetigt = 1 AND gm.belastend = 1) AS gesundheitslasten,
        i.medizin_bereit, i.tierarzt_bereit,
        am.anwesenheit,
        (SELECT COUNT(*) FROM interessent_charakter ic WHERE ic.interessent_id = i.id) AS charakter_wuensche,
        (SELECT COUNT(*) FROM tier_charakter tc WHERE tc.tier_id = t.id) AS tier_charaktere,
        (SELECT COUNT(*) FROM interessent_charakter ic
         JOIN tier_charakter tc ON tc.charakter_id = ic.charakter_id
         WHERE ic.interessent_id = i.id AND tc.tier_id = t.id) AS charakter_treffer,
        EXISTS(SELECT 1 FROM interessent_standort isp
               WHERE isp.interessent_id = i.id AND isp.standort_id = t.standort_id) AS wunschstandort,
        EXISTS(SELECT 1 FROM interessent_standort isp WHERE isp.interessent_id = i.id) AS standortwunsch_erfasst,
        i.bezirk_id AS interessent_bezirk,
        s.bezirk_id AS standort_bezirk,
     i.max_entfernung_km,
     fn_entfernung_km(ib.breitengrad, ib.laengengrad,
                 COALESCE(s.breitengrad, sb.breitengrad), COALESCE(s.laengengrad, sb.laengengrad)) AS entfernung_km
    FROM tier t
    CROSS JOIN interessent i
    JOIN standort s ON s.id = t.standort_id
    LEFT JOIN bezirk ib ON ib.id = i.bezirk_id
    LEFT JOIN bezirk sb ON sb.id = s.bezirk_id
    LEFT JOIN tier_groesse tg ON tg.id = t.groesse_id
    LEFT JOIN arbeitsmodell am ON am.id = i.arbeitsmodell_id
    LEFT JOIN interessent_tiererfahrung e
        ON e.interessent_id = i.id AND e.tierart_id = t.tierart_id
), teilwerte AS (
    SELECT
        b.*,
        CASE WHEN b.groessen_abstand IS NULL THEN NULL
             ELSE GREATEST(0, 1 - 0.5 * b.groessen_abstand) END AS groessen_passung,
        CASE WHEN b.tier_alter IS NULL
                  OR (b.wunschalter_min IS NULL AND b.wunschalter_max IS NULL) THEN NULL
             ELSE GREATEST(0, 1 - GREATEST(0,
                      COALESCE(b.wunschalter_min, b.tier_alter) - b.tier_alter,
                      b.tier_alter - COALESCE(b.wunschalter_max, b.tier_alter)) / 5) END AS alter_passung,
        CASE WHEN b.min_zeit = 0 THEN 1
             WHEN b.zeit_stunden IS NULL OR b.min_zeit IS NULL THEN NULL
             WHEN b.zeit_stunden < b.min_zeit THEN 0
             ELSE LEAST(1, 0.5 + 0.5 * (b.zeit_stunden - b.min_zeit) / b.min_zeit) END AS betreuung_passung,
        CASE WHEN b.allein_stunden IS NULL OR b.max_allein IS NULL THEN NULL
             WHEN b.allein_stunden > b.max_allein THEN 0
             WHEN b.max_allein = 0 THEN 1
             ELSE 0.5 + 0.5 * (b.max_allein - b.allein_stunden) / b.max_allein END AS allein_passung,
        CASE WHEN b.min_wohnflaeche = 0 THEN 1
             WHEN b.wohnflaeche IS NULL OR b.min_wohnflaeche IS NULL THEN NULL
             WHEN b.wohnflaeche < b.min_wohnflaeche THEN 0
             ELSE LEAST(1, 0.5 + 0.5 * (b.wohnflaeche - b.min_wohnflaeche) / b.min_wohnflaeche) END AS wohn_passung,
        CASE WHEN b.erfahrungslevel IS NULL OR b.min_erfahrung IS NULL THEN NULL
             WHEN b.erfahrungslevel < b.min_erfahrung THEN 0
             WHEN b.min_erfahrung >= 5 THEN 1
             ELSE 0.5 + 0.5 * (b.erfahrungslevel - b.min_erfahrung) / (5 - b.min_erfahrung) END AS erfahrung_passung,
        CASE WHEN b.kinder_ok = 1 THEN 1 WHEN b.kinder_ok = 0 AND b.kinder = 0 THEN 0.5
             WHEN b.kinder_ok = 0 AND b.kinder = 1 THEN 0 END AS kinder_wert,
        CASE WHEN b.hund_ok = 1 THEN 1 WHEN b.hund_ok = 0 AND b.hund_vorhanden = 0 THEN 0.5
             WHEN b.hund_ok = 0 AND b.hund_vorhanden = 1 THEN 0 END AS hund_wert,
        CASE WHEN b.katze_ok = 1 THEN 1 WHEN b.katze_ok = 0 AND b.katze_vorhanden = 0 THEN 0.5
             WHEN b.katze_ok = 0 AND b.katze_vorhanden = 1 THEN 0 END AS katze_wert,
        CASE WHEN b.kleintiere_ok = 1 THEN 1 WHEN b.kleintiere_ok = 0 AND b.kleintiere_vorhanden = 0 THEN 0.5
             WHEN b.kleintiere_ok = 0 AND b.kleintiere_vorhanden = 1 THEN 0 END AS kleintier_wert,
        CASE WHEN b.monatskosten = 0 THEN 1
             WHEN b.budget IS NULL OR b.monatskosten IS NULL THEN NULL
             WHEN b.budget < b.monatskosten THEN 0
             ELSE LEAST(1, 0.5 + 0.5 * (b.budget - b.monatskosten) / b.monatskosten) END AS budget_passung
    FROM basis b
), kategorien AS (
    SELECT
        tier_id,
        interessent_id,
        (tierart_passt + COALESCE(groessen_passung, 0) + COALESCE(alter_passung, 0))
            / (1 + (groessen_passung IS NOT NULL) + (alter_passung IS NOT NULL)) AS tierart,
        CASE WHEN tier_aktivitaet IS NULL OR interessent_aktivitaet IS NULL THEN NULL
             ELSE 1 - ABS(tier_aktivitaet - interessent_aktivitaet) / 4 END AS aktivitaet,
        (COALESCE(betreuung_passung, 0) + COALESCE(allein_passung, 0))
            / NULLIF((betreuung_passung IS NOT NULL) + (allein_passung IS NOT NULL), 0) AS zeit,
        wohn_passung AS wohnsituation,
        erfahrung_passung AS erfahrung,
        (COALESCE(kinder_wert, 0) + COALESCE(hund_wert, 0) + COALESCE(katze_wert, 0) + COALESCE(kleintier_wert, 0))
            / NULLIF((kinder_wert IS NOT NULL) + (hund_wert IS NOT NULL)
                     + (katze_wert IS NOT NULL) + (kleintier_wert IS NOT NULL), 0) AS vertraeglichkeit,
        -- Ohne belastende Merkmale volle Punktzahl, sonst zaehlt die Bereitschaft des Interessenten.
        CASE WHEN gesundheitslasten = 0 THEN 1
             WHEN medizin_bereit IS NULL OR tierarzt_bereit IS NULL THEN NULL
             ELSE (medizin_bereit + tierarzt_bereit) / 2 END AS gesundheit,
        -- Je kuerzer das Tier allein bleiben darf, desto wichtiger ist die Anwesenheit zu Hause.
        CASE WHEN anwesenheit IS NULL OR max_allein IS NULL THEN NULL
             ELSE 1 - GREATEST(0, 1 - max_allein / 8) * (1 - anwesenheit) END AS alltagsrhythmus,
        budget_passung AS budget,
        CASE WHEN charakter_wuensche = 0 OR tier_charaktere = 0 THEN NULL
             ELSE charakter_treffer / charakter_wuensche END AS charakter,
        CASE WHEN wunschstandort = 1 THEN 1
             WHEN entfernung_km IS NOT NULL
                 THEN GREATEST(0, 1 - entfernung_km / COALESCE(max_entfernung_km, 50))
             WHEN standortwunsch_erfasst = 1 THEN 0
             ELSE NULL END AS naehe
    FROM teilwerte
)
SELECT tier_id, interessent_id, 'Tierart' AS kriterium, tierart AS passung FROM kategorien
UNION ALL SELECT tier_id, interessent_id, 'Aktivitaet', aktivitaet FROM kategorien
UNION ALL SELECT tier_id, interessent_id, 'Zeit', zeit FROM kategorien
UNION ALL SELECT tier_id, interessent_id, 'Wohnsituation', wohnsituation FROM kategorien
UNION ALL SELECT tier_id, interessent_id, 'Erfahrung', erfahrung FROM kategorien
UNION ALL SELECT tier_id, interessent_id, 'Vertraeglichkeit', vertraeglichkeit FROM kategorien
UNION ALL SELECT tier_id, interessent_id, 'Gesundheit', gesundheit FROM kategorien
UNION ALL SELECT tier_id, interessent_id, 'Alltagsrhythmus', alltagsrhythmus FROM kategorien
UNION ALL SELECT tier_id, interessent_id, 'Budget', budget FROM kategorien
UNION ALL SELECT tier_id, interessent_id, 'Charakter', charakter FROM kategorien
UNION ALL SELECT tier_id, interessent_id, 'Naehe', naehe FROM kategorien;

-- Fehlende Kategorien geben 0 Punkte. Wie viel vom Gewicht echte Daten hat, steht in datenabdeckung_prozent.
CREATE OR REPLACE VIEW matching_score AS
WITH gewichtung AS (
    SELECT COUNT(*) AS anzahl_gewichte, SUM(gewicht) AS gesamtgewicht,
           (SELECT COUNT(*) FROM matching_kategorie) AS anzahl_kategorien
    FROM matching_gewichtung
), punkte AS (
    SELECT k.tier_id, k.interessent_id,
           SUM(COALESCE(k.passung * g.gewicht, 0)) AS punkte,
           SUM(CASE WHEN k.passung IS NOT NULL THEN COALESCE(g.gewicht, 0) ELSE 0 END) AS erfasstes_gewicht
    FROM matching_kriterien k
    LEFT JOIN matching_gewichtung g ON g.kriterium = k.kriterium
    GROUP BY k.tier_id, k.interessent_id
)
SELECT
    d.tier_id, d.interessent_id, d.tiername, d.pseudonym, d.tierstatus,
    d.tier_verfuegbar, d.interessent_aktiv, d.eignung, d.ausschlussgruende,
    d.offene_pruefungen,
    d.entfernung_km,
    (g.anzahl_gewichte = g.anzahl_kategorien AND g.gesamtgewicht = 100) AS gewichtung_vollstaendig,
    CASE WHEN d.eignung = 'ausgeschlossen' THEN 0
         WHEN d.eignung = 'pruefung_offen' THEN NULL
         WHEN g.anzahl_gewichte = g.anzahl_kategorien AND g.gesamtgewicht = 100
             THEN ROUND(100 * p.punkte / g.gesamtgewicht, 1)
         ELSE NULL END AS match_prozent,
    CASE WHEN g.anzahl_gewichte = g.anzahl_kategorien AND g.gesamtgewicht = 100
         THEN ROUND(100 * p.erfasstes_gewicht / g.gesamtgewicht, 1)
         ELSE NULL END AS datenabdeckung_prozent
FROM matching_entscheidung d
JOIN punkte p ON p.tier_id = d.tier_id AND p.interessent_id = d.interessent_id
CROSS JOIN gewichtung g;