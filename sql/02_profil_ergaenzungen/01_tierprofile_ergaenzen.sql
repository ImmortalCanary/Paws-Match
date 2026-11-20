USE paws_match;
SET NAMES utf8mb4;

CREATE TABLE tier_rasse (
    id INT PRIMARY KEY AUTO_INCREMENT,
    tierart_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    CONSTRAINT uq_tier_rasse UNIQUE (tierart_id, name),
    CONSTRAINT uq_tier_rasse_id UNIQUE (id, tierart_id),
    CONSTRAINT fk_tier_rasse_tierart
        FOREIGN KEY (tierart_id) REFERENCES tierart(id)
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
    beschreibung VARCHAR(500)
) ENGINE = InnoDB;

CREATE TABLE tier_gesundheit (
    tier_id INT NOT NULL,
    gesundheitsmerkmal_id INT NOT NULL,
    bestaetigt BOOLEAN NOT NULL,
    geprueft_am DATE NOT NULL,
    hinweis VARCHAR(500),
    PRIMARY KEY (tier_id, gesundheitsmerkmal_id),
    CONSTRAINT fk_tier_gesundheit_tier FOREIGN KEY (tier_id) REFERENCES tier(id),
    CONSTRAINT fk_tier_gesundheit_merkmal
        FOREIGN KEY (gesundheitsmerkmal_id) REFERENCES gesundheitsmerkmal(id),
    CONSTRAINT ck_tier_gesundheit_bestaetigt CHECK (bestaetigt IN (0, 1))
) ENGINE = InnoDB;

ALTER TABLE tier
    ADD COLUMN rasse_id INT NULL,
    ADD COLUMN groesse_id INT NULL,
    ADD COLUMN pflegeaufwand_id INT NULL,
    ADD COLUMN foto_url VARCHAR(2048) NULL,
    ADD CONSTRAINT fk_tier_rasse FOREIGN KEY (rasse_id, tierart_id)
        REFERENCES tier_rasse(id, tierart_id),
    ADD CONSTRAINT fk_tier_groesse FOREIGN KEY (groesse_id)
        REFERENCES tier_groesse(id),
    ADD CONSTRAINT fk_tier_pflegeaufwand FOREIGN KEY (pflegeaufwand_id)
        REFERENCES pflegeaufwand(id);

INSERT INTO tier_groesse (id, name, rang) VALUES
    (1, 'klein', 1),
    (2, 'mittel', 2),
    (3, 'gross', 3);

INSERT INTO pflegeaufwand (id, name, rang) VALUES
    (1, 'niedrig', 1),
    (2, 'mittel', 2),
    (3, 'hoch', 3);

INSERT INTO gesundheitsmerkmal (name, beschreibung) VALUES
    ('Chronische Erkrankung', 'Art und Versorgung im individuellen Hinweis dokumentieren.'),
    ('Allergie', 'Ausloeser und erforderliche Massnahmen im Hinweis dokumentieren.'),
    ('Gelenkprobleme', 'Mobilitaetsanforderungen zusaetzlich im Tierprofil pruefen.'),
    ('Regelmaessige Medikamentengabe', 'Bedarf und Betreuung zusaetzlich im Matching beruecksichtigen.'),
    ('Behinderung', 'Konkrete Einschraenkungen im Hinweis dokumentieren.'),
    ('Geimpft', 'Pruefdatum und individuellen Impfstatus beachten.'),
    ('Kastriert', 'Bestaetigten oder ausdruecklich verneinten Status dokumentieren.');
