-- Vermittlung beenden: Rueckgabe, Tod oder sonstiger Grund. Nur eine Rueckgabe macht das Tier wieder verfuegbar.
USE paws_match;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_vermittlung_beenden;

DELIMITER $$
CREATE PROCEDURE sp_vermittlung_beenden (
    IN p_vermittlung INT,
    IN p_mitarbeiter INT,
    IN p_grund VARCHAR(20),
    IN p_notiz VARCHAR(500)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_tier INT DEFAULT NULL;
    DECLARE v_bewerbung INT DEFAULT NULL;
    DECLARE v_beendet DATETIME DEFAULT NULL;
    DECLARE v_tierstatus VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_grund IS NULL OR p_grund NOT IN ('rueckgabe', 'verstorben', 'sonstiges') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Beendigungsgrund muss rueckgabe, verstorben oder sonstiges sein.';
    END IF;

    START TRANSACTION;

    SELECT tier_id INTO v_tier FROM vermittlung WHERE id = p_vermittlung;

    IF v_tier IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vermittlung nicht gefunden.';
    END IF;

    -- Gleiche Sperrreihenfolge wie in sp_vermitteln: erst das Tier, dann der Vorgang.
    SELECT status INTO v_tierstatus FROM tier WHERE id = v_tier FOR UPDATE;
    SELECT bewerbung_id, beendet_am INTO v_bewerbung, v_beendet
    FROM vermittlung WHERE id = p_vermittlung FOR UPDATE;

    IF NOT EXISTS (
        SELECT 1 FROM mitarbeiter m JOIN tier t ON t.standort_id = m.standort_id
        WHERE m.id = p_mitarbeiter AND t.id = v_tier
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mitarbeiter gehoert nicht zum Standort des Tieres.';
    END IF;

    IF v_beendet IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vermittlung ist bereits beendet.';
    END IF;

    IF v_tierstatus <> 'vermittelt' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Beenden in diesem Status nicht moeglich.';
    END IF;

    -- Bypass fuer den neuen standortpruefenden tier-Trigger (BEFORE INSERT/UPDATE) des DB
    -- Specialists: der Standortcheck oben ist bereits strenger/ausreichend. Direkt danach
    -- zurueckgesetzt, damit die Session nicht dauerhaft im Admin-Bypass bleibt.
    -- Zwischenschritt wie beim Vermitteln: die Reservierung zeigt dem Trigger, dass die Prozedur laeuft.
    SET @pm_ist_admin = 1;
    UPDATE tier SET status = 'reserviert', reserviert_fuer_bewerbung_id = v_bewerbung WHERE id = v_tier;
    SET @pm_ist_admin = NULL;

    UPDATE vermittlung
    SET beendet_am = NOW(),
        beendigungsgrund = p_grund,
        notiz = CONCAT_WS(' | ', notiz, CONCAT('Beendet: ', p_grund), p_notiz)
    WHERE id = p_vermittlung;

    -- Nur zurueckgegebene Tiere werden wieder vermittelt; Tod und Sonstiges bleiben gesperrt.
    SET @pm_ist_admin = 1;
    UPDATE tier
    SET status = IF(p_grund = 'rueckgabe', 'verfuegbar', 'nicht_vermittelbar'),
        reserviert_fuer_bewerbung_id = NULL
    WHERE id = v_tier;
    SET @pm_ist_admin = NULL;

    COMMIT;
END$$
DELIMITER ;