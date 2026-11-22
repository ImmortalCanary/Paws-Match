USE paws_match;
SET NAMES utf8mb4;
SET SESSION group_concat_max_len = 65535;

-- Automatische Assertions fuer Vorschlags-, Vermittlungs- und Loeschprozeduren.
-- Testdaten mit IDs ab 9001 werden angelegt und wieder entfernt; Demodaten bleiben unveraendert.

-- MEMORY-Tabelle, damit Ergebnisse ein ROLLBACK ueberstehen.
DROP TEMPORARY TABLE IF EXISTS test_ergebnis;
CREATE TEMPORARY TABLE test_ergebnis (
    nr INT AUTO_INCREMENT PRIMARY KEY,
    testfall VARCHAR(200) NOT NULL,
    erwartet VARCHAR(500),
    ist VARCHAR(500),
    bestanden BOOLEAN
) ENGINE = MEMORY;

DROP PROCEDURE IF EXISTS test_erwarte_fehler;
DROP PROCEDURE IF EXISTS test_erwarte_erfolg;
DROP PROCEDURE IF EXISTS test_aufraeumen;

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

CREATE PROCEDURE test_erwarte_erfolg (IN p_testfall VARCHAR(200), IN p_sql TEXT)
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
    VALUES (p_testfall, 'kein Fehler', COALESCE(v_meldung, 'kein Fehler'), v_sqlstate IS NULL);
END$$

CREATE PROCEDURE test_aufraeumen ()
BEGIN
    DELETE FROM vermittlung WHERE tier_id >= 9001 OR bewerbung_id >= 9001;
    DELETE FROM termin WHERE bewerbung_id >= 9001;
    DELETE FROM bewerbung WHERE id >= 9001 OR tier_id >= 9001 OR interessent_id >= 9001;
    DELETE FROM tier WHERE id >= 9001;
    DELETE FROM interessent WHERE id >= 9001;
END$$
DELIMITER ;

-- Reste eines abgebrochenen Laufs entfernen und Ausgangszustand festhalten.
CALL test_aufraeumen();

SELECT MD5(CONCAT_WS('#',
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, status) ORDER BY id) FROM tier),
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, interessent_id, tier_id, status, COALESCE(notiz, '-')) ORDER BY id) FROM bewerbung),
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, aktiv, pseudonym, email) ORDER BY id) FROM interessent),
    (SELECT COUNT(*) FROM vermittlung), (SELECT COUNT(*) FROM merkliste),
    (SELECT COUNT(*) FROM interessent_charakter), (SELECT COUNT(*) FROM interessent_tierart),
    (SELECT COUNT(*) FROM tier_charakter), (SELECT COUNT(*) FROM tier_beduerfnis),
    (SELECT SUM(gewicht) FROM matching_gewichtung)))
INTO @fingerprint_vorher;

-- 1. Vorschlaege (einzige Quelle: matching_vorschlaege)
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Vorschlaege Interessent 17 in Rangfolge', '6,11,16,8,13',
       COALESCE(GROUP_CONCAT(tier_id ORDER BY match_prozent DESC, datenabdeckung_prozent DESC, tier_id), '-'),
       COALESCE(GROUP_CONCAT(tier_id ORDER BY match_prozent DESC, datenabdeckung_prozent DESC, tier_id), '-') = '6,11,16,8,13'
FROM matching_vorschlaege WHERE interessent_id = 17;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Vorschlaege Tier 16', '17',
       COALESCE(GROUP_CONCAT(interessent_id ORDER BY interessent_id), '-'),
       COALESCE(GROUP_CONCAT(interessent_id ORDER BY interessent_id), '-') = '17'
FROM matching_vorschlaege WHERE tier_id = 16;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Vorschlagsview entspricht den Regeln (unabhaengig nachgerechnet)',
       CONCAT(COUNT(*), ' Paare'), CONCAT((SELECT COUNT(*) FROM matching_vorschlaege), ' Paare'),
       COUNT(*) = (SELECT COUNT(*) FROM matching_vorschlaege) AND COUNT(*) > 0
       AND COUNT(*) = (SELECT COUNT(*) FROM matching_vorschlaege v
                       JOIN matching_score x ON x.tier_id = v.tier_id AND x.interessent_id = v.interessent_id
                       JOIN tier t ON t.id = x.tier_id JOIN interessent i ON i.id = x.interessent_id
                       WHERE x.eignung = 'geeignet' AND t.status = 'verfuegbar' AND i.aktiv = 1
                         AND x.match_prozent >= 50)
