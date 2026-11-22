-- Orte: Bundesland > Ort > Bezirk. Freigeschaltet ist erstmal nur Berlin, ganz Deutschland kommt spaeter.
-- In der Datei stehen amtliche Namen mit Umlauten, also bitte als UTF-8 ausfuehren.
USE paws_match;
SET NAMES utf8mb4;

DELIMITER $$

-- Macht aus 'Neukölln', 'NEUKOELLN' oder ' neukölln ' immer 'neukoelln', damit man Schreibweisen vergleichen kann.
CREATE FUNCTION fn_text_normalisieren (p_text VARCHAR(200))
RETURNS VARCHAR(200)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v VARCHAR(400);

    IF p_text IS NULL THEN
        RETURN NULL;
    END IF;

    SET v = LOWER(TRIM(p_text));
    SET v = REPLACE(v, 'ä', 'ae');
    SET v = REPLACE(v, 'ö', 'oe');
    SET v = REPLACE(v, 'ü', 'ue');
    SET v = REPLACE(v, 'ß', 'ss');
    SET v = REGEXP_REPLACE(v, '[^a-z0-9]', '');

    RETURN NULLIF(v, '');
END$$

-- Levenshtein-Distanz: wie viele Buchstaben man einfuegen, loeschen oder tauschen muss, bis zwei Woerter gleich sind.
CREATE FUNCTION fn_levenshtein (p_a VARCHAR(200), p_b VARCHAR(200))
RETURNS INT
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_la INT DEFAULT CHAR_LENGTH(p_a);
    DECLARE v_lb INT DEFAULT CHAR_LENGTH(p_b);
    DECLARE v_i INT DEFAULT 1;
    DECLARE v_j INT DEFAULT 0;
    DECLARE v_zeichen VARCHAR(1);
    DECLARE v_kosten INT;
    -- Je eine Zeile der Rechenmatrix als Bytes (ein Byte pro Feld reicht, die Texte haben max. 200 Zeichen).
    DECLARE v_vorher VARBINARY(256) DEFAULT '';
    DECLARE v_aktuell VARBINARY(256);

    IF p_a IS NULL OR p_b IS NULL THEN
        RETURN NULL;
    END IF;
    IF v_la = 0 THEN
        RETURN v_lb;
    END IF;
    IF v_lb = 0 THEN
        RETURN v_la;
    END IF;

    WHILE v_j <= v_lb DO
        SET v_vorher = CONCAT(v_vorher, CHAR(v_j USING binary));
        SET v_j = v_j + 1;
    END WHILE;

    WHILE v_i <= v_la DO
        SET v_zeichen = SUBSTRING(p_a, v_i, 1);
        SET v_aktuell = CHAR(v_i USING binary);
        SET v_j = 1;
        WHILE v_j <= v_lb DO
            SET v_kosten = IF(v_zeichen = SUBSTRING(p_b, v_j, 1), 0, 1);
            SET v_aktuell = CONCAT(v_aktuell, CHAR(LEAST(
                ORD(SUBSTRING(v_vorher, v_j, 1)) + v_kosten,
                ORD(SUBSTRING(v_vorher, v_j + 1, 1)) + 1,
                ORD(SUBSTRING(v_aktuell, v_j, 1)) + 1) USING binary));
            SET v_j = v_j + 1;
        END WHILE;
        SET v_vorher = v_aktuell;
        SET v_i = v_i + 1;
    END WHILE;

    RETURN ORD(SUBSTRING(v_vorher, v_lb + 1, 1));
END$$

DELIMITER ;

CREATE TABLE bundesland (
    id INT PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE,
    kuerzel CHAR(2) NOT NULL UNIQUE,
    CONSTRAINT ck_bundesland_id CHECK (id BETWEEN 1 AND 16)
) ENGINE = InnoDB;

CREATE TABLE ort (
    id INT PRIMARY KEY AUTO_INCREMENT,
    bundesland_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    ags CHAR(8) UNIQUE,
    aktiv BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_ort_name UNIQUE (bundesland_id, name),
    CONSTRAINT fk_ort_bundesland FOREIGN KEY (bundesland_id) REFERENCES bundesland(id),
    CONSTRAINT ck_ort_ags CHECK (ags REGEXP '^[0-9]{8}$'),
    CONSTRAINT ck_ort_aktiv CHECK (aktiv IN (0, 1))
) ENGINE = InnoDB;

