-- Tests fuer die Orte und die Bezirkserkennung. Die Datei enthaelt Umlaute, also als UTF-8 ausfuehren.
-- Was geaendert wird, laeuft in einer Transaktion und wird danach zurueckgerollt.
USE paws_match;
SET NAMES utf8mb4;
SET SESSION group_concat_max_len = 65535;

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

-- 1. Hilfsfunktionen
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Normalisierung: Umlaute, ss, Gross/klein, Sonderzeichen', 'strasseaeoeue12',
       COALESCE(fn_text_normalisieren('  Straße Ä-Ö/Ü 12 '), 'NULL'),
       fn_text_normalisieren('  Straße Ä-Ö/Ü 12 ') = 'strasseaeoeue12';

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Normalisierung: leere Eingabe', 'NULL / NULL',
       CONCAT(COALESCE(fn_text_normalisieren(''), 'NULL'), ' / ', COALESCE(fn_text_normalisieren(NULL), 'NULL')),
       fn_text_normalisieren('') IS NULL AND fn_text_normalisieren(NULL) IS NULL;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Levenshtein-Distanzen', '3 / 3 / 0 / 2',
       CONCAT_WS(' / ', fn_levenshtein('kitten', 'sitting'), fn_levenshtein('', 'abc'),
                 fn_levenshtein('abc', 'abc'), fn_levenshtein('spandau', 'spandua')),
       fn_levenshtein('kitten', 'sitting') = 3 AND fn_levenshtein('', 'abc') = 3
       AND fn_levenshtein('abc', 'abc') = 0 AND fn_levenshtein('spandau', 'spandua') = 2;

-- 2. Stammdaten und Auswahlliste
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Stammdaten: 16 Bundeslaender, 1 aktiver Ort, 12 Bezirke', '16 / 1 / 12',
       CONCAT_WS(' / ', (SELECT COUNT(*) FROM bundesland), (SELECT COUNT(*) FROM ort WHERE aktiv = 1),
                 (SELECT COUNT(*) FROM bezirk)),
       (SELECT COUNT(*) FROM bundesland) = 16 AND (SELECT COUNT(*) FROM ort WHERE aktiv = 1) = 1
       AND (SELECT COUNT(*) FROM bezirk) = 12;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Auswahlliste: 12 Berliner Bezirke', '12 / Berlin',
       CONCAT(COUNT(*), ' / ', GROUP_CONCAT(DISTINCT ort)),
       COUNT(*) = 12 AND COUNT(DISTINCT ort) = 1 AND MIN(ort) = 'Berlin'
FROM bezirk_auswahl;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Jeder Bezirk und jeder Ortsteil wird eindeutig erkannt', '0 Abweichungen',
       CONCAT(COUNT(*), ' Abweichungen'), COUNT(*) = 0
FROM (
    SELECT id AS bezirk_id, name FROM bezirk
    UNION ALL
    SELECT bezirk_id, name FROM bezirk_alias
) n
WHERE NOT (fn_bezirk_id(n.name, NULL) <=> n.bezirk_id);

-- 3. Freitext-Erkennung: Schreibweisen, Umlaute, Tippfehler, Ortsteile
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT CONCAT('Erkennung: "', COALESCE(e.eingabe, 'NULL'), '"'),
       COALESCE(e.erwartet, 'nicht erkannt'),
       COALESCE((SELECT name FROM bezirk WHERE id = fn_bezirk_id(e.eingabe, NULL)), 'nicht erkannt'),
       (SELECT name FROM bezirk WHERE id = fn_bezirk_id(e.eingabe, NULL)) <=> e.erwartet
