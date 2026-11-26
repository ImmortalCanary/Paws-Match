-- Tierprofile erweitern: Rasse, Groesse, Pflegeaufwand, Gesundheit und Kleintiere.
USE paws_match;
SET NAMES utf8mb4;

CREATE TABLE tier_rasse (
    id INT PRIMARY KEY AUTO_INCREMENT,
    tierart_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    CONSTRAINT uq_tier_rasse UNIQUE (tierart_id, name),
    CONSTRAINT uq_tier_rasse_id UNIQUE (id, tierart_id),
    CONSTRAINT fk_tier_rasse_tierart FOREIGN KEY (tierart_id) REFERENCES tierart(id)
) ENGINE = InnoDB;

CREATE TABLE tier_groesse (
    id INT PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE,
    rang INT NOT NULL UNIQUE,
    CONSTRAINT ck_tier_groesse_rang CHECK (rang > 0)
) ENGINE = InnoDB;

CREATE TABLE pflegeaufwand (
    id INT PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE,
    rang INT NOT NULL UNIQUE,
    CONSTRAINT ck_pflegeaufwand_rang CHECK (rang > 0)
) ENGINE = InnoDB;

CREATE TABLE gesundheitsmerkmal (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL UNIQUE,
    beschreibung VARCHAR(500),
    -- belastend = 1 heisst: das Merkmal macht zusaetzliche Betreuung noetig (zaehlt im Matching).
    belastend BOOLEAN NOT NULL,
    CONSTRAINT ck_gesundheitsmerkmal_belastend CHECK (belastend IN (0, 1))
) ENGINE = InnoDB;

CREATE TABLE tier_gesundheit (
    tier_id INT NOT NULL,
    gesundheitsmerkmal_id INT NOT NULL,
    bestaetigt BOOLEAN NOT NULL,
    geprueft_am DATE NOT NULL,
    hinweis VARCHAR(500),
    PRIMARY KEY (tier_id, gesundheitsmerkmal_id),
    CONSTRAINT fk_tier_gesundheit_tier FOREIGN KEY (tier_id) REFERENCES tier(id) ON DELETE CASCADE,
    CONSTRAINT fk_tier_gesundheit_merkmal FOREIGN KEY (gesundheitsmerkmal_id) REFERENCES gesundheitsmerkmal(id),
    CONSTRAINT ck_tier_gesundheit_bestaetigt CHECK (bestaetigt IN (0, 1))
) ENGINE = InnoDB;

ALTER TABLE tier
    ADD COLUMN rasse_id INT NULL,
    ADD COLUMN groesse_id INT NULL,
    ADD COLUMN pflegeaufwand_id INT NULL,
    ADD COLUMN foto_url VARCHAR(2048) NULL,
    ADD COLUMN kleintiere_ok BOOLEAN NULL,
    ADD CONSTRAINT fk_tier_rasse FOREIGN KEY (rasse_id, tierart_id) REFERENCES tier_rasse(id, tierart_id),
    ADD CONSTRAINT fk_tier_groesse FOREIGN KEY (groesse_id) REFERENCES tier_groesse(id),
    ADD CONSTRAINT fk_tier_pflegeaufwand FOREIGN KEY (pflegeaufwand_id) REFERENCES pflegeaufwand(id),
    ADD CONSTRAINT ck_tier_kleintiere CHECK (kleintiere_ok IN (0, 1));

INSERT INTO tier_groesse (id, name, rang) VALUES
    (1, 'klein', 1), (2, 'mittel', 2), (3, 'gross', 3);

INSERT INTO pflegeaufwand (id, name, rang) VALUES
    (1, 'niedrig', 1), (2, 'mittel', 2), (3, 'hoch', 3);