CREATE TABLE bezirk (
    id INT PRIMARY KEY AUTO_INCREMENT,
    ort_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    schluessel VARCHAR(20),
    suchname VARCHAR(200) NOT NULL DEFAULT '',
    CONSTRAINT uq_bezirk_name UNIQUE (ort_id, name),
    CONSTRAINT uq_bezirk_suchname UNIQUE (ort_id, suchname),
    CONSTRAINT uq_bezirk_schluessel UNIQUE (ort_id, schluessel),
    CONSTRAINT fk_bezirk_ort FOREIGN KEY (ort_id) REFERENCES ort(id),
    CONSTRAINT ck_bezirk_suchname CHECK (suchname <> '')
) ENGINE = InnoDB;

-- Weitere Namen fuer einen Bezirk, z. B. Ortsteile oder alte Bezirksnamen.
CREATE TABLE bezirk_alias (
    id INT PRIMARY KEY AUTO_INCREMENT,
    bezirk_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    suchname VARCHAR(200) NOT NULL DEFAULT '',
    CONSTRAINT uq_bezirk_alias UNIQUE (bezirk_id, suchname),
    CONSTRAINT fk_bezirk_alias_bezirk FOREIGN KEY (bezirk_id) REFERENCES bezirk(id) ON DELETE CASCADE,
    CONSTRAINT ck_bezirk_alias_suchname CHECK (suchname <> '')
) ENGINE = InnoDB;

DELIMITER $$

CREATE TRIGGER trg_bezirk_suchname_neu BEFORE INSERT ON bezirk
FOR EACH ROW SET NEW.suchname = COALESCE(fn_text_normalisieren(NEW.name), '')$$

CREATE TRIGGER trg_bezirk_suchname_aendern BEFORE UPDATE ON bezirk
FOR EACH ROW SET NEW.suchname = COALESCE(fn_text_normalisieren(NEW.name), '')$$

CREATE TRIGGER trg_bezirk_alias_suchname_neu BEFORE INSERT ON bezirk_alias
FOR EACH ROW SET NEW.suchname = COALESCE(fn_text_normalisieren(NEW.name), '')$$

CREATE TRIGGER trg_bezirk_alias_suchname_aendern BEFORE UPDATE ON bezirk_alias
FOR EACH ROW SET NEW.suchname = COALESCE(fn_text_normalisieren(NEW.name), '')$$

DELIMITER ;

-- Die IDs sind die offiziellen Laenderschluessel.
INSERT INTO bundesland (id, name, kuerzel) VALUES
    (1, 'Schleswig-Holstein', 'SH'), (2, 'Hamburg', 'HH'), (3, 'Niedersachsen', 'NI'),
    (4, 'Bremen', 'HB'), (5, 'Nordrhein-Westfalen', 'NW'), (6, 'Hessen', 'HE'),
    (7, 'Rheinland-Pfalz', 'RP'), (8, 'Baden-Württemberg', 'BW'), (9, 'Bayern', 'BY'),
    (10, 'Saarland', 'SL'), (11, 'Berlin', 'BE'), (12, 'Brandenburg', 'BB'),
    (13, 'Mecklenburg-Vorpommern', 'MV'), (14, 'Sachsen', 'SN'), (15, 'Sachsen-Anhalt', 'ST'),
    (16, 'Thüringen', 'TH');

INSERT INTO ort (id, bundesland_id, name, ags, aktiv) VALUES
    (1, 11, 'Berlin', '11000000', 1);

-- ID und Schluessel sind die Berliner Bezirksnummern.
INSERT INTO bezirk (id, ort_id, name, schluessel) VALUES
    (1, 1, 'Mitte', '01'),
    (2, 1, 'Friedrichshain-Kreuzberg', '02'),
    (3, 1, 'Pankow', '03'),
    (4, 1, 'Charlottenburg-Wilmersdorf', '04'),
    (5, 1, 'Spandau', '05'),
    (6, 1, 'Steglitz-Zehlendorf', '06'),
    (7, 1, 'Tempelhof-Schöneberg', '07'),
    (8, 1, 'Neukölln', '08'),
    (9, 1, 'Treptow-Köpenick', '09'),
    (10, 1, 'Marzahn-Hellersdorf', '10'),
    (11, 1, 'Lichtenberg', '11'),
    (12, 1, 'Reinickendorf', '12');