FROM (
    SELECT 'Mitte' AS eingabe, 'Mitte' AS erwartet
    UNION ALL SELECT 'Neukölln', 'Neukölln'
    UNION ALL SELECT 'Neukoelln', 'Neukölln'
    UNION ALL SELECT 'NEUKÖLLN', 'Neukölln'
    UNION ALL SELECT '  neukölln  ', 'Neukölln'
    UNION ALL SELECT 'Neukolln', 'Neukölln'
    UNION ALL SELECT 'Neuköln', 'Neukölln'
    -- So sieht 'Neukoelln' mit Umlaut aus, wenn UTF-8 faelschlich als Latin-1 gelesen wurde.
    UNION ALL SELECT CONVERT(X'4E65756BC383C2B66C6C6E' USING utf8mb4), 'Neukölln'
    UNION ALL SELECT 'Berlin-Mitte', 'Mitte'
    UNION ALL SELECT 'Berlin Neukölln', 'Neukölln'
    UNION ALL SELECT 'Neukölln (Berlin)', 'Neukölln'
    UNION ALL SELECT 'Bezirk Pankow', 'Pankow'
    UNION ALL SELECT 'Mite', 'Mitte'
    UNION ALL SELECT 'Tempelhof Schoeneberg', 'Tempelhof-Schöneberg'
    UNION ALL SELECT 'tempelhof-schöneberg', 'Tempelhof-Schöneberg'
    UNION ALL SELECT 'Lichtenbreg', 'Lichtenberg'
    UNION ALL SELECT 'Spandua', 'Spandau'
    UNION ALL SELECT 'Reinickendorff', 'Reinickendorf'
    UNION ALL SELECT 'Prenzlauer Berg', 'Pankow'
    UNION ALL SELECT 'Kreuzberg', 'Friedrichshain-Kreuzberg'
    UNION ALL SELECT 'Köpenick', 'Treptow-Köpenick'
    UNION ALL SELECT 'Koepenick', 'Treptow-Köpenick'
    UNION ALL SELECT 'Hohenschönhausen', 'Lichtenberg'
    UNION ALL SELECT 'Weißensee', 'Pankow'
    UNION ALL SELECT 'Weissensee', 'Pankow'
    UNION ALL SELECT 'Märkisches Viertel', 'Reinickendorf'
    UNION ALL SELECT 'Hamburg', NULL
    UNION ALL SELECT 'München', NULL
    UNION ALL SELECT 'Berlin', NULL
    UNION ALL SELECT 'Xyz', NULL
    UNION ALL SELECT '', NULL
    UNION ALL SELECT NULL, NULL
) e;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Einschraenkung auf Ort', '1 / NULL',
       CONCAT(COALESCE(fn_bezirk_id('Mitte', 1), 'NULL'), ' / ', COALESCE(fn_bezirk_id('Mitte', 999), 'NULL')),
       fn_bezirk_id('Mitte', 1) = 1 AND fn_bezirk_id('Mitte', 999) IS NULL;

-- 4. Demodaten: verschiedene Schreibweisen landen im richtigen Bezirk
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Demodaten: alle Standorte und Profile haben einen Bezirk', '0',
       CONCAT((SELECT COUNT(*) FROM standort WHERE bezirk_id IS NULL)
              + (SELECT COUNT(*) FROM interessent WHERE bezirk_id IS NULL)),
       (SELECT COUNT(*) FROM standort WHERE bezirk_id IS NULL)
       + (SELECT COUNT(*) FROM interessent WHERE bezirk_id IS NULL) = 0;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Demodaten: Profile 7, 9, 13, 16, 19 zugeordnet', 'Pankow, Neukölln, Spandau, Mitte, Neukölln',
       GROUP_CONCAT(b.name ORDER BY i.id SEPARATOR ', '),
       GROUP_CONCAT(b.name ORDER BY i.id SEPARATOR ', ') = 'Pankow, Neukölln, Spandau, Mitte, Neukölln'
FROM interessent i JOIN bezirk b ON b.id = i.bezirk_id
WHERE i.id IN (7, 9, 13, 16, 19);

-- 5. Orte freischalten und weitere Orte ergaenzen (Beispiel Hamburg)
START TRANSACTION;
UPDATE ort SET aktiv = 0 WHERE id = 1;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Nicht freigeschalteter Ort: keine Auswahl, keine Erkennung', '0 / NULL',
       CONCAT((SELECT COUNT(*) FROM bezirk_auswahl), ' / ', COALESCE(fn_bezirk_id('Mitte', NULL), 'NULL')),
       (SELECT COUNT(*) FROM bezirk_auswahl) = 0 AND fn_bezirk_id('Mitte', NULL) IS NULL;
