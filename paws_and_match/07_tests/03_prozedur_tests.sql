-- Tests fuer Vorschlaege, Reservierung, Vermittlung und Loeschen.
-- Dafuer legen wir Testdaten ab ID 9001 an und loeschen sie am Ende wieder. Die Demodaten bleiben gleich.
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
    -- Erst die Reservierungen loesen, sonst blockiert fk_tier_reservierung das Loeschen der Bewerbungen.
    -- Bypass fuer den fail-closed Standort-Trigger (P0.2, trg_tier_standort_pruefen_update):
    -- dieses UPDATE laeuft ohne vorherigen Prozeduraufruf, direkt danach wieder zurueckgesetzt.
    SET @pm_ist_admin = 1;
    UPDATE tier SET status = 'verfuegbar', reserviert_fuer_bewerbung_id = NULL
    WHERE id >= 9001 AND reserviert_fuer_bewerbung_id IS NOT NULL;
    SET @pm_ist_admin = NULL;
    DELETE FROM vermittlung WHERE tier_id >= 9001 OR bewerbung_id >= 9001;
    DELETE FROM termin WHERE bewerbung_id >= 9001;
    DELETE FROM bewerbung WHERE id >= 9001 OR tier_id >= 9001 OR interessent_id >= 9001;
    DELETE FROM tier WHERE id >= 9001;
    DELETE FROM interessent WHERE id >= 9001;
END$$
DELIMITER ;

-- Falls ein frueherer Lauf abgebrochen ist: Reste entfernen und Ausgangszustand merken.
CALL test_aufraeumen();

SELECT MD5(CONCAT_WS('#',
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, status, COALESCE(reserviert_fuer_bewerbung_id, '-')) ORDER BY id) FROM tier),
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, interessent_id, tier_id, status, COALESCE(notiz, '-')) ORDER BY id) FROM bewerbung),
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, aktiv, pseudonym, email) ORDER BY id) FROM interessent),
    (SELECT COUNT(*) FROM vermittlung), (SELECT COUNT(*) FROM merkliste),
    (SELECT COUNT(*) FROM interessent_charakter), (SELECT COUNT(*) FROM interessent_tierart),
    (SELECT COUNT(*) FROM tier_charakter), (SELECT COUNT(*) FROM tier_beduerfnis),
    (SELECT COUNT(*) FROM tier_gesundheit),
    (SELECT SUM(gewicht) FROM matching_gewichtung),
    (SELECT SUM(wert) FROM matching_einstellung)))
INTO @fingerprint_vorher;

-- 1. Vorschlaege (kommen alle aus der View matching_vorschlaege)
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
-- P5.2: Durch die 80 neuen Demotiere (IDs 21-100) erfuellen inzwischen deutlich mehr Tiere
-- die harten Kriterien von Interessent 17 als frueher (vom Database & Matching Specialist
-- vorab korrekt vorhergesagt, siehe team/tasks.md P5.2-Zeile). Liste nach einem frischen
-- Install am 2026-11-26 per CALL sp_vorschlaege_fuer_interessent(17) real ermittelt und hier
-- uebernommen (Algorithmus nicht angepasst, reine Testfixture-Aktualisierung).
SELECT 'Vorschlaege Interessent 17 in Rangfolge', '29,22,21,54,62,28,6,11,16,30,60,61,23,26',
       COALESCE(GROUP_CONCAT(tier_id ORDER BY match_prozent DESC, datenabdeckung_prozent DESC, tier_id), '-'),
    COALESCE(GROUP_CONCAT(tier_id ORDER BY match_prozent DESC, datenabdeckung_prozent DESC, tier_id), '-') = '29,22,21,54,62,28,6,11,16,30,60,61,23,26'
FROM matching_vorschlaege WHERE interessent_id = 17;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Vorschlaege Tier 16', '17',
       COALESCE(GROUP_CONCAT(interessent_id ORDER BY interessent_id), '-'),
       COALESCE(GROUP_CONCAT(interessent_id ORDER BY interessent_id), '-') = '17'
FROM matching_vorschlaege WHERE tier_id = 16;

