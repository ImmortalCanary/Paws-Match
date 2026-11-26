-- Tier fuer eine konkrete Bewerbung reservieren.
USE paws_match;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_reservieren;

DELIMITER $$
CREATE PROCEDURE sp_reservieren (IN p_bewerbung INT, IN p_mitarbeiter INT)
MODIFIES SQL DATA
BEGIN
    DECLARE v_tier INT DEFAULT NULL;
    DECLARE v_interessent INT DEFAULT NULL;
    DECLARE v_tierstatus VARCHAR(30);
    DECLARE v_bewerbungsstatus VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT tier_id INTO v_tier FROM bewerbung WHERE id = p_bewerbung;

    IF v_tier IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bewerbung nicht gefunden.';
    END IF;

    -- Gleiche Sperrreihenfolge wie in sp_vermitteln: erst das Tier, dann die Bewerbung.
    SELECT status INTO v_tierstatus FROM tier WHERE id = v_tier FOR UPDATE;
    SELECT status, interessent_id INTO v_bewerbungsstatus, v_interessent
    FROM bewerbung WHERE id = p_bewerbung FOR UPDATE;

    IF NOT EXISTS (
        SELECT 1 FROM mitarbeiter m JOIN tier t ON t.standort_id = m.standort_id
        WHERE m.id = p_mitarbeiter AND t.id = v_tier
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mitarbeiter gehoert nicht zum Standort des Tieres.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM interessent WHERE id = v_interessent AND aktiv = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Interessentenprofil ist nicht aktiv.';
    END IF;

    IF v_tierstatus <> 'verfuegbar' OR v_bewerbungsstatus NOT IN ('offen', 'in_pruefung') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reservierung in diesem Status nicht moeglich.';
    END IF;

    -- Bypass fuer den neuen standortpruefenden tier-Trigger (BEFORE INSERT/UPDATE) des DB
    -- Specialists: der Standortcheck oben ist bereits strenger/ausreichend. Direkt danach
    -- zurueckgesetzt, damit die Session nicht dauerhaft im Admin-Bypass bleibt.
    SET @pm_ist_admin = 1;
    UPDATE tier SET status = 'reserviert', reserviert_fuer_bewerbung_id = p_bewerbung WHERE id = v_tier;
    SET @pm_ist_admin = NULL;
    UPDATE bewerbung SET status = 'in_pruefung' WHERE id = p_bewerbung AND status = 'offen';

    COMMIT;
END$$
DELIMITER ;