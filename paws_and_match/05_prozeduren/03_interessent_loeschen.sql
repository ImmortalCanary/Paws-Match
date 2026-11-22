USE paws_match;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_interessent_loeschen;

DELIMITER $$
-- Ohne Bewerbungshistorie wird das Profil geloescht (abhaengige Profildaten per Cascade).
-- Mit Historie bleiben Bewerbungen erhalten; Personendaten werden anonymisiert.
CREATE PROCEDURE sp_interessent_loeschen (IN p_id INT, OUT p_ergebnis VARCHAR(20))
MODIFIES SQL DATA
BEGIN
    DECLARE v_anzahl INT DEFAULT 0;

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
            bezirk = 'anonymisiert',
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
