USE paws_match;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_vorschlaege_fuer_tier;

DELIMITER $$
CREATE PROCEDURE sp_vorschlaege_fuer_tier (IN p_id INT)
SQL SECURITY INVOKER
READS SQL DATA
BEGIN
    DECLARE altes_textlimit BIGINT UNSIGNED DEFAULT NULL;
    DECLARE mindestscore DECIMAL(5,2) DEFAULT 50.00;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF altes_textlimit IS NOT NULL THEN
            SET SESSION group_concat_max_len = altes_textlimit;
        END IF;
        RESIGNAL;
    END;

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
       OR EXISTS (SELECT 1 FROM matching_gewichtung WHERE gewicht IS NULL OR gewicht <= 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Die neun Matching-Gewichte muessen vollstaendig und positiv sein.';
    END IF;

    SET altes_textlimit = @@SESSION.group_concat_max_len;
    SET SESSION group_concat_max_len = 65535;

    SELECT
        s.tier_id, s.interessent_id, s.tiername, ta.name AS tierart,
        st.id AS standort_id, st.name AS standort, s.pseudonym,
        i.bezirk AS interessenten_bezirk, s.eignung, s.tierstatus,
        s.match_prozent, s.datenabdeckung_prozent,
        'Alle relevanten harten Kriterien sind erfuellt; Score aus den erfassten Kriterien.' AS begruendung,
        s.ausschlussgruende, s.offene_pruefungen
    FROM matching_score s
    JOIN tier t ON t.id = s.tier_id
    JOIN tierart ta ON ta.id = t.tierart_id
    JOIN standort st ON st.id = t.standort_id
    JOIN interessent i ON i.id = s.interessent_id
    WHERE s.tier_id = p_id
      AND i.aktiv = 1
      AND s.interessent_aktiv = 1
      AND s.eignung = 'geeignet'
      AND s.tier_verfuegbar = 1
      AND s.tierstatus = 'verfuegbar'
      AND s.gewichtung_vollstaendig = 1
      AND s.match_prozent IS NOT NULL
      AND s.match_prozent >= mindestscore
    ORDER BY s.match_prozent DESC, s.datenabdeckung_prozent DESC, s.interessent_id;

    SET SESSION group_concat_max_len = altes_textlimit;
END$$
DELIMITER ;