SET @mindestscore = (SELECT wert FROM matching_einstellung WHERE schluessel = 'mindestscore');

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Vorschlagsview entspricht den Regeln (unabhaengig nachgerechnet)',
       CONCAT(COUNT(*), ' Paare'), CONCAT((SELECT COUNT(*) FROM matching_vorschlaege), ' Paare'),
       COUNT(*) = (SELECT COUNT(*) FROM matching_vorschlaege) AND COUNT(*) > 0
       AND COUNT(*) = (SELECT COUNT(*) FROM matching_vorschlaege v
                       JOIN matching_score x ON x.tier_id = v.tier_id AND x.interessent_id = v.interessent_id
                       JOIN tier t ON t.id = x.tier_id JOIN interessent i ON i.id = x.interessent_id
                       WHERE x.eignung = 'geeignet' AND t.status = 'verfuegbar' AND i.aktiv = 1
                         AND x.match_prozent >= @mindestscore)
FROM matching_score s
JOIN tier t ON t.id = s.tier_id
JOIN interessent i ON i.id = s.interessent_id
WHERE s.eignung = 'geeignet' AND t.status = 'verfuegbar' AND i.aktiv = 1
  AND s.gewichtung_vollstaendig = 1 AND s.match_prozent >= @mindestscore;

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

-- 2. Fehlerfaelle bei den Vorschlagsprozeduren
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

-- Reserviert wird immer fuer eine konkrete Bewerbung, darum hier eine Testbewerbung.
START TRANSACTION;
INSERT INTO bewerbung (id, interessent_id, tier_id) VALUES (9101, 17, 16);
-- Bypass fuer den fail-closed Standort-Trigger (P0.2): roher UPDATE ohne Prozeduraufruf.
SET @pm_ist_admin = 1;
UPDATE tier SET status = 'reserviert', reserviert_fuer_bewerbung_id = 9101 WHERE id = 16;
SET @pm_ist_admin = NULL;
CALL test_erwarte_fehler('Nicht verfuegbares Tier', 'CALL sp_vorschlaege_fuer_tier(16)', 'nicht fuer neue Vorschlaege');
-- P5.2: gleiche Liste wie oben (Rangfolge-Test), aber ohne Tier 16 (jetzt reserviert).
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Nicht verfuegbares Tier erscheint nicht bei Interessent 17', '29,22,21,54,62,28,6,11,30,60,61,23,26',
       COALESCE(GROUP_CONCAT(tier_id ORDER BY match_prozent DESC, tier_id), '-'),
       COALESCE(GROUP_CONCAT(tier_id ORDER BY match_prozent DESC, tier_id), '-') = '29,22,21,54,62,28,6,11,30,60,61,23,26'
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

START TRANSACTION;
DELETE FROM matching_einstellung WHERE schluessel = 'mindestscore';
CALL test_erwarte_fehler('Fehlender Mindestscore', 'CALL sp_vorschlaege_fuer_interessent(17)', 'Mindestscore muss in matching_einstellung');
ROLLBACK;

-- 3. Testdaten fuer Reservierung, Vermittlung, Loeschen und Cascade anlegen

-- P0.2: fail-closed by design - ohne gesetzte Session-Variablen (@pm_mitarbeiter_id/
-- @pm_ist_admin) muss JEDER rohe INSERT/UPDATE auf tier blockieren, nicht nur bei
-- tatsaechlich abweichendem Standort. An dieser Stelle im Skript ist noch keine der beiden
-- Variablen gesetzt (NULL), genau der von einer manipulierten Anfrage simulierte Fall.
CALL test_erwarte_fehler('P0.2: Tier-Insert ohne Session-Variablen blockiert (fail-closed)',
    'INSERT INTO tier (standort_id, tierart_id, name) VALUES (1, 1, ''Testtier ohne Bypass'')',
    'Mitarbeiter gehoert nicht zum Standort des Tieres');
CALL test_erwarte_fehler('P0.2: Tier-Update ohne Session-Variablen blockiert (fail-closed)',
    'UPDATE tier SET name = ''Geaendert ohne Bypass'' WHERE id = 1', 'Mitarbeiter gehoert nicht zum Standort des Tieres');

-- Bypass fuer den fail-closed Standort-Trigger (P0.2): rohe Fixture-Inserts ohne Prozeduraufruf.
SET @pm_ist_admin = 1;
INSERT INTO tier (id, standort_id, tierart_id, name) VALUES
    (9001, 1, 1, 'Testtier A'), (9002, 1, 1, 'Testtier B'),
    (9003, 1, 1, 'Testtier C'), (9004, 1, 1, 'Testtier D'),
    (9005, 1, 1, 'Testtier E'), (9006, 1, 1, 'Testtier F');
