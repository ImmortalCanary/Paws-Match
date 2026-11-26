-- Stufe 3: Vorschlaege. Die Regeln dafuer stehen nur hier, Prozeduren und Ausgabe lesen aus dieser View.
USE paws_match;
SET NAMES utf8mb4;

-- Stellschrauben des Tierheims. Wie bei den Gewichten steht der Wert in der Datenbank, nicht im Code.
CREATE TABLE matching_einstellung (
    schluessel VARCHAR(40) PRIMARY KEY,
    wert DECIMAL(6,2) NOT NULL,
    beschreibung VARCHAR(200) NOT NULL,
    CONSTRAINT ck_matching_einstellung_wert CHECK (wert BETWEEN 0 AND 100)
) ENGINE = InnoDB;

INSERT INTO matching_einstellung (schluessel, wert, beschreibung) VALUES
    ('mindestscore', 50.00, 'Ab diesem Match-Prozent wird ein geeignetes Paar vorgeschlagen.');

-- Basis fuer Stufe 3: alle Paare, die strukturell fuer einen Vorschlag infrage kommen
-- (geeignet, Tier verfuegbar, Profil aktiv, Gewichtung vollstaendig) - unabhaengig vom
-- aktuell eingestellten Mindestscore. Einzige Quelle fuer jede Mindestscore-Filterung,
-- egal ob mit dem gespeicherten Wert (View `matching_vorschlaege` unten) oder mit einem
-- frei gewaehlten Vergleichswert (z. B. die "was-waere-wenn"-Vorschau beim Verschieben des
-- Reglers in admin_matching.py: SELECT ... FROM matching_vorschlaege_alle WHERE
-- match_prozent >= <eingegebener Wert>). Damit muss das Filterpraedikat selbst nirgendwo
-- sonst dupliziert werden.
CREATE OR REPLACE VIEW matching_vorschlaege_alle AS
SELECT
    s.tier_id,
    s.interessent_id,
    s.tiername,
    ta.name AS tierart,
    st.id AS standort_id,
    st.name AS standort,
    sb.name AS standort_bezirk,
    s.pseudonym,
    ib.name AS interessenten_bezirk,
    s.eignung,
    s.tierstatus,
    s.match_prozent,
    s.datenabdeckung_prozent,
    s.entfernung_km,
    'Alle harten Kriterien erfuellt; Score aus den gewichteten Teilpassungen.' AS begruendung
FROM matching_score s
JOIN tier t ON t.id = s.tier_id
JOIN tierart ta ON ta.id = t.tierart_id
JOIN standort st ON st.id = t.standort_id
LEFT JOIN bezirk sb ON sb.id = st.bezirk_id
JOIN interessent i ON i.id = s.interessent_id
LEFT JOIN bezirk ib ON ib.id = i.bezirk_id
WHERE s.eignung = 'geeignet'
  AND s.tierstatus = 'verfuegbar'
  AND s.interessent_aktiv = 1
  AND s.gewichtung_vollstaendig = 1;

-- Die eigentlichen Vorschlaege: dieselbe Basis, gefiltert auf den in der Datenbank
-- hinterlegten Mindestscore. Prozeduren und Ausgabe lesen weiterhin nur von hier.
CREATE OR REPLACE VIEW matching_vorschlaege AS
WITH einstellung AS (
    SELECT MAX(CASE WHEN schluessel = 'mindestscore' THEN wert END) AS mindestscore
    FROM matching_einstellung
)
SELECT v.*, e.mindestscore
FROM matching_vorschlaege_alle v
CROSS JOIN einstellung e
WHERE v.match_prozent >= e.mindestscore;