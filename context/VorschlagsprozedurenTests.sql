USE paws_match;
SET NAMES utf8mb4;

-- ============================================================
-- Voraussetzungen
-- ============================================================
-- Beide Prozeduren und ihre Voraussetzungen müssen bereits
-- installiert sein.
--
-- Dieses Skript:
--   - verändert keine Fachdaten;
--   - erstellt oder ersetzt keine Datenbankobjekte;
--   - verwendet nur SELECT, SET und die beiden lesenden Prozeduren.
--
-- Durchführung in derselben Verbindung und möglichst ohne
-- gleichzeitige Änderungen an Profilen oder Matching-Gewichten.
--
-- Ergebnislisten werden manuell verglichen.
-- Dieses Skript ist kein automatisierter Assertion-Test.
-- ============================================================


-- ============================================================
-- 1. Installation und Gewichtung kontrollieren
-- ============================================================

SELECT
    ROUTINE_NAME,
    ROUTINE_TYPE,
    SECURITY_TYPE,
    SQL_DATA_ACCESS
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE()
  AND ROUTINE_NAME IN (
      'sp_vorschlaege_fuer_interessent',
      'sp_vorschlaege_fuer_tier'
  )
ORDER BY ROUTINE_NAME;

-- Erwartet:
-- Zwei Zeilen, jeweils PROCEDURE / INVOKER / READS SQL DATA.

SELECT
    COUNT(*) AS AnzahlGewichte,
    SUM(
        CASE
            WHEN Gewicht IS NULL OR Gewicht <= 0 THEN 1
            ELSE 0
        END
    ) AS UngueltigeGewichte,
    SUM(Gewicht) AS Gewichtssumme
FROM MatchingGewichtung;

-- Erwartet laut vereinbarter Konfiguration:
-- AnzahlGewichte = 9
-- UngueltigeGewichte = 0
-- Gewichtssumme = 100


-- ============================================================
-- 2. Ein tatsächlich vorschlagsfähiges Paar auswählen
-- ============================================================

SET @TestInteressent = NULL;
SET @TestTier = NULL;

SELECT
    s.InteressentId,
    s.TierId
INTO
    @TestInteressent,
    @TestTier
FROM MatchingScore s
JOIN interessent i ON i.id = s.InteressentId
JOIN tier t ON t.id = s.TierId
JOIN tierart ta ON ta.id = t.tierart_id
JOIN standort st ON st.id = t.standort_id
WHERE i.aktiv = 1
  AND s.InteressentAktiv = 1
  AND s.Eignung = 'geeignet'
  AND s.TierVerfuegbar = 1
  AND s.Tierstatus = 'verfuegbar'
  AND s.GewichtungVollstaendig = 1
  AND s.MatchProzent IS NOT NULL
  AND s.MatchProzent >= 50.00
ORDER BY s.InteressentId, s.TierId
LIMIT 1;

SELECT
    @TestInteressent AS TestInteressent,
    @TestTier AS TestTier,
    CASE
        WHEN @TestInteressent IS NULL OR @TestTier IS NULL
            THEN 'ÜBERSPRUNGEN: Kein vorschlagsfähiges Paar vorhanden.'
        ELSE 'BEREIT: Tests 3 und 4 können ausgeführt werden.'
    END AS Teststatus;

-- Wenn keine IDs ermittelt wurden:
-- Tests 3 und 4 überspringen.
-- NULL an die Prozeduren zu übergeben wäre ein Eingabefehler,
-- kein Test einer leeren Vorschlagsliste.


-- ============================================================
-- 3. Tier-Vorschläge für einen Interessenten
-- ============================================================
-- Nur ausführen, wenn @TestInteressent nicht NULL ist.

SELECT
    'ERWARTET: Tier-Vorschläge' AS Testabschnitt;

SELECT
    s.TierId,
    s.InteressentId,
    s.MatchProzent,
    s.DatenabdeckungProzent
