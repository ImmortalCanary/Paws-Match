-- Interessent loeschen oder anonymisieren.
USE paws_match;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_interessent_loeschen;

DELIMITER $$
-- Ohne Bewerbungen wird das Profil einfach geloescht (Wuensche usw. gehen per Cascade mit).
-- Mit Bewerbungen bleibt die Historie stehen und nur die persoenlichen Daten werden entfernt.
CREATE PROCEDURE sp_interessent_loeschen (IN p_id INT, OUT p_ergebnis VARCHAR(20))
MODIFIES SQL DATA
BEGIN
    DECLARE v_anzahl INT DEFAULT 0;
    DECLARE v_betroffene_tiere INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_ergebnis = NULL;

    IF p_id IS NULL OR p_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Eine positive Interessenten-ID ist erforderlich.';
    END IF;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_anzahl FROM interessent WHERE id = p_id FOR UPDATE;

    IF v_anzahl = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Interessentenprofil nicht gefunden.';
    END IF;

    IF EXISTS (SELECT 1 FROM bewerbung WHERE interessent_id = p_id) THEN
        -- Tiere freigeben, die durch eine offene/in-Pruefung-Bewerbung dieses Interessenten
        -- reserviert sind - sonst bliebe das Tier nach dem Zurueckziehen faelschlich
        -- 'reserviert' mit totem Bewerbung-Verweis stehen (stale Reservierung).
        -- Sperrreihenfolge wie in sp_reservieren/sp_reservierung_aufheben: erst Tier, dann Bewerbung.
        SELECT COUNT(*) INTO v_betroffene_tiere
        FROM tier
        WHERE reserviert_fuer_bewerbung_id IN (
            SELECT id FROM bewerbung WHERE interessent_id = p_id AND status IN ('offen', 'in_pruefung')
        )
        FOR UPDATE;

        -- Bypass fuer den neuen standortpruefenden tier-Trigger (BEFORE INSERT/UPDATE) des DB
        -- Specialists: diese Prozedur hat keinen Standortbezug/-check (Interessenten-Loeschen
        -- ist standortunabhaengig), daher hier bewusst immer der Bypass, nicht nur bedingt.
        -- Direkt danach zurueckgesetzt, damit die Session nicht dauerhaft im Admin-Bypass bleibt.
        SET @pm_ist_admin = 1;
        UPDATE tier
        SET status = 'verfuegbar', reserviert_fuer_bewerbung_id = NULL
        WHERE reserviert_fuer_bewerbung_id IN (
            SELECT id FROM bewerbung WHERE interessent_id = p_id AND status IN ('offen', 'in_pruefung')
        );
        SET @pm_ist_admin = NULL;

        UPDATE bewerbung
        SET status = IF(status IN ('offen', 'in_pruefung'), 'zurueckgezogen', status),
            notiz = NULL
        WHERE interessent_id = p_id;

        DELETE FROM merkliste WHERE interessent_id = p_id;
        DELETE FROM interessent_charakter WHERE interessent_id = p_id;
        DELETE FROM interessent_tierart WHERE interessent_id = p_id;
        DELETE FROM interessent_beduerfnis WHERE interessent_id = p_id;
        DELETE FROM interessent_groesse WHERE interessent_id = p_id;
        DELETE FROM interessent_standort WHERE interessent_id = p_id;
        DELETE FROM interessent_tiererfahrung WHERE interessent_id = p_id;

        UPDATE interessent
        SET aktiv = 0,
            pseudonym = CONCAT('Anonymisiert ', p_id),
            email = CONCAT('anonymisiert-', p_id, '@paws-match.invalid'),
            bezirk_id = NULL,
            max_suchzone_id = NULL, max_entfernung_km = NULL,
            wohnflaeche = NULL, garten = NULL, etage = NULL, aufzug = NULL,
            kinder = NULL, hund_vorhanden = NULL, katze_vorhanden = NULL,
            zeit_stunden = NULL, allein_stunden = NULL, erfahrung = NULL,
            budget = NULL, medizin_bereit = NULL, aktivitaet = NULL,
            wohnform_id = NULL, balkon = NULL, balkon_gesichert = NULL,
            haushaltsgroesse = NULL, kleintiere_vorhanden = NULL,
            arbeitsmodell_id = NULL, wunschalter_min = NULL, wunschalter_max = NULL,
            training_bereit = NULL, tierarzt_bereit = NULL, max_pflegeaufwand_id = NULL
        WHERE id = p_id;

        SET p_ergebnis = 'anonymisiert';
    ELSE
        DELETE FROM interessent WHERE id = p_id;
        SET p_ergebnis = 'geloescht';
    END IF;

    COMMIT;
END$$
DELIMITER ;