INSERT INTO gesundheitsmerkmal (name, beschreibung, belastend) VALUES
    ('Chronische Erkrankung', 'Art und Versorgung im individuellen Hinweis dokumentieren.', 1),
    ('Allergie', 'Ausloeser und erforderliche Massnahmen im Hinweis dokumentieren.', 1),
    ('Gelenkprobleme', 'Mobilitaetsanforderungen zusaetzlich im Tierprofil pruefen.', 1),
    ('Regelmaessige Medikamentengabe', 'Bedarf und Betreuung zusaetzlich im Matching beruecksichtigen.', 1),
    ('Behinderung', 'Konkrete Einschraenkungen im Hinweis dokumentieren.', 1),
    ('Geimpft', 'Pruefdatum und individuellen Impfstatus beachten.', 0),
    ('Kastriert', 'Bestaetigten oder ausdruecklich verneinten Status dokumentieren.', 0);

-- Rassenkatalog (Meeting-Feedback Phase 5, P5.1): je Tierart ein Mischling-Eintrag plus eine
-- nicht erschoepfende Auswahl gaengiger Rassen/Arten, genug fuer realistische Testabdeckung.
-- Rasse ist rein beschreibend/Anzeige (siehe context/ENTWICKLUNG.md Abschnitt 8a/9: bewusst nicht
-- Teil des Matchings). Seltene Rassen ausserhalb des Katalogs deckt weiterhin tier.beschreibung ab
-- (z. B. "Mischling, vermutlich mit Jack-Russell-Anteil") - keine zusaetzliche Freitextspalte noetig.
INSERT INTO tier_rasse (id, tierart_id, name) VALUES
    -- Hund (tierart_id 1)
    (1, 1, 'Mischling'), (2, 1, 'Labrador Retriever'), (3, 1, 'Golden Retriever'),
    (4, 1, 'Deutscher Schaeferhund'), (5, 1, 'Jack Russell Terrier'), (6, 1, 'Mops'),
    (7, 1, 'Dackel'), (8, 1, 'Chihuahua'), (9, 1, 'Border Collie'), (10, 1, 'Beagle'),
    (11, 1, 'Boxer'), (12, 1, 'Malinois (Belgischer Schaeferhund)'), (13, 1, 'Siberian Husky'),
    -- Katze (tierart_id 2)
    (14, 2, 'Hauskatze (Mischling)'), (15, 2, 'Europaeisch Kurzhaar'), (16, 2, 'Britisch Kurzhaar'),
    (17, 2, 'Maine Coon'), (18, 2, 'Siamkatze'), (19, 2, 'Perserkatze'), (20, 2, 'Bengalkatze'),
    (21, 2, 'Norwegische Waldkatze'), (22, 2, 'Russisch Blau'), (23, 2, 'Ragdoll'), (24, 2, 'Sphynx'),
    -- Kaninchen (tierart_id 3)
    (25, 3, 'Mischling'), (26, 3, 'Deutscher Widder'), (27, 3, 'Loewenkopf'), (28, 3, 'Zwergkaninchen'),
    (29, 3, 'Rex-Kaninchen'), (30, 3, 'Zwergwidder'), (31, 3, 'Hermelin'),
    (32, 3, 'Rheinischer Schecke'), (33, 3, 'Farbenzwerg'),
    -- Meerschweinchen (tierart_id 4)
    (34, 4, 'Mischling'), (35, 4, 'Glatthaar'), (36, 4, 'Rosetten-Meerschweinchen (Abessinier)'),
    (37, 4, 'Peru-Meerschweinchen'), (38, 4, 'Sheltie'), (39, 4, 'Skinny Pig'),
    (40, 4, 'Teddy'), (41, 4, 'Texel'),
    -- Vogel (tierart_id 5)
    (42, 5, 'Mischling / unbekannte Art'), (43, 5, 'Wellensittich'), (44, 5, 'Nymphensittich'),
    (45, 5, 'Kanarienvogel'), (46, 5, 'Zebrafink'), (47, 5, 'Agapornis (Unzertrennliche)'),
    (48, 5, 'Graupapagei'), (49, 5, 'Ara'), (50, 5, 'Kakadu');
