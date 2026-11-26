-- Tests fuer das Matching. Die erwarteten Werte passen zu den Demodaten aus 03_demo_daten.
-- Was geaendert wird, laeuft in einer Transaktion und wird danach zurueckgerollt.
USE paws_match;
SET NAMES utf8mb4;
SET SESSION group_concat_max_len = 65535;

-- MEMORY-Tabelle, weil die Ergebnisse sonst beim ROLLBACK mit verschwinden wuerden.
DROP TEMPORARY TABLE IF EXISTS test_ergebnis;
CREATE TEMPORARY TABLE test_ergebnis (
    nr INT AUTO_INCREMENT PRIMARY KEY,
    testfall VARCHAR(200) NOT NULL,
    erwartet VARCHAR(500),
    ist VARCHAR(500),
    bestanden BOOLEAN
) ENGINE = MEMORY;

DROP PROCEDURE IF EXISTS test_erwarte_fehler;

DELIMITER $$
CREATE PROCEDURE test_erwarte_fehler (IN p_testfall VARCHAR(200), IN p_sql TEXT, IN p_meldung VARCHAR(255))
BEGIN
    DECLARE v_sqlstate CHAR(5) DEFAULT NULL;
    DECLARE v_meldung TEXT DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
        GET DIAGNOSTICS CONDITION 1 v_sqlstate = RETURNED_SQLSTATE, v_meldung = MESSAGE_TEXT;

    SET @test_sql = p_sql;
    PREPARE test_stmt FROM @test_sql;
    IF v_sqlstate IS NULL THEN
        EXECUTE test_stmt;
        DEALLOCATE PREPARE test_stmt;
    END IF;

    INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
    VALUES (p_testfall, CONCAT('Fehler: ', p_meldung), COALESCE(v_meldung, 'kein Fehler'),
            v_sqlstate IS NOT NULL AND v_meldung LIKE CONCAT('%', p_meldung, '%'));
END$$
DELIMITER ;

-- 1. Struktur und Konsistenz
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Katalog enthaelt 11 Score-Kategorien', '11', CONCAT(COUNT(*)), COUNT(*) = 11
FROM matching_kategorie;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Gewichtung: 11 Kriterien mit Summe 100', '11 / 100.00',
       CONCAT(COUNT(*), ' / ', SUM(gewicht)), COUNT(*) = 11 AND SUM(gewicht) = 100
FROM matching_gewichtung;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Jede Kategorie hat genau ein Gewicht', '0 ohne Gewicht', CONCAT(COUNT(*), ' ohne Gewicht'), COUNT(*) = 0
FROM matching_kategorie k
LEFT JOIN matching_gewichtung g ON g.kriterium = k.name
WHERE g.kriterium IS NULL;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Entscheidung deckt alle Tier-Interessent-Paare ab',
       CONCAT((SELECT COUNT(*) FROM tier) * (SELECT COUNT(*) FROM interessent)),
       CONCAT(COUNT(*)),
       COUNT(*) = (SELECT COUNT(*) FROM tier) * (SELECT COUNT(*) FROM interessent)
FROM matching_entscheidung;

START TRANSACTION;
-- Interessent 1/Tier 2 eignet sich nicht fuer einen reinen Geo-Test (schon ohne Geografie wegen
-- Tierartwunsch/Balkon ausgeschlossen, Standort 2 hat ohnehin keine Koordinaten). Interessent 17/
-- Tier 8 hat echte Koordinaten (~17,3 km) und sonst keine Ausschlussgruende, darum hier verwendet;
-- die dauerhafte Suchzonen-Einschraenkung aus den Demodaten wird dafuer kurz aufgehoben.
UPDATE interessent SET max_suchzone_id = NULL, max_entfernung_km = 5 WHERE id = 17;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Radius 5 km schliesst einen weiter entfernten Standort aus', 'ausgeschlossen / Entfernung',
       CONCAT(eignung, ' / ', ausschlussgruende),
       eignung = 'ausgeschlossen' AND ausschlussgruende LIKE '%Entfernung%'
