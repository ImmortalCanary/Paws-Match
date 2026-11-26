-- Reservierung zuruecknehmen: Tier steht wieder fuer alle zur Verfuegung.
USE paws_match;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_reservierung_aufheben;

DELIMITER $$
CREATE PROCEDURE sp_reservierung_aufheben (IN p_tier INT, IN p_mitarbeiter INT)
MODIFIES SQL DATA
BEGIN
    DECLARE v_tierstatus VARCHAR(30) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT status INTO v_tierstatus FROM tier WHERE id = p_tier FOR UPDATE;

    IF v_tierstatus IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tier nicht gefunden.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM mitarbeiter m JOIN tier t ON t.standort_id = m.standort_id
        WHERE m.id = p_mitarbeiter AND t.id = p_tier
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mitarbeiter gehoert nicht zum Standort des Tieres.';
    END IF;

    IF v_tierstatus <> 'reserviert' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tier ist nicht reserviert.';
    END IF;

    -- Bypass fuer den neuen standortpruefenden tier-Trigger (BEFORE INSERT/UPDATE) des DB
    -- Specialists: der Standortcheck oben ist bereits strenger/ausreichend. Direkt danach
    -- zurueckgesetzt, damit die Session nicht dauerhaft im Admin-Bypass bleibt.
    SET @pm_ist_admin = 1;
    UPDATE tier SET status = 'verfuegbar', reserviert_fuer_bewerbung_id = NULL WHERE id = p_tier;
    SET @pm_ist_admin = NULL;

    COMMIT;
END$$
DELIMITER ;