ROLLBACK;

START TRANSACTION;
INSERT INTO ort (id, bundesland_id, name, ags, aktiv) VALUES (2, 2, 'Hamburg', '02000000', 1);
INSERT INTO bezirk (id, ort_id, name, schluessel) VALUES (101, 2, 'Hamburg-Mitte', '01'), (102, 2, 'Altona', '02');
INSERT INTO bezirk_alias (bezirk_id, name) VALUES (101, 'Mitte');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Erweiterung Hamburg: Altona / Hamburg-Altona / Hamburg Mitte', '102 / 102 / 101',
       CONCAT_WS(' / ', COALESCE(fn_bezirk_id('Altona', NULL), 'NULL'),
                 COALESCE(fn_bezirk_id('Hamburg-Altona', NULL), 'NULL'),
                 COALESCE(fn_bezirk_id('Hamburg Mitte', NULL), 'NULL')),
       fn_bezirk_id('Altona', NULL) = 102 AND fn_bezirk_id('Hamburg-Altona', NULL) = 102
       AND fn_bezirk_id('Hamburg Mitte', NULL) = 101;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Mehrdeutig "Mitte": ohne Ort NULL, mit Ort eindeutig', 'NULL / 1 / 101',
       CONCAT_WS(' / ', COALESCE(fn_bezirk_id('Mitte', NULL), 'NULL'),
                 COALESCE(fn_bezirk_id('Mitte', 1), 'NULL'), COALESCE(fn_bezirk_id('Mitte', 2), 'NULL')),
       fn_bezirk_id('Mitte', NULL) IS NULL AND fn_bezirk_id('Mitte', 1) = 1 AND fn_bezirk_id('Mitte', 2) = 101;
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Auswahlliste nach Erweiterung', '14 Bezirke / 2 Orte',
       CONCAT(COUNT(*), ' Bezirke / ', COUNT(DISTINCT ort_id), ' Orte'),
       COUNT(*) = 14 AND COUNT(DISTINCT ort_id) = 2
FROM bezirk_auswahl;
ROLLBACK;

-- 6. Datenqualitaet
START TRANSACTION;
CALL test_erwarte_fehler('Doppelter Bezirk in anderer Schreibweise',
    'INSERT INTO bezirk (ort_id, name) VALUES (1, ''Neukoelln'')', 'uq_bezirk_suchname');
CALL test_erwarte_fehler('Aktives Profil ohne Bezirk',
    'UPDATE interessent SET bezirk_id = NULL WHERE id = 1', 'ck_interessent_bezirk');
CALL test_erwarte_fehler('Standort mit unbekanntem Bezirk',
    'UPDATE standort SET bezirk_id = 999 WHERE id = 1', 'foreign key constraint fails');
CALL test_erwarte_fehler('Ungueltiger Gemeindeschluessel',
    'INSERT INTO ort (bundesland_id, name, ags) VALUES (12, ''Potsdam'', ''ABC'')', 'ck_ort_ags');
CALL test_erwarte_fehler('Import mit unbekanntem Bezirk',
    'SELECT fn_bezirk_id_pflicht(''Atlantis'') INTO @x', 'Bezirk nicht erkannt');
ROLLBACK;

DROP PROCEDURE test_erwarte_fehler;

SELECT nr, testfall, erwartet, ist, IF(bestanden, 'OK', 'FEHLER') AS ergebnis
FROM test_ergebnis ORDER BY nr;

-- NULL heisst: konnte nicht geprueft werden. Das zaehlen wir als Fehler.
SELECT COUNT(*) AS tests, SUM(COALESCE(bestanden, 0)) AS bestanden,
       COUNT(*) - SUM(COALESCE(bestanden, 0)) AS fehlgeschlagen,
       IF(SUM(COALESCE(bestanden, 0)) = COUNT(*), 'ALLE ORTS-TESTS BESTANDEN', 'ORTS-TESTS FEHLGESCHLAGEN') AS gesamtergebnis
FROM test_ergebnis;

DROP TEMPORARY TABLE test_ergebnis;