FROM MatchingScore s
JOIN tier t ON t.id = s.TierId
JOIN tierart ta ON ta.id = t.tierart_id
JOIN standort st ON st.id = t.standort_id
JOIN interessent i ON i.id = s.InteressentId
WHERE s.InteressentId = @TestInteressent
  AND i.aktiv = 1
  AND s.InteressentAktiv = 1
  AND s.Eignung = 'geeignet'
  AND s.TierVerfuegbar = 1
  AND s.Tierstatus = 'verfuegbar'
  AND s.GewichtungVollstaendig = 1
  AND s.MatchProzent IS NOT NULL
  AND s.MatchProzent >= 50.00
ORDER BY
    s.MatchProzent DESC,
    s.DatenabdeckungProzent DESC,
    s.TierId;

SET @TextlimitVorTest = @@SESSION.group_concat_max_len;

-- Bei fehlender Test-ID diese Zeile überspringen:
CALL sp_vorschlaege_fuer_interessent(@TestInteressent);

SELECT
    @TextlimitVorTest AS TextlimitVorher,
    @@SESSION.group_concat_max_len AS TextlimitNachher,
    CASE
        WHEN @TextlimitVorTest = @@SESSION.group_concat_max_len
            THEN 'BESTANDEN'
        ELSE 'FEHLER: Sitzungseinstellung wurde verändert.'
    END AS WiederherstellungTextlimit;

-- Prüfen:
-- 1. TierId/InteressentId entsprechen der erwarteten Liste.
-- 2. Score und Datenabdeckung stimmen überein.
-- 3. Reihenfolge stimmt einschließlich TierId bei Gleichstand.
-- 4. Nur Eignung = geeignet und Tierstatus = verfuegbar.
-- 5. Das in Test 2 ausgewählte Tier ist enthalten.
-- 6. Begründung und Hinweisfelder werden ausgegeben.


-- ============================================================
-- 4. Interessenten-Vorschläge für ein Tier
-- ============================================================
-- Nur ausführen, wenn @TestTier nicht NULL ist.

SELECT
    'ERWARTET: Interessenten-Vorschläge' AS Testabschnitt;

SELECT
    s.TierId,
    s.InteressentId,
    s.MatchProzent,
    s.DatenabdeckungProzent
FROM MatchingScore s
JOIN tier t ON t.id = s.TierId
JOIN tierart ta ON ta.id = t.tierart_id
JOIN standort st ON st.id = t.standort_id
JOIN interessent i ON i.id = s.InteressentId
WHERE s.TierId = @TestTier
  AND i.aktiv = 1
  AND s.InteressentAktiv = 1
  AND s.Eignung = 'geeignet'
  AND s.TierVerfuegbar = 1
  AND s.Tierstatus = 'verfuegbar'
  AND s.GewichtungVollstaendig = 1
  AND s.MatchProzent IS NOT NULL
  AND s.MatchProzent >= 50.00
ORDER BY
    s.MatchProzent DESC,
    s.DatenabdeckungProzent DESC,
    s.InteressentId;

SET @TextlimitVorTest = @@SESSION.group_concat_max_len;

-- Bei fehlender Test-ID diese Zeile überspringen:
CALL sp_vorschlaege_fuer_tier(@TestTier);

SELECT
    @TextlimitVorTest AS TextlimitVorher,
    @@SESSION.group_concat_max_len AS TextlimitNachher,
    CASE
        WHEN @TextlimitVorTest = @@SESSION.group_concat_max_len
            THEN 'BESTANDEN'
        ELSE 'FEHLER: Sitzungseinstellung wurde verändert.'
    END AS WiederherstellungTextlimit;

-- Prüfen:
-- 1. TierId/InteressentId entsprechen der erwarteten Liste.
-- 2. Score und Datenabdeckung stimmen überein.
-- 3. Reihenfolge stimmt einschließlich InteressentId bei Gleichstand.
-- 4. Der in Test 2 ausgewählte Interessent ist enthalten.
-- 5. Dasselbe Paar hat in beiden Richtungen denselben Score
--    und dieselbe Datenabdeckung.
-- 6. Pseudonym und InteressentenBezirk werden ausgegeben.


