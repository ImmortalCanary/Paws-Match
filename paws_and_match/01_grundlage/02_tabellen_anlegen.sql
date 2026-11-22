USE paws_match;
SET NAMES utf8mb4;

CREATE TABLE tierheim (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    CONSTRAINT ck_tierheim_email CHECK (email LIKE '%_@_%._%')
) ENGINE = InnoDB;

CREATE TABLE standort (
    id INT PRIMARY KEY AUTO_INCREMENT,
    tierheim_id INT NOT NULL,
    name VARCHAR(120) NOT NULL,
    bezirk VARCHAR(60) NOT NULL,
    ort VARCHAR(50) NOT NULL DEFAULT 'Berlin',
    kapazitaet INT NOT NULL,
    CONSTRAINT fk_standort_tierheim FOREIGN KEY (tierheim_id) REFERENCES tierheim(id),
    CONSTRAINT ck_standort_kapazitaet CHECK (kapazitaet > 0),
    CONSTRAINT ck_standort_ort CHECK (ort = 'Berlin')
) ENGINE = InnoDB;

CREATE TABLE mitarbeiter (
    id INT PRIMARY KEY AUTO_INCREMENT,
    standort_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    CONSTRAINT fk_mitarbeiter_standort FOREIGN KEY (standort_id) REFERENCES standort(id),
    CONSTRAINT ck_mitarbeiter_email CHECK (email LIKE '%_@_%._%')
) ENGINE = InnoDB;

CREATE TABLE tierart (
    id INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
) ENGINE = InnoDB;

CREATE TABLE interessent (
    id INT PRIMARY KEY AUTO_INCREMENT,
    pseudonym VARCHAR(80) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    bezirk VARCHAR(60) NOT NULL,
    aktiv BOOLEAN NOT NULL DEFAULT TRUE,
    wohnflaeche DECIMAL(6,2),
    garten BOOLEAN,
    etage INT,
    aufzug BOOLEAN,
    kinder BOOLEAN,
    hund_vorhanden BOOLEAN,
    katze_vorhanden BOOLEAN,
    zeit_stunden DECIMAL(4,1),
    allein_stunden DECIMAL(4,1),
    erfahrung INT,
    budget DECIMAL(8,2),
    medizin_bereit BOOLEAN,
    aktivitaet INT,
    CONSTRAINT ck_interessent_email CHECK (email LIKE '%_@_%._%'),
    CONSTRAINT ck_interessent_aktiv CHECK (aktiv IN (0, 1)),
    CONSTRAINT ck_interessent_wohnflaeche CHECK (wohnflaeche >= 0),
    CONSTRAINT ck_interessent_garten CHECK (garten IN (0, 1)),
    CONSTRAINT ck_interessent_etage CHECK (etage >= 0),
    CONSTRAINT ck_interessent_aufzug CHECK (aufzug IN (0, 1)),
    CONSTRAINT ck_interessent_kinder CHECK (kinder IN (0, 1)),
    CONSTRAINT ck_interessent_hund CHECK (hund_vorhanden IN (0, 1)),
    CONSTRAINT ck_interessent_katze CHECK (katze_vorhanden IN (0, 1)),
    CONSTRAINT ck_interessent_zeit CHECK (zeit_stunden BETWEEN 0 AND 24),
    CONSTRAINT ck_interessent_alleinzeit CHECK (allein_stunden BETWEEN 0 AND 24),
    CONSTRAINT ck_interessent_tagesstunden CHECK (zeit_stunden + allein_stunden <= 24),
    CONSTRAINT ck_interessent_erfahrung CHECK (erfahrung BETWEEN 0 AND 5),
    CONSTRAINT ck_interessent_budget CHECK (budget >= 0),
    CONSTRAINT ck_interessent_medizin CHECK (medizin_bereit IN (0, 1)),
    CONSTRAINT ck_interessent_aktivitaet CHECK (aktivitaet BETWEEN 1 AND 5)
) ENGINE = InnoDB;

