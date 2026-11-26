-- Anmeldedaten fuer die Oberflaeche: ein Konto je Mitarbeiter plus ein Adminkonto.
USE paws_match;
SET NAMES utf8mb4;

DROP TABLE IF EXISTS benutzerkonto;

CREATE TABLE benutzerkonto (
    id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(150) NOT NULL UNIQUE,
    passwort_hash VARCHAR(255) NOT NULL,
    rolle ENUM('mitarbeiter', 'admin') NOT NULL,
    -- Admins haengen an keinem Standort, Mitarbeiterkonten immer.
    mitarbeiter_id INT NULL,
    aktiv BOOLEAN NOT NULL DEFAULT TRUE,
    angelegt_am DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_benutzerkonto_mitarbeiter FOREIGN KEY (mitarbeiter_id) REFERENCES mitarbeiter(id),
    CONSTRAINT uq_benutzerkonto_mitarbeiter UNIQUE (mitarbeiter_id),
    CONSTRAINT ck_benutzerkonto_rolle CHECK (
        (rolle = 'admin' AND mitarbeiter_id IS NULL)
        OR (rolle = 'mitarbeiter' AND mitarbeiter_id IS NOT NULL)
    ),
    CONSTRAINT ck_benutzerkonto_email CHECK (email REGEXP '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$'),
    CONSTRAINT ck_benutzerkonto_aktiv CHECK (aktiv IN (0, 1))
) ENGINE = InnoDB;

-- Demokonten. Passwort fuer alle: paws2026 (nur fuer den lokalen Testbetrieb gedacht).
-- Der Hash ist ein bcrypt-Hash; die Oberflaeche prueft ihn mit der Bibliothek bcrypt.
INSERT INTO benutzerkonto (email, passwort_hash, rolle, mitarbeiter_id)
SELECT m.email, '$2b$10$J.4d98B5nGggpMl5cfwVyuH3PELAx20qUa9vHD79vvjbNHBQu6fFG', 'mitarbeiter', m.id
FROM mitarbeiter m;

INSERT INTO benutzerkonto (email, passwort_hash, rolle, mitarbeiter_id) VALUES
    ('admin@example.org', '$2b$10$J.4d98B5nGggpMl5cfwVyuH3PELAx20qUa9vHD79vvjbNHBQu6fFG', 'admin', NULL);

SELECT rolle, COUNT(*) AS konten FROM benutzerkonto GROUP BY rolle;
