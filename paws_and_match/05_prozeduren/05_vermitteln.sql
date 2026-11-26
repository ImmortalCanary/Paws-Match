-- Vermittlung abschliessen: Bewerbung annehmen, Tier als vermittelt markieren, andere Bewerbungen ablehnen.
USE paws_match;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_vermitteln;

DELIMITER $$
CREATE PROCEDURE sp_vermitteln (IN p_bewerbung INT, IN p_mitarbeiter INT)
MODIFIES SQL DATA
BEGIN
    DECLARE v_tier INT DEFAULT NULL;
    DECLARE v_interessent INT DEFAULT NULL;
    DECLARE v_tierstatus VARCHAR(30);
    DECLARE v_reserviert INT DEFAULT NULL;
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

    -- Erst das Tier sperren, dann die Bewerbung (wie im Bewerbungs-Trigger), sonst drohen Deadlocks.
    SELECT status, reserviert_fuer_bewerbung_id INTO v_tierstatus, v_reserviert
    FROM tier WHERE id = v_tier FOR UPDATE;
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

    IF v_tierstatus = 'reserviert' AND v_reserviert <> p_bewerbung THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tier ist fuer eine andere Bewerbung reserviert.';
    END IF;

    IF v_tierstatus NOT IN ('verfuegbar', 'reserviert')
       OR v_bewerbungsstatus NOT IN ('offen', 'in_pruefung') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vermittlung in diesem Status nicht moeglich.';
    END IF;

    -- Bypass fuer den neuen standortpruefenden tier-Trigger (BEFORE INSERT/UPDATE) des DB
    -- Specialists: der Standortcheck oben ist bereits strenger/ausreichend. Direkt danach
    -- zurueckgesetzt, damit die Session nicht dauerhaft im Admin-Bypass bleibt.
    SET @pm_ist_admin = 1;
    UPDATE tier SET status = 'reserviert', reserviert_fuer_bewerbung_id = p_bewerbung WHERE id = v_tier;
    SET @pm_ist_admin = NULL;
    UPDATE bewerbung SET status = 'angenommen' WHERE id = p_bewerbung;

    INSERT INTO vermittlung (bewerbung_id, tier_id, mitarbeiter_id)
    VALUES (p_bewerbung, v_tier, p_mitarbeiter);

    SET @pm_ist_admin = 1;
    UPDATE tier SET status = 'vermittelt', reserviert_fuer_bewerbung_id = NULL WHERE id = v_tier;
    SET @pm_ist_admin = NULL;

    UPDATE bewerbung
    SET status = 'abgelehnt',
        notiz = CONCAT_WS(' | ', notiz, 'Automatisch abgelehnt: Tier wurde anderweitig vermittelt.')
    WHERE tier_id = v_tier
      AND id <> p_bewerbung
      AND status IN ('offen', 'in_pruefung');

    COMMIT;
END$$
DELIMITER ;