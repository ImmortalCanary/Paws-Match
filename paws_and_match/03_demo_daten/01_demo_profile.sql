-- Organisationsdaten sind recherchiert; Tiere, Interessenten und Mitarbeitende sind Demodaten.
USE paws_match;
SET NAMES utf8mb4;

-- Die Adress- und Organisationsdaten stammen aus den unten im README aufgefuehrten Verzeichnissen.
INSERT INTO tierheim (id, name, email, website) VALUES
    (1, 'Tierheim Berlin gGmbH', 'tierheim@tierschutz-berlin.de', 'https://tierschutz-berlin.de/'),
    (2, 'Tierschutzverein Tierheim Falkensee u.U. e.V.', 'info@tierheim-falkensee.de', 'https://www.tierheim-falkensee.de/'),
    (3, 'Tierheim Ladeburg', 'info@tierheim-ladeburg.de', 'https://www.tierheim-ladeburg.de/'),
    (4, 'Tierschutzverein Strausberg, Rüdersdorf u.U. e.V.', NULL, 'https://meintierschutzverein.de/'),
    (5, 'Tierheim Märkisch Buchholz des TSV Königs Wusterhausen e.V.', NULL, 'https://www.tierheim-kw.de/'),
    (6, 'Samtpfoten Neukölln e.V.', NULL, 'https://www.samtpfoten-neukoelln.com/'),
    (7, 'Ein Freund fürs Leben e.V.', 'info@ein-freund-fuers-leben.org', 'https://www.ein-freund-fuers-leben.org/'),
    (8, 'Katzenhilfe Berlin e.V.', 'katzenhilfeberlin@gmail.com', 'https://www.katzen-hilfe-berlin.de/'),
    (9, 'Auxilium Animalis e.V.', 'kontakt@auxilium-animalis.de', 'https://auxilium-animalis.de/'),
    (11, 'Tiere suchen Freunde e.V.', NULL, NULL),
    (12, 'Deutscher Katzenschutzbund gem. e.V.', NULL, NULL),
    (13, 'Aktion Tier – Menschen für Tiere e.V.', NULL, NULL),
    (14, 'Hundehoffnung Berlin e.V.', NULL, NULL),
    (15, 'Tierschutzverein-Phelan e.V.', NULL, NULL),
    (16, 'Notmeerschweinchen.de e.V.', NULL, NULL),
    (17, 'Aktionsgemeinschaft Tierhilfe e.V.', NULL, NULL),
    (18, 'Hund und Katzen Hilfe Spandau und Umgebung e.V.', NULL, NULL),
    (19, 'Katzen in Not Berlin e.V.', NULL, NULL),
    (20, 'SOS Hunde-Hilfe e.V.', NULL, NULL),
    (21, 'SOS-Strassentiere e.V.', NULL, NULL),
    (22, 'Tierfairliebt e.V.', NULL, NULL),
    (23, 'New Life 4 Spanish Animals e.V.', NULL, NULL),
    (24, 'Cats at Andros e.V.', NULL, NULL),
    (25, 'Hunderettung e.V.', NULL, NULL),
    (26, 'Fellchenhilfe', NULL, NULL),
    (27, 'Katzenhaus des TSV Frankfurt (Oder) e.V.', 'info@tierschutz-ff.de', 'http://www.tierschutz-ff.de/'),
    (31, 'Tierheim Am Bürgerhof Luckenwalde', NULL, 'https://www.tierheim-luckenwalde.de/'),
    (32, 'Tierheim Cottbus', 'info@tierheim-cottbus.de', 'https://www.tierheim-cottbus.de/'),
    (33, 'Tierheim Fürstenwalde', NULL, 'https://www.tsv-fuewa.de/'),
    (34, 'Tierheim Rathenow', NULL, 'https://www.tierheim-rathenow.jimdo.com/'),
    (35, 'Tierheim Tornow', NULL, 'https://www.tierschutzverein-ohv.de/'),
    (36, 'Tierschutzverein Bad Belzig u.U. e.V.', NULL, 'https://www.tierschutzverein-belzig.de/'),
    (39, 'Tierschutzverein Finsterwalde e.V.', NULL, 'https://www.tierschutzverein-finsterwalde.de/'),
    (41, 'Tierschutzverein Nordische in Not e.V.', NULL, 'https://www.nordische-in-not.de/'),
    (44, 'Tierschutzverein Potsdam u.U. e.V.', NULL, 'https://www.tierschutzverein-potsdam.de/'),
    (45, 'Tierschutzverein Prignitz e.V.', NULL, 'https://www.tierschutzverein-prignitz.de/'),
    (48, 'Tierschutzverein Seelow u.U. e.V.', NULL, 'https://tierschutzsee.hpage.com/'),
    (51, 'Tierschutzverein Wittstock u.U. e.V.', NULL, 'https://www.tierschutzverein-wittstock.de/');

UPDATE tierheim
SET quelle_url = CASE WHEN id = 1 THEN 'https://www.tierschutzbund.de/tierheime-deutschland/berlin/'
                      WHEN id BETWEEN 6 AND 26 THEN 'https://tierheimstern.de/tierheim/berlin/berlin'
                  WHEN id IN (27, 31, 32, 33, 34, 35, 36, 39, 41, 42, 44, 45, 48, 51)
                      THEN 'https://www.tierschutzbund.de/tierheime-deutschland/brandenburg/seite-2/'
                  ELSE 'https://www.tierschutzbund.de/tierheime-deutschland/brandenburg/' END,
    geprueft_am = '2026-11-25',
    datenstatus = 'zu_pruefen';