-- ============================================================
-- 5. Daten für weitere Testfälle finden
-- ============================================================

-- Inaktives Interessentenprofil:
SET @InaktiverInteressent = (
    SELECT MIN(id)
    FROM interessent
    WHERE aktiv = 0
);

-- Nicht verfügbares Tier:
SET @NichtVerfuegbaresTier = (
    SELECT MIN(id)
    FROM tier
    WHERE status <> 'verfuegbar'
       OR status IS NULL
);

-- Positive, nicht vorhandene IDs aus dem INT-Wertebereich:
-- Es wird die erste Lücke nach einer bestehenden ID gesucht.
-- Falls bereits ID 1 fehlt, wird 1 verwendet.

SET @UnbekannterInteressent = (
    SELECT MIN(k.id)
    FROM (
        SELECT 1 AS id
        UNION ALL
        SELECT id + 1
        FROM interessent
        WHERE id > 0 AND id < 2147483647
    ) k
    LEFT JOIN interessent i ON i.id = k.id
    WHERE i.id IS NULL
);

SET @UnbekanntesTier = (
    SELECT MIN(k.id)
    FROM (
        SELECT 1 AS id
        UNION ALL
        SELECT id + 1
        FROM tier
        WHERE id > 0 AND id < 2147483647
    ) k
    LEFT JOIN tier t ON t.id = k.id
    WHERE t.id IS NULL
);

SELECT
    @InaktiverInteressent AS InaktiverInteressent,
    @NichtVerfuegbaresTier AS NichtVerfuegbaresTier,
    @UnbekannterInteressent AS UnbekannterInteressent,
    @UnbekanntesTier AS UnbekanntesTier;

-- NULL bedeutet: Für diesen Fall wurde kein Testwert gefunden.
-- Den betreffenden Aufruf dann überspringen.


-- ============================================================
-- 6. Fehlerfälle: einzeln ausführen
-- ============================================================

-- 6a. Ungültige Interessenten-ID
-- Erwartet jeweils SQLSTATE 45000:
-- Eine positive Interessenten-ID ist erforderlich.

-- CALL sp_vorschlaege_fuer_interessent(NULL);
-- CALL sp_vorschlaege_fuer_interessent(0);
-- CALL sp_vorschlaege_fuer_interessent(-1);


-- 6b. Ungültige Tier-ID
-- Erwartet jeweils SQLSTATE 45000:
-- Eine positive Tier-ID ist erforderlich.

-- CALL sp_vorschlaege_fuer_tier(NULL);
-- CALL sp_vorschlaege_fuer_tier(0);
-- CALL sp_vorschlaege_fuer_tier(-1);


-- 6c. Unbekannter Interessent
-- Nur ausführen, wenn @UnbekannterInteressent nicht NULL ist.
-- Erwartet SQLSTATE 45000:
-- Interessentenprofil nicht gefunden.

-- CALL sp_vorschlaege_fuer_interessent(@UnbekannterInteressent);


-- 6d. Unbekanntes Tier
-- Nur ausführen, wenn @UnbekanntesTier nicht NULL ist.
-- Erwartet SQLSTATE 45000:
-- Tier nicht gefunden.

-- CALL sp_vorschlaege_fuer_tier(@UnbekanntesTier);


-- 6e. Inaktives Interessentenprofil
-- Nur ausführen, wenn @InaktiverInteressent nicht NULL ist.
-- Erwartet SQLSTATE 45000:
-- Interessentenprofil ist nicht aktiv.

-- CALL sp_vorschlaege_fuer_interessent(@InaktiverInteressent);


-- 6f. Nicht verfügbares Tier
-- Nur ausführen, wenn @NichtVerfuegbaresTier nicht NULL ist.
-- Erwartet SQLSTATE 45000:
-- Tier ist aktuell nicht für neue Vorschläge verfügbar.

-- CALL sp_vorschlaege_fuer_tier(@NichtVerfuegbaresTier);