FROM matching_score s
JOIN tier t ON t.id = s.tier_id
JOIN interessent i ON i.id = s.interessent_id
WHERE s.eignung = 'geeignet' AND t.status = 'verfuegbar' AND i.aktiv = 1
  AND s.gewichtung_vollstaendig = 1 AND s.match_prozent >= 50;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Beide Vorschlagsprozeduren lesen aus matching_vorschlaege', '2', CONCAT(COUNT(*)), COUNT(*) = 2
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'paws_match'
  AND ROUTINE_NAME IN ('sp_vorschlaege_fuer_interessent', 'sp_vorschlaege_fuer_tier')
  AND ROUTINE_DEFINITION LIKE '%FROM matching_vorschlaege%';

CALL test_erwarte_erfolg('sp_vorschlaege_fuer_interessent(17) laeuft', 'CALL sp_vorschlaege_fuer_interessent(17)');
CALL test_erwarte_erfolg('sp_vorschlaege_fuer_tier(16) laeuft', 'CALL sp_vorschlaege_fuer_tier(16)');

SET @textlimit_vorher = @@SESSION.group_concat_max_len;
CALL sp_vorschlaege_fuer_interessent(1);
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
VALUES ('Prozedur veraendert keine Sitzungsvariablen', CONCAT(@textlimit_vorher),
        CONCAT(@@SESSION.group_concat_max_len), @@SESSION.group_concat_max_len = @textlimit_vorher);

-- 2. Fehlerfaelle der Vorschlagsprozeduren
CALL test_erwarte_fehler('Interessent NULL', 'CALL sp_vorschlaege_fuer_interessent(NULL)', 'positive Interessenten-ID');
CALL test_erwarte_fehler('Interessent 0', 'CALL sp_vorschlaege_fuer_interessent(0)', 'positive Interessenten-ID');
CALL test_erwarte_fehler('Interessent -1', 'CALL sp_vorschlaege_fuer_interessent(-1)', 'positive Interessenten-ID');
CALL test_erwarte_fehler('Interessent unbekannt', 'CALL sp_vorschlaege_fuer_interessent(99999)', 'Interessentenprofil nicht gefunden');
CALL test_erwarte_fehler('Tier NULL', 'CALL sp_vorschlaege_fuer_tier(NULL)', 'positive Tier-ID');
CALL test_erwarte_fehler('Tier 0', 'CALL sp_vorschlaege_fuer_tier(0)', 'positive Tier-ID');
CALL test_erwarte_fehler('Tier -1', 'CALL sp_vorschlaege_fuer_tier(-1)', 'positive Tier-ID');
CALL test_erwarte_fehler('Tier unbekannt', 'CALL sp_vorschlaege_fuer_tier(99999)', 'Tier nicht gefunden');

START TRANSACTION;
UPDATE interessent SET aktiv = 0 WHERE id = 17;
CALL test_erwarte_fehler('Inaktiver Interessent', 'CALL sp_vorschlaege_fuer_interessent(17)', 'nicht aktiv');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Inaktiver Interessent erscheint nicht bei Tier 16', '0', CONCAT(COUNT(*)), COUNT(*) = 0
FROM matching_vorschlaege WHERE tier_id = 16;
ROLLBACK;

START TRANSACTION;
UPDATE tier SET status = 'reserviert' WHERE id = 16;
CALL test_erwarte_fehler('Nicht verfuegbares Tier', 'CALL sp_vorschlaege_fuer_tier(16)', 'nicht fuer neue Vorschlaege');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Nicht verfuegbares Tier erscheint nicht bei Interessent 17', '6,11,8,13',
       COALESCE(GROUP_CONCAT(tier_id ORDER BY match_prozent DESC, tier_id), '-'),
       COALESCE(GROUP_CONCAT(tier_id ORDER BY match_prozent DESC, tier_id), '-') = '6,11,8,13'