INSERT INTO standort (id, tierheim_id, name, art, ort_id, bezirk_id, strasse, plz,
                      breitengrad, laengengrad, kapazitaet) VALUES
    (1, 1, 'Tierheim Berlin', 'tierheim', 1, 11, 'Hausvaterweg 39', '13057', 52.575587, 13.545059, NULL),
    (2, 2, 'Tierheim Falkensee', 'tierheim', 2, 13, 'Dallgower Straße 104', '14624', NULL, NULL, NULL),
    (3, 3, 'Tierheim Ladeburg', 'tierheim', 3, 14, 'Biesenthaler Weg 23', '16321', 52.714756, 13.588590, NULL),
    (4, 4, 'Tierauffangstation Rüdersdorf', 'auffangstation', 5, 16, 'Woltersdorfer Straße 50', '15562', NULL, NULL, NULL),
    (5, 5, 'Tierheim Märkisch Buchholz', 'tierheim', 4, 15, 'Am Tierheim 1', '15757', NULL, NULL, NULL),
    (6, 6, 'Samtpfoten Neukölln', 'pflegestellen', 1, 8, NULL, NULL, NULL, NULL, NULL),
    (7, 7, 'Ein Freund fürs Leben', 'pflegestellen', 1, 6, NULL, NULL, NULL, NULL, NULL),
    (8, 8, 'Katzenhilfe Berlin', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (9, 9, 'Auxilium Animalis', 'pflegestellen', 1, 1, NULL, NULL, NULL, NULL, NULL),
    (11, 11, 'Tiere suchen Freunde', 'pflegestellen', 1, 3, NULL, NULL, NULL, NULL, NULL),
    (12, 12, 'Deutscher Katzenschutzbund', 'pflegestellen', 1, 2, NULL, NULL, NULL, NULL, NULL),
    (13, 13, 'Aktion Tier', 'pflegestellen', 1, 7, NULL, NULL, NULL, NULL, NULL),
    (14, 14, 'Hundehoffnung Berlin', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (15, 15, 'Tierschutzverein Phelan', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (16, 16, 'Notmeerschweinchen.de', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (17, 17, 'Aktionsgemeinschaft Tierhilfe', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (18, 18, 'Hund und Katzen Hilfe Spandau', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (19, 19, 'Katzen in Not Berlin', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (20, 20, 'SOS Hunde-Hilfe', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (21, 21, 'SOS-Strassentiere Köpenick', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (22, 22, 'Tierfairliebt', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (23, 23, 'New Life 4 Spanish Animals', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (24, 24, 'Cats at Andros', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (25, 25, 'Hunderettung', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (26, 26, 'Fellchenhilfe', 'pflegeverein', 1, NULL, NULL, NULL, NULL, NULL, NULL),
    (27, 27, 'Katzenhaus Frankfurt (Oder)', 'katzenhaus', 12, 23, 'Georg-Simon-Ohm-Straße 8a', '15236', NULL, NULL, NULL),
    (30, 32, 'Tierheim Cottbus', 'tierheim', 11, 22, 'Am Großen Spreewehr 1A', '03044', NULL, NULL, NULL),
    (31, 33, 'Tierheim Fürstenwalde', 'tierheim', 6, 17, 'Buchholzer Chaussee 1a', '15517', NULL, NULL, NULL),
    (32, 34, 'Tierheim Rathenow', 'tierheim', 10, 21, 'Bammer Landstraße 33c', '14712', NULL, NULL, NULL),
    (33, 35, 'Tierheim Tornow', 'tierheim', 8, 19, 'Blumenower Straße 3', '16798', NULL, NULL, NULL),
    (34, 36, 'Tierheim Verlorenwasser', 'auffangstation', 17, 28, 'Verlorenwasser 1', '14806', NULL, NULL, NULL),
    (35, 39, 'Tierheim Finsterwalde', 'auffangstation', 22, 33, 'Wahrenbrücker Straße 10', '03253', NULL, NULL, NULL);

UPDATE standort s
JOIN tierheim h ON h.id = s.tierheim_id
SET s.quelle_url = h.quelle_url, s.geprueft_am = '2026-11-25', s.datenstatus = 'zu_pruefen';

INSERT INTO tierheim (id, name, email, website, quelle_url, geprueft_am, datenstatus) VALUES
    (37, 'Tierheim Brandenburg an der Havel', NULL, 'https://www.tierheim-brandenburg.de/',
     'https://www.tierschutzbund.de/tierheime-deutschland/brandenburg/seite-2/', '2026-11-25', 'zu_pruefen');
INSERT INTO standort (id, tierheim_id, name, art, ort_id, bezirk_id, strasse, plz, kapazitaet)
VALUES (37, 37, 'Tierheim Brandenburg', 'tierheim', 9, 20, 'Caasmannstraße 16', '14770', NULL);
UPDATE standort SET quelle_url = 'https://www.tierschutzbund.de/tierheime-deutschland/brandenburg/seite-2/',
    geprueft_am = '2026-11-25', datenstatus = 'zu_pruefen' WHERE id = 37;

INSERT INTO mitarbeiter (id, standort_id, name, email) VALUES
    (1, 1, 'Demo-Team 1', 'team1@example.org'),
    (2, 2, 'Demo-Team 2', 'team2@example.org'),
    (3, 3, 'Demo-Team 3', 'team3@example.org'),
    (4, 4, 'Demo-Team 4', 'team4@example.org'),
    (5, 5, 'Demo-Team 5', 'team5@example.org');

INSERT INTO interessent
(id, pseudonym, email, bezirk_id, wohnflaeche, garten, etage, aufzug, kinder,
 hund_vorhanden, katze_vorhanden, zeit_stunden, allein_stunden, erfahrung,
 budget, medizin_bereit, aktivitaet)
VALUES
(1, 'Profil 1', 'profil1@example.org', fn_bezirk_id_pflicht('Mitte'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 1),
(2, 'Profil 2', 'profil2@example.org', fn_bezirk_id_pflicht('Pankow'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 2),
(3, 'Profil 3', 'profil3@example.org', fn_bezirk_id_pflicht('Spandau'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 3),
(4, 'Profil 4', 'profil4@example.org', fn_bezirk_id_pflicht('Neukoelln'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 4),
(5, 'Profil 5', 'profil5@example.org', fn_bezirk_id_pflicht('Lichtenberg'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 5),
(6, 'Profil 6', 'profil6@example.org', fn_bezirk_id_pflicht('Berlin-Mitte'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 1),
(7, 'Profil 7', 'profil7@example.org', fn_bezirk_id_pflicht('Prenzlauer Berg'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 2),
(8, 'Profil 8', 'profil8@example.org', fn_bezirk_id_pflicht('SPANDAU'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 3),
(9, 'Profil 9', 'profil9@example.org', fn_bezirk_id_pflicht('neukolln'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 4),
(10, 'Profil 10', 'profil10@example.org', fn_bezirk_id_pflicht('Lichtenberg (Berlin)'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 5),
(11, 'Profil 11', 'profil11@example.org', fn_bezirk_id_pflicht('Wedding'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 1),
(12, 'Profil 12', 'profil12@example.org', fn_bezirk_id_pflicht('Weissensee'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 2),
(13, 'Profil 13', 'profil13@example.org', fn_bezirk_id_pflicht('Spandua'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 3),
(14, 'Profil 14', 'profil14@example.org', fn_bezirk_id_pflicht('Bezirk Neukoelln'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 4),
(15, 'Profil 15', 'profil15@example.org', fn_bezirk_id_pflicht('Karlshorst'), 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 5),
(16, 'Profil 16', 'profil16@example.org', fn_bezirk_id_pflicht('Moabit'), 60, 0, 3, 1, 0, 0, 1, 4, 6, 2, 250, 0, 2),
(17, 'Profil 17', 'profil17@example.org', fn_bezirk_id_pflicht('Pankow'), 100, 1, 0, 0, 1, 1, 0, 8, 3, 4, 500, 1, 4),
(18, 'Profil 18', 'profil18@example.org', fn_bezirk_id_pflicht('Spandau'), 75, 0, 2, 1, 0, 0, 0, 5, 8, 1, 300, 1, 3),
(19, 'Profil 19', 'profil19@example.org', fn_bezirk_id_pflicht('Neukoeln'), 90, 1, 0, 0, 0, 0, 1, 7, 4, 3, 400, 1, 5),
(20, 'Profil 20', 'profil20@example.org', fn_bezirk_id_pflicht('Lichtenberg'), 55, 0, 4, 0, 0, 1, 1, 3, 10, 0, 200, 0, 1);

INSERT INTO interessent_tierart (interessent_id, tierart_id) VALUES
    (1, 1), (2, 2), (3, 3), (4, 4), (5, 5),
    (6, 1), (7, 2), (8, 3), (9, 4), (10, 5),
    (11, 1), (12, 2), (13, 3), (14, 4), (15, 5),
    (16, 2), (16, 3), (17, 1), (17, 3), (18, 4),
    (18, 5), (19, 1), (19, 2), (20, 3), (20, 4);

INSERT INTO interessent_charakter (interessent_id, charakter_id) VALUES
    (1, 1), (2, 2), (3, 3), (4, 4), (5, 5),
    (6, 1), (7, 2), (8, 3), (9, 4), (10, 5),
    (11, 1), (12, 2), (13, 3), (14, 4), (15, 5),
    (16, 1), (16, 3), (17, 2), (17, 4), (18, 1),
    (18, 5), (19, 2), (19, 6), (20, 1);

-- Trusted Setup-Kontext: trg_tier_standort_pruefen_insert/_update (01_grundlage/03_tabellen_anlegen.sql)
-- blockieren per Default (fail-closed), wenn @pm_mitarbeiter_id/@pm_ist_admin nicht gesetzt sind.
-- Demodaten-Skripte sind kein UI-Schreibpfad, daher hier wie in den Prozeduren per Bypass erlaubt.
SET @pm_ist_admin = 1;

INSERT INTO tier
(id, standort_id, tierart_id, name, geburtsdatum, geburt_geschaetzt, geschlecht,
 gewicht_kg, beschreibung, aktivitaet, min_wohnflaeche, garten_noetig,
 treppen_vermeiden, kinder_ok, hund_ok, katze_ok, min_zeit, max_allein,
 min_erfahrung, monatskosten, medizin_noetig)
VALUES
(1, 1, 1, 'Bruno', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 1, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(2, 2, 2, 'Mila', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 2, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(3, 3, 3, 'Flocke', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 3, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(4, 4, 4, 'Pino', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 4, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(5, 5, 5, 'Pia', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 5, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(6, 1, 1, 'Balu', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 1, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(7, 2, 2, 'Luna', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 2, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(8, 3, 3, 'Momo', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 3, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(9, 4, 4, 'Fips', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 4, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(10, 5, 5, 'Kiki', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 5, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(11, 1, 1, 'Oskar', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 1, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(12, 2, 2, 'Nala', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 2, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(13, 3, 3, 'Wolke', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 3, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(14, 4, 4, 'Pepe', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 4, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(15, 5, 5, 'Coco', '2021-05-01', 1, 'unbekannt', 5, 'Fiktives Tierprofil.', 5, 30, 0, 0, 1, 1, 1, 2, 5, 1, 100, 0),
(16, 1, 1, 'Bello', '2020-03-15', 1, 'maennlich', 18, 'Fiktiver, aktiver Hund.', 5, 70, 1, 0, 1, 1, 0, 3, 4, 3, 350, 0),
(17, 2, 2, 'Minka', '2022-07-01', 1, 'weiblich', 4, 'Fiktive, ruhige Katze.', 1, 40, 0, 0, 1, 1, 1, 1, 8, 1, 120, 0),
(18, 3, 3, 'Hopsi', '2023-01-10', 1, 'unbekannt', 2, 'Fiktives Kaninchen.', 2, 35, 0, 0, 1, 1, 1, 2, 6, 1, 90, 0),
(19, 4, 4, 'Nussi', '2022-11-20', 1, 'unbekannt', 1, 'Fiktives Meerschweinchen.', 2, 30, 0, 0, 1, 1, 1, 1, 5, 1, 70, 0),
(20, 5, 5, 'Pip', '2023-05-05', 1, 'unbekannt', 1, 'Fiktiver Vogel.', 3, 30, 0, 0, 1, 1, 1, 1, 4, 1, 60, 0);

INSERT INTO tier_charakter (tier_id, charakter_id) VALUES
    (1, 1), (2, 2), (3, 3), (4, 4), (5, 5),
    (6, 1), (7, 2), (8, 3), (9, 4), (10, 5),
    (11, 1), (12, 2), (13, 3), (14, 4), (15, 5),
    (16, 2), (16, 6), (17, 1), (18, 3), (18, 7),
    (19, 2), (19, 7), (20, 4), (20, 6);

INSERT INTO tier_beduerfnis (tier_id, beduerfnis_id, hinweis) VALUES
    (1, 1, 'Individuelle Bedingung vor Vermittlung pruefen.'),
    (2, 2, 'Individuelle Bedingung vor Vermittlung pruefen.'),
    (3, 3, 'Individuelle Bedingung vor Vermittlung pruefen.'),
    (4, 4, 'Individuelle Bedingung vor Vermittlung pruefen.'),
    (5, 5, 'Individuelle Bedingung vor Vermittlung pruefen.'),
    (16, 6, 'Taeglicher Auslauf ist fuer dieses fiktive Tierprofil vorgesehen.'),
    (17, 7, 'Ruhiger Haushalt ist fuer dieses fiktive Tierprofil vorgesehen.'),
    (18, 8, 'Regelmaessige Pflege ist fuer dieses fiktive Tierprofil vorgesehen.'),
    (19, 6, 'Taeglicher Auslauf ist fuer dieses fiktive Tierprofil vorgesehen.'),
    (20, 7, 'Ruhiger Haushalt ist fuer dieses fiktive Tierprofil vorgesehen.');

-- Interessent 7 lehnt den gesicherten Balkon ab (balkon_gesichert = 0, siehe oben), Interessent 9
-- lehnt Training ab (training_bereit = 0) - seit der Abloesung der direkten Spalten-Kriterien
-- 'Erforderlicher gesicherter Balkon'/'Notwendiges Training' (siehe team/decisions.md P2-7) ist
-- diese Bestaetigung die einzige Quelle fuer den Ausschluss; die Spalten balkon_gesichert/
-- training_bereit selbst fliessen in keine Score-Kategorie ein (anders als medizin_bereit/
-- tierarzt_bereit, die weiterhin in "Gesundheit" zaehlen).
INSERT INTO interessent_beduerfnis (interessent_id, beduerfnis_id, bestaetigt) VALUES
    (1, 1, 1), (2, 2, 1), (3, 3, 1), (4, 4, 1), (5, 5, 1),
    (7, 2, 0), (9, 4, 0),
    (17, 6, 1), (16, 7, 1), (18, 8, 1), (19, 6, 1), (20, 7, 1);

INSERT INTO merkliste (interessent_id, tier_id) VALUES
    (1, 1), (2, 2), (3, 3), (4, 4), (5, 5);

INSERT INTO bewerbung (id, interessent_id, tier_id) VALUES
    (1, 1, 1), (2, 2, 2), (3, 3, 3), (4, 4, 4), (5, 5, 5);

INSERT INTO termin (id, bewerbung_id, mitarbeiter_id, zeitpunkt, art) VALUES
    (1, 1, 1, '2026-12-01 14:00:00', 'kennenlernen'),
    (2, 2, 2, '2026-12-01 14:00:00', 'kennenlernen'),
    (3, 3, 3, '2026-12-01 14:00:00', 'kennenlernen'),
    (4, 4, 4, '2026-12-01 14:00:00', 'kennenlernen'),
    (5, 5, 5, '2026-12-01 14:00:00', 'kennenlernen');

-- Zusatzangaben fuer die Tiere: Groesse, Pflegeaufwand und ob sie mit Kleintieren klarkommen.
UPDATE tier SET groesse_id = 2, pflegeaufwand_id = 2, kleintiere_ok = 1 WHERE id IN (1, 6, 11);
UPDATE tier SET groesse_id = 3, pflegeaufwand_id = 2, kleintiere_ok = 0 WHERE id = 16;
UPDATE tier SET groesse_id = 1, pflegeaufwand_id = 1, kleintiere_ok = 0 WHERE id IN (2, 7, 12, 17);
UPDATE tier SET groesse_id = 1, pflegeaufwand_id = 2, kleintiere_ok = 1 WHERE id IN (3, 8, 13, 4, 9, 14, 19);
UPDATE tier SET groesse_id = 1, pflegeaufwand_id = 3, kleintiere_ok = 1 WHERE id = 18;
UPDATE tier SET groesse_id = 1, pflegeaufwand_id = 1, kleintiere_ok = 1 WHERE id IN (5, 10, 15, 20);

-- Gesundheit: belastende Merkmale (ID 1-5) zaehlen im Matching, Impfung und Kastration (6, 7) nicht.
-- Bei Tier 19 ist das Merkmal bewusst unbestaetigt und bleibt deshalb ohne Wirkung.
INSERT INTO tier_gesundheit (tier_id, gesundheitsmerkmal_id, bestaetigt, geprueft_am, hinweis) VALUES
    (1, 4, 1, '2026-01-15', 'Fiktive Dauermedikation, taeglich zu geben.'),
    (5, 6, 1, '2026-02-01', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (16, 6, 1, '2026-02-01', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (16, 7, 1, '2026-02-01', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (17, 1, 1, '2026-03-10', 'Fiktive chronische Erkrankung mit regelmaessiger Kontrolle.'),
    (18, 3, 1, '2026-03-10', 'Fiktive Gelenkprobleme, ruhige Haltung noetig.'),
    (19, 2, 0, '2026-03-10', 'Allergieverdacht, noch nicht bestaetigt.');

-- Zusatzangaben fuer die Interessenten.
UPDATE interessent
SET wohnform_id = 2, balkon = 0, balkon_gesichert = 0, haushaltsgroesse = 2,
    kleintiere_vorhanden = 0, arbeitsmodell_id = 3, wunschalter_min = 1, wunschalter_max = 10,
    training_bereit = 1, tierarzt_bereit = 1, max_pflegeaufwand_id = 3
WHERE id BETWEEN 1 AND 15;

UPDATE interessent SET balkon = 1, balkon_gesichert = 1 WHERE id IN (2, 12);
UPDATE interessent SET balkon = 1, balkon_gesichert = 0 WHERE id = 7;
UPDATE interessent SET training_bereit = 0 WHERE id = 9;

UPDATE interessent
SET wohnform_id = 1, balkon = 1, balkon_gesichert = 1, haushaltsgroesse = 1,
    kleintiere_vorhanden = 1, arbeitsmodell_id = 1, wunschalter_min = 0, wunschalter_max = 8,
    training_bereit = 0, tierarzt_bereit = 1, max_pflegeaufwand_id = 2
WHERE id = 16;

-- Profil 17 sucht nur in Berlin (Suchzone 1); schliesst Brandenburg-Standorte hart aus (siehe ENTWICKLUNG.md Abschnitt 6).
UPDATE interessent
SET wohnform_id = 2, balkon = 0, balkon_gesichert = 0, haushaltsgroesse = 4,
    kleintiere_vorhanden = 0, arbeitsmodell_id = 2, wunschalter_min = 1, wunschalter_max = 12,
    training_bereit = 1, tierarzt_bereit = 1, max_pflegeaufwand_id = 3, max_suchzone_id = 1
WHERE id = 17;

UPDATE interessent
SET wohnform_id = 1, balkon = 1, balkon_gesichert = 0, haushaltsgroesse = 1,
    kleintiere_vorhanden = 1, arbeitsmodell_id = 1, wunschalter_min = 0, wunschalter_max = 6,
    training_bereit = 1, tierarzt_bereit = 1, max_pflegeaufwand_id = 2
WHERE id = 18;

UPDATE interessent
SET wohnform_id = 2, balkon = 0, balkon_gesichert = 0, haushaltsgroesse = 2,
    kleintiere_vorhanden = 0, arbeitsmodell_id = 4, wunschalter_min = 0, wunschalter_max = 15,
    training_bereit = 1, tierarzt_bereit = 1, max_pflegeaufwand_id = 3
WHERE id = 19;

UPDATE interessent
SET wohnform_id = 1, balkon = 1, balkon_gesichert = 1, haushaltsgroesse = 1,
    kleintiere_vorhanden = 0, arbeitsmodell_id = 1,
    training_bereit = 0, tierarzt_bereit = 0, max_pflegeaufwand_id = 1
WHERE id = 20;

-- Profil 13 hat absichtlich keine Erfahrung eingetragen, damit man eine offene Pruefung sieht.
INSERT INTO interessent_tiererfahrung (interessent_id, tierart_id, erfahrungslevel) VALUES
    (1, 1, 3), (2, 2, 3), (3, 3, 3), (4, 4, 3), (5, 5, 3),
    (6, 1, 3), (7, 2, 3), (8, 3, 3), (9, 4, 3), (10, 5, 3),
    (11, 1, 3), (12, 2, 3), (14, 4, 3), (15, 5, 3),
    (16, 2, 2), (16, 3, 2), (17, 1, 4), (17, 3, 2),
    (18, 4, 1), (18, 5, 1), (19, 1, 2), (19, 2, 3),
    (20, 3, 0), (20, 4, 1);

INSERT INTO interessent_groesse (interessent_id, groesse_id) VALUES
    (1, 2), (16, 1), (17, 2), (17, 3);

INSERT INTO interessent_standort (interessent_id, standort_id) VALUES
    (17, 1);


-- Demodaten-Erweiterung (Meeting-Feedback Phase 5, P5.2): 80 zusaetzliche Tiere (ids 21-100),
-- 16 je Tierart (Hund/Katze/Kaninchen/Meerschweinchen/Vogel), verteilt auf deutlich mehr der
-- oben bereits recherchierten Standorte. Vier Tiere darunter (21, 37, 53, 69+70) sind bewusst
-- als P5.3-Demonstrationspaare konstruiert, siehe team/tasks.md P5.3-Zeile fuer die genaue
-- erwartete Einordnung (sehr gut/mittel/Grenzfall/harter Ausschluss).

-- Fuenf weitere Demo-Mitarbeiterkonten (analog "Demo-Team N"), damit die neu genutzten
-- Standorte auch UI-seitig als "eigener Standort" eines Mitarbeiters testbar sind (P0.2-
-- Standortberechtigung), nicht nur per Admin-Bypass erreichbar sind wie der Rest dieser Datei.
INSERT INTO mitarbeiter (id, standort_id, name, email) VALUES
    (6, 6, 'Demo-Team 6', 'team6@example.org'),
    (7, 14, 'Demo-Team 7', 'team7@example.org'),
    (8, 16, 'Demo-Team 8', 'team8@example.org'),
    (9, 20, 'Demo-Team 9', 'team9@example.org'),
    (10, 26, 'Demo-Team 10', 'team10@example.org');

SET @pm_ist_admin = 1;

INSERT INTO tier
(id, standort_id, tierart_id, name, geburtsdatum, geburt_geschaetzt, geschlecht,
 gewicht_kg, beschreibung, aktivitaet, min_wohnflaeche, garten_noetig,
 treppen_vermeiden, kinder_ok, hund_ok, katze_ok, min_zeit, max_allein,
 min_erfahrung, monatskosten, medizin_noetig)
VALUES
(21, 1, 1, 'Rex', '2022-06-01', 0, 'maennlich', 22, 'Fiktiver, unkomplizierter Familienhund ohne besondere Anforderungen.', 1, 20, 0, 0, 1, 1, 1, 2, 10, 0, 100, 0),
(22, 14, 1, 'Balu2', '2024-05-15', 0, 'unbekannt', 13.35, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 2, 30, 0, 0, 1, 1, 1, 1, 8, 0, 200, 0),
(23, 20, 1, 'Lasse', '2023-05-15', 1, 'maennlich', 15.57, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 2, 25, 0, 0, 1, 1, 1, 1, 3, 2, 80, 0),
(24, 23, 1, 'Finn', '2022-08-15', 1, 'weiblich', 5.56, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 2, 45, 0, 0, 0, 1, 1, 2, 3, 2, 120, 0),
(25, 25, 1, 'Jack', '2022-01-15', 1, 'maennlich', 32.66, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 1, 20, 0, 0, 0, 0, 1, 2, 6, 1, 80, 0),
(26, 18, 1, 'Buddy', '2014-04-15', 1, 'maennlich', 11.46, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 2, 70, 1, 1, 1, 1, 1, 1, 3, 0, 250, 0),
(27, 4, 1, 'Sam', '2019-06-15', 0, 'maennlich', 18.78, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 4, 30, 0, 0, 0, 1, 1, 2, 8, 0, 200, 0),
(28, 7, 1, 'Rocky', '2019-01-15', 1, 'weiblich', 5.97, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 5, 20, 0, 1, 1, 1, 1, 3, 3, 3, 100, 0),
(29, 9, 1, 'Teddy2', '2015-09-15', 1, 'weiblich', 12.43, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 1, 45, 0, 1, 1, 1, 0, 2, 8, 0, 80, 0),
(30, 11, 1, 'Nero', '2021-07-15', 1, 'maennlich', 10.47, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 1, 50, 0, 1, 1, 1, 1, 3, 6, 2, 250, 0),
(31, 13, 1, 'Max2', '2025-02-15', 1, 'unbekannt', 7.33, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 5, 20, 0, 0, 0, 0, 1, 2, 4, 2, 150, 0),
(32, 17, 1, 'Benno', '2016-05-15', 0, 'weiblich', 14.09, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 1, 75, 0, 0, 0, 1, 1, 2, 3, 0, 200, 0),
(33, 21, 1, 'Theo', '2014-05-15', 1, 'weiblich', 25.06, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 4, 75, 0, 0, 1, 1, 1, 2, 4, 1, 100, 0),
(34, 22, 1, 'Elvis', '2025-04-15', 0, 'maennlich', 13.69, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 4, 75, 1, 1, 0, 1, 0, 1, 8, 1, 250, 0),
(35, 30, 1, 'Cooper', '2021-05-15', 0, 'weiblich', 25.57, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 3, 20, 0, 0, 1, 1, 1, 2, 4, 1, 100, 0),
(36, 31, 1, 'Amigo', '2025-11-15', 1, 'weiblich', 27.19, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart hund.', 1, 55, 0, 0, 0, 0, 0, 3, 8, 0, 100, 0),
(37, 6, 2, 'Mira', '2017-11-15', 1, 'weiblich', 4.2, 'Fiktive aeltere Katze mit Allergie, braucht einen ruhigen Zweitplatz.', 4, 40, 0, 0, 1, 1, 1, 4, 6, 2, 150, 0),
(38, 8, 2, 'Kessy', '2025-12-15', 1, 'weiblich', 3.3, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 4, 30, 0, 0, 1, 1, 0, 1, 8, 0, 80, 0),
(39, 12, 2, 'Simba', '2019-05-15', 1, 'maennlich', 4.25, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 5, 30, 0, 1, 0, 1, 0, 1, 8, 0, 120, 0),
(40, 19, 2, 'Loki', '2020-02-15', 1, 'maennlich', 3.8, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 3, 25, 0, 0, 0, 1, 1, 2, 10, 0, 100, 0),
(41, 24, 2, 'Pixel', '2023-02-15', 1, 'weiblich', 3.64, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 5, 25, 0, 1, 1, 0, 1, 1, 8, 0, 80, 0),
(42, 27, 2, 'Zora', '2026-08-15', 0, 'maennlich', 3.38, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 5, 40, 0, 0, 1, 0, 1, 1, 6, 2, 80, 0),
(43, 18, 2, 'Felix2', '2017-02-15', 1, 'weiblich', 5.86, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 3, 40, 0, 0, 1, 0, 1, 1, 10, 0, 100, 0),
(44, 7, 2, 'Smilla', '2017-10-15', 1, 'unbekannt', 6.28, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 1, 45, 0, 0, 0, 1, 0, 0, 8, 1, 120, 0),
(45, 9, 2, 'Gizmo', '2023-03-15', 1, 'weiblich', 6.42, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 5, 30, 0, 0, 1, 1, 1, 0, 6, 2, 80, 0),
(46, 11, 2, 'Yuma', '2015-03-15', 0, 'maennlich', 3.4, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 1, 25, 0, 0, 1, 1, 0, 1, 8, 0, 80, 0),
(47, 13, 2, 'Nemo2', '2014-05-15', 0, 'maennlich', 4.8, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 4, 40, 0, 0, 1, 1, 0, 0, 8, 0, 100, 0),
(48, 17, 2, 'Frieda', '2019-01-15', 1, 'maennlich', 5.33, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 4, 30, 0, 0, 1, 0, 1, 2, 10, 2, 100, 0),
(49, 21, 2, 'Jonny', '2021-03-15', 1, 'maennlich', 6.02, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 3, 25, 0, 0, 1, 1, 0, 0, 8, 2, 120, 0),
(50, 22, 2, 'Stella', '2015-06-15', 1, 'maennlich', 6.49, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 5, 30, 0, 0, 1, 1, 0, 2, 8, 1, 100, 0),
(51, 33, 2, 'Moritz', '2024-08-15', 0, 'maennlich', 3.41, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 2, 25, 0, 0, 1, 1, 0, 1, 8, 0, 60, 0),
(52, 34, 2, 'Yoda', '2024-04-15', 0, 'maennlich', 4.47, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart katze.', 5, 25, 0, 1, 0, 1, 0, 1, 8, 0, 80, 0),
(53, 26, 3, 'Hoppel', '2023-02-01', 1, 'unbekannt', 2.1, 'Fiktives Kaninchen mit Handling-Bedarf, braucht erfahrene Halter.', 3, 20, 0, 0, 1, 1, 1, 1, 10, 4, 50, 0),
(54, 1, 3, 'Fluse', '2018-11-15', 0, 'weiblich', 3.26, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 3, 15, 0, 1, 1, 1, 1, 1, 6, 1, 40, 0),
(55, 2, 3, 'Karotte', '2018-03-15', 0, 'maennlich', 1.58, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 2, 20, 0, 1, 1, 0, 1, 1, 6, 0, 40, 0),
(56, 3, 3, 'Pummel', '2022-02-15', 1, 'maennlich', 3.19, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 1, 15, 0, 0, 0, 1, 1, 1, 10, 0, 60, 0),
(57, 5, 3, 'Hasi', '2023-04-15', 1, 'weiblich', 4.03, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 3, 30, 0, 0, 1, 1, 1, 2, 8, 1, 70, 0),
(58, 7, 3, 'Nibbles', '2022-01-15', 0, 'weiblich', 2.08, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 2, 25, 0, 1, 1, 0, 0, 1, 10, 2, 40, 0),
(59, 9, 3, 'Schnuffel', '2021-06-15', 1, 'maennlich', 2.88, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 3, 30, 0, 0, 1, 0, 1, 1, 8, 1, 70, 0),
(60, 11, 3, 'Muemmel', '2020-06-15', 1, 'unbekannt', 2.82, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 2, 30, 0, 0, 1, 1, 1, 2, 8, 1, 60, 0),
(61, 13, 3, 'Peter2', '2019-09-15', 1, 'weiblich', 2.83, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 1, 20, 0, 0, 1, 1, 1, 2, 10, 1, 40, 0),
(62, 17, 3, 'Benny2', '2025-11-15', 1, 'unbekannt', 4.04, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 4, 25, 0, 0, 1, 1, 1, 2, 10, 2, 40, 0),
(63, 21, 3, 'Keks2', '2018-04-15', 0, 'maennlich', 2.38, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 4, 20, 0, 1, 1, 0, 1, 1, 10, 2, 50, 0),
(64, 22, 3, 'Flummi', '2023-09-15', 1, 'unbekannt', 1.72, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 4, 25, 0, 0, 1, 0, 0, 2, 8, 2, 60, 0),
(65, 30, 3, 'Pucki', '2019-06-15', 1, 'weiblich', 4.21, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 4, 25, 0, 0, 1, 1, 0, 1, 10, 1, 50, 0),
(66, 31, 3, 'Juma', '2023-08-15', 1, 'unbekannt', 2.57, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 2, 20, 0, 0, 0, 1, 0, 2, 8, 1, 50, 0),
(67, 32, 3, 'Krick', '2022-11-15', 0, 'maennlich', 1.25, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 5, 15, 0, 0, 0, 1, 1, 1, 8, 1, 70, 0),
(68, 35, 3, 'Spotti', '2025-04-15', 0, 'weiblich', 2.2, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart kaninchen.', 4, 15, 0, 0, 1, 0, 0, 1, 6, 1, 70, 0),
(69, 16, 4, 'Keks', '2024-09-01', 1, 'weiblich', 0.9, 'Fiktives, genuegsames Meerschweinchen.', 2, 20, 0, 0, 1, 1, 1, 3, 8, 1, 80, 0),
(70, 16, 4, 'Kruemel', '2024-09-01', 1, 'maennlich', 0.9, 'Fiktives Meerschweinchen, braucht etwas haeufiger Gesellschaft als Keks.', 2, 20, 0, 0, 1, 1, 1, 3, 7.5, 1, 80, 0),
(71, 26, 4, 'Erdnuss', '2022-01-15', 1, 'weiblich', 1.47, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 1, 20, 0, 1, 1, 0, 0, 1, 12, 1, 40, 0),
(72, 1, 4, 'Flecki', '2020-11-15', 0, 'unbekannt', 0.89, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 2, 15, 0, 0, 1, 1, 1, 1, 12, 0, 40, 0),
(73, 2, 4, 'Wuschel', '2025-05-15', 1, 'maennlich', 1.17, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 1, 15, 0, 1, 1, 0, 1, 1, 10, 1, 50, 0),
(74, 3, 4, 'Moehrle', '2022-01-15', 0, 'weiblich', 0.99, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 2, 10, 0, 0, 1, 1, 1, 1, 10, 1, 50, 0),
(75, 5, 4, 'Pepsi', '2021-12-15', 0, 'maennlich', 1.01, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 4, 15, 0, 0, 1, 1, 1, 1, 12, 0, 40, 0),
(76, 9, 4, 'Nussi2', '2026-02-15', 1, 'unbekannt', 1.21, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 1, 15, 0, 1, 1, 1, 1, 1, 12, 0, 50, 0),
(77, 11, 4, 'Pummelchen', '2022-03-15', 1, 'unbekannt', 1.25, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 5, 10, 0, 1, 1, 0, 0, 2, 12, 1, 40, 1),
(78, 13, 4, 'Speedy', '2025-01-15', 1, 'maennlich', 1.35, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 5, 20, 0, 0, 1, 1, 1, 1, 8, 0, 30, 0),
(79, 17, 4, 'Fiete', '2020-06-15', 1, 'unbekannt', 1.3, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 1, 10, 0, 0, 0, 0, 0, 1, 12, 0, 30, 0),
(80, 21, 4, 'Moppel', '2025-12-15', 1, 'unbekannt', 0.74, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 1, 15, 0, 0, 1, 1, 1, 1, 10, 1, 40, 0),
(81, 22, 4, 'Pfeffer', '2021-02-15', 0, 'maennlich', 1.48, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 3, 10, 0, 0, 1, 1, 0, 1, 8, 0, 50, 0),
(82, 30, 4, 'Zimt', '2024-11-15', 1, 'maennlich', 1.12, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 5, 20, 0, 0, 1, 0, 1, 1, 12, 1, 50, 0),
(83, 31, 4, 'Keksi', '2026-02-15', 1, 'maennlich', 0.77, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 1, 20, 0, 0, 0, 0, 1, 2, 12, 0, 40, 1),
(84, 33, 4, 'Minzi', '2025-11-15', 1, 'unbekannt', 0.86, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart meerschwein.', 2, 20, 0, 0, 1, 0, 1, 1, 10, 1, 50, 0),
(85, 1, 5, 'Pipo', '2013-11-15', 0, 'maennlich', 0.11, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 2, 15, 0, 0, 1, 0, 0, 1, 12, 0, 30, 0),
(86, 2, 5, 'Hansi', '2016-05-15', 0, 'weiblich', 1.0, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 2, 15, 0, 0, 1, 1, 1, 0, 6, 2, 60, 0),
(87, 3, 5, 'Kiwi2', '2020-09-15', 1, 'maennlich', 0.26, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 2, 15, 0, 0, 1, 1, 1, 0, 10, 2, 80, 0),
(88, 5, 5, 'Lori', '2015-09-15', 0, 'maennlich', 0.11, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 2, 15, 0, 0, 1, 1, 1, 1, 8, 1, 30, 0),
(89, 7, 5, 'Sunny', '2012-11-15', 1, 'weiblich', 0.16, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 3, 20, 0, 0, 1, 1, 1, 0, 12, 1, 30, 0),
(90, 9, 5, 'Rio2', '2025-05-15', 0, 'maennlich', 0.61, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 1, 20, 0, 0, 1, 1, 1, 0, 10, 1, 30, 0),
(91, 11, 5, 'Blue', '2025-10-15', 1, 'maennlich', 0.98, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 3, 15, 0, 0, 1, 1, 1, 0, 10, 0, 30, 0),
(92, 13, 5, 'Fiete2', '2022-06-15', 0, 'maennlich', 0.94, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 5, 20, 0, 0, 0, 1, 1, 1, 10, 0, 40, 0),
(93, 17, 5, 'Picco', '2021-01-15', 0, 'unbekannt', 0.44, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 4, 20, 0, 0, 1, 1, 0, 1, 10, 0, 30, 0),
(94, 21, 5, 'Mango', '2025-07-15', 0, 'unbekannt', 0.65, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 3, 10, 0, 1, 0, 1, 1, 0, 12, 0, 40, 0),
(95, 22, 5, 'Kolibri', '2018-04-15', 1, 'unbekannt', 0.3, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 1, 20, 0, 0, 1, 0, 0, 0, 12, 2, 80, 0),
(96, 30, 5, 'Pauli', '2024-11-15', 1, 'maennlich', 0.68, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 1, 15, 0, 1, 1, 1, 0, 0, 8, 1, 40, 0),
(97, 31, 5, 'Nemo3', '2015-07-15', 1, 'maennlich', 0.83, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 1, 15, 0, 0, 1, 0, 0, 1, 6, 1, 80, 0),
(98, 32, 5, 'Toffee', '2023-04-15', 1, 'unbekannt', 0.25, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 5, 10, 0, 1, 1, 1, 1, 1, 8, 2, 60, 0),
(99, 34, 5, 'Felix3', '2026-02-15', 0, 'weiblich', 0.95, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 5, 20, 0, 0, 1, 1, 0, 0, 12, 2, 30, 0),
(100, 37, 5, 'Cora', '2020-01-15', 1, 'maennlich', 0.74, 'Fiktives Tierprofil (Demodaten-Erweiterung), Tierart vogel.', 3, 10, 0, 0, 1, 1, 1, 1, 6, 1, 40, 0);

-- Groesse, Pflegeaufwand und Kleintiervertraeglichkeit, gruppiert nach gleicher Kombination.
UPDATE tier SET groesse_id = 2, pflegeaufwand_id = 1, kleintiere_ok = 1 WHERE id IN (21);
UPDATE tier SET groesse_id = 1, pflegeaufwand_id = 1, kleintiere_ok = 1 WHERE id IN (22, 23, 27, 35, 49, 51, 53, 55, 58, 60, 62, 68, 69, 70, 72, 76, 77, 79, 81, 82, 88, 91, 97);
UPDATE tier SET groesse_id = 2, pflegeaufwand_id = 1, kleintiere_ok = 0 WHERE id IN (24, 29, 30);
UPDATE tier SET groesse_id = 1, pflegeaufwand_id = 2, kleintiere_ok = 0 WHERE id IN (25, 28, 41, 61, 66);
UPDATE tier SET groesse_id = 3, pflegeaufwand_id = 2, kleintiere_ok = 1 WHERE id IN (26);
UPDATE tier SET groesse_id = 1, pflegeaufwand_id = 2, kleintiere_ok = 1 WHERE id IN (31, 45, 46, 48, 54, 56, 57, 64, 80, 90, 93, 99);
UPDATE tier SET groesse_id = 3, pflegeaufwand_id = 1, kleintiere_ok = 1 WHERE id IN (32);
UPDATE tier SET groesse_id = 3, pflegeaufwand_id = 1, kleintiere_ok = 0 WHERE id IN (33, 34);
UPDATE tier SET groesse_id = 2, pflegeaufwand_id = 2, kleintiere_ok = 1 WHERE id IN (36, 37, 43, 92, 100);
UPDATE tier SET groesse_id = 1, pflegeaufwand_id = 3, kleintiere_ok = 1 WHERE id IN (38, 52, 63, 67, 74, 78, 86, 94, 95, 96, 98);
UPDATE tier SET groesse_id = 1, pflegeaufwand_id = 1, kleintiere_ok = 0 WHERE id IN (39, 50, 59, 65, 71, 75, 87);
UPDATE tier SET groesse_id = 1, pflegeaufwand_id = 3, kleintiere_ok = 0 WHERE id IN (40, 73, 83, 84, 85);
UPDATE tier SET groesse_id = 2, pflegeaufwand_id = 2, kleintiere_ok = 0 WHERE id IN (42, 47);
UPDATE tier SET groesse_id = 2, pflegeaufwand_id = 3, kleintiere_ok = 1 WHERE id IN (44);
UPDATE tier SET groesse_id = 2, pflegeaufwand_id = 3, kleintiere_ok = 0 WHERE id IN (89);

-- Rassen aus dem neuen Katalog (tier_rasse), gruppiert nach Rasse.
UPDATE tier SET rasse_id = 1 WHERE id IN (30, 32, 33);
UPDATE tier SET rasse_id = 2 WHERE id IN (21);
UPDATE tier SET rasse_id = 4 WHERE id IN (24, 27);
UPDATE tier SET rasse_id = 6 WHERE id IN (29);
UPDATE tier SET rasse_id = 7 WHERE id IN (35);
UPDATE tier SET rasse_id = 8 WHERE id IN (23, 36);
UPDATE tier SET rasse_id = 9 WHERE id IN (31);
UPDATE tier SET rasse_id = 10 WHERE id IN (26, 28);
UPDATE tier SET rasse_id = 11 WHERE id IN (34);
UPDATE tier SET rasse_id = 12 WHERE id IN (25);
UPDATE tier SET rasse_id = 13 WHERE id IN (22);
UPDATE tier SET rasse_id = 14 WHERE id IN (49, 50);
UPDATE tier SET rasse_id = 16 WHERE id IN (39);
UPDATE tier SET rasse_id = 17 WHERE id IN (37, 46);
UPDATE tier SET rasse_id = 18 WHERE id IN (43);
UPDATE tier SET rasse_id = 20 WHERE id IN (47);
UPDATE tier SET rasse_id = 21 WHERE id IN (45, 48);
UPDATE tier SET rasse_id = 22 WHERE id IN (40, 44, 51, 52);
UPDATE tier SET rasse_id = 23 WHERE id IN (38, 42);
UPDATE tier SET rasse_id = 24 WHERE id IN (41);
UPDATE tier SET rasse_id = 25 WHERE id IN (53, 56, 63);
UPDATE tier SET rasse_id = 26 WHERE id IN (57, 65);
UPDATE tier SET rasse_id = 27 WHERE id IN (58, 62, 68);
UPDATE tier SET rasse_id = 28 WHERE id IN (61);
UPDATE tier SET rasse_id = 29 WHERE id IN (60, 67);
UPDATE tier SET rasse_id = 30 WHERE id IN (55, 64);
UPDATE tier SET rasse_id = 32 WHERE id IN (59);
UPDATE tier SET rasse_id = 33 WHERE id IN (54, 66);
UPDATE tier SET rasse_id = 34 WHERE id IN (69, 70, 72, 75, 79, 80, 81, 84);
UPDATE tier SET rasse_id = 35 WHERE id IN (74);
UPDATE tier SET rasse_id = 36 WHERE id IN (76);
UPDATE tier SET rasse_id = 37 WHERE id IN (78, 83);
UPDATE tier SET rasse_id = 39 WHERE id IN (77);
UPDATE tier SET rasse_id = 40 WHERE id IN (71, 73, 82);
UPDATE tier SET rasse_id = 42 WHERE id IN (85, 90, 94, 98);
UPDATE tier SET rasse_id = 43 WHERE id IN (93);
UPDATE tier SET rasse_id = 44 WHERE id IN (89, 99);
UPDATE tier SET rasse_id = 45 WHERE id IN (86, 87, 97);
UPDATE tier SET rasse_id = 48 WHERE id IN (88);
UPDATE tier SET rasse_id = 49 WHERE id IN (92, 100);
UPDATE tier SET rasse_id = 50 WHERE id IN (91, 95, 96);

INSERT INTO tier_charakter (tier_id, charakter_id) VALUES
    (21, 1),
    (22, 4),
    (22, 2),
    (23, 5),
    (24, 6),
    (24, 2),
    (25, 2),
    (26, 6),
    (27, 7),
    (27, 5),
    (28, 6),
    (28, 2),
    (29, 4),
    (29, 2),
    (30, 5),
    (31, 4),
    (32, 6),
    (33, 5),
    (33, 1),
    (34, 6),
    (35, 5),
    (35, 2),
    (36, 7),
    (36, 6),
    (37, 1),
    (38, 1),
    (39, 3),
    (39, 5),
    (40, 4),
    (41, 6),
    (42, 7),
    (43, 4),
    (44, 3),
    (45, 7),
    (46, 5),
    (46, 6),
    (47, 5),
    (48, 1),
    (49, 4),
    (50, 4),
    (50, 3),
    (51, 4),
    (52, 7),
    (53, 5),
    (54, 6),
    (55, 4),
    (55, 3),
    (56, 4),
    (56, 6),
    (57, 7),
    (57, 5),
    (58, 7),
    (59, 7),
    (60, 1),
    (61, 4),
    (62, 6),
    (62, 1),
    (63, 6),
    (64, 3),
    (64, 1),
    (65, 7),
    (66, 2),
    (67, 1),
    (67, 6),
    (68, 5),
    (69, 1),
    (70, 1),
    (71, 5),
    (71, 1),
    (72, 7),
    (73, 1),
    (74, 1),
    (74, 6),
    (75, 1),
    (76, 3),
    (77, 4),
    (77, 1),
    (78, 7),
    (79, 4),
    (79, 2),
    (80, 4),
    (80, 6),
    (81, 3),
    (82, 7),
    (83, 4),
    (83, 5),
    (84, 6),
    (84, 3),
    (85, 4),
    (85, 5),
    (86, 4),
    (86, 1),
    (87, 1),
    (88, 4),
    (89, 2),
    (90, 5),
    (90, 7),
    (91, 4),
    (91, 6),
    (92, 4),
    (92, 7),
    (93, 7),
    (93, 3),
    (94, 3),
    (95, 1),
    (96, 2),
    (96, 5),
    (97, 5),
    (98, 5),
    (98, 6),
    (99, 1),
    (99, 2),
    (100, 7);

INSERT INTO tier_beduerfnis (tier_id, beduerfnis_id, hinweis) VALUES
    (24, 7, 'Ruhiger Haushalt ist fuer dieses fiktive Tierprofil vorgesehen.'),
    (33, 4, 'Fiktiver Trainingsbedarf vor der Vermittlung.'),
    (38, 5, 'Fiktiver Bedarf an Spezialfutter.'),
    (71, 6, 'Taeglicher Auslauf ist fuer dieses fiktive Tierprofil vorgesehen.'),
    (77, 1, 'Fiktive taegliche Medikamentengabe, siehe Gesundheitseintrag.'),
    (79, 4, 'Fiktiver Trainingsbedarf vor der Vermittlung.'),
    (83, 1, 'Fiktive taegliche Medikamentengabe, siehe Gesundheitseintrag.'),
    (84, 2, 'Fiktiver gesicherter Balkon erforderlich (Ausbruchsgefahr).'),
    (95, 2, 'Fiktiver gesicherter Balkon erforderlich (Ausbruchsgefahr).');

INSERT INTO tier_gesundheit (tier_id, gesundheitsmerkmal_id, bestaetigt, geprueft_am, hinweis) VALUES
    (25, 3, 0, '2026-03-01', 'Fiktive Gelenkprobleme, ruhige Haltung empfohlen. (noch nicht bestaetigt)'),
    (27, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (30, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (33, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (35, 3, 1, '2026-03-01', 'Fiktive Gelenkprobleme, ruhige Haltung empfohlen.'),
    (36, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (37, 2, 1, '2026-04-01', 'Fiktive Futterallergie, Spezialfutter empfohlen.'),
    (38, 3, 1, '2026-03-01', 'Fiktive Gelenkprobleme, ruhige Haltung empfohlen.'),
    (38, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (41, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (42, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (44, 3, 1, '2026-03-01', 'Fiktive Gelenkprobleme, ruhige Haltung empfohlen.'),
    (46, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (47, 5, 1, '2026-03-01', 'Fiktive leichte Behinderung, keine besonderen Einschraenkungen im Alltag.'),
    (47, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (51, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (52, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (55, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (55, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (57, 3, 1, '2026-03-01', 'Fiktive Gelenkprobleme, ruhige Haltung empfohlen.'),
    (58, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (59, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (62, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (63, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (64, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (65, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (66, 5, 0, '2026-03-01', 'Fiktive leichte Behinderung, keine besonderen Einschraenkungen im Alltag. (noch nicht bestaetigt)'),
    (68, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (71, 2, 0, '2026-03-01', 'Fiktive Allergie, Ausloeser im individuellen Hinweis dokumentiert. (noch nicht bestaetigt)'),
    (72, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (73, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (75, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (77, 4, 1, '2026-02-01', 'Fiktive Dauermedikation, taeglich zu geben.'),
    (77, 2, 1, '2026-03-01', 'Fiktive Allergie, Ausloeser im individuellen Hinweis dokumentiert.'),
    (78, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (80, 1, 1, '2026-03-01', 'Fiktive chronische Erkrankung, regelmaessige Kontrolle noetig.'),
    (80, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (82, 1, 1, '2026-03-01', 'Fiktive chronische Erkrankung, regelmaessige Kontrolle noetig.'),
    (83, 4, 1, '2026-02-01', 'Fiktive Dauermedikation, taeglich zu geben.'),
    (85, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (86, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (87, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (88, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (89, 5, 1, '2026-03-01', 'Fiktive leichte Behinderung, keine besonderen Einschraenkungen im Alltag.'),
    (90, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (91, 5, 1, '2026-03-01', 'Fiktive leichte Behinderung, keine besonderen Einschraenkungen im Alltag.'),
    (91, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.'),
    (92, 5, 1, '2026-03-01', 'Fiktive leichte Behinderung, keine besonderen Einschraenkungen im Alltag.'),
    (96, 5, 1, '2026-03-01', 'Fiktive leichte Behinderung, keine besonderen Einschraenkungen im Alltag.'),
    (97, 1, 1, '2026-03-01', 'Fiktive chronische Erkrankung, regelmaessige Kontrolle noetig.'),
    (98, 7, 1, '2026-01-10', 'Kastration im fiktiven Tierprofil vermerkt.'),
    (99, 6, 1, '2026-01-10', 'Impfschutz laut fiktivem Impfpass vollstaendig.');

