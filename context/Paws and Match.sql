-- Paws & Match - Installation in einem eigenen Schema
CREATE DATABASE IF NOT EXISTS paws_match
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE paws_match;
CREATE TABLE tierheim (
 id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(120) NOT NULL, email VARCHAR(150) NOT NULL UNIQUE
) ENGINE=InnoDB;
CREATE TABLE standort (
 id INT PRIMARY KEY AUTO_INCREMENT, tierheim_id INT NOT NULL, name VARCHAR(120) NOT NULL,
 bezirk VARCHAR(60) NOT NULL, ort VARCHAR(50) NOT NULL DEFAULT 'Berlin', kapazitaet INT NOT NULL,
 FOREIGN KEY(tierheim_id) REFERENCES tierheim(id), CHECK(kapazitaet>0), CHECK(ort='Berlin')
) ENGINE=InnoDB;
CREATE TABLE mitarbeiter (
 id INT PRIMARY KEY AUTO_INCREMENT, standort_id INT NOT NULL, name VARCHAR(100) NOT NULL,
 email VARCHAR(150) NOT NULL UNIQUE, FOREIGN KEY(standort_id) REFERENCES standort(id)
) ENGINE=InnoDB;
CREATE TABLE tierart (id INT PRIMARY KEY, name VARCHAR(50) NOT NULL UNIQUE) ENGINE=InnoDB;
CREATE TABLE interessent (
 id INT PRIMARY KEY AUTO_INCREMENT, pseudonym VARCHAR(80) NOT NULL, email VARCHAR(150) NOT NULL UNIQUE,
 bezirk VARCHAR(60) NOT NULL, aktiv BOOLEAN NOT NULL DEFAULT TRUE,
 wohnflaeche DECIMAL(6,2), garten BOOLEAN, etage INT, aufzug BOOLEAN,
 kinder BOOLEAN, hund_vorhanden BOOLEAN, katze_vorhanden BOOLEAN,
 zeit_stunden DECIMAL(4,1), allein_stunden DECIMAL(4,1), erfahrung INT,
 budget DECIMAL(8,2), medizin_bereit BOOLEAN, aktivitaet INT,
 CHECK(wohnflaeche>=0), CHECK(etage>=0), CHECK(zeit_stunden BETWEEN 0 AND 24),
 CHECK(allein_stunden BETWEEN 0 AND 24), CHECK(erfahrung BETWEEN 0 AND 5),
 CHECK(budget>=0), CHECK(aktivitaet BETWEEN 1 AND 5)
) ENGINE=InnoDB;
CREATE TABLE tier (
 id INT PRIMARY KEY AUTO_INCREMENT, standort_id INT NOT NULL, tierart_id INT NOT NULL,
 name VARCHAR(80) NOT NULL, geburtsdatum DATE, geburt_geschaetzt BOOLEAN NOT NULL DEFAULT FALSE,
 geschlecht ENUM('weiblich','maennlich','unbekannt') NOT NULL DEFAULT 'unbekannt',
 gewicht_kg DECIMAL(6,2), beschreibung TEXT,
 status ENUM('verfuegbar','reserviert','vermittelt','nicht_vermittelbar') NOT NULL DEFAULT 'verfuegbar',
 aktivitaet INT, min_wohnflaeche DECIMAL(6,2), garten_noetig BOOLEAN,
 treppen_vermeiden BOOLEAN, kinder_ok BOOLEAN, hund_ok BOOLEAN, katze_ok BOOLEAN,
 min_zeit DECIMAL(4,1), max_allein DECIMAL(4,1), min_erfahrung INT,
 monatskosten DECIMAL(8,2), medizin_noetig BOOLEAN,
 FOREIGN KEY(standort_id) REFERENCES standort(id), FOREIGN KEY(tierart_id) REFERENCES tierart(id),
 CHECK(gewicht_kg>0), CHECK(aktivitaet BETWEEN 1 AND 5), CHECK(min_wohnflaeche>=0),
 CHECK(min_zeit BETWEEN 0 AND 24), CHECK(max_allein BETWEEN 0 AND 24),
 CHECK(min_erfahrung BETWEEN 0 AND 5), CHECK(monatskosten>=0),
 INDEX idx_tier_status_art(status,tierart_id,standort_id)
) ENGINE=InnoDB;
CREATE TABLE charakter (
 id INT PRIMARY KEY, name VARCHAR(60) NOT NULL UNIQUE
) ENGINE=InnoDB;
CREATE TABLE tier_charakter (
 tier_id INT NOT NULL, charakter_id INT NOT NULL, PRIMARY KEY(tier_id,charakter_id),
 FOREIGN KEY(tier_id) REFERENCES tier(id), FOREIGN KEY(charakter_id) REFERENCES charakter(id)
) ENGINE=InnoDB;
CREATE TABLE interessent_charakter (
 interessent_id INT NOT NULL, charakter_id INT NOT NULL, PRIMARY KEY(interessent_id,charakter_id),
 FOREIGN KEY(interessent_id) REFERENCES interessent(id), FOREIGN KEY(charakter_id) REFERENCES charakter(id)
) ENGINE=InnoDB;
CREATE TABLE interessent_tierart (
 interessent_id INT NOT NULL, tierart_id INT NOT NULL, PRIMARY KEY(interessent_id,tierart_id),
 FOREIGN KEY(interessent_id) REFERENCES interessent(id), FOREIGN KEY(tierart_id) REFERENCES tierart(id)
) ENGINE=InnoDB;
CREATE TABLE beduerfnis (
 id INT PRIMARY KEY, name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;
CREATE TABLE tier_beduerfnis (
 tier_id INT NOT NULL, beduerfnis_id INT NOT NULL, hinweis VARCHAR(250),
 PRIMARY KEY(tier_id,beduerfnis_id), FOREIGN KEY(tier_id) REFERENCES tier(id),
 FOREIGN KEY(beduerfnis_id) REFERENCES beduerfnis(id)
) ENGINE=InnoDB;
CREATE TABLE interessent_beduerfnis (
 interessent_id INT NOT NULL, beduerfnis_id INT NOT NULL,
 bestaetigt BOOLEAN NOT NULL, PRIMARY KEY(interessent_id,beduerfnis_id),
 FOREIGN KEY(interessent_id) REFERENCES interessent(id), FOREIGN KEY(beduerfnis_id) REFERENCES beduerfnis(id)
) ENGINE=InnoDB;
CREATE TABLE merkliste (
 interessent_id INT NOT NULL, tier_id INT NOT NULL, erstellt_am TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(interessent_id,tier_id), FOREIGN KEY(interessent_id) REFERENCES interessent(id),
 FOREIGN KEY(tier_id) REFERENCES tier(id)
) ENGINE=InnoDB;
CREATE TABLE bewerbung (
 id INT PRIMARY KEY AUTO_INCREMENT, interessent_id INT NOT NULL, tier_id INT NOT NULL,
 status ENUM('offen','in_pruefung','abgelehnt','zurueckgezogen','angenommen') NOT NULL DEFAULT 'offen',
 erstellt_am TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, notiz TEXT,
 UNIQUE(interessent_id,tier_id), FOREIGN KEY(interessent_id) REFERENCES interessent(id),
 FOREIGN KEY(tier_id) REFERENCES tier(id)
) ENGINE=InnoDB;
CREATE TABLE termin (
 id INT PRIMARY KEY AUTO_INCREMENT, bewerbung_id INT NOT NULL, mitarbeiter_id INT NOT NULL,
 zeitpunkt DATETIME NOT NULL, art ENUM('gespraech','kennenlernen','nachkontrolle') NOT NULL,
 FOREIGN KEY(bewerbung_id) REFERENCES bewerbung(id), FOREIGN KEY(mitarbeiter_id) REFERENCES mitarbeiter(id)
) ENGINE=InnoDB;
CREATE TABLE vermittlung (
 id INT PRIMARY KEY AUTO_INCREMENT, bewerbung_id INT NOT NULL UNIQUE, tier_id INT NOT NULL,
 mitarbeiter_id INT NOT NULL, vermittelt_am DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 beendet_am DATETIME NULL, notiz TEXT,
 aktives_tier INT GENERATED ALWAYS AS (CASE WHEN beendet_am IS NULL THEN tier_id ELSE NULL END) STORED,
 UNIQUE(aktives_tier), FOREIGN KEY(bewerbung_id) REFERENCES bewerbung(id),
 FOREIGN KEY(tier_id) REFERENCES tier(id), FOREIGN KEY(mitarbeiter_id) REFERENCES mitarbeiter(id),
 CHECK(beendet_am IS NULL OR beendet_am>=vermittelt_am)
) ENGINE=InnoDB;
CREATE TABLE matching_gewicht (
 kriterium VARCHAR(30) PRIMARY KEY, gewicht DECIMAL(6,2) NOT NULL, CHECK(gewicht>0)
) ENGINE=InnoDB;
INSERT INTO matching_gewicht VALUES ('aktivitaet',50),('charakter',40),('bezirk',10);
-- Ausschliesslich fiktive Demonstrationsdaten, keine realen Einrichtungen oder Personen.
INSERT INTO tierart VALUES (1,'Hund'),(2,'Katze'),(3,'Kaninchen'),(4,'Meerschweinchen'),(5,'Vogel');
INSERT INTO charakter VALUES (1,'ruhig'),(2,'verspielt'),(3,'schuechtern'),(4,'kontaktfreudig'),(5,'eigenstaendig');
INSERT INTO beduerfnis VALUES (1,'taegliche Medikamentengabe'),(2,'gesicherter Balkon'),(3,'Vergesellschaftung erforderlich'),(4,'Training erforderlich'),(5,'Spezialfutter');
INSERT INTO tierheim VALUES (1,'Demo-Tierschutz 1','heim1@example.org');
INSERT INTO standort VALUES (1,1,'Demo-Standort Mitte','Mitte','Berlin',30);
INSERT INTO mitarbeiter VALUES (1,1,'Demo-Team 1','team1@example.org');
INSERT INTO tierheim VALUES (2,'Demo-Tierschutz 2','heim2@example.org');
INSERT INTO standort VALUES (2,2,'Demo-Standort Pankow','Pankow','Berlin',30);
INSERT INTO mitarbeiter VALUES (2,2,'Demo-Team 2','team2@example.org');
INSERT INTO tierheim VALUES (3,'Demo-Tierschutz 3','heim3@example.org');
INSERT INTO standort VALUES (3,3,'Demo-Standort Spandau','Spandau','Berlin',30);
INSERT INTO mitarbeiter VALUES (3,3,'Demo-Team 3','team3@example.org');
INSERT INTO tierheim VALUES (4,'Demo-Tierschutz 4','heim4@example.org');
INSERT INTO standort VALUES (4,4,'Demo-Standort Neukoelln','Neukoelln','Berlin',30);
INSERT INTO mitarbeiter VALUES (4,4,'Demo-Team 4','team4@example.org');
INSERT INTO tierheim VALUES (5,'Demo-Tierschutz 5','heim5@example.org');
INSERT INTO standort VALUES (5,5,'Demo-Standort Lichtenberg','Lichtenberg','Berlin',30);
INSERT INTO mitarbeiter VALUES (5,5,'Demo-Team 5','team5@example.org');
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (1,'Profil 1','profil1@example.org','Mitte',80,1,0,0,0,0,0,6,2,4,400,1,1);
INSERT INTO interessent_tierart VALUES (1,1);
INSERT INTO interessent_charakter VALUES (1,1);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (2,'Profil 2','profil2@example.org','Pankow',80,1,0,0,0,0,0,6,2,4,400,1,2);
INSERT INTO interessent_tierart VALUES (2,2);
INSERT INTO interessent_charakter VALUES (2,2);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (3,'Profil 3','profil3@example.org','Spandau',80,1,0,0,0,0,0,6,2,4,400,1,3);
INSERT INTO interessent_tierart VALUES (3,3);
INSERT INTO interessent_charakter VALUES (3,3);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (4,'Profil 4','profil4@example.org','Neukoelln',80,1,0,0,0,0,0,6,2,4,400,1,4);
INSERT INTO interessent_tierart VALUES (4,4);
INSERT INTO interessent_charakter VALUES (4,4);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (5,'Profil 5','profil5@example.org','Lichtenberg',80,1,0,0,0,0,0,6,2,4,400,1,5);
INSERT INTO interessent_tierart VALUES (5,5);
INSERT INTO interessent_charakter VALUES (5,5);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (6,'Profil 6','profil6@example.org','Mitte',80,1,0,0,0,0,0,6,2,4,400,1,1);
INSERT INTO interessent_tierart VALUES (6,1);
INSERT INTO interessent_charakter VALUES (6,1);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (7,'Profil 7','profil7@example.org','Pankow',80,1,0,0,0,0,0,6,2,4,400,1,2);
INSERT INTO interessent_tierart VALUES (7,2);
INSERT INTO interessent_charakter VALUES (7,2);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (8,'Profil 8','profil8@example.org','Spandau',80,1,0,0,0,0,0,6,2,4,400,1,3);
INSERT INTO interessent_tierart VALUES (8,3);
INSERT INTO interessent_charakter VALUES (8,3);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (9,'Profil 9','profil9@example.org','Neukoelln',80,1,0,0,0,0,0,6,2,4,400,1,4);
INSERT INTO interessent_tierart VALUES (9,4);
INSERT INTO interessent_charakter VALUES (9,4);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (10,'Profil 10','profil10@example.org','Lichtenberg',80,1,0,0,0,0,0,6,2,4,400,1,5);
INSERT INTO interessent_tierart VALUES (10,5);
INSERT INTO interessent_charakter VALUES (10,5);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (11,'Profil 11','profil11@example.org','Mitte',80,1,0,0,0,0,0,6,2,4,400,1,1);
INSERT INTO interessent_tierart VALUES (11,1);
INSERT INTO interessent_charakter VALUES (11,1);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (12,'Profil 12','profil12@example.org','Pankow',80,1,0,0,0,0,0,6,2,4,400,1,2);
INSERT INTO interessent_tierart VALUES (12,2);
INSERT INTO interessent_charakter VALUES (12,2);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (13,'Profil 13','profil13@example.org','Spandau',80,1,0,0,0,0,0,6,2,4,400,1,3);
INSERT INTO interessent_tierart VALUES (13,3);
INSERT INTO interessent_charakter VALUES (13,3);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (14,'Profil 14','profil14@example.org','Neukoelln',80,1,0,0,0,0,0,6,2,4,400,1,4);
INSERT INTO interessent_tierart VALUES (14,4);
INSERT INTO interessent_charakter VALUES (14,4);
INSERT INTO interessent (id,pseudonym,email,bezirk,wohnflaeche,garten,etage,aufzug,kinder,hund_vorhanden,katze_vorhanden,zeit_stunden,allein_stunden,erfahrung,budget,medizin_bereit,aktivitaet) VALUES (15,'Profil 15','profil15@example.org','Lichtenberg',80,1,0,0,0,0,0,6,2,4,400,1,5);
INSERT INTO interessent_tierart VALUES (15,5);
INSERT INTO interessent_charakter VALUES (15,5);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (1,1,1,'Bruno','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',1,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (1,1);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (2,2,2,'Mila','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',2,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (2,2);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (3,3,3,'Flocke','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',3,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (3,3);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (4,4,4,'Pino','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',4,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (4,4);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (5,5,5,'Pia','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',5,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (5,5);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (6,1,1,'Balu','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',1,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (6,1);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (7,2,2,'Luna','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',2,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (7,2);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (8,3,3,'Momo','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',3,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (8,3);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (9,4,4,'Fips','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',4,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (9,4);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (10,5,5,'Kiki','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',5,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (10,5);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (11,1,1,'Oskar','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',1,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (11,1);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (12,2,2,'Nala','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',2,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (12,2);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (13,3,3,'Wolke','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',3,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (13,3);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (14,4,4,'Pepe','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',4,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (14,4);
INSERT INTO tier (id,standort_id,tierart_id,name,geburtsdatum,geburt_geschaetzt,geschlecht,gewicht_kg,beschreibung,aktivitaet,min_wohnflaeche,garten_noetig,treppen_vermeiden,kinder_ok,hund_ok,katze_ok,min_zeit,max_allein,min_erfahrung,monatskosten,medizin_noetig) VALUES (15,5,5,'Coco','2021-05-01',1,'unbekannt',5,'Fiktives Tierprofil fuer die Projektpraesentation.',5,30,0,0,1,1,1,2,5,1,100,0);
INSERT INTO tier_charakter VALUES (15,5);
INSERT INTO tier_beduerfnis VALUES (1,1,'Individuelle Bedingung vor Vermittlung pruefen.');
INSERT INTO interessent_beduerfnis VALUES (1,1,1);
INSERT INTO merkliste(interessent_id,tier_id) VALUES (1,1);
INSERT INTO bewerbung(id,interessent_id,tier_id) VALUES (1,1,1);
INSERT INTO termin VALUES (1,1,1,'2026-12-01 14:00:00','kennenlernen');
INSERT INTO tier_beduerfnis VALUES (2,2,'Individuelle Bedingung vor Vermittlung pruefen.');
INSERT INTO interessent_beduerfnis VALUES (2,2,1);
INSERT INTO merkliste(interessent_id,tier_id) VALUES (2,2);
INSERT INTO bewerbung(id,interessent_id,tier_id) VALUES (2,2,2);
INSERT INTO termin VALUES (2,2,2,'2026-12-01 14:00:00','kennenlernen');
INSERT INTO tier_beduerfnis VALUES (3,3,'Individuelle Bedingung vor Vermittlung pruefen.');
INSERT INTO interessent_beduerfnis VALUES (3,3,1);
INSERT INTO merkliste(interessent_id,tier_id) VALUES (3,3);
INSERT INTO bewerbung(id,interessent_id,tier_id) VALUES (3,3,3);
INSERT INTO termin VALUES (3,3,3,'2026-12-01 14:00:00','kennenlernen');
INSERT INTO tier_beduerfnis VALUES (4,4,'Individuelle Bedingung vor Vermittlung pruefen.');
INSERT INTO interessent_beduerfnis VALUES (4,4,1);
INSERT INTO merkliste(interessent_id,tier_id) VALUES (4,4);
INSERT INTO bewerbung(id,interessent_id,tier_id) VALUES (4,4,4);
INSERT INTO termin VALUES (4,4,4,'2026-12-01 14:00:00','kennenlernen');
INSERT INTO tier_beduerfnis VALUES (5,5,'Individuelle Bedingung vor Vermittlung pruefen.');
INSERT INTO interessent_beduerfnis VALUES (5,5,1);
INSERT INTO merkliste(interessent_id,tier_id) VALUES (5,5);
INSERT INTO bewerbung(id,interessent_id,tier_id) VALUES (5,5,5);
INSERT INTO termin VALUES (5,5,5,'2026-12-01 14:00:00','kennenlernen');

-- Fehlende kritische Angaben fuehren zu 'pruefung_offen', nicht zu einer Freigabe.
CREATE VIEW v_match_basis AS
SELECT t.id AS tier_id, i.id AS interessent_id, t.name AS tiername,
 i.pseudonym, t.standort_id, t.status AS tierstatus,
 CASE WHEN NOT EXISTS(SELECT 1 FROM interessent_tierart p WHERE p.interessent_id=i.id AND p.tierart_id=t.tierart_id)
 OR (t.garten_noetig=1 AND i.garten=0)
 OR (t.treppen_vermeiden=1 AND i.etage>0 AND i.aufzug=0)
 OR (t.kinder_ok=0 AND i.kinder=1) OR (t.hund_ok=0 AND i.hund_vorhanden=1)
 OR (t.katze_ok=0 AND i.katze_vorhanden=1)
 OR i.wohnflaeche<t.min_wohnflaeche OR i.zeit_stunden<t.min_zeit
 OR i.allein_stunden>t.max_allein OR i.erfahrung<t.min_erfahrung
 OR i.budget<t.monatskosten OR (t.medizin_noetig=1 AND i.medizin_bereit=0)
 OR EXISTS(SELECT 1 FROM tier_beduerfnis tb JOIN interessent_beduerfnis ib
 ON ib.beduerfnis_id=tb.beduerfnis_id AND ib.interessent_id=i.id
 WHERE tb.tier_id=t.id AND ib.bestaetigt=0)
 THEN 'ausgeschlossen'
 WHEN i.wohnflaeche IS NULL OR i.garten IS NULL OR i.etage IS NULL OR i.aufzug IS NULL
 OR i.kinder IS NULL OR i.hund_vorhanden IS NULL OR i.katze_vorhanden IS NULL
 OR i.zeit_stunden IS NULL OR i.allein_stunden IS NULL OR i.erfahrung IS NULL
 OR i.budget IS NULL OR i.medizin_bereit IS NULL
 OR t.min_wohnflaeche IS NULL OR t.garten_noetig IS NULL OR t.treppen_vermeiden IS NULL
 OR t.kinder_ok IS NULL OR t.hund_ok IS NULL OR t.katze_ok IS NULL
 OR t.min_zeit IS NULL OR t.max_allein IS NULL OR t.min_erfahrung IS NULL
 OR t.monatskosten IS NULL OR t.medizin_noetig IS NULL
 OR EXISTS(SELECT 1 FROM tier_beduerfnis tb WHERE tb.tier_id=t.id AND NOT EXISTS(
 SELECT 1 FROM interessent_beduerfnis ib WHERE ib.interessent_id=i.id AND ib.beduerfnis_id=tb.beduerfnis_id))
 THEN 'pruefung_offen' ELSE 'geeignet' END AS eignung,
 CASE WHEN t.aktivitaet IS NOT NULL AND i.aktivitaet IS NOT NULL
 THEN 1.0-ABS(t.aktivitaet-i.aktivitaet)/4.0 END AS aktivitaet_passung,
 CASE WHEN EXISTS(SELECT 1 FROM interessent_charakter ic WHERE ic.interessent_id=i.id)
 THEN (SELECT COUNT(*) FROM interessent_charakter ic JOIN tier_charakter tc ON tc.charakter_id=ic.charakter_id
 WHERE ic.interessent_id=i.id AND tc.tier_id=t.id)*1.0 /
 (SELECT COUNT(*) FROM interessent_charakter ic WHERE ic.interessent_id=i.id) END AS charakter_passung,
 CASE WHEN s.bezirk=i.bezirk THEN 1.0 ELSE 0.0 END AS bezirk_passung
FROM tier t JOIN standort s ON s.id=t.standort_id CROSS JOIN interessent i
WHERE i.aktiv=1;
CREATE VIEW v_match_kriterien AS
SELECT tier_id,interessent_id,'aktivitaet' AS kriterium,aktivitaet_passung AS passung FROM v_match_basis
UNION ALL SELECT tier_id,interessent_id,'charakter',charakter_passung FROM v_match_basis
UNION ALL SELECT tier_id,interessent_id,'bezirk',bezirk_passung FROM v_match_basis;
CREATE VIEW v_match_score AS
SELECT b.tier_id,b.interessent_id,b.tiername,b.pseudonym,b.standort_id,b.eignung,b.tierstatus,
 CASE WHEN b.eignung='geeignet' THEN ROUND(100*SUM(CASE WHEN k.passung IS NOT NULL THEN k.passung*g.gewicht ELSE 0 END)/
 NULLIF(SUM(CASE WHEN k.passung IS NOT NULL THEN g.gewicht ELSE 0 END),0),1) END AS match_prozent,
 ROUND(100*SUM(CASE WHEN k.passung IS NOT NULL THEN g.gewicht ELSE 0 END)/NULLIF(SUM(g.gewicht),0),1) AS datenabdeckung_prozent
FROM v_match_basis b JOIN v_match_kriterien k ON k.tier_id=b.tier_id AND k.interessent_id=b.interessent_id
JOIN matching_gewicht g ON g.kriterium=k.kriterium
GROUP BY b.tier_id,b.interessent_id,b.tiername,b.pseudonym,b.standort_id,b.eignung,b.tierstatus;
CREATE VIEW v_vorschlaege AS SELECT * FROM v_match_score WHERE eignung='geeignet' AND tierstatus='verfuegbar';
CREATE VIEW v_match_details AS
SELECT k.*,g.gewicht, ROUND(k.passung*100,1) AS passung_prozent
FROM v_match_kriterien k JOIN matching_gewicht g ON g.kriterium=k.kriterium;
CREATE VIEW v_auslastung AS
SELECT s.id,s.name,s.kapazitaet,COUNT(t.id) AS aktuelle_tiere,
 ROUND(100.0*COUNT(t.id)/s.kapazitaet,1) AS auslastung_prozent
FROM standort s LEFT JOIN tier t ON t.standort_id=s.id AND t.status<>'vermittelt'
GROUP BY s.id,s.name,s.kapazitaet;
CREATE VIEW v_offene_bewerbungen AS
SELECT b.id,b.status,b.erstellt_am,t.name AS tier,i.pseudonym,t.standort_id
FROM bewerbung b JOIN tier t ON t.id=b.tier_id JOIN interessent i ON i.id=b.interessent_id
WHERE b.status IN ('offen','in_pruefung');
DELIMITER $$
CREATE TRIGGER trg_bewerbung_pruefen BEFORE INSERT ON bewerbung FOR EACH ROW
BEGIN
 DECLARE v_status VARCHAR(30);
 SELECT status INTO v_status FROM tier WHERE id=NEW.tier_id FOR UPDATE;
 IF v_status<>'verfuegbar' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Tier ist nicht verfuegbar.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM interessent WHERE id=NEW.interessent_id AND aktiv=1) THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Interessentenprofil ist nicht aktiv.'; END IF;
END$$
CREATE TRIGGER trg_vermittlung_pruefen BEFORE INSERT ON vermittlung FOR EACH ROW
BEGIN
 IF NOT EXISTS(SELECT 1 FROM bewerbung b JOIN tier t ON t.id=b.tier_id
 JOIN mitarbeiter m ON m.standort_id=t.standort_id
 WHERE b.id=NEW.bewerbung_id AND b.tier_id=NEW.tier_id AND b.status='angenommen'
 AND m.id=NEW.mitarbeiter_id AND t.status='vermittelt') THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Vermittlung nur ueber sp_vermitteln abschliessen.'; END IF;
END$$
CREATE PROCEDURE sp_vorschlaege_fuer_interessent(IN p_id INT)
BEGIN
 SELECT * FROM v_vorschlaege WHERE interessent_id=p_id ORDER BY match_prozent DESC,tier_id;
END$$
CREATE PROCEDURE sp_vorschlaege_fuer_tier(IN p_id INT)
BEGIN
 SELECT * FROM v_vorschlaege WHERE tier_id=p_id ORDER BY match_prozent DESC,interessent_id;
END$$
CREATE PROCEDURE sp_vermitteln(IN p_bewerbung INT,IN p_mitarbeiter INT)
BEGIN
 DECLARE v_tier INT;
 DECLARE v_interessent INT;
 DECLARE v_status VARCHAR(30);
 DECLARE v_bewerbung VARCHAR(30);
 DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
 START TRANSACTION;
 SELECT tier_id,interessent_id INTO v_tier,v_interessent FROM bewerbung WHERE id=p_bewerbung;
 IF v_tier IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Bewerbung nicht gefunden.'; END IF;
 SELECT status INTO v_status FROM tier WHERE id=v_tier FOR UPDATE;
 SELECT status INTO v_bewerbung FROM bewerbung WHERE id=p_bewerbung FOR UPDATE;
 IF v_status NOT IN ('verfuegbar','reserviert') OR v_bewerbung NOT IN ('offen','in_pruefung') THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Status erlaubt keine Vermittlung.'; END IF;
 IF NOT EXISTS(SELECT 1 FROM v_match_basis WHERE tier_id=v_tier AND interessent_id=v_interessent AND eignung='geeignet') THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Eignung fehlt oder muss noch geprueft werden.'; END IF;
 UPDATE tier SET status='vermittelt' WHERE id=v_tier;
 UPDATE bewerbung SET status='angenommen' WHERE id=p_bewerbung;
 INSERT INTO vermittlung(bewerbung_id,tier_id,mitarbeiter_id) VALUES(p_bewerbung,v_tier,p_mitarbeiter);
 UPDATE bewerbung SET status='abgelehnt' WHERE tier_id=v_tier AND id<>p_bewerbung AND status IN ('offen','in_pruefung');
 COMMIT;
END$$
DELIMITER ;
-- Lesende Beispiele
SELECT * FROM v_auslastung;
CALL sp_vorschlaege_fuer_interessent(1);
CALL sp_vorschlaege_fuer_tier(1);
SELECT * FROM v_match_details WHERE tier_id=1 AND interessent_id=1;
SELECT * FROM v_match_score WHERE eignung<>'geeignet';
SELECT * FROM v_offene_bewerbungen;
-- Zustandsaenderung nur bei Bedarf manuell ausfuehren:
-- CALL sp_vermitteln(1,1);
