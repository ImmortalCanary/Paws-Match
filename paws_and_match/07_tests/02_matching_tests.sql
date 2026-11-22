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
SELECT 'Gewichtung: 9 Kriterien mit Summe 100', '9 / 100.00',
       CONCAT(COUNT(*), ' / ', SUM(gewicht)), COUNT(*) = 9 AND SUM(gewicht) = 100
FROM matching_gewichtung;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Entscheidung deckt alle Tier-Interessent-Paare ab',
       CONCAT((SELECT COUNT(*) FROM tier) * (SELECT COUNT(*) FROM interessent)),
       CONCAT(COUNT(*)),
       COUNT(*) = (SELECT COUNT(*) FROM tier) * (SELECT COUNT(*) FROM interessent)
FROM matching_entscheidung;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Jedes Paar hat genau 9 verschiedene Kriterien', '0 Abweichungen', CONCAT(COUNT(*), ' Abweichungen'), COUNT(*) = 0
FROM (SELECT tier_id, interessent_id FROM matching_kriterien
      GROUP BY tier_id, interessent_id
      HAVING COUNT(*) <> 9 OR COUNT(DISTINCT kriterium) <> 9) x;

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
    UNION ALL SELECT 9, 4, 'ausgeschlossen', 'Notwendiges Training'
    UNION ALL SELECT 19, 16, 'ausgeschlossen', 'Tierartspezifische Erfahrung'
    UNION ALL SELECT 7, 2, 'ausgeschlossen', 'Erforderlicher gesicherter Balkon'
    UNION ALL SELECT 16, 17, 'ausgeschlossen', 'Kleintiervertraeglichkeit'
    UNION ALL SELECT 20, 19, 'ausgeschlossen', 'Alleinzeit'
    UNION ALL SELECT 17, 2, 'ausgeschlossen', 'Tierartwunsch'
    UNION ALL SELECT 6, 1, 'pruefung_offen', 'Bestaetigung verbindlicher Beduerfnisse'
    UNION ALL SELECT 13, 3, 'pruefung_offen', 'Tierartspezifische Erfahrung'
) e
LEFT JOIN matching_entscheidung d
    ON d.interessent_id = e.interessent_id AND d.tier_id = e.tier_id;

-- 3. Scores, vorher von Hand ausgerechnet
-- Interessent 1 / Tier 1:   20 + 15 + 13,5 + 15 + 7,5 + 10 + 5 + 5 + 5 = 96,0
-- Interessent 17 / Tier 16: 20 + 11,25 + 12,19 + 10,71 + 7,5 + 7,5 + 3,57 + 2,5 + 5 = 80,2
-- Interessent 17 / Tier 8:  16,67 + 11,25 + 12,75 + 15 + 6,25 + 10 + 5 + 0 + 0 = 76,9
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT CONCAT('Score Interessent ', e.interessent_id, ' / Tier ', e.tier_id),
       CONCAT(e.score), COALESCE(CONCAT(s.match_prozent), 'NULL'), s.match_prozent = e.score
FROM (
    SELECT 1 AS interessent_id, 1 AS tier_id, 96.0 AS score
    UNION ALL SELECT 17, 16, 80.2
    UNION ALL SELECT 17, 8, 76.9
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

-- Alles genau auf dem Minimum: 20 + 0 + 7,5 + 7,5 + 5 + 7,5 + 2,5 + 2,5 + 5 = 57,5
-- (mit der alten Berechnung mit 70 Grundpunkten kaeme hier 75,0 raus)
START TRANSACTION;
UPDATE interessent
SET wohnflaeche = 70, zeit_stunden = 3, allein_stunden = 4, budget = 350, aktivitaet = 1
WHERE id = 17;
UPDATE interessent_tiererfahrung SET erfahrungslevel = 3 WHERE interessent_id = 17 AND tierart_id = 1;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Score an den Mindestgrenzen ohne Grundpunkte', 'geeignet, 57.5',
       CONCAT(eignung, ', ', COALESCE(match_prozent, 'NULL')),
       eignung = 'geeignet' AND match_prozent = 57.5
FROM matching_score WHERE interessent_id = 17 AND tier_id = 16;
ROLLBACK;

-- 5. Fehlende weiche Angaben: 0 Punkte und weniger Datenabdeckung
START TRANSACTION;
DELETE FROM interessent_charakter WHERE interessent_id = 17;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Fehlende Charakterwuensche: Score -2,5 und Abdeckung 95', '77.7 / 95.0',
       CONCAT(match_prozent, ' / ', datenabdeckung_prozent),
       match_prozent = 77.7 AND datenabdeckung_prozent = 95.0
FROM matching_score WHERE interessent_id = 17 AND tier_id = 16;
ROLLBACK;

-- 6. Gewichtung muss vollstaendig sein und 100 ergeben
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

-- 7. Ungueltige Werte duerfen gar nicht erst gespeichert werden
START TRANSACTION;
CALL test_erwarte_fehler('Interessent: Betreuungs- plus Alleinzeit > 24 h',
    'UPDATE interessent SET zeit_stunden = 20, allein_stunden = 10 WHERE id = 1', 'ck_interessent_tagesstunden');
CALL test_erwarte_fehler('Tier: ungueltiger Wahrheitswert',
    'UPDATE tier SET garten_noetig = 2 WHERE id = 1', 'ck_tier_garten_noetig');
CALL test_erwarte_fehler('Interessent: ungueltige E-Mail',
    'UPDATE interessent SET email = ''keine-adresse'' WHERE id = 1', 'ck_interessent_email');
CALL test_erwarte_fehler('Gewichtung: nicht positives Gewicht',
    'UPDATE matching_gewichtung SET gewicht = 0 WHERE kriterium = ''Naehe''', 'ck_matching_gewicht');
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