CREATE TABLE tier (
    id INT PRIMARY KEY AUTO_INCREMENT,
    standort_id INT NOT NULL,
    tierart_id INT NOT NULL,
    name VARCHAR(80) NOT NULL,
    geburtsdatum DATE,
    geburt_geschaetzt BOOLEAN NOT NULL DEFAULT FALSE,
    geschlecht ENUM('weiblich', 'maennlich', 'unbekannt') NOT NULL DEFAULT 'unbekannt',
    gewicht_kg DECIMAL(6,2),
    beschreibung TEXT,
    status ENUM('verfuegbar', 'reserviert', 'vermittelt', 'nicht_vermittelbar') NOT NULL DEFAULT 'verfuegbar',
    aktivitaet INT,
    min_wohnflaeche DECIMAL(6,2),
    garten_noetig BOOLEAN,
    treppen_vermeiden BOOLEAN,
    kinder_ok BOOLEAN,
    hund_ok BOOLEAN,
    katze_ok BOOLEAN,
    min_zeit DECIMAL(4,1),
    max_allein DECIMAL(4,1),
    min_erfahrung INT,
    monatskosten DECIMAL(8,2),
    medizin_noetig BOOLEAN,
    CONSTRAINT fk_tier_standort FOREIGN KEY (standort_id) REFERENCES standort(id),
    CONSTRAINT fk_tier_tierart FOREIGN KEY (tierart_id) REFERENCES tierart(id),
    CONSTRAINT ck_tier_geburt_geschaetzt CHECK (geburt_geschaetzt IN (0, 1)),
    CONSTRAINT ck_tier_gewicht CHECK (gewicht_kg > 0),
    CONSTRAINT ck_tier_aktivitaet CHECK (aktivitaet BETWEEN 1 AND 5),
    CONSTRAINT ck_tier_min_wohnflaeche CHECK (min_wohnflaeche >= 0),
    CONSTRAINT ck_tier_garten_noetig CHECK (garten_noetig IN (0, 1)),
    CONSTRAINT ck_tier_treppen CHECK (treppen_vermeiden IN (0, 1)),
    CONSTRAINT ck_tier_kinder_ok CHECK (kinder_ok IN (0, 1)),
    CONSTRAINT ck_tier_hund_ok CHECK (hund_ok IN (0, 1)),
    CONSTRAINT ck_tier_katze_ok CHECK (katze_ok IN (0, 1)),
    CONSTRAINT ck_tier_min_zeit CHECK (min_zeit BETWEEN 0 AND 24),
    CONSTRAINT ck_tier_max_allein CHECK (max_allein BETWEEN 0 AND 24),
    CONSTRAINT ck_tier_tagesstunden CHECK (min_zeit + max_allein <= 24),
    CONSTRAINT ck_tier_min_erfahrung CHECK (min_erfahrung BETWEEN 0 AND 5),
    CONSTRAINT ck_tier_monatskosten CHECK (monatskosten >= 0),
    CONSTRAINT ck_tier_medizin CHECK (medizin_noetig IN (0, 1)),
    INDEX idx_tier_status_art (status, tierart_id, standort_id)
) ENGINE = InnoDB;

CREATE TABLE charakter (
    id INT PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE
) ENGINE = InnoDB;

CREATE TABLE tier_charakter (
    tier_id INT NOT NULL,
    charakter_id INT NOT NULL,
    PRIMARY KEY (tier_id, charakter_id),
    CONSTRAINT fk_tier_charakter_tier FOREIGN KEY (tier_id) REFERENCES tier(id) ON DELETE CASCADE,
    CONSTRAINT fk_tier_charakter_charakter FOREIGN KEY (charakter_id) REFERENCES charakter(id)
) ENGINE = InnoDB;

CREATE TABLE interessent_charakter (
    interessent_id INT NOT NULL,
    charakter_id INT NOT NULL,
    PRIMARY KEY (interessent_id, charakter_id),
    CONSTRAINT fk_interessent_charakter_interessent FOREIGN KEY (interessent_id) REFERENCES interessent(id) ON DELETE CASCADE,
    CONSTRAINT fk_interessent_charakter_charakter FOREIGN KEY (charakter_id) REFERENCES charakter(id)
) ENGINE = InnoDB;

