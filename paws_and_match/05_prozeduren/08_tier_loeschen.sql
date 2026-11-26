-- Tier loeschen oder archivieren (P0.3). Analog zu sp_interessent_loeschen: ohne
-- Bewerbungshistorie wird hart geloescht, mit Historie bleibt der Datensatz stehen
-- (Archivierung statt Loeschen), damit bewerbung/vermittlung ihre Fremdschluessel behalten.
USE paws_match;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_tier_loeschen;

DELIMITER $$
CREATE PROCEDURE sp_tier_loeschen (
    IN p_tier_id INT,
    IN p_mitarbeiter_id INT,
    IN p_ist_admin TINYINT(1),
    OUT p_ergebnis VARCHAR(20)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_status VARCHAR(30) DEFAULT NULL;
    DECLARE v_hat_bewerbungen TINYINT(1) DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_ergebnis = NULL;

    IF p_tier_id IS NULL OR p_tier_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Eine positive Tier-ID ist erforderlich.';
    END IF;

    START TRANSACTION;

    SELECT status INTO v_status FROM tier WHERE id = p_tier_id FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tier nicht gefunden.';
    END IF;

    -- Admin darf standortuebergreifend loeschen/archivieren; sonst wie sp_reservieren
    -- nur fuer den eigenen Standort (strengere, eigene Pruefung dieser Prozedur).
    -- Fail-closed: nur bei p_ist_admin = 1 wird der Standortcheck uebersprungen, NULL zaehlt
    -- als "kein Admin" (konsistent mit dem fail-closed Trigger des DB Specialists).
    IF p_ist_admin IS NULL OR p_ist_admin <> 1 THEN
        IF NOT EXISTS (
            SELECT 1 FROM mitarbeiter m JOIN tier t ON t.standort_id = m.standort_id
            WHERE m.id = p_mitarbeiter_id AND t.id = p_tier_id
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mitarbeiter gehoert nicht zum Standort des Tieres.';
        END IF;
    END IF;

    SELECT EXISTS (SELECT 1 FROM bewerbung WHERE tier_id = p_tier_id) INTO v_hat_bewerbungen;

    IF NOT v_hat_bewerbungen THEN
        -- Keine Historie vorhanden: Hard-Delete. Cascade auf tier_charakter/tier_beduerfnis/
        -- merkliste ist bereits per FK definiert, kein CASCADE auf Historie noetig (gibt keine).
        -- Kein @pm_ist_admin-Bypass noetig: der neue Standort-Trigger des DB Specialists
        -- ist BEFORE INSERT/UPDATE, feuert also nicht bei DELETE.
        DELETE FROM tier WHERE id = p_tier_id;

        SET p_ergebnis = 'geloescht';
    ELSE
        -- Historie vorhanden: archivieren statt loeschen. Bewerbung/Vermittlung bleiben
        -- unangetastet, kein CASCADE.
        -- Ab hier @pm_ist_admin = 1 vor jedem UPDATE tier: reiner Bypass fuer den neuen
        -- standortpruefenden Trigger des DB Specialists (BEFORE INSERT/UPDATE), da diese
        -- Prozedur die Standortberechtigung oben bereits selbst (und strenger, inkl.
        -- Admin-Fall) geprueft hat. Direkt danach wieder zurueckgesetzt, damit die
        -- Session ausserhalb dieser Prozedur nicht dauerhaft im Admin-Bypass bleibt.
        IF v_status = 'reserviert' THEN
            -- Reservierung zuerst freigeben (wie in sp_interessent_loeschen), sonst
            -- verletzt der folgende Statuswechsel ck_tier_reservierung.
            SET @pm_ist_admin = 1;
            UPDATE tier SET status = 'verfuegbar', reserviert_fuer_bewerbung_id = NULL
            WHERE id = p_tier_id;
            SET @pm_ist_admin = NULL;
        END IF;

        SET @pm_ist_admin = 1;
        UPDATE tier SET status = 'geloescht' WHERE id = p_tier_id;
        SET @pm_ist_admin = NULL;

        SET p_ergebnis = 'archiviert';
    END IF;

    COMMIT;
END$$
DELIMITER ;
