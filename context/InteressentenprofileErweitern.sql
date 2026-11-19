-- InteressentenprofileErweitern.sql
-- Einmalig nach Paws and Match.sql und TierprofileErweitern.sql ausführen.
-- MySQL ab 8.0.16. DDL ist nicht als Ganzes zurückrollbar.
-- Keine vorhandenen Profile überschreiben oder unbekannte Angaben erfinden.
-- Noch nicht in MySQL getestet; verändert keine Matching-Views.
USE paws_match;
SET NAMES utf8mb4;

CREATE TABLE Wohnform (
    Id INT PRIMARY KEY,
    Name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Arbeitsmodell (
    Id INT PRIMARY KEY,
    Name VARCHAR(60) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO Wohnform (Id, Name)
VALUES (1,'Wohnung'),(2,'Haus'),(3,'Reihenhaus'),(4,'Wohngemeinschaft'),(5,'Sonstige Wohnform');
INSERT INTO Arbeitsmodell (Id, Name)
VALUES (1,'Überwiegend vor Ort'),(2,'Überwiegend zu Hause'),(3,'Hybrid'),(4,'Wechselnde Arbeitszeiten'),(5,'Keine Erwerbstätigkeit');

-- Arbeitsmodell erlaubt keine automatische Schlussfolgerung über Betreuungszeit.
-- Maßgeblich bleiben zeit_stunden und allein_stunden im bestehenden Profil.
ALTER TABLE interessent
    ADD COLUMN WohnformId INT NULL,
    ADD COLUMN Balkon BOOLEAN NULL,
    ADD COLUMN BalkonGesichert BOOLEAN NULL,
    ADD COLUMN Haushaltsgroesse INT NULL,
    ADD COLUMN KleintiereVorhanden BOOLEAN NULL,
    ADD COLUMN ArbeitsmodellId INT NULL,
    ADD COLUMN WunschalterMin DECIMAL(5,2) NULL,
    ADD COLUMN WunschalterMax DECIMAL(5,2) NULL,
    ADD COLUMN TrainingBereit BOOLEAN NULL,
    ADD COLUMN TierarztBereit BOOLEAN NULL,
    ADD COLUMN MaxPflegeaufwandId INT NULL,
    ADD CONSTRAINT fkInteressentWohnform FOREIGN KEY (WohnformId) REFERENCES Wohnform(Id),
    ADD CONSTRAINT fkInteressentArbeitsmodell FOREIGN KEY (ArbeitsmodellId) REFERENCES Arbeitsmodell(Id),
    ADD CONSTRAINT fkInteressentPflege FOREIGN KEY (MaxPflegeaufwandId) REFERENCES Pflegeaufwand(Id),
    ADD CONSTRAINT ckInteressentBalkon CHECK (Balkon IN (0,1)),
    ADD CONSTRAINT ckInteressentBalkonsicherung CHECK (BalkonGesichert IN (0,1)),
    ADD CONSTRAINT ckInteressentGesicherterBalkon CHECK (
        BalkonGesichert IS NULL OR BalkonGesichert=0
        OR (Balkon IS NOT NULL AND Balkon=1)
    ),
    ADD CONSTRAINT ckInteressentHaushalt CHECK (Haushaltsgroesse>=1),
    ADD CONSTRAINT ckInteressentKleintiere CHECK (KleintiereVorhanden IN (0,1)),
    ADD CONSTRAINT ckInteressentWunschalterMin CHECK (WunschalterMin>=0),
    ADD CONSTRAINT ckInteressentWunschalterMax CHECK (WunschalterMax>=0),
    ADD CONSTRAINT ckInteressentAltersbereich CHECK (WunschalterMin<=WunschalterMax),
    ADD CONSTRAINT ckInteressentTraining CHECK (TrainingBereit IN (0,1)),
    ADD CONSTRAINT ckInteressentTierarzt CHECK (TierarztBereit IN (0,1));

-- Alterswünsche in Jahren; NULL bedeutet keine dokumentierte Grenze.
-- Bei geschätztem Tiergeburtsdatum ist auch das berechnete Alter nur geschätzt.
-- NULL bei Bereitschaft bedeutet unbekannt, 0 ausdrücklich nein, 1 ja.
-- Haushaltsgröße umfasst den Interessenten selbst.
-- Pflegebereitschaft wird über den Rang in Pflegeaufwand verglichen, nicht über die ID.

CREATE TABLE InteressentGroesse (
    InteressentId INT NOT NULL,
    GroesseId INT NOT NULL,
    PRIMARY KEY (InteressentId, GroesseId),
    FOREIGN KEY (InteressentId) REFERENCES interessent(id),
    FOREIGN KEY (GroesseId) REFERENCES TierGroesse(Id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE InteressentStandort (
    InteressentId INT NOT NULL,
    StandortId INT NOT NULL,
    PRIMARY KEY (InteressentId, StandortId),
    FOREIGN KEY (InteressentId) REFERENCES interessent(id),
    FOREIGN KEY (StandortId) REFERENCES standort(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE InteressentTiererfahrung (
    InteressentId INT NOT NULL,
    TierartId INT NOT NULL,
    Erfahrungslevel INT NOT NULL,
    PRIMARY KEY (InteressentId, TierartId),
    FOREIGN KEY (InteressentId) REFERENCES interessent(id),
    FOREIGN KEY (TierartId) REFERENCES tierart(id),
    CHECK (Erfahrungslevel BETWEEN 0 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Keine Zeile bei Größen- und Standortpräferenzen: kein Wunsch dokumentiert.
-- Daraus später keinen harten Ausschluss ableiten.
-- Keine Erfahrungszeile: tierartspezifische Erfahrung unbekannt, nicht automatisch 0.
-- Allgemeine Erfahrung nicht ungeprüft auf jede Tierart übertragen.
-- Präferenzen und fiktive Testfälle folgen im Testdaten-Schritt.

SELECT i.id, i.pseudonym, w.Name AS Wohnform, i.Balkon,
       i.BalkonGesichert, i.Haushaltsgroesse, i.KleintiereVorhanden,
       a.Name AS Arbeitsmodell, i.WunschalterMin, i.WunschalterMax,
       i.TrainingBereit, i.TierarztBereit, p.Name AS MaximalerPflegeaufwand
FROM interessent i
LEFT JOIN Wohnform w ON w.Id=i.WohnformId
LEFT JOIN Arbeitsmodell a ON a.Id=i.ArbeitsmodellId
LEFT JOIN Pflegeaufwand p ON p.Id=i.MaxPflegeaufwandId
ORDER BY i.id;

-- Soll-Ergebnis: keine Zeilen mit widersprüchlichen Angaben.
SELECT id, pseudonym FROM interessent
WHERE WunschalterMin>WunschalterMax
   OR (BalkonGesichert=1 AND (Balkon IS NULL OR Balkon<>1))
   OR Haushaltsgroesse<1;