CREATE TABLE interessent_tierart (
    interessent_id INT NOT NULL,
    tierart_id INT NOT NULL,
    PRIMARY KEY (interessent_id, tierart_id),
    CONSTRAINT fk_interessent_tierart_interessent FOREIGN KEY (interessent_id) REFERENCES interessent(id) ON DELETE CASCADE,
    CONSTRAINT fk_interessent_tierart_tierart FOREIGN KEY (tierart_id) REFERENCES tierart(id)
) ENGINE = InnoDB;

CREATE TABLE beduerfnis (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
) ENGINE = InnoDB;

CREATE TABLE tier_beduerfnis (
    tier_id INT NOT NULL,
    beduerfnis_id INT NOT NULL,
    hinweis VARCHAR(250),
    PRIMARY KEY (tier_id, beduerfnis_id),
    CONSTRAINT fk_tier_beduerfnis_tier FOREIGN KEY (tier_id) REFERENCES tier(id) ON DELETE CASCADE,
    CONSTRAINT fk_tier_beduerfnis_beduerfnis FOREIGN KEY (beduerfnis_id) REFERENCES beduerfnis(id)
) ENGINE = InnoDB;

CREATE TABLE interessent_beduerfnis (
    interessent_id INT NOT NULL,
    beduerfnis_id INT NOT NULL,
    bestaetigt BOOLEAN NOT NULL,
    PRIMARY KEY (interessent_id, beduerfnis_id),
    CONSTRAINT fk_interessent_beduerfnis_interessent FOREIGN KEY (interessent_id) REFERENCES interessent(id) ON DELETE CASCADE,
    CONSTRAINT fk_interessent_beduerfnis_beduerfnis FOREIGN KEY (beduerfnis_id) REFERENCES beduerfnis(id),
    CONSTRAINT ck_interessent_beduerfnis_bestaetigt CHECK (bestaetigt IN (0, 1))
) ENGINE = InnoDB;

CREATE TABLE merkliste (
    interessent_id INT NOT NULL,
    tier_id INT NOT NULL,
    erstellt_am TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (interessent_id, tier_id),
    CONSTRAINT fk_merkliste_interessent FOREIGN KEY (interessent_id) REFERENCES interessent(id) ON DELETE CASCADE,
    CONSTRAINT fk_merkliste_tier FOREIGN KEY (tier_id) REFERENCES tier(id) ON DELETE CASCADE
) ENGINE = InnoDB;

-- Bewerbungen, Termine und Vermittlungen sind Historie: kein Cascade, Loeschen wird blockiert.
CREATE TABLE bewerbung (
    id INT PRIMARY KEY AUTO_INCREMENT,
    interessent_id INT NOT NULL,
    tier_id INT NOT NULL,
    status ENUM('offen', 'in_pruefung', 'abgelehnt', 'zurueckgezogen', 'angenommen') NOT NULL DEFAULT 'offen',
    erstellt_am TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notiz TEXT,
    CONSTRAINT uq_bewerbung_paar UNIQUE (interessent_id, tier_id),
    CONSTRAINT fk_bewerbung_interessent FOREIGN KEY (interessent_id) REFERENCES interessent(id),
    CONSTRAINT fk_bewerbung_tier FOREIGN KEY (tier_id) REFERENCES tier(id)
) ENGINE = InnoDB;

CREATE TABLE termin (
    id INT PRIMARY KEY AUTO_INCREMENT,
    bewerbung_id INT NOT NULL,
    mitarbeiter_id INT NOT NULL,
    zeitpunkt DATETIME NOT NULL,
    art ENUM('gespraech', 'kennenlernen', 'nachkontrolle') NOT NULL,
    CONSTRAINT fk_termin_bewerbung FOREIGN KEY (bewerbung_id) REFERENCES bewerbung(id),
    CONSTRAINT fk_termin_mitarbeiter FOREIGN KEY (mitarbeiter_id) REFERENCES mitarbeiter(id)
) ENGINE = InnoDB;

