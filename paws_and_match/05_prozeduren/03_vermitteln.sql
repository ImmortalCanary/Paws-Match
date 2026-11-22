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

    IF v_tierstatus NOT IN ('verfuegbar', 'reserviert')
       OR v_bewerbungsstatus NOT IN ('offen', 'in_pruefung') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vermittlung in diesem Status nicht moeglich.';
    END IF;

    UPDATE tier SET status = 'reserviert' WHERE id = v_tier;
    UPDATE bewerbung SET status = 'angenommen' WHERE id = p_bewerbung;

    INSERT INTO vermittlung (bewerbung_id, tier_id, mitarbeiter_id)
    VALUES (p_bewerbung, v_tier, p_mitarbeiter);

    UPDATE tier SET status = 'vermittelt' WHERE id = v_tier;

    UPDATE bewerbung
    SET status = 'abgelehnt',
        notiz = CONCAT_WS(' | ', notiz, 'Automatisch abgelehnt: Tier wurde anderweitig vermittelt.')
    WHERE tier_id = v_tier
      AND id <> p_bewerbung
      AND status IN ('offen', 'in_pruefung');

    COMMIT;
END$$
DELIMITER ;
