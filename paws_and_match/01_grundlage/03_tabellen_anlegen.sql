-- Basistabellen sowie die Trigger fuer Bewerbung und Vermittlung.
USE paws_match;
SET NAMES utf8mb4;

CREATE TABLE tierheim (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(150),
    website VARCHAR(1000),
    datenstatus ENUM('verifiziert', 'zu_pruefen') NOT NULL DEFAULT 'zu_pruefen',
    quelle_url VARCHAR(1000),
    geprueft_am DATE,
    CONSTRAINT ck_tierheim_email CHECK (email IS NULL OR email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$')
) ENGINE = InnoDB;

CREATE TABLE standort (
    id INT PRIMARY KEY AUTO_INCREMENT,
    tierheim_id INT NOT NULL,
    name VARCHAR(120) NOT NULL,
    art ENUM('tierheim', 'auffangstation', 'katzenhaus', 'pflegestellen', 'pflegeverein') NOT NULL DEFAULT 'tierheim',
    ort_id INT NOT NULL,
    bezirk_id INT NULL,
    strasse VARCHAR(150),
    plz CHAR(5),
    breitengrad DECIMAL(9,6),
    laengengrad DECIMAL(9,6),
    quelle_url VARCHAR(1000),
    geprueft_am DATE,
    datenstatus ENUM('verifiziert', 'zu_pruefen') NOT NULL DEFAULT 'zu_pruefen',
    kapazitaet INT NULL,
    CONSTRAINT fk_standort_tierheim FOREIGN KEY (tierheim_id) REFERENCES tierheim(id),
    CONSTRAINT fk_standort_ort FOREIGN KEY (ort_id) REFERENCES ort(id),
    CONSTRAINT fk_standort_bezirk FOREIGN KEY (bezirk_id) REFERENCES bezirk(id),
    CONSTRAINT ck_standort_kapazitaet CHECK (kapazitaet IS NULL OR kapazitaet > 0),
    CONSTRAINT ck_standort_plz CHECK (plz IS NULL OR plz REGEXP '^[0-9]{5}$'),
    CONSTRAINT ck_standort_breitengrad CHECK (breitengrad BETWEEN -90 AND 90),
    CONSTRAINT ck_standort_laengengrad CHECK (laengengrad BETWEEN -180 AND 180),
    CONSTRAINT ck_standort_koordinatenpaar CHECK (
        (breitengrad IS NULL AND laengengrad IS NULL)
        OR (breitengrad IS NOT NULL AND laengengrad IS NOT NULL)
    )
) ENGINE = InnoDB;

CREATE TABLE mitarbeiter (
    id INT PRIMARY KEY AUTO_INCREMENT,
    standort_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    CONSTRAINT fk_mitarbeiter_standort FOREIGN KEY (standort_id) REFERENCES standort(id),
    CONSTRAINT ck_mitarbeiter_email CHECK (email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$')
) ENGINE = InnoDB;

CREATE TABLE tierart (
    id INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
) ENGINE = InnoDB;

CREATE TABLE interessent (
    id INT PRIMARY KEY AUTO_INCREMENT,
    pseudonym VARCHAR(80) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    bezirk_id INT NULL,
    aktiv BOOLEAN NOT NULL DEFAULT TRUE,
    max_suchzone_id INT NULL,
    max_entfernung_km SMALLINT NULL,
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
    CONSTRAINT fk_interessent_bezirk FOREIGN KEY (bezirk_id) REFERENCES bezirk(id),
    CONSTRAINT fk_interessent_max_suchzone FOREIGN KEY (max_suchzone_id) REFERENCES suchzone(id),
    -- Ohne Bezirk geht nur bei anonymisierten Profilen, die sind immer inaktiv.
    CONSTRAINT ck_interessent_bezirk CHECK (aktiv = 0 OR bezirk_id IS NOT NULL),
    CONSTRAINT ck_interessent_email CHECK (email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$'),
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
    CONSTRAINT ck_interessent_aktivitaet CHECK (aktivitaet BETWEEN 1 AND 5),
    CONSTRAINT ck_interessent_max_entfernung CHECK (
        max_entfernung_km IS NULL OR
        (max_entfernung_km BETWEEN 5 AND 250 AND MOD(max_entfernung_km, 5) = 0)
    )
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
    -- 'geloescht' = archiviert (Historie/FK-Constraints bleiben bestehen, kein Hard-Delete):
    -- sp_tier_loeschen setzt diesen Status statt das Tier zu entfernen, wenn eine Bewerbung
    -- existiert. Fachlich eigenstaendig, nicht zu verwechseln mit 'nicht_vermittelbar'
    -- (= nicht adoptierbar, aber weiterhin aktiv verwaltet).
    status ENUM('verfuegbar', 'reserviert', 'vermittelt', 'nicht_vermittelbar', 'geloescht') NOT NULL DEFAULT 'verfuegbar',
    -- Bei 'reserviert' muss feststehen, fuer welche Bewerbung reserviert wurde (Fremdschluessel weiter unten).
    reserviert_fuer_bewerbung_id INT NULL,
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
    CONSTRAINT ck_tier_reservierung CHECK (
        (status = 'reserviert' AND reserviert_fuer_bewerbung_id IS NOT NULL)
        OR (status <> 'reserviert' AND reserviert_fuer_bewerbung_id IS NULL)
    ),
    INDEX idx_tier_status_art (status, tierart_id, standort_id)
) ENGINE = InnoDB;

-- Serverseitige Mehrfachklick-Sperre beim Tier-Anlegen (P0.1/P0.3): die Oberflaeche erzeugt
-- pro Formularinstanz einen Client-Token; die PK-Eindeutigkeit verhindert, dass ein zweiter
-- Aufruf mit demselben Token erneut einfuegt (er bekommt stattdessen die schon angelegte
-- tier_id zurueck). Keine eigene Bereinigung/Ablaufzeit vorgesehen (geringes Datenvolumen).
CREATE TABLE tier_anlage_token (
    token VARCHAR(64) PRIMARY KEY,
    tier_id INT NULL,
    erstellt_am TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tier_anlage_token_tier FOREIGN KEY (tier_id) REFERENCES tier(id) ON DELETE CASCADE
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

-- Bewerbung, Termin und Vermittlung sind Historie. Darum kein Cascade, Loeschen wird hier blockiert.
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

-- Erst jetzt moeglich, weil bewerbung auf tier zeigt und tier auf bewerbung zurueckverweist.
ALTER TABLE tier
    ADD CONSTRAINT fk_tier_reservierung FOREIGN KEY (reserviert_fuer_bewerbung_id) REFERENCES bewerbung(id);

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
    beendigungsgrund ENUM('rueckgabe', 'verstorben', 'sonstiges') NULL,
    notiz TEXT,
    aktives_tier INT GENERATED ALWAYS AS (CASE WHEN beendet_am IS NULL THEN tier_id ELSE NULL END) STORED,
    CONSTRAINT uq_vermittlung_aktives_tier UNIQUE (aktives_tier),
    CONSTRAINT fk_vermittlung_bewerbung FOREIGN KEY (bewerbung_id) REFERENCES bewerbung(id),
    CONSTRAINT fk_vermittlung_tier FOREIGN KEY (tier_id) REFERENCES tier(id),
    CONSTRAINT fk_vermittlung_mitarbeiter FOREIGN KEY (mitarbeiter_id) REFERENCES mitarbeiter(id),
    CONSTRAINT ck_vermittlung_zeitraum CHECK (beendet_am IS NULL OR beendet_am >= vermittelt_am),
    CONSTRAINT ck_vermittlung_beendigung CHECK (
        (beendet_am IS NULL AND beendigungsgrund IS NULL)
        OR (beendet_am IS NOT NULL AND beendigungsgrund IS NOT NULL)
    )
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
          AND t.reserviert_fuer_bewerbung_id = NEW.bewerbung_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vermittlung nur ueber sp_vermitteln abschliessen.';
    END IF;
END$$

-- Eine Reservierung muss immer zu einer laufenden Bewerbung fuer genau dieses Tier gehoeren.
CREATE TRIGGER trg_tier_reservierung
BEFORE UPDATE ON tier
FOR EACH ROW
BEGIN
    IF NEW.reserviert_fuer_bewerbung_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM bewerbung b
            WHERE b.id = NEW.reserviert_fuer_bewerbung_id
              AND b.tier_id = NEW.id
              AND b.status IN ('offen', 'in_pruefung', 'angenommen')
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Reservierung braucht eine laufende Bewerbung fuer dieses Tier.';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_vermittlung_beenden_pruefen
BEFORE UPDATE ON vermittlung
FOR EACH ROW
BEGIN
    IF OLD.beendet_am IS NOT NULL AND NEW.beendet_am IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Eine beendete Vermittlung kann nicht wieder geoeffnet werden.';
    END IF;

    -- Gleiches Vorgehen wie beim Vermitteln: die Prozedur reserviert das Tier vorher.
    IF NOT (NEW.beendet_am <=> OLD.beendet_am) THEN
        IF NOT EXISTS (
            SELECT 1 FROM tier t
            WHERE t.id = NEW.tier_id
              AND t.status = 'reserviert'
              AND t.reserviert_fuer_bewerbung_id = NEW.bewerbung_id
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Vermittlung nur ueber sp_vermittlung_beenden beenden.';
        END IF;
    END IF;
END$$

-- P0.2: serverseitige Standortberechtigung beim direkten Tier-Schreiben aus der Oberflaeche
-- (ui/queries.py fuehrt INSERT/UPDATE auf tier ohne Prozeduraufruf aus). Vertrag mit den
-- schreibenden Prozeduren in 05_prozeduren: diese setzen vor ihrem eigenen UPDATE/DELETE auf
-- tier `SET @pm_ist_admin = 1;` als bewussten Bypass (sie haben bereits eine eigene, staerkere
-- Standortpruefung ueber ihren p_mitarbeiter-Parameter). Fail-closed per Design: sind die
-- Sitzungsvariablen nicht gesetzt (NULL), wird blockiert, nicht durchgelassen.
CREATE TRIGGER trg_tier_standort_pruefen_insert
BEFORE INSERT ON tier
FOR EACH ROW
BEGIN
    IF NOT (@pm_ist_admin <=> 1) THEN
        IF NOT EXISTS (
            SELECT 1 FROM mitarbeiter
            WHERE id = @pm_mitarbeiter_id AND standort_id = NEW.standort_id
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Mitarbeiter gehoert nicht zum Standort des Tieres.';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_tier_standort_pruefen_update
BEFORE UPDATE ON tier
FOR EACH ROW
BEGIN
    IF NOT (@pm_ist_admin <=> 1) THEN
        IF NOT EXISTS (
            SELECT 1 FROM mitarbeiter
            WHERE id = @pm_mitarbeiter_id AND standort_id = NEW.standort_id
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Mitarbeiter gehoert nicht zum Standort des Tieres.';
        END IF;
    END IF;
END$$

DELIMITER ;
