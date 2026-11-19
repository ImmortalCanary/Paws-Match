-- TierVorschlaege.sql
-- Nach MatchingEntscheidung.sql und MatchingScore.sql samt Voraussetzungen.
-- MySQL ab 8.0.16; noch nicht ausgeführt oder getestet.
-- Installation ersetzt die bestehende Prozedur, nicht deren Aufrufsignatur.
-- DROP/CREATE ist nicht atomar; bei einem Fehler muss die Prozedur wiederhergestellt werden.
-- Prozedurspezifische Berechtigungen nach einer Installation erneut prüfen.
-- Kein Überschreiben von Profilen oder Vermittlungsdaten.
USE paws_match;
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_vorschlaege_fuer_interessent;
DELIMITER $$
CREATE PROCEDURE sp_vorschlaege_fuer_interessent(IN p_id INT)
SQL SECURITY INVOKER
READS SQL DATA
BEGIN
    DECLARE AltesTextlimit BIGINT UNSIGNED DEFAULT NULL;
    DECLARE Mindestscore DECIMAL(5,2) DEFAULT 50.00;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF AltesTextlimit IS NOT NULL THEN
            SET SESSION group_concat_max_len=AltesTextlimit;
        END IF;
        RESIGNAL;
    END;

    IF p_id IS NULL OR p_id<=0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT='Eine positive Interessenten-ID ist erforderlich.';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM interessent WHERE id=p_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT='Interessentenprofil nicht gefunden.';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM interessent WHERE id=p_id AND aktiv=1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT='Interessentenprofil ist nicht aktiv.';
    END IF;
    IF (SELECT COUNT(*) FROM MatchingGewichtung)<>9
       OR EXISTS(SELECT 1 FROM MatchingGewichtung WHERE Gewicht IS NULL OR Gewicht<=0) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT='Die neun Matching-Gewichte müssen vollständig und positiv sein.';
    END IF;

    SET AltesTextlimit=@@SESSION.group_concat_max_len;
    SET SESSION group_concat_max_len=65535;

    SELECT
        s.TierId,
        s.InteressentId,
        s.Tiername,
        ta.name AS Tierart,
        st.id AS StandortId,
        st.name AS Standort,
        st.bezirk AS Bezirk,
        s.Pseudonym,
        s.Eignung,
        s.Tierstatus,
        s.MatchProzent,
        s.DatenabdeckungProzent,
        'Alle relevanten harten Kriterien sind erfüllt; Score aus den erfassten Kriterien.' AS Begruendung,
        s.Ausschlussgruende,
        s.OffenePruefungen
    FROM MatchingScore s
    JOIN tier t ON t.id=s.TierId
    JOIN tierart ta ON ta.id=t.tierart_id
    JOIN standort st ON st.id=t.standort_id
    JOIN interessent i ON i.id=s.InteressentId
    WHERE s.InteressentId=p_id
      AND i.aktiv=1
      AND s.InteressentAktiv=1
      AND s.Eignung='geeignet'
      AND s.TierVerfuegbar=1
      AND s.Tierstatus='verfuegbar'
      AND s.GewichtungVollstaendig=1
      AND s.MatchProzent IS NOT NULL
      AND s.MatchProzent>=Mindestscore
    ORDER BY s.MatchProzent DESC,
             s.DatenabdeckungProzent DESC,
             s.TierId;

    SET SESSION group_concat_max_len=AltesTextlimit;
END$$
DELIMITER ;

-- Beispiel nach erfolgreicher Installation; nicht automatisch ausführen:
-- CALL sp_vorschlaege_fuer_interessent(17);
-- Keine Zeilen bedeutet: aktuell kein Tier erfüllt alle Vorschlagsbedingungen.
-- Unbekannte neue Pflichtangaben können zunächst alle passenden Paare offenlassen.
-- Fehlende weiche Angaben reduzieren die Datenabdeckung, nicht automatisch die Passung.
-- Kein zusätzlicher Mindestwert für Datenabdeckung wurde vereinbart.
-- Sechs erfüllte Mindestkriterien tragen zusammen 75 von 100 Gewichtspunkten bei.
-- Daher filtert die 50-Prozent-Grenze derzeit keine geeigneten Paare zusätzlich aus.
-- Eignung und Score bleiben Entscheidungshilfen, keine automatische Vermittlung.
-- sp_vorschlaege_fuer_tier sowie alte Views bleiben hier unverändert.