FROM matching_vorschlaege WHERE interessent_id = 17;
ROLLBACK;

START TRANSACTION;
UPDATE matching_gewichtung SET gewicht = 25 WHERE kriterium = 'Tierart';
CALL test_erwarte_fehler('Gewichtssumme ungleich 100 (Interessent)', 'CALL sp_vorschlaege_fuer_interessent(17)', '100 ergeben');
CALL test_erwarte_fehler('Gewichtssumme ungleich 100 (Tier)', 'CALL sp_vorschlaege_fuer_tier(16)', '100 ergeben');
ROLLBACK;

START TRANSACTION;
DELETE FROM matching_gewichtung WHERE kriterium = 'Naehe';
CALL test_erwarte_fehler('Fehlendes Gewicht', 'CALL sp_vorschlaege_fuer_interessent(17)', '100 ergeben');
ROLLBACK;

-- 3. Testdaten fuer Vermittlung, Loeschung und Cascade
INSERT INTO tier (id, standort_id, tierart_id, name) VALUES
    (9001, 1, 1, 'Testtier A'), (9002, 1, 1, 'Testtier B'),
    (9003, 1, 1, 'Testtier C'), (9004, 1, 1, 'Testtier D');
INSERT INTO interessent (id, pseudonym, email, bezirk_id, aktiv, wohnflaeche) VALUES
    (9001, 'Test 1', 'test9001@example.org', 1, 1, 50),
    (9002, 'Test 2', 'test9002@example.org', 1, 1, 50),
    (9003, 'Test 3', 'test9003@example.org', 1, 1, 50),
    (9004, 'Test 4', 'test9004@example.org', 1, 1, 50),
    (9005, 'Test 5', 'test9005@example.org', 1, 0, 50),
    (9006, 'Test 6', 'test9006@example.org', 1, 1, 50);
INSERT INTO bewerbung (id, interessent_id, tier_id, notiz) VALUES
    (9001, 9001, 9001, NULL), (9002, 9002, 9001, 'Testnotiz'),
    (9003, 9003, 9002, 'Persoenliche Notiz'), (9004, 9006, 9003, NULL);
INSERT INTO interessent_charakter (interessent_id, charakter_id) VALUES (9003, 1), (9004, 1);
INSERT INTO interessent_tierart (interessent_id, tierart_id) VALUES (9003, 1), (9004, 1);
INSERT INTO merkliste (interessent_id, tier_id) VALUES (9003, 9002), (9004, 9002), (9001, 9004);
INSERT INTO tier_charakter (tier_id, charakter_id) VALUES (9004, 1);
INSERT INTO tier_beduerfnis (tier_id, beduerfnis_id) VALUES (9004, 1);

-- 4. Vermittlung
CALL test_erwarte_fehler('Vermitteln: unbekannte Bewerbung', 'CALL sp_vermitteln(99999, 1)', 'Bewerbung nicht gefunden');
CALL test_erwarte_fehler('Vermitteln: Mitarbeiter anderer Standort', 'CALL sp_vermitteln(9001, 2)', 'Mitarbeiter gehoert nicht zum Standort');

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Fehlgeschlagene Vermittlung vollstaendig zurueckgerollt', 'verfuegbar / offen / 0',
       CONCAT(t.status, ' / ', b.status, ' / ', (SELECT COUNT(*) FROM vermittlung WHERE tier_id = 9001)),
       t.status = 'verfuegbar' AND b.status = 'offen' AND (SELECT COUNT(*) FROM vermittlung WHERE tier_id = 9001) = 0
FROM tier t JOIN bewerbung b ON b.id = 9001 WHERE t.id = 9001;

CALL test_erwarte_fehler('Direkter Insert in vermittlung blockiert',
    'INSERT INTO vermittlung (bewerbung_id, tier_id, mitarbeiter_id) VALUES (9001, 9001, 1)', 'nur ueber sp_vermitteln');

UPDATE interessent SET aktiv = 0 WHERE id = 9006;
CALL test_erwarte_fehler('Vermitteln: inaktiver Interessent', 'CALL sp_vermitteln(9004, 1)', 'nicht aktiv');

