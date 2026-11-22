USE paws_match;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_vorschlaege_fuer_tier;

DELIMITER $$
CREATE PROCEDURE sp_vorschlaege_fuer_tier (IN p_id INT)
SQL SECURITY INVOKER
READS SQL DATA
BEGIN
    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Eine positive Tier-ID ist erforderlich.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tier WHERE id = p_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tier nicht gefunden.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tier WHERE id = p_id AND status = 'verfuegbar') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tier ist aktuell nicht fuer neue Vorschlaege verfuegbar.';
    END IF;

    IF (SELECT COUNT(*) FROM matching_gewichtung) <> 9
       OR (SELECT SUM(gewicht) FROM matching_gewichtung) <> 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Die neun Matching-Gewichte muessen vollstaendig sein und 100 ergeben.';
    END IF;

    SELECT tier_id, interessent_id, tiername, tierart, standort_id, standort,
           pseudonym, interessenten_bezirk, eignung, tierstatus,
           match_prozent, datenabdeckung_prozent, begruendung
    FROM matching_vorschlaege
    WHERE tier_id = p_id
    ORDER BY match_prozent DESC, datenabdeckung_prozent DESC, interessent_id;
END$$
DELIMITER ;