-- Berliner Ortsteile und die alten Bezirksnamen Hohenschoenhausen und Treptow.
INSERT INTO bezirk_alias (bezirk_id, name) VALUES
    (1, 'Moabit'), (1, 'Hansaviertel'), (1, 'Tiergarten'), (1, 'Wedding'), (1, 'Gesundbrunnen'),
    (2, 'Friedrichshain'), (2, 'Kreuzberg'),
    (3, 'Prenzlauer Berg'), (3, 'Weißensee'), (3, 'Blankenburg'), (3, 'Heinersdorf'), (3, 'Karow'),
    (3, 'Stadtrandsiedlung Malchow'), (3, 'Blankenfelde'), (3, 'Buch'), (3, 'Französisch Buchholz'),
    (3, 'Niederschönhausen'), (3, 'Rosenthal'), (3, 'Wilhelmsruh'),
    (4, 'Charlottenburg'), (4, 'Wilmersdorf'), (4, 'Schmargendorf'), (4, 'Grunewald'),
    (4, 'Westend'), (4, 'Charlottenburg-Nord'), (4, 'Halensee'),
    (5, 'Haselhorst'), (5, 'Siemensstadt'), (5, 'Staaken'), (5, 'Gatow'), (5, 'Kladow'),
    (5, 'Hakenfelde'), (5, 'Falkenhagener Feld'), (5, 'Wilhelmstadt'),
    (6, 'Steglitz'), (6, 'Lichterfelde'), (6, 'Lankwitz'), (6, 'Zehlendorf'), (6, 'Dahlem'),
    (6, 'Nikolassee'), (6, 'Wannsee'),
    (7, 'Schöneberg'), (7, 'Friedenau'), (7, 'Tempelhof'), (7, 'Mariendorf'), (7, 'Marienfelde'),
    (7, 'Lichtenrade'),
    (8, 'Britz'), (8, 'Buckow'), (8, 'Rudow'), (8, 'Gropiusstadt'),
    (9, 'Treptow'), (9, 'Alt-Treptow'), (9, 'Plänterwald'), (9, 'Baumschulenweg'), (9, 'Johannisthal'),
    (9, 'Niederschöneweide'), (9, 'Altglienicke'), (9, 'Adlershof'), (9, 'Bohnsdorf'),
    (9, 'Oberschöneweide'), (9, 'Köpenick'), (9, 'Friedrichshagen'), (9, 'Rahnsdorf'),
    (9, 'Grünau'), (9, 'Müggelheim'), (9, 'Schmöckwitz'),
    (10, 'Marzahn'), (10, 'Biesdorf'), (10, 'Kaulsdorf'), (10, 'Mahlsdorf'), (10, 'Hellersdorf'),
    (11, 'Hohenschönhausen'), (11, 'Friedrichsfelde'), (11, 'Karlshorst'), (11, 'Falkenberg'),
    (11, 'Malchow'), (11, 'Wartenberg'), (11, 'Neu-Hohenschönhausen'), (11, 'Alt-Hohenschönhausen'),
    (11, 'Fennpfuhl'), (11, 'Rummelsburg'),
    (12, 'Tegel'), (12, 'Konradshöhe'), (12, 'Heiligensee'), (12, 'Frohnau'), (12, 'Hermsdorf'),
    (12, 'Waidmannslust'), (12, 'Lübars'), (12, 'Wittenau'), (12, 'Märkisches Viertel'),
    (12, 'Borsigwalde');

