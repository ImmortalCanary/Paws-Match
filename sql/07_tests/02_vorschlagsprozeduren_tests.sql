USE paws_match;
SET NAMES utf8mb4;

SET @test_interessent = NULL;
SET @test_tier = NULL;

SELECT
    s.interessent_id,
    s.tier_id
INTO
    @test_interessent,
    @test_tier
FROM matching_score s
JOIN interessent i ON i.id = s.interessent_id
JOIN tier t ON t.id = s.tier_id
WHERE i.aktiv = 1
  AND s.interessent_aktiv = 1
  AND s.eignung = 'geeignet'
  AND s.tier_verfuegbar = 1
  AND s.tierstatus = 'verfuegbar'
  AND s.gewichtung_vollstaendig = 1
  AND s.match_prozent IS NOT NULL
  AND s.match_prozent >= 50.00
ORDER BY s.interessent_id, s.tier_id
LIMIT 1;

SELECT
    @test_interessent AS test_interessent,
    @test_tier AS test_tier;

-- Nur ausfuehren, wenn @test_interessent nicht NULL ist.
CALL sp_vorschlaege_fuer_interessent(@test_interessent);

-- Nur ausfuehren, wenn @test_tier nicht NULL ist.
CALL sp_vorschlaege_fuer_tier(@test_tier);

-- Fehlerfaelle einzeln ausfuehren:
-- CALL sp_vorschlaege_fuer_interessent(NULL);
-- CALL sp_vorschlaege_fuer_interessent(0);
-- CALL sp_vorschlaege_fuer_interessent(-1);
-- CALL sp_vorschlaege_fuer_tier(NULL);
-- CALL sp_vorschlaege_fuer_tier(0);
-- CALL sp_vorschlaege_fuer_tier(-1);