FROM matching_entscheidung WHERE interessent_id = 17 AND tier_id = 8;
UPDATE interessent SET max_entfernung_km = NULL, max_suchzone_id = 1 WHERE id = 1;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Berlin-Zone schliesst Standort in Brandenburg aus', 'ausgeschlossen / Suchzone',
       CONCAT(eignung, ' / ', ausschlussgruende),
       eignung = 'ausgeschlossen' AND ausschlussgruende LIKE '%Suchzone%'
FROM matching_entscheidung WHERE interessent_id = 1 AND tier_id = 5;
UPDATE standort SET breitengrad = NULL, laengengrad = NULL, bezirk_id = NULL WHERE id = 3;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Unbekannte Entfernung erfordert manuelle Pruefung', 'pruefung_offen / Entfernung',
       CONCAT(eignung, ' / ', offene_pruefungen),
       eignung = 'pruefung_offen' AND offene_pruefungen LIKE '%Entfernung%'
FROM matching_entscheidung WHERE interessent_id = 17 AND tier_id = 8;
ROLLBACK;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Jedes Paar hat genau 11 verschiedene Kriterien', '0 Abweichungen', CONCAT(COUNT(*), ' Abweichungen'), COUNT(*) = 0
FROM (SELECT tier_id, interessent_id FROM matching_kriterien
      GROUP BY tier_id, interessent_id
      HAVING COUNT(*) <> 11 OR COUNT(DISTINCT kriterium) <> 11) x;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Teilpassungen liegen zwischen 0 und 1', '0 Abweichungen', CONCAT(COUNT(*), ' Abweichungen'), COUNT(*) = 0
FROM matching_kriterien WHERE passung < 0 OR passung > 1;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Score passt zur Eignung und liegt in 0..100', '0 Abweichungen', CONCAT(COUNT(*), ' Abweichungen'), COUNT(*) = 0
FROM matching_score
WHERE (eignung = 'ausgeschlossen' AND (match_prozent IS NULL OR match_prozent <> 0))
   OR (eignung = 'pruefung_offen' AND match_prozent IS NOT NULL)
   OR (eignung = 'geeignet' AND match_prozent IS NULL)
   OR match_prozent < 0 OR match_prozent > 100
   OR datenabdeckung_prozent IS NULL OR datenabdeckung_prozent < 0 OR datenabdeckung_prozent > 100;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Doppelte View matching_zusatzpruefung entfernt', '0', CONCAT(COUNT(*)), COUNT(*) = 0
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'paws_match' AND TABLE_NAME = 'matching_zusatzpruefung';

-- 2. Bekannte Paare: Eignung und der passende Grund muessen stimmen
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT CONCAT('Eignung Interessent ', e.interessent_id, ' / Tier ', e.tier_id),
       CONCAT(e.eignung, IF(e.kriterium IS NULL, '', CONCAT(' (', e.kriterium, ')'))),
       CONCAT(COALESCE(d.eignung, 'fehlt'), ' | ', COALESCE(d.ausschlussgruende, ''), ' | ', COALESCE(d.offene_pruefungen, '')),
       d.eignung = e.eignung
       AND (e.kriterium IS NULL
            OR (e.eignung = 'ausgeschlossen' AND d.ausschlussgruende LIKE CONCAT('%', e.kriterium, '%'))
            OR (e.eignung = 'pruefung_offen' AND d.offene_pruefungen LIKE CONCAT('%', e.kriterium, '%')))
FROM (
    SELECT 1 AS interessent_id, 1 AS tier_id, 'geeignet' AS eignung, NULL AS kriterium
    UNION ALL SELECT 17, 16, 'geeignet', NULL
    UNION ALL SELECT 4, 4, 'geeignet', NULL
    UNION ALL SELECT 9, 4, 'ausgeschlossen', 'Verbindliches Beduerfnis ausdruecklich abgelehnt'
    UNION ALL SELECT 19, 16, 'ausgeschlossen', 'Tierartspezifische Erfahrung'
    UNION ALL SELECT 7, 2, 'ausgeschlossen', 'Verbindliches Beduerfnis ausdruecklich abgelehnt'
    UNION ALL SELECT 16, 17, 'ausgeschlossen', 'Kleintiervertraeglichkeit'
    UNION ALL SELECT 20, 19, 'ausgeschlossen', 'Alleinzeit'
    UNION ALL SELECT 17, 2, 'ausgeschlossen', 'Tierartwunsch'
    UNION ALL SELECT 6, 1, 'pruefung_offen', 'Bestaetigung verbindlicher Beduerfnisse'
    UNION ALL SELECT 13, 3, 'pruefung_offen', 'Tierartspezifische Erfahrung'
) e
LEFT JOIN matching_entscheidung d
    ON d.interessent_id = e.interessent_id AND d.tier_id = e.tier_id;