SET @pm_ist_admin = NULL;
INSERT INTO interessent (id, pseudonym, email, bezirk_id, aktiv, wohnflaeche) VALUES
    (9001, 'Test 1', 'test9001@example.org', 1, 1, 50),
    (9002, 'Test 2', 'test9002@example.org', 1, 1, 50),
    (9003, 'Test 3', 'test9003@example.org', 1, 1, 50),
    (9004, 'Test 4', 'test9004@example.org', 1, 1, 50),
    (9005, 'Test 5', 'test9005@example.org', 1, 0, 50),
    (9006, 'Test 6', 'test9006@example.org', 1, 1, 50),
    (9007, 'Test 7', 'test9007@example.org', 1, 1, 50),
    (9008, 'Test 8', 'test9008@example.org', 1, 1, 50);
INSERT INTO bewerbung (id, interessent_id, tier_id, notiz) VALUES
    (9001, 9001, 9001, NULL), (9002, 9002, 9001, 'Testnotiz'),
    (9003, 9003, 9002, 'Persoenliche Notiz'), (9004, 9006, 9003, NULL),
    (9005, 9007, 9005, NULL), (9006, 9008, 9005, NULL),
    (9007, 9007, 9006, NULL);
INSERT INTO interessent_charakter (interessent_id, charakter_id) VALUES (9003, 1), (9004, 1);
INSERT INTO interessent_tierart (interessent_id, tierart_id) VALUES (9003, 1), (9004, 1);
INSERT INTO merkliste (interessent_id, tier_id) VALUES (9003, 9002), (9004, 9002), (9001, 9004);
INSERT INTO tier_charakter (tier_id, charakter_id) VALUES (9004, 1);
INSERT INTO tier_beduerfnis (tier_id, beduerfnis_id) VALUES (9004, 1);

-- 4. Reservierung
CALL test_erwarte_fehler('Reservieren: unbekannte Bewerbung', 'CALL sp_reservieren(99999, 1)', 'Bewerbung nicht gefunden');
CALL test_erwarte_fehler('Reservieren: Mitarbeiter anderer Standort', 'CALL sp_reservieren(9005, 2)', 'Mitarbeiter gehoert nicht zum Standort');
CALL test_erwarte_erfolg('Reservieren: gueltige Bewerbung', 'CALL sp_reservieren(9005, 1)');

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Reservierung haengt an der Bewerbung', 'reserviert / 9005 / in_pruefung',
       CONCAT(t.status, ' / ', COALESCE(t.reserviert_fuer_bewerbung_id, '-'), ' / ', b.status),
       t.status = 'reserviert' AND t.reserviert_fuer_bewerbung_id = 9005 AND b.status = 'in_pruefung'
FROM tier t JOIN bewerbung b ON b.id = 9005 WHERE t.id = 9005;

CALL test_erwarte_fehler('Reservieren: Tier schon reserviert', 'CALL sp_reservieren(9006, 1)', 'Reservierung in diesem Status nicht moeglich');
CALL test_erwarte_fehler('Vermitteln: Tier fuer andere Bewerbung reserviert', 'CALL sp_vermitteln(9006, 1)', 'fuer eine andere Bewerbung reserviert');
-- Bypass fuer den fail-closed Standort-Trigger (P0.2): beide folgenden Statements sind rohe
-- UPDATEs ohne Prozeduraufruf und sollen den jeweils erwarteten CHECK-/Reservierungs-Trigger-
-- Fehler zeigen, nicht die Standortmeldung.
SET @pm_ist_admin = 1;
CALL test_erwarte_fehler('Status reserviert ohne Bewerbung blockiert',
    'UPDATE tier SET status = ''reserviert'' WHERE id = 9006', 'ck_tier_reservierung');
CALL test_erwarte_fehler('Reservierung fuer fremde Bewerbung blockiert',
    'UPDATE tier SET reserviert_fuer_bewerbung_id = 9007 WHERE id = 9005', 'laufende Bewerbung fuer dieses Tier');
