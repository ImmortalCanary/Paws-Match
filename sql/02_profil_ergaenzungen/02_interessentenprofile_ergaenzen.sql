USE paws_match;
SET NAMES utf8mb4;

CREATE TABLE wohnform (
    id INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
) ENGINE = InnoDB;

CREATE TABLE arbeitsmodell (
    id INT PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE
) ENGINE = InnoDB;

INSERT INTO wohnform (id, name) VALUES
    (1, 'Wohnung'),
    (2, 'Haus'),
    (3, 'Reihenhaus'),
    (4, 'Wohngemeinschaft'),
    (5, 'Sonstige Wohnform');

INSERT INTO arbeitsmodell (id, name) VALUES
    (1, 'Ueberwiegend vor Ort'),
    (2, 'Ueberwiegend zu Hause'),
    (3, 'Hybrid'),
    (4, 'Wechselnde Arbeitszeiten'),
    (5, 'Keine Erwerbstaetigkeit');

ALTER TABLE interessent
    ADD COLUMN wohnform_id INT NULL,
    ADD COLUMN balkon BOOLEAN NULL,
    ADD COLUMN balkon_gesichert BOOLEAN NULL,
    ADD COLUMN haushaltsgroesse INT NULL,
    ADD COLUMN kleintiere_vorhanden BOOLEAN NULL,
    ADD COLUMN arbeitsmodell_id INT NULL,
    ADD COLUMN wunschalter_min DECIMAL(5,2) NULL,
    ADD COLUMN wunschalter_max DECIMAL(5,2) NULL,
    ADD COLUMN training_bereit BOOLEAN NULL,
    ADD COLUMN tierarzt_bereit BOOLEAN NULL,
    ADD COLUMN max_pflegeaufwand_id INT NULL,
    ADD CONSTRAINT fk_interessent_wohnform
        FOREIGN KEY (wohnform_id) REFERENCES wohnform(id),
    ADD CONSTRAINT fk_interessent_arbeitsmodell
        FOREIGN KEY (arbeitsmodell_id) REFERENCES arbeitsmodell(id),
    ADD CONSTRAINT fk_interessent_pflegeaufwand
        FOREIGN KEY (max_pflegeaufwand_id) REFERENCES pflegeaufwand(id),
    ADD CONSTRAINT ck_interessent_balkon CHECK (balkon IN (0, 1)),
    ADD CONSTRAINT ck_interessent_balkon_gesichert
        CHECK (balkon_gesichert IN (0, 1)),
    ADD CONSTRAINT ck_interessent_gesicherter_balkon CHECK (
        balkon_gesichert IS NULL
        OR balkon_gesichert = 0
        OR (balkon IS NOT NULL AND balkon = 1)
    ),
    ADD CONSTRAINT ck_interessent_haushalt CHECK (haushaltsgroesse >= 1),
    ADD CONSTRAINT ck_interessent_kleintiere
        CHECK (kleintiere_vorhanden IN (0, 1)),
    ADD CONSTRAINT ck_interessent_wunschalter_min
        CHECK (wunschalter_min >= 0),
    ADD CONSTRAINT ck_interessent_wunschalter_max
        CHECK (wunschalter_max >= 0),
    ADD CONSTRAINT ck_interessent_altersbereich
        CHECK (wunschalter_min <= wunschalter_max),
    ADD CONSTRAINT ck_interessent_training CHECK (training_bereit IN (0, 1)),
    ADD CONSTRAINT ck_interessent_tierarzt CHECK (tierarzt_bereit IN (0, 1));

CREATE TABLE interessent_groesse (
    interessent_id INT NOT NULL,
    groesse_id INT NOT NULL,
    PRIMARY KEY (interessent_id, groesse_id),
    CONSTRAINT fk_interessent_groesse_interessent
        FOREIGN KEY (interessent_id) REFERENCES interessent(id),
    CONSTRAINT fk_interessent_groesse_groesse
        FOREIGN KEY (groesse_id) REFERENCES tier_groesse(id)
) ENGINE = InnoDB;

CREATE TABLE interessent_standort (
    interessent_id INT NOT NULL,
    standort_id INT NOT NULL,
    PRIMARY KEY (interessent_id, standort_id),
    CONSTRAINT fk_interessent_standort_interessent
        FOREIGN KEY (interessent_id) REFERENCES interessent(id),
    CONSTRAINT fk_interessent_standort_standort
        FOREIGN KEY (standort_id) REFERENCES standort(id)
) ENGINE = InnoDB;

CREATE TABLE interessent_tiererfahrung (
    interessent_id INT NOT NULL,
    tierart_id INT NOT NULL,
    erfahrungslevel INT NOT NULL,
    PRIMARY KEY (interessent_id, tierart_id),
    CONSTRAINT fk_interessent_tiererfahrung_interessent
        FOREIGN KEY (interessent_id) REFERENCES interessent(id),
    CONSTRAINT fk_interessent_tiererfahrung_tierart
        FOREIGN KEY (tierart_id) REFERENCES tierart(id),
    CONSTRAINT ck_interessent_tiererfahrung
        CHECK (erfahrungslevel BETWEEN 0 AND 5)
) ENGINE = InnoDB;