-- 3. Scores, vorher von Hand ausgerechnet
-- Reihenfolge: Tierart, Aktivitaet, Zeit, Wohnsituation, Erfahrung, Vertraeglichkeit,
--              Gesundheit, Alltagsrhythmus, Budget, Charakter, Naehe
-- Interessent 1 / Tier 1:   Naehe wird aus der Entfernung von ca. 7,45 km berechnet.
-- Interessent 17 / Tier 16: 20 + 9,75 + 10,56 + 9,29 + 6,75 + 6,75 + 7 + 5 + 2,86 + 2 + 3 = 83,0
-- Interessent 17 / Tier 8:  16,67 + 9,75 + 11,05 + 13 + 5,63 + 9 + 7 + 5 + 4 + 0 + 0 = 81,1
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT CONCAT('Score Interessent ', e.interessent_id, ' / Tier ', e.tier_id),
       CONCAT(e.score), COALESCE(CONCAT(s.match_prozent), 'NULL'), s.match_prozent = e.score
FROM (
    SELECT 1 AS interessent_id, 1 AS tier_id, 95.3 AS score
    UNION ALL SELECT 17, 16, 83.0
    UNION ALL SELECT 17, 8, 0.0
) e
LEFT JOIN matching_score s ON s.interessent_id = e.interessent_id AND s.tier_id = e.tier_id;

-- 4. Der Score soll sich auch innerhalb der harten Grenzen veraendern
SET @score_vorher = (SELECT match_prozent FROM matching_score WHERE interessent_id = 17 AND tier_id = 16);

START TRANSACTION;
UPDATE interessent SET wohnflaeche = 75 WHERE id = 17;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Weniger Wohnflaechenreserve senkt Score (Wohnsituation graduell)',
       CONCAT('geeignet, < ', @score_vorher), CONCAT(eignung, ', ', match_prozent),
       eignung = 'geeignet' AND match_prozent < @score_vorher
FROM matching_score WHERE interessent_id = 17 AND tier_id = 16;
ROLLBACK;

START TRANSACTION;
UPDATE interessent SET budget = 2000 WHERE id = 17;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Mehr Budgetreserve erhoeht Score (Budget graduell)',
       CONCAT('geeignet, > ', @score_vorher), CONCAT(eignung, ', ', match_prozent),
       eignung = 'geeignet' AND match_prozent > @score_vorher
FROM matching_score WHERE interessent_id = 17 AND tier_id = 16;
ROLLBACK;

-- Alle Reserven genau auf dem Minimum (Gesundheit und Alltagsrhythmus sind hier ohnehin voll):
-- 20 + 0 + 6,5 + 6,5 + 4,5 + 6,75 + 7 + 5 + 2 + 2 + 3 = 63,25 -> 63,3
-- (mit der alten Berechnung mit 70 Grundpunkten kaeme hier ein kuenstlich hoher Wert raus)
START TRANSACTION;
UPDATE interessent
SET wohnflaeche = 70, zeit_stunden = 3, allein_stunden = 4, budget = 350, aktivitaet = 1
WHERE id = 17;
UPDATE interessent_tiererfahrung SET erfahrungslevel = 3 WHERE interessent_id = 17 AND tierart_id = 1;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Score an den Mindestgrenzen ohne Grundpunkte', 'geeignet, 63.3',
       CONCAT(eignung, ', ', COALESCE(match_prozent, 'NULL')),
       eignung = 'geeignet' AND match_prozent = 63.3