SET @pm_ist_admin = NULL;
CALL test_erwarte_fehler('Reservierung aufheben: Tier nicht reserviert', 'CALL sp_reservierung_aufheben(9006, 1)', 'Tier ist nicht reserviert');
CALL test_erwarte_fehler('Reservierung aufheben: Mitarbeiter anderer Standort', 'CALL sp_reservierung_aufheben(9005, 2)', 'Mitarbeiter gehoert nicht zum Standort');
CALL test_erwarte_erfolg('Reservierung aufheben', 'CALL sp_reservierung_aufheben(9005, 1)');

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Nach dem Aufheben ist das Tier wieder frei', 'verfuegbar / -',
       CONCAT(status, ' / ', COALESCE(reserviert_fuer_bewerbung_id, '-')),
       status = 'verfuegbar' AND reserviert_fuer_bewerbung_id IS NULL
FROM tier WHERE id = 9005;

-- 5. Vermittlung
CALL test_erwarte_fehler('Vermitteln: unbekannte Bewerbung', 'CALL sp_vermitteln(99999, 1)', 'Bewerbung nicht gefunden');
CALL test_erwarte_fehler('Vermitteln: Mitarbeiter anderer Standort', 'CALL sp_vermitteln(9001, 2)', 'Mitarbeiter gehoert nicht zum Standort');

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Fehlgeschlagene Vermittlung vollstaendig zurueckgerollt', 'verfuegbar / - / offen / 0',
       CONCAT(t.status, ' / ', COALESCE(t.reserviert_fuer_bewerbung_id, '-'), ' / ', b.status, ' / ',
              (SELECT COUNT(*) FROM vermittlung WHERE tier_id = 9001)),
       t.status = 'verfuegbar' AND t.reserviert_fuer_bewerbung_id IS NULL AND b.status = 'offen'
       AND (SELECT COUNT(*) FROM vermittlung WHERE tier_id = 9001) = 0
FROM tier t JOIN bewerbung b ON b.id = 9001 WHERE t.id = 9001;

CALL test_erwarte_fehler('Direkter Insert in vermittlung blockiert',
    'INSERT INTO vermittlung (bewerbung_id, tier_id, mitarbeiter_id) VALUES (9001, 9001, 1)', 'nur ueber sp_vermitteln');

UPDATE interessent SET aktiv = 0 WHERE id = 9006;
CALL test_erwarte_fehler('Vermitteln: inaktiver Interessent', 'CALL sp_vermitteln(9004, 1)', 'nicht aktiv');

CALL test_erwarte_erfolg('Vermitteln: gueltige Bewerbung', 'CALL sp_vermitteln(9001, 1)');

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Vermittlung: Tier, Bewerbung und Vermittlung korrekt', 'vermittelt / - / angenommen / 1',
       CONCAT(t.status, ' / ', COALESCE(t.reserviert_fuer_bewerbung_id, '-'), ' / ', b.status, ' / ',
              (SELECT COUNT(*) FROM vermittlung WHERE tier_id = 9001)),
       t.status = 'vermittelt' AND t.reserviert_fuer_bewerbung_id IS NULL AND b.status = 'angenommen'
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

-- 6. Vermittlung beenden
CALL test_erwarte_erfolg('Vermitteln fuer den Rueckgabetest', 'CALL sp_vermitteln(9007, 1)');
SET @vermittlung_9006 = (SELECT id FROM vermittlung WHERE bewerbung_id = 9007);

CALL test_erwarte_fehler('Beenden: unbekannte Vermittlung',
    'CALL sp_vermittlung_beenden(99999, 1, ''rueckgabe'', NULL)', 'Vermittlung nicht gefunden');
CALL test_erwarte_fehler('Beenden: ungueltiger Grund',
    CONCAT('CALL sp_vermittlung_beenden(', @vermittlung_9006, ', 1, ''egal'', NULL)'), 'Beendigungsgrund muss');
CALL test_erwarte_fehler('Beenden: Mitarbeiter anderer Standort',
    CONCAT('CALL sp_vermittlung_beenden(', @vermittlung_9006, ', 2, ''rueckgabe'', NULL)'), 'Mitarbeiter gehoert nicht zum Standort');