-- Alle Schreibweisen, unter denen ein Bezirk gefunden wird, auch mit Ort davor oder dahinter ('Berlin-Mitte').
CREATE OR REPLACE VIEW bezirk_suchbegriff AS
WITH begriff AS (
    SELECT b.id AS bezirk_id, b.ort_id, b.suchname FROM bezirk b
    UNION ALL
    SELECT a.bezirk_id, b.ort_id, a.suchname
    FROM bezirk_alias a JOIN bezirk b ON b.id = a.bezirk_id
), ortsname AS (
    SELECT id AS ort_id, fn_text_normalisieren(name) AS suchname FROM ort WHERE aktiv = 1
)
SELECT g.bezirk_id, g.ort_id, g.suchname AS suchbegriff
FROM begriff g JOIN ortsname o ON o.ort_id = g.ort_id
UNION
SELECT g.bezirk_id, g.ort_id, CONCAT(o.suchname, g.suchname)
FROM begriff g JOIN ortsname o ON o.ort_id = g.ort_id
UNION
SELECT g.bezirk_id, g.ort_id, CONCAT(g.suchname, o.suchname)
FROM begriff g JOIN ortsname o ON o.ort_id = g.ort_id;

-- Fuer das Dropdown in einer Oberflaeche. Zeigt nur Orte, die freigeschaltet sind.
CREATE OR REPLACE VIEW bezirk_auswahl AS
SELECT b.id AS bezirk_id, b.name AS bezirk, b.schluessel, o.id AS ort_id, o.name AS ort,
       bl.name AS bundesland
FROM bezirk b
JOIN ort o ON o.id = b.ort_id
JOIN bundesland bl ON bl.id = o.bundesland_id
WHERE o.aktiv = 1;

DELIMITER $$

-- Sucht zu einer frei eingetippten Ortsangabe den passenden Bezirk.
-- Erst wird exakt gesucht, dann mit Tippfehlern (1 Fehler bei 4-5 Buchstaben, sonst 2). Unklar = NULL.
CREATE FUNCTION fn_bezirk_id (p_text VARCHAR(200), p_ort_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_text VARCHAR(200);
    DECLARE v_anzahl INT DEFAULT 0;
    DECLARE v_treffer INT DEFAULT NULL;
    DECLARE v_abstand INT DEFAULT NULL;
    DECLARE v_grenze INT;

    SET v_text = fn_text_normalisieren(p_text);
    IF v_text IS NULL THEN
        RETURN NULL;
    END IF;
    SET v_text = REGEXP_REPLACE(v_text, '^(stadtbezirk|bezirk|ortsteil)', '');
    IF v_text = '' THEN
        RETURN NULL;
    END IF;

    SELECT COUNT(DISTINCT bezirk_id), MIN(bezirk_id) INTO v_anzahl, v_treffer
    FROM bezirk_suchbegriff
    WHERE suchbegriff = v_text AND (p_ort_id IS NULL OR ort_id = p_ort_id);

    IF v_anzahl > 0 THEN
        RETURN IF(v_anzahl = 1, v_treffer, NULL);
    END IF;

    SET v_grenze = CASE WHEN CHAR_LENGTH(v_text) <= 3 THEN 0
                        WHEN CHAR_LENGTH(v_text) <= 5 THEN 1
                        ELSE 2 END;
    IF v_grenze = 0 THEN
        RETURN NULL;
    END IF;

    WITH abstand AS (
        SELECT bezirk_id, MIN(fn_levenshtein(v_text, suchbegriff)) AS distanz
        FROM bezirk_suchbegriff
        WHERE (p_ort_id IS NULL OR ort_id = p_ort_id)
          AND ABS(CHAR_LENGTH(suchbegriff) - CHAR_LENGTH(v_text)) <= v_grenze
        GROUP BY bezirk_id
    )
    SELECT bezirk_id, distanz, COUNT(*) OVER (PARTITION BY distanz)
    INTO v_treffer, v_abstand, v_anzahl
    FROM abstand
    ORDER BY distanz, bezirk_id
    LIMIT 1;

    IF v_abstand IS NULL OR v_abstand > v_grenze OR v_anzahl <> 1 THEN
        RETURN NULL;
    END IF;
    RETURN v_treffer;
END$$

-- Fuer Importe: wie fn_bezirk_id, gibt aber einen Fehler aus statt NULL.
CREATE FUNCTION fn_bezirk_id_pflicht (p_text VARCHAR(200))
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_id INT DEFAULT fn_bezirk_id(p_text, NULL);
    DECLARE v_meldung VARCHAR(128);

    IF v_id IS NULL THEN
        SET v_meldung = LEFT(CONCAT('Bezirk nicht erkannt oder mehrdeutig: ', COALESCE(p_text, 'NULL')), 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_meldung;
    END IF;
    RETURN v_id;
END$$

DELIMITER ;