FROM matching_score WHERE interessent_id = 17 AND tier_id = 16;
ROLLBACK;

-- 5. Fehlende weiche Angaben: 0 Punkte und weniger Datenabdeckung
START TRANSACTION;
DELETE FROM interessent_charakter WHERE interessent_id = 17;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Fehlende Charakterwuensche: Score -2 und Abdeckung 96', '81.0 / 96.0',
       CONCAT(match_prozent, ' / ', datenabdeckung_prozent),
       match_prozent = 81.0 AND datenabdeckung_prozent = 96.0
FROM matching_score WHERE interessent_id = 17 AND tier_id = 16;
ROLLBACK;

-- 6. Gesundheit: nur bestaetigte und belastende Merkmale zaehlen
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Gesundheit: Tier 16 hat nur unbelastende Merkmale', '1.0000',
       COALESCE(CONCAT(ROUND(passung, 4)), 'NULL'), passung = 1
FROM matching_kriterien WHERE kriterium = 'Gesundheit' AND tier_id = 16 AND interessent_id = 17;

-- Tier 1 braucht Medikamente, Profil 20 ist weder dazu noch zum Tierarzt bereit.
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Gesundheit: belastendes Merkmal ohne Bereitschaft', '0.0000',
       COALESCE(CONCAT(ROUND(passung, 4)), 'NULL'), passung = 0
FROM matching_kriterien WHERE kriterium = 'Gesundheit' AND tier_id = 1 AND interessent_id = 20;

-- Profil 16 ist nur zum Tierarzt bereit, also die Haelfte.
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Gesundheit: halbe Bereitschaft ergibt 0,5', '0.5000',
       COALESCE(CONCAT(ROUND(passung, 4)), 'NULL'), passung = 0.5
FROM matching_kriterien WHERE kriterium = 'Gesundheit' AND tier_id = 1 AND interessent_id = 16;

-- Bei Tier 19 ist das Merkmal unbestaetigt und darf deshalb nichts bewirken.
SET @gesundheit_vorher = (SELECT passung FROM matching_kriterien
                          WHERE kriterium = 'Gesundheit' AND tier_id = 19 AND interessent_id = 16);
START TRANSACTION;
UPDATE tier_gesundheit SET bestaetigt = 1 WHERE tier_id = 19 AND gesundheitsmerkmal_id = 2;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Gesundheit: Merkmal wirkt erst nach Bestaetigung', '1.0000 -> 0.5000',
       CONCAT(ROUND(@gesundheit_vorher, 4), ' -> ', ROUND(passung, 4)),
       @gesundheit_vorher = 1 AND passung = 0.5
FROM matching_kriterien WHERE kriterium = 'Gesundheit' AND tier_id = 19 AND interessent_id = 16;
ROLLBACK;

-- 7. Alltagsrhythmus: Alleinzeit des Tieres gegen die Anwesenheit laut Arbeitsmodell
-- Tier 17 darf 8 Stunden allein bleiben, dann ist das Arbeitsmodell egal.
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Alltagsrhythmus: lange Alleinzeit passt immer', '1.0000',
       COALESCE(CONCAT(ROUND(passung, 4)), 'NULL'), passung = 1
FROM matching_kriterien WHERE kriterium = 'Alltagsrhythmus' AND tier_id = 17 AND interessent_id = 20;

-- Tier 20 darf nur 4 Stunden allein bleiben, Profil 20 ist ueberwiegend vor Ort (0,25).
-- 1 - (1 - 4/8) * (1 - 0,25) = 0,625
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Alltagsrhythmus: kurze Alleinzeit braucht Anwesenheit', '0.6250',
       COALESCE(CONCAT(ROUND(passung, 4)), 'NULL'), passung = 0.625
FROM matching_kriterien WHERE kriterium = 'Alltagsrhythmus' AND tier_id = 20 AND interessent_id = 20;

START TRANSACTION;
UPDATE interessent SET arbeitsmodell_id = 2 WHERE id = 20;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Alltagsrhythmus: mehr Anwesenheit hebt den Wert', '1.0000',
       COALESCE(CONCAT(ROUND(passung, 4)), 'NULL'), passung = 1
