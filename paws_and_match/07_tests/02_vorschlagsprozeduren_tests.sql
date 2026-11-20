USE paws_match;
SET NAMES utf8mb4;

-- Nur lesende Tests; keine Fachdaten oder Datenbankobjekte aendern.
-- Soll- und Istlisten manuell vergleichen. Keine automatische Assertion.
SET @test_interessent = NULL;
SET @test_tier = NULL;
SET @textlimit_vor_test = @@SESSION.group_concat_max_len;
SET SESSION group_concat_max_len = 65535;

SELECT s.interessent_id, s.tier_id
INTO @test_interessent, @test_tier
FROM matching_score s
JOIN interessent i ON i.id = s.interessent_id
JOIN tier t ON t.id = s.tier_id
JOIN tierart ta ON ta.id = t.tierart_id
JOIN standort st ON st.id = t.standort_id
WHERE i.aktiv = 1
  AND s.interessent_aktiv = 1
  AND s.eignung = 'geeignet'
  AND s.tier_verfuegbar = 1
  AND s.tierstatus = 'verfuegbar'
  AND s.gewichtung_vollstaendig = 1
  AND s.match_prozent >= 50.00
ORDER BY s.interessent_id, s.tier_id
LIMIT 1;

SELECT @test_interessent AS test_interessent, @test_tier AS test_tier,
       IF(@test_interessent IS NULL,
          'UEBERSPRUNGEN: Kein geeignetes Testpaar vorhanden; kein Erfolgsnachweis.',
          'BEREIT: Soll- und Istlisten vergleichen.') AS teststatus;

SELECT 'SOLL: Tiere fuer den Testinteressenten' AS testabschnitt;
SELECT s.tier_id, s.interessent_id, s.match_prozent, s.datenabdeckung_prozent
FROM matching_score s
JOIN interessent i ON i.id = s.interessent_id
JOIN tier t ON t.id = s.tier_id
JOIN tierart ta ON ta.id = t.tierart_id
JOIN standort st ON st.id = t.standort_id
WHERE s.interessent_id = @test_interessent
  AND i.aktiv = 1 AND s.interessent_aktiv = 1
  AND s.eignung = 'geeignet' AND s.tier_verfuegbar = 1
  AND s.tierstatus = 'verfuegbar' AND s.gewichtung_vollstaendig = 1
  AND s.match_prozent >= 50.00
ORDER BY s.match_prozent DESC, s.datenabdeckung_prozent DESC, s.tier_id;

SET SESSION group_concat_max_len = @textlimit_vor_test;
SET @test_sql = IF(@test_interessent IS NULL,
    'SELECT ''UEBERSPRUNGEN: Kein Testinteressent'' AS teststatus',
    'CALL sp_vorschlaege_fuer_interessent(@test_interessent)');
PREPARE vorschlagstest FROM @test_sql;
EXECUTE vorschlagstest;
DEALLOCATE PREPARE vorschlagstest;
SELECT IF(@@SESSION.group_concat_max_len = @textlimit_vor_test,
          'OK', 'FEHLER') AS textlimit_nach_tiervorschlaegen;

SET SESSION group_concat_max_len = 65535;
SELECT 'SOLL: Interessenten fuer das Testtier' AS testabschnitt;
SELECT s.tier_id, s.interessent_id, s.match_prozent, s.datenabdeckung_prozent
FROM matching_score s
JOIN interessent i ON i.id = s.interessent_id
JOIN tier t ON t.id = s.tier_id
JOIN tierart ta ON ta.id = t.tierart_id
JOIN standort st ON st.id = t.standort_id
WHERE s.tier_id = @test_tier
  AND i.aktiv = 1 AND s.interessent_aktiv = 1
  AND s.eignung = 'geeignet' AND s.tier_verfuegbar = 1
  AND s.tierstatus = 'verfuegbar' AND s.gewichtung_vollstaendig = 1
  AND s.match_prozent >= 50.00
ORDER BY s.match_prozent DESC, s.datenabdeckung_prozent DESC, s.interessent_id;

SET SESSION group_concat_max_len = @textlimit_vor_test;
SET @test_sql = IF(@test_tier IS NULL,
    'SELECT ''UEBERSPRUNGEN: Kein Testtier'' AS teststatus',
    'CALL sp_vorschlaege_fuer_tier(@test_tier)');
PREPARE vorschlagstest FROM @test_sql;
EXECUTE vorschlagstest;
DEALLOCATE PREPARE vorschlagstest;
SELECT IF(@@SESSION.group_concat_max_len = @textlimit_vor_test,
          'OK', 'FEHLER') AS textlimit_nach_interessentenvorschlaegen;

-- Erwartete Fehler einzeln ausfuehren: jeweils SQLSTATE 45000.
-- CALL sp_vorschlaege_fuer_interessent(NULL);
-- CALL sp_vorschlaege_fuer_interessent(0);
-- CALL sp_vorschlaege_fuer_interessent(-1);
-- CALL sp_vorschlaege_fuer_tier(NULL);
-- CALL sp_vorschlaege_fuer_tier(0);
-- CALL sp_vorschlaege_fuer_tier(-1);

-- Noch separat zu testen: unbekannte IDs, inaktive Profile,
-- nicht verfuegbare Tiere, ungueltige Gewichtung und Laufzeitfehler.
-- Ohne kontrollierte Testdaten ist dies kein vollstaendiger Regressionstest.