CALL test_erwarte_fehler('Vermittlung von Hand beenden blockiert',
    CONCAT('UPDATE vermittlung SET beendet_am = NOW(), beendigungsgrund = ''rueckgabe'' WHERE id = ', @vermittlung_9006),
    'nur ueber sp_vermittlung_beenden');

CALL test_erwarte_erfolg('Vermittlung beenden (Rueckgabe)',
    CONCAT('CALL sp_vermittlung_beenden(', @vermittlung_9006, ', 1, ''rueckgabe'', ''Testrueckgabe'')'));

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Rueckgabe: Tier wieder verfuegbar, Vorgang beendet', 'verfuegbar / - / rueckgabe / beendet / Notiz ergaenzt',
       CONCAT(t.status, ' / ', COALESCE(t.reserviert_fuer_bewerbung_id, '-'), ' / ',
              COALESCE(v.beendigungsgrund, '-'), ' / ', IF(v.beendet_am IS NULL, 'offen', 'beendet'), ' / ',
              COALESCE(v.notiz, '-')),
       t.status = 'verfuegbar' AND t.reserviert_fuer_bewerbung_id IS NULL
       AND v.beendigungsgrund = 'rueckgabe' AND v.beendet_am IS NOT NULL
       AND v.aktives_tier IS NULL
       AND v.notiz LIKE '%Beendet: rueckgabe | Testrueckgabe%'
FROM tier t JOIN vermittlung v ON v.id = @vermittlung_9006 WHERE t.id = 9006;

CALL test_erwarte_fehler('Beenden: schon beendet',
    CONCAT('CALL sp_vermittlung_beenden(', @vermittlung_9006, ', 1, ''rueckgabe'', NULL)'), 'bereits beendet');
CALL test_erwarte_fehler('Beendete Vermittlung wieder oeffnen blockiert',
    CONCAT('UPDATE vermittlung SET beendet_am = NULL, beendigungsgrund = NULL WHERE id = ', @vermittlung_9006),
    'nicht wieder geoeffnet werden');

-- Nach der Rueckgabe darf dasselbe Tier erneut vermittelt werden (uq_vermittlung_aktives_tier ist frei).
INSERT INTO bewerbung (id, interessent_id, tier_id) VALUES (9008, 9008, 9006);
CALL test_erwarte_erfolg('Zurueckgegebenes Tier erneut vermitteln', 'CALL sp_vermitteln(9008, 1)');
SET @vermittlung_9006_neu = (SELECT id FROM vermittlung WHERE bewerbung_id = 9008);

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Zwei Vermittlungen, aber nur eine aktive', '2 / 1',
       CONCAT(COUNT(*), ' / ', SUM(aktives_tier IS NOT NULL)),
       COUNT(*) = 2 AND SUM(aktives_tier IS NOT NULL) = 1
FROM vermittlung WHERE tier_id = 9006;

CALL test_erwarte_erfolg('Vermittlung beenden (verstorben)',
    CONCAT('CALL sp_vermittlung_beenden(', @vermittlung_9006_neu, ', 1, ''verstorben'', NULL)'));

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Nur eine Rueckgabe macht das Tier wieder verfuegbar', 'nicht_vermittelbar',
       status, status = 'nicht_vermittelbar'
FROM tier WHERE id = 9006;

-- 7. Loeschen und Anonymisieren
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

-- 7b. Stale-Reservierung: ein Interessent mit einer aktiven Reservierung wird geloescht/
-- anonymisiert - das reservierte Tier muss wieder freigegeben werden, statt mit einem toten
-- Bewerbung-Verweis 'reserviert' stehen zu bleiben (Regressionstest fuer den P2-2-Fix in
-- 05_prozeduren/07_interessent_loeschen.sql).
-- Bypass fuer den fail-closed Standort-Trigger (P0.2): roher Fixture-Insert ohne Prozeduraufruf.
SET @pm_ist_admin = 1;
INSERT INTO tier (id, standort_id, tierart_id, name) VALUES (9009, 1, 1, 'Testtier G');
SET @pm_ist_admin = NULL;
INSERT INTO interessent (id, pseudonym, email, bezirk_id, aktiv, wohnflaeche) VALUES
    (9009, 'Test 9', 'test9009@example.org', 1, 1, 50);