FROM matching_kriterien WHERE kriterium = 'Alltagsrhythmus' AND tier_id = 20 AND interessent_id = 20;
ROLLBACK;

START TRANSACTION;
UPDATE interessent SET arbeitsmodell_id = NULL WHERE id = 20;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Alltagsrhythmus: ohne Arbeitsmodell NULL', 'NULL',
       COALESCE(CONCAT(ROUND(passung, 4)), 'NULL'), passung IS NULL
FROM matching_kriterien WHERE kriterium = 'Alltagsrhythmus' AND tier_id = 20 AND interessent_id = 20;
ROLLBACK;

-- 8. Mindestscore kommt aus der Einstellungstabelle
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Mindestscore steht in matching_einstellung', '50.00',
       COALESCE(CONCAT(wert), 'fehlt'), wert = 50.00
FROM matching_einstellung WHERE schluessel = 'mindestscore';

SET @vorschlaege_vorher = (SELECT COUNT(*) FROM matching_vorschlaege);

START TRANSACTION;
UPDATE matching_einstellung SET wert = 90 WHERE schluessel = 'mindestscore';
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Hoeherer Mindestscore filtert Vorschlaege',
       CONCAT('0 unter 90 und weniger als ', @vorschlaege_vorher),
       CONCAT((SELECT COUNT(*) FROM matching_vorschlaege WHERE match_prozent < 90), ' unter 90 und ',
              (SELECT COUNT(*) FROM matching_vorschlaege), ' gesamt'),
       (SELECT COUNT(*) FROM matching_vorschlaege WHERE match_prozent < 90) = 0
       AND (SELECT COUNT(*) FROM matching_vorschlaege) < @vorschlaege_vorher;
ROLLBACK;

START TRANSACTION;
DELETE FROM matching_einstellung WHERE schluessel = 'mindestscore';
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Fehlender Mindestscore: keine Vorschlaege', '0', CONCAT(COUNT(*)), COUNT(*) = 0
FROM matching_vorschlaege;
ROLLBACK;

-- 9. Gewichtung muss vollstaendig sein und 100 ergeben
START TRANSACTION;
UPDATE matching_gewichtung SET gewicht = 25 WHERE kriterium = 'Tierart';
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Gewichtssumme 105: kein Score, kein Vorschlag', '0 Scores / 0 Vorschlaege',
       CONCAT(SUM(match_prozent IS NOT NULL AND eignung = 'geeignet'), ' Scores / ',
              (SELECT COUNT(*) FROM matching_vorschlaege), ' Vorschlaege'),
       SUM(match_prozent IS NOT NULL AND eignung = 'geeignet') = 0
       AND SUM(gewichtung_vollstaendig) = 0
       AND (SELECT COUNT(*) FROM matching_vorschlaege) = 0
FROM matching_score;
ROLLBACK;

START TRANSACTION;
DELETE FROM matching_gewichtung WHERE kriterium = 'Naehe';
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Fehlendes Gewicht: kein Score', '0 Scores',
       CONCAT(SUM(match_prozent IS NOT NULL AND eignung = 'geeignet'), ' Scores'),
       SUM(match_prozent IS NOT NULL AND eignung = 'geeignet') = 0
FROM matching_score;
ROLLBACK;

-- 10. Ungueltige Werte duerfen gar nicht erst gespeichert werden
START TRANSACTION;
CALL test_erwarte_fehler('Interessent: Betreuungs- plus Alleinzeit > 24 h',
    'UPDATE interessent SET zeit_stunden = 20, allein_stunden = 10 WHERE id = 1', 'ck_interessent_tagesstunden');
-- Bypass fuer den fail-closed Standort-Trigger (P0.2, trg_tier_standort_pruefen_update):
-- dieser rohe UPDATE ohne Prozeduraufruf soll den CHECK-Fehler zeigen, nicht die
-- Standortmeldung. Direkt danach zurueckgesetzt.
SET @pm_ist_admin = 1;
CALL test_erwarte_fehler('Tier: ungueltiger Wahrheitswert',
    'UPDATE tier SET garten_noetig = 2 WHERE id = 1', 'ck_tier_garten_noetig');