CALL test_erwarte_erfolg('Vermitteln: gueltige Bewerbung', 'CALL sp_vermitteln(9001, 1)');

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Vermittlung: Tier, Bewerbung und Vermittlung korrekt', 'vermittelt / angenommen / 1',
       CONCAT(t.status, ' / ', b.status, ' / ', (SELECT COUNT(*) FROM vermittlung WHERE tier_id = 9001)),
       t.status = 'vermittelt' AND b.status = 'angenommen'
       AND (SELECT COUNT(*) FROM vermittlung WHERE tier_id = 9001 AND bewerbung_id = 9001 AND mitarbeiter_id = 1) = 1
FROM tier t JOIN bewerbung b ON b.id = 9001 WHERE t.id = 9001;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Konkurrierende Bewerbung automatisch abgelehnt', 'abgelehnt, Notiz ergaenzt',
       CONCAT(status, ', ', COALESCE(notiz, '-')),
       status = 'abgelehnt' AND notiz LIKE 'Testnotiz | %anderweitig vermittelt%'
FROM bewerbung WHERE id = 9002;

CALL test_erwarte_fehler('Vermitteln: Tier bereits vermittelt', 'CALL sp_vermitteln(9002, 1)', 'in diesem Status');
CALL test_erwarte_fehler('Bewerbung auf vermitteltes Tier blockiert',
    'INSERT INTO bewerbung (interessent_id, tier_id) VALUES (9004, 9001)', 'Tier ist nicht verfuegbar');
CALL test_erwarte_fehler('Bewerbung inaktiver Interessent blockiert',
    'INSERT INTO bewerbung (interessent_id, tier_id) VALUES (9005, 9002)', 'nicht aktiv');

-- 5. Loeschstrategie
CALL test_erwarte_fehler('Loeschen: ID NULL', 'CALL sp_interessent_loeschen(NULL, @erg)', 'positive Interessenten-ID');
CALL test_erwarte_fehler('Loeschen: unbekannte ID', 'CALL sp_interessent_loeschen(99999, @erg)', 'nicht gefunden');

CALL test_erwarte_erfolg('Loeschen mit Historie laeuft', 'CALL sp_interessent_loeschen(9003, @erg_9003)');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Mit Historie: anonymisiert, Bewerbung bleibt erhalten',
       'anonymisiert / 0 / anonymisiert-9003@paws-match.invalid / zurueckgezogen ohne Notiz / 0 Profildaten',
       CONCAT(@erg_9003, ' / ', i.aktiv, ' / ', i.email, ' / ', b.status, ' ', COALESCE(b.notiz, 'ohne Notiz'), ' / ',
              (SELECT COUNT(*) FROM interessent_charakter WHERE interessent_id = 9003)
              + (SELECT COUNT(*) FROM interessent_tierart WHERE interessent_id = 9003)
              + (SELECT COUNT(*) FROM merkliste WHERE interessent_id = 9003), ' Profildaten'),
       @erg_9003 = 'anonymisiert' AND i.aktiv = 0 AND i.email = 'anonymisiert-9003@paws-match.invalid'
       AND i.pseudonym = 'Anonymisiert 9003' AND i.wohnflaeche IS NULL AND i.bezirk_id IS NULL
       AND b.status = 'zurueckgezogen' AND b.notiz IS NULL
       AND (SELECT COUNT(*) FROM interessent_charakter WHERE interessent_id = 9003)
           + (SELECT COUNT(*) FROM interessent_tierart WHERE interessent_id = 9003)
           + (SELECT COUNT(*) FROM merkliste WHERE interessent_id = 9003) = 0
FROM interessent i JOIN bewerbung b ON b.interessent_id = i.id WHERE i.id = 9003;

