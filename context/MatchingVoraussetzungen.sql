-- MatchingVoraussetzungen.sql
-- Einmalig nach Basis, TierprofileErweitern.sql und InteressentenprofileErweitern.sql.
-- MySQL ab 8.0.16. DDL ist nicht als Ganzes zurückrollbar.
-- Teilprüfung, kein vollständiges Matching und keine Score-Berechnung.
-- Bestehende Matching-Views bleiben unverändert; Integration folgt separat.
-- Noch nicht in MySQL getestet. Keine bestehenden Tierangaben erfinden.
USE paws_match;
SET NAMES utf8mb4;

ALTER TABLE tier
    ADD COLUMN KleintiereOk BOOLEAN NULL,
    ADD CONSTRAINT ckTierKleintiere CHECK (KleintiereOk IN (0,1));

-- KleintiereOk: 1=verträglich, 0=nicht verträglich, NULL=unbekannt.
-- KleintiereVorhanden: 1=vorhanden, 0=keine, NULL=unbekannt.
-- Kein Kleintier im Haushalt oder bestätigte Verträglichkeit: Bedingung erfüllt.
-- Erfahrung: Mindestwert 0 erfordert keinen Nachweis.
-- Bei positivem Mindestwert zählt ausschließlich die tierartspezifische Angabe.
-- Fehlender Mindestwert oder erforderlicher Erfahrungsnachweis: Prüfung offen.
CREATE VIEW MatchingZusatzpruefung AS
SELECT
    t.id AS TierId,
    i.id AS InteressentId,
    t.name AS Tiername,
    i.pseudonym AS Pseudonym,
    t.min_erfahrung AS MindestErfahrung,
    e.Erfahrungslevel AS TierartErfahrung,
    CASE
        WHEN i.KleintiereVorhanden=1 AND t.KleintiereOk=0
            THEN 'ausgeschlossen'
        WHEN i.KleintiereVorhanden=0 OR t.KleintiereOk=1
            THEN 'erfuellt'
        ELSE 'pruefung_offen'
    END AS KleintierPruefung,
    CASE
        WHEN t.min_erfahrung=0 THEN 'erfuellt'
        WHEN e.Erfahrungslevel<t.min_erfahrung THEN 'ausgeschlossen'
        WHEN t.min_erfahrung IS NULL OR e.Erfahrungslevel IS NULL
            THEN 'pruefung_offen'
        ELSE 'erfuellt'
    END AS ErfahrungsPruefung,
    NULLIF(CONCAT_WS(' | ',
        CASE
            WHEN i.KleintiereVorhanden=1 AND t.KleintiereOk=0
                THEN 'Tier ist nicht mit den vorhandenen Kleintieren verträglich'
            WHEN i.KleintiereVorhanden=0 OR t.KleintiereOk=1 THEN NULL
            ELSE CONCAT_WS('; ',
                IF(i.KleintiereVorhanden IS NULL,
                   'Angabe zu vorhandenen Kleintieren fehlt', NULL),
                IF(t.KleintiereOk IS NULL,
                   'Kleintierverträglichkeit des Tieres fehlt', NULL)
            )
        END,
        CASE
            WHEN t.min_erfahrung=0 THEN NULL
            WHEN t.min_erfahrung IS NULL
                THEN 'Mindestanforderung an Erfahrung fehlt'
            WHEN e.Erfahrungslevel IS NULL
                THEN 'Erfahrung mit dieser Tierart fehlt'
            WHEN e.Erfahrungslevel<t.min_erfahrung
                THEN 'Tierartspezifische Erfahrung reicht nicht aus'
            ELSE NULL
        END
    ), '') AS Hinweise
FROM tier t
CROSS JOIN interessent i
LEFT JOIN InteressentTiererfahrung e
    ON e.InteressentId=i.id AND e.TierartId=t.tierart_id
WHERE i.aktiv=1;

-- erfuellt bedeutet nur: diese einzelne Zusatzbedingung ist erfüllt.
-- Daraus keine Gesamteignung oder Verfügbarkeit ableiten.
SELECT * FROM MatchingZusatzpruefung ORDER BY InteressentId, TierId;

-- Soll-Ergebnis: keine Zeilen; nicht erfüllte Teilprüfungen brauchen einen Hinweis.
SELECT * FROM MatchingZusatzpruefung
WHERE (KleintierPruefung<>'erfuellt' OR ErfahrungsPruefung<>'erfuellt')
  AND Hinweise IS NULL;

-- Soll-Ergebnis: keine Zeilen; Mindestanforderung 0 verlangt keinen Nachweis.
SELECT * FROM MatchingZusatzpruefung
WHERE MindestErfahrung=0 AND ErfahrungsPruefung<>'erfuellt';
