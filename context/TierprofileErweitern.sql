-- TierprofileErweitern.sql
-- Einmalige Schemaerweiterung nach Installation von Paws and Match.sql.
-- MySQL 8.0.16 oder neuer; CHECK-Constraints müssen durchgesetzt werden.
-- Nicht erneut ausführen. DDL ist nicht als Ganzes zurückrollbar.
-- Bestehende Tierdaten bleiben erhalten; neue Angaben sind zunächst unbekannt.
-- Neue Objekte verwenden Namen ohne Unterstriche.
-- Noch nicht in MySQL getestet. Matching-Regeln werden hier nicht verändert.
USE paws_match;
SET NAMES utf8mb4;

CREATE TABLE TierRasse (
    Id INT PRIMARY KEY AUTO_INCREMENT,
    TierartId INT NOT NULL,
    Name VARCHAR(100) NOT NULL,
    UNIQUE (TierartId, Name),
    UNIQUE (Id, TierartId),
    FOREIGN KEY (TierartId) REFERENCES tierart(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE TierGroesse (
    Id INT PRIMARY KEY,
    Name VARCHAR(30) NOT NULL UNIQUE,
    Rang INT NOT NULL UNIQUE,
    CHECK (Rang > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Pflegeaufwand (
    Id INT PRIMARY KEY,
    Name VARCHAR(30) NOT NULL UNIQUE,
    Rang INT NOT NULL UNIQUE,
    CHECK (Rang > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE Gesundheitsmerkmal (
    Id INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL UNIQUE,
    Beschreibung VARCHAR(500)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE TierGesundheit (
    TierId INT NOT NULL,
    GesundheitsmerkmalId INT NOT NULL,
    Bestaetigt BOOLEAN NOT NULL,
    GeprueftAm DATE NOT NULL,
    Hinweis VARCHAR(500),
    PRIMARY KEY (TierId, GesundheitsmerkmalId),
    FOREIGN KEY (TierId) REFERENCES tier(id),
    FOREIGN KEY (GesundheitsmerkmalId) REFERENCES Gesundheitsmerkmal(Id),
    CHECK (Bestaetigt IN (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Eine fehlende Gesundheitszuordnung bedeutet unbekannt, nicht gesund.
-- Bestaetigt=0 bedeutet: Merkmal zum Prüfdatum ausdrücklich verneint.
-- Medikamente, Kastrierung und Impfung können so getrennt dokumentiert werden.
-- Aus Gesundheitsmerkmalen werden hier keine Anforderungen automatisch abgeleitet.
ALTER TABLE tier
    ADD COLUMN RasseId INT NULL,
    ADD COLUMN GroesseId INT NULL,
    ADD COLUMN PflegeaufwandId INT NULL,
    ADD COLUMN FotoUrl VARCHAR(2048) NULL,
    ADD CONSTRAINT fkTierRasse FOREIGN KEY (RasseId, tierart_id)
        REFERENCES TierRasse(Id, TierartId),
    ADD CONSTRAINT fkTierGroesse FOREIGN KEY (GroesseId)
        REFERENCES TierGroesse(Id),
    ADD CONSTRAINT fkTierPflegeaufwand FOREIGN KEY (PflegeaufwandId)
        REFERENCES Pflegeaufwand(Id);

-- Fachliche Größen- und Pflegeskalen bleiben bewusst dreistufig.
-- Größe ist eine Kategorie, keine aus dem Gewicht abgeleitete Tierwohlregel.
INSERT INTO TierGroesse (Id, Name, Rang)
VALUES (1,'klein',1),(2,'mittel',2),(3,'groß',3);
INSERT INTO Pflegeaufwand (Id, Name, Rang)
VALUES (1,'niedrig',1),(2,'mittel',2),(3,'hoch',3);
INSERT INTO Gesundheitsmerkmal (Name, Beschreibung)
VALUES
('Chronische Erkrankung','Art und Versorgung im individuellen Hinweis dokumentieren.'),
('Allergie','Auslöser und erforderliche Maßnahmen im Hinweis dokumentieren.'),
('Gelenkprobleme','Mobilitätsanforderungen zusätzlich im Tierprofil prüfen.'),
('Regelmäßige Medikamentengabe','Bedarf und Betreuung zusätzlich im Matching berücksichtigen.'),
('Behinderung','Konkrete Einschränkungen im Hinweis dokumentieren.'),
('Geimpft','Prüfdatum und individuellen Impfstatus beachten.'),
('Kastriert','Bestätigten oder ausdrücklich verneinten Status dokumentieren.');

-- Keine Rassen oder Gesundheitszustände für bestehende Tiere erfinden.
-- Rassen und fiktive Tierzuordnungen folgen in einem separaten Testdaten-Schritt.
-- Kompatibilität mit den bisherigen Demo-INSERTs bleibt durch benannte Spalten erhalten.

-- Übersicht der neuen Attribute; NULL bedeutet unbekannt.
SELECT t.id, t.name, r.Name AS Rasse, g.Name AS Groesse,
       p.Name AS Pflege, t.FotoUrl
FROM tier t
LEFT JOIN TierRasse r ON r.Id=t.RasseId AND r.TierartId=t.tierart_id
LEFT JOIN TierGroesse g ON g.Id=t.GroesseId
LEFT JOIN Pflegeaufwand p ON p.Id=t.PflegeaufwandId
ORDER BY t.id;

-- Soll-Ergebnis: keine Zeilen, jede zugewiesene Rasse gehört zur Tierart.
SELECT t.id, t.RasseId, t.tierart_id
FROM tier t
LEFT JOIN TierRasse r ON r.Id=t.RasseId AND r.TierartId=t.tierart_id
WHERE t.RasseId IS NOT NULL AND r.Id IS NULL;
