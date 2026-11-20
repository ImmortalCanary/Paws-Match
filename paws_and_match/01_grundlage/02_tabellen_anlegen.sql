USE paws_match;
SET NAMES utf8mb4;

CREATE TRIGGER trg_vermittlung_pruefen
BEFORE INSERT ON vermittlung
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM bewerbung b
        JOIN tier t ON t.id = b.tier_id
        JOIN mitarbeiter m ON m.standort_id = t.standort_id
        WHERE b.id = NEW.bewerbung_id
          AND b.tier_id = NEW.tier_id
          AND b.status = 'angenommen'
          AND m.id = NEW.mitarbeiter_id
          AND t.status = 'reserviert'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vermittlung nur ueber sp_vermitteln abschliessen.';
    END IF;
END$$

CREATE PROCEDURE sp_vermitteln (IN p_bewerbung INT, IN p_mitarbeiter INT)
BEGIN
    DECLARE v_tier INT;
    DECLARE v_interessent INT;
    DECLARE v_tierstatus VARCHAR(30);
    DECLARE v_bewerbungsstatus VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT tier_id, interessent_id INTO v_tier, v_interessent FROM bewerbung WHERE id = p_bewerbung;

    IF v_tier IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bewerbung nicht gefunden.';
    END IF;

    SELECT status INTO v_tierstatus FROM tier WHERE id = v_tier FOR UPDATE;
    SELECT status INTO v_bewerbungsstatus FROM bewerbung WHERE id = p_bewerbung FOR UPDATE;

    IF v_tierstatus NOT IN ('verfuegbar', 'reserviert')
       OR v_bewerbungsstatus NOT IN ('offen', 'in_pruefung') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vermittlung in diesem Status nicht moeglich.';
    END IF;

    UPDATE tier SET status = 'reserviert' WHERE id = v_tier;
    UPDATE bewerbung SET status = 'angenommen' WHERE id = p_bewerbung;

    INSERT INTO vermittlung (bewerbung_id, tier_id, mitarbeiter_id)
    VALUES (p_bewerbung, v_tier, p_mitarbeiter);

    UPDATE tier SET status = 'vermittelt' WHERE id = v_tier;

    COMMIT;
END$$

DELIMITER ;