INSERT INTO bewerbung (id, interessent_id, tier_id) VALUES (9009, 9009, 9009);
CALL test_erwarte_erfolg('Reservieren fuer Stale-Reservierungstest', 'CALL sp_reservieren(9009, 1)');

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Vor dem Loeschen: Tier reserviert', 'reserviert / 9009',
       CONCAT(status, ' / ', COALESCE(reserviert_fuer_bewerbung_id, '-')),
       status = 'reserviert' AND reserviert_fuer_bewerbung_id = 9009
FROM tier WHERE id = 9009;

CALL test_erwarte_erfolg('Loeschen gibt reservierte Tiere frei (stale-Reservierung)', 'CALL sp_interessent_loeschen(9009, @erg_9009)');

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Nach dem Loeschen: Tier wieder verfuegbar, Bewerbung zurueckgezogen', 'anonymisiert / verfuegbar / - / zurueckgezogen',
       CONCAT(@erg_9009, ' / ', t.status, ' / ', COALESCE(t.reserviert_fuer_bewerbung_id, '-'), ' / ', b.status),
       @erg_9009 = 'anonymisiert' AND t.status = 'verfuegbar' AND t.reserviert_fuer_bewerbung_id IS NULL
       AND b.status = 'zurueckgezogen'
FROM tier t JOIN bewerbung b ON b.id = 9009 WHERE t.id = 9009;

-- 7c. sp_tier_loeschen (P0.3): Hard-Delete ohne Historie, Archivierung mit Historie
-- (inkl. vorher reserviertem Tier), Standort-/Admin-Pruefung.
SET @pm_ist_admin = 1;
INSERT INTO tier (id, standort_id, tierart_id, name) VALUES
    (9010, 1, 1, 'Testtier H'), (9011, 1, 1, 'Testtier I'),
    (9012, 1, 1, 'Testtier J'), (9013, 1, 1, 'Testtier K');
SET @pm_ist_admin = NULL;
INSERT INTO interessent (id, pseudonym, email, bezirk_id, aktiv, wohnflaeche) VALUES
    (9010, 'Test 10', 'test9010@example.org', 1, 1, 50),
    (9011, 'Test 11', 'test9011@example.org', 1, 1, 50);
INSERT INTO bewerbung (id, interessent_id, tier_id) VALUES
    (9010, 9010, 9011), (9011, 9011, 9012);

CALL test_erwarte_fehler('Tier loeschen: ID NULL', 'CALL sp_tier_loeschen(NULL, 1, 0, @erg_tl)', 'positive Tier-ID');
CALL test_erwarte_fehler('Tier loeschen: unbekannte ID', 'CALL sp_tier_loeschen(99999, 1, 0, @erg_tl)', 'Tier nicht gefunden');

CALL test_erwarte_erfolg('Tier ohne Historie loeschen laeuft', 'CALL sp_tier_loeschen(9010, 1, 0, @erg_9010)');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Tier ohne Historie: hart geloescht', 'geloescht / 0',
       CONCAT(@erg_9010, ' / ', (SELECT COUNT(*) FROM tier WHERE id = 9010)),
       @erg_9010 = 'geloescht' AND (SELECT COUNT(*) FROM tier WHERE id = 9010) = 0;

CALL test_erwarte_erfolg('Tier mit Historie archivieren laeuft', 'CALL sp_tier_loeschen(9011, 1, 0, @erg_9011)');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Tier mit Historie: archiviert, Zeile bleibt, Bewerbung unveraendert', 'archiviert / geloescht / offen',
       CONCAT(@erg_9011, ' / ', t.status, ' / ', b.status),
       @erg_9011 = 'archiviert' AND t.status = 'geloescht' AND b.status = 'offen'
FROM tier t JOIN bewerbung b ON b.id = 9010 WHERE t.id = 9011;

-- Reserviertes Tier mit Historie: sp_tier_loeschen muss die Reservierung zuerst freigeben,
-- sonst wuerde der folgende Statuswechsel auf 'geloescht' ck_tier_reservierung verletzen.
CALL test_erwarte_erfolg('Reservieren fuer sp_tier_loeschen-Test', 'CALL sp_reservieren(9011, 1)');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Vor dem Loeschen: Tier reserviert', 'reserviert / 9011',
       CONCAT(status, ' / ', COALESCE(reserviert_fuer_bewerbung_id, '-')),
       status = 'reserviert' AND reserviert_fuer_bewerbung_id = 9011