CREATE TABLE vermittlung (
    id INT PRIMARY KEY AUTO_INCREMENT,
    bewerbung_id INT NOT NULL UNIQUE,
    tier_id INT NOT NULL,
    mitarbeiter_id INT NOT NULL,
    vermittelt_am DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    beendet_am DATETIME NULL,
    notiz TEXT,
    aktives_tier INT GENERATED ALWAYS AS (CASE WHEN beendet_am IS NULL THEN tier_id ELSE NULL END) STORED,
    CONSTRAINT uq_vermittlung_aktives_tier UNIQUE (aktives_tier),
    CONSTRAINT fk_vermittlung_bewerbung FOREIGN KEY (bewerbung_id) REFERENCES bewerbung(id),
    CONSTRAINT fk_vermittlung_tier FOREIGN KEY (tier_id) REFERENCES tier(id),
    CONSTRAINT fk_vermittlung_mitarbeiter FOREIGN KEY (mitarbeiter_id) REFERENCES mitarbeiter(id),
    CONSTRAINT ck_vermittlung_zeitraum CHECK (beendet_am IS NULL OR beendet_am >= vermittelt_am)
) ENGINE = InnoDB;

DELIMITER $$

CREATE TRIGGER trg_bewerbung_pruefen
BEFORE INSERT ON bewerbung
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(30);

    SELECT status INTO v_status FROM tier WHERE id = NEW.tier_id FOR UPDATE;

    IF v_status <> 'verfuegbar' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tier ist nicht verfuegbar.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM interessent WHERE id = NEW.interessent_id AND aktiv = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Interessentenprofil ist nicht aktiv.';
    END IF;
END$$

CREATE TRIGGER trg_vermittlung_pruefen
BEFORE INSERT ON vermittlung
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM bewerbung b
        JOIN tier t ON t.id = b.tier_id
        JOIN mitarbeiter m ON m.standort_id = t.standort_id
        WHERE b.id = NEW.bewerbung_id
          AND b.tier_id = NEW.tier_id
          AND b.status = 'angenommen'
          AND m.id = NEW.mitarbeiter_id
          AND t.status = 'reserviert'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vermittlung nur ueber sp_vermitteln abschliessen.';
    END IF;
END$$

CREATE PROCEDURE sp_vermitteln (IN p_bewerbung INT, IN p_mitarbeiter INT)
MODIFIES SQL DATA
BEGIN
    DECLARE v_tier INT DEFAULT NULL;
    DECLARE v_interessent INT DEFAULT NULL;
    DECLARE v_tierstatus VARCHAR(30);
    DECLARE v_bewerbungsstatus VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT tier_id INTO v_tier FROM bewerbung WHERE id = p_bewerbung;

    IF v_tier IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bewerbung nicht gefunden.';
    END IF;

    -- Gleiche Sperrreihenfolge wie trg_bewerbung_pruefen (erst Tier, dann Bewerbung).
    SELECT status INTO v_tierstatus FROM tier WHERE id = v_tier FOR UPDATE;
    SELECT status, interessent_id INTO v_bewerbungsstatus, v_interessent
    FROM bewerbung WHERE id = p_bewerbung FOR UPDATE;

    IF NOT EXISTS (
        SELECT 1 FROM mitarbeiter m JOIN tier t ON t.standort_id = m.standort_id
        WHERE m.id = p_mitarbeiter AND t.id = v_tier
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mitarbeiter gehoert nicht zum Standort des Tieres.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM interessent WHERE id = v_interessent AND aktiv = 1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Interessentenprofil ist nicht aktiv.';
    END IF;

    IF v_tierstatus NOT IN ('verfuegbar', 'reserviert')
       OR v_bewerbungsstatus NOT IN ('offen', 'in_pruefung') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vermittlung in diesem Status nicht moeglich.';
    END IF;

    UPDATE tier SET status = 'reserviert' WHERE id = v_tier;
    UPDATE bewerbung SET status = 'angenommen' WHERE id = p_bewerbung;

    INSERT INTO vermittlung (bewerbung_id, tier_id, mitarbeiter_id)
    VALUES (p_bewerbung, v_tier, p_mitarbeiter);

    UPDATE tier SET status = 'vermittelt' WHERE id = v_tier;

    UPDATE bewerbung
    SET status = 'abgelehnt',
        notiz = CONCAT_WS(' | ', notiz, 'Automatisch abgelehnt: Tier wurde anderweitig vermittelt.')
    WHERE tier_id = v_tier
      AND id <> p_bewerbung
      AND status IN ('offen', 'in_pruefung');

    COMMIT;
END$$

DELIMITER ;