CALL test_erwarte_erfolg('Loeschen ohne Historie laeuft', 'CALL sp_interessent_loeschen(9004, @erg_9004)');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Ohne Historie: geloescht inkl. abhaengiger Profildaten (Cascade)', 'geloescht / 0 / 0',
       CONCAT(@erg_9004, ' / ', (SELECT COUNT(*) FROM interessent WHERE id = 9004), ' / ',
              (SELECT COUNT(*) FROM interessent_charakter WHERE interessent_id = 9004)
              + (SELECT COUNT(*) FROM interessent_tierart WHERE interessent_id = 9004)
              + (SELECT COUNT(*) FROM merkliste WHERE interessent_id = 9004)),
       @erg_9004 = 'geloescht'
       AND (SELECT COUNT(*) FROM interessent WHERE id = 9004) = 0
       AND (SELECT COUNT(*) FROM interessent_charakter WHERE interessent_id = 9004)
           + (SELECT COUNT(*) FROM interessent_tierart WHERE interessent_id = 9004)
           + (SELECT COUNT(*) FROM merkliste WHERE interessent_id = 9004) = 0;

-- 6. Tiere: Historie geschuetzt, abhaengige Profildaten per Cascade
CALL test_erwarte_fehler('Tier mit Bewerbungshistorie nicht loeschbar', 'DELETE FROM tier WHERE id = 9002', 'foreign key constraint fails');
CALL test_erwarte_erfolg('Tier ohne Historie loeschbar', 'DELETE FROM tier WHERE id = 9004');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Tier geloescht inkl. Charakter, Beduerfnis und Merkliste', '0',
       CONCAT((SELECT COUNT(*) FROM tier_charakter WHERE tier_id = 9004)
              + (SELECT COUNT(*) FROM tier_beduerfnis WHERE tier_id = 9004)
              + (SELECT COUNT(*) FROM merkliste WHERE tier_id = 9004)),
       (SELECT COUNT(*) FROM tier_charakter WHERE tier_id = 9004)
       + (SELECT COUNT(*) FROM tier_beduerfnis WHERE tier_id = 9004)
       + (SELECT COUNT(*) FROM merkliste WHERE tier_id = 9004) = 0;

-- 7. Aufraeumen und pruefen, dass die Demodaten unveraendert sind
CALL test_aufraeumen();
ALTER TABLE tier AUTO_INCREMENT = 1;
ALTER TABLE interessent AUTO_INCREMENT = 1;
ALTER TABLE bewerbung AUTO_INCREMENT = 1;
ALTER TABLE vermittlung AUTO_INCREMENT = 1;

SELECT MD5(CONCAT_WS('#',
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, status) ORDER BY id) FROM tier),
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, interessent_id, tier_id, status, COALESCE(notiz, '-')) ORDER BY id) FROM bewerbung),
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, aktiv, pseudonym, email) ORDER BY id) FROM interessent),
    (SELECT COUNT(*) FROM vermittlung), (SELECT COUNT(*) FROM merkliste),
    (SELECT COUNT(*) FROM interessent_charakter), (SELECT COUNT(*) FROM interessent_tierart),
    (SELECT COUNT(*) FROM tier_charakter), (SELECT COUNT(*) FROM tier_beduerfnis),
    (SELECT SUM(gewicht) FROM matching_gewichtung)))
INTO @fingerprint_nachher;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
VALUES ('Demodaten nach den Tests unveraendert', @fingerprint_vorher, @fingerprint_nachher,
        @fingerprint_vorher = @fingerprint_nachher);

DROP PROCEDURE test_erwarte_fehler;
DROP PROCEDURE test_erwarte_erfolg;
DROP PROCEDURE test_aufraeumen;

SELECT nr, testfall, erwartet, ist, IF(bestanden, 'OK', 'FEHLER') AS ergebnis
FROM test_ergebnis ORDER BY nr;

-- NULL (nicht auswertbar) zaehlt als Fehler.
SELECT COUNT(*) AS tests, SUM(COALESCE(bestanden, 0)) AS bestanden,
       COUNT(*) - SUM(COALESCE(bestanden, 0)) AS fehlgeschlagen,
       IF(SUM(COALESCE(bestanden, 0)) = COUNT(*), 'ALLE PROZEDUR-TESTS BESTANDEN', 'PROZEDUR-TESTS FEHLGESCHLAGEN') AS gesamtergebnis
FROM test_ergebnis;

DROP TEMPORARY TABLE test_ergebnis;