FROM tier WHERE id = 9012;

CALL test_erwarte_erfolg('Reserviertes Tier mit Historie archivieren laeuft', 'CALL sp_tier_loeschen(9012, 1, 0, @erg_9012)');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Reserviertes Tier: archiviert, Reservierung freigegeben, kein ck_tier_reservierung-Verstoss',
       'archiviert / geloescht / -',
       CONCAT(@erg_9012, ' / ', status, ' / ', COALESCE(reserviert_fuer_bewerbung_id, '-')),
       @erg_9012 = 'archiviert' AND status = 'geloescht' AND reserviert_fuer_bewerbung_id IS NULL
FROM tier WHERE id = 9012;

CALL test_erwarte_fehler('Tier loeschen: Mitarbeiter anderer Standort', 'CALL sp_tier_loeschen(9013, 2, 0, @erg_tl2)', 'Mitarbeiter gehoert nicht zum Standort');
CALL test_erwarte_erfolg('Tier loeschen: Admin darf fremden Standort', 'CALL sp_tier_loeschen(9013, 2, 1, @erg_9013)');
INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
SELECT 'Admin-Loeschung ueber Standortgrenze hinweg: hart geloescht', 'geloescht / 0',
       CONCAT(@erg_9013, ' / ', (SELECT COUNT(*) FROM tier WHERE id = 9013)),
       @erg_9013 = 'geloescht' AND (SELECT COUNT(*) FROM tier WHERE id = 9013) = 0;

-- 8. Tiere: Historie ist geschuetzt, Zusatzdaten gehen per Cascade mit
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

-- 9. Aufraeumen und pruefen, ob die Demodaten noch genauso aussehen wie vorher
CALL test_aufraeumen();
ALTER TABLE tier AUTO_INCREMENT = 1;
ALTER TABLE interessent AUTO_INCREMENT = 1;
ALTER TABLE bewerbung AUTO_INCREMENT = 1;
ALTER TABLE vermittlung AUTO_INCREMENT = 1;

SELECT MD5(CONCAT_WS('#',
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, status, COALESCE(reserviert_fuer_bewerbung_id, '-')) ORDER BY id) FROM tier),
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, interessent_id, tier_id, status, COALESCE(notiz, '-')) ORDER BY id) FROM bewerbung),
    (SELECT GROUP_CONCAT(CONCAT_WS(':', id, aktiv, pseudonym, email) ORDER BY id) FROM interessent),
    (SELECT COUNT(*) FROM vermittlung), (SELECT COUNT(*) FROM merkliste),
    (SELECT COUNT(*) FROM interessent_charakter), (SELECT COUNT(*) FROM interessent_tierart),
    (SELECT COUNT(*) FROM tier_charakter), (SELECT COUNT(*) FROM tier_beduerfnis),
    (SELECT COUNT(*) FROM tier_gesundheit),
    (SELECT SUM(gewicht) FROM matching_gewichtung),
    (SELECT SUM(wert) FROM matching_einstellung)))
INTO @fingerprint_nachher;

INSERT INTO test_ergebnis (testfall, erwartet, ist, bestanden)
VALUES ('Demodaten nach den Tests unveraendert', @fingerprint_vorher, @fingerprint_nachher,
        @fingerprint_vorher = @fingerprint_nachher);

DROP PROCEDURE test_erwarte_fehler;
DROP PROCEDURE test_erwarte_erfolg;
DROP PROCEDURE test_aufraeumen;

SELECT nr, testfall, erwartet, ist, IF(bestanden, 'OK', 'FEHLER') AS ergebnis
FROM test_ergebnis ORDER BY nr;

-- NULL heisst: konnte nicht geprueft werden. Das zaehlen wir als Fehler.
SELECT COUNT(*) AS tests, SUM(COALESCE(bestanden, 0)) AS bestanden,
       COUNT(*) - SUM(COALESCE(bestanden, 0)) AS fehlgeschlagen,
       IF(SUM(COALESCE(bestanden, 0)) = COUNT(*), 'ALLE PROZEDUR-TESTS BESTANDEN', 'PROZEDUR-TESTS FEHLGESCHLAGEN') AS gesamtergebnis
FROM test_ergebnis;

DROP TEMPORARY TABLE test_ergebnis;