SET @pm_ist_admin = NULL;
CALL test_erwarte_fehler('Interessent: ungueltige E-Mail',
    'UPDATE interessent SET email = ''keine-adresse'' WHERE id = 1', 'ck_interessent_email');
-- P0.5: die gehaertete REGEXP muss mehrfaches '@', Leerzeichen und einen fehlenden Punkt im
-- Domainteil ablehnen (vorher gingen diese drei Faelle mit dem alten LIKE-Muster durch).
CALL test_erwarte_fehler('Interessent: E-Mail mit doppeltem @-Zeichen',
    'UPDATE interessent SET email = ''a@@b.c'' WHERE id = 1', 'ck_interessent_email');
CALL test_erwarte_fehler('Interessent: E-Mail mit Leerzeichen in der Adresse',
    'UPDATE interessent SET email = ''a @b.c'' WHERE id = 1', 'ck_interessent_email');
CALL test_erwarte_fehler('Interessent: E-Mail ohne Punkt im Domainteil',
    'UPDATE interessent SET email = ''a@bc'' WHERE id = 1', 'ck_interessent_email');
-- Positivprobe: eine normale Adresse muss weiterhin akzeptiert werden (kein Overblocking).
UPDATE interessent SET email = 'gueltige-adresse@beispiel.de' WHERE id = 1;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Interessent: gueltige E-Mail wird weiterhin akzeptiert', 'gueltige-adresse@beispiel.de',
       email, email = 'gueltige-adresse@beispiel.de'
FROM interessent WHERE id = 1;
CALL test_erwarte_fehler('Gewichtung: nicht positives Gewicht',
    'UPDATE matching_gewichtung SET gewicht = 0 WHERE kriterium = ''Naehe''', 'ck_matching_gewicht');
CALL test_erwarte_fehler('Gewichtung: unbekannte Kategorie',
    'INSERT INTO matching_gewichtung (kriterium, gewicht) VALUES (''Fantasie'', 1)', 'foreign key constraint fails');
CALL test_erwarte_fehler('Mindestscore ausserhalb von 0 bis 100',
    'UPDATE matching_einstellung SET wert = 150 WHERE schluessel = ''mindestscore''', 'ck_matching_einstellung_wert');
CALL test_erwarte_fehler('Arbeitsmodell: Anwesenheit ausserhalb von 0 bis 1',
    'UPDATE arbeitsmodell SET anwesenheit = 1.5 WHERE id = 1', 'ck_arbeitsmodell_anwesenheit');
CALL test_erwarte_fehler('Gesundheitsmerkmal: ungueltiger Wahrheitswert',
    'UPDATE gesundheitsmerkmal SET belastend = 2 WHERE id = 1', 'ck_gesundheitsmerkmal_belastend');
CALL test_erwarte_fehler('Interessent: Umkreis kein 5-km-Schritt',
    'UPDATE interessent SET max_entfernung_km = 27 WHERE id = 1', 'ck_interessent_max_entfernung');
CALL test_erwarte_fehler('Interessent: Umkreis oberhalb 250 km',
    'UPDATE interessent SET max_entfernung_km = 255 WHERE id = 1', 'ck_interessent_max_entfernung');
ROLLBACK;

DROP PROCEDURE test_erwarte_fehler;

SELECT nr, testfall, erwartet, ist, IF(bestanden, 'OK', 'FEHLER') AS ergebnis
FROM test_ergebnis ORDER BY nr;

-- NULL heisst: konnte nicht geprueft werden. Das zaehlen wir als Fehler.
SELECT COUNT(*) AS tests, SUM(COALESCE(bestanden, 0)) AS bestanden,
       COUNT(*) - SUM(COALESCE(bestanden, 0)) AS fehlgeschlagen,
       IF(SUM(COALESCE(bestanden, 0)) = COUNT(*), 'ALLE MATCHING-TESTS BESTANDEN', 'MATCHING-TESTS FEHLGESCHLAGEN') AS gesamtergebnis
FROM test_ergebnis;

DROP TEMPORARY TABLE test_ergebnis;