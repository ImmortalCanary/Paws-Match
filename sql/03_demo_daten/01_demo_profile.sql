USE paws_match;
SET NAMES utf8mb4;

-- Ausschliesslich fiktive Demonstrationsdaten.

INSERT INTO tierheim (id, name, email) VALUES
    (1, 'Demo-Tierschutz 1', 'heim1@example.org'),
    (2, 'Demo-Tierschutz 2', 'heim2@example.org'),
    (3, 'Demo-Tierschutz 3', 'heim3@example.org'),
    (4, 'Demo-Tierschutz 4', 'heim4@example.org'),
    (5, 'Demo-Tierschutz 5', 'heim5@example.org');

INSERT INTO standort (id, tierheim_id, name, bezirk, ort, kapazitaet) VALUES
    (1, 1, 'Demo-Standort Mitte', 'Mitte', 'Berlin', 30),
    (2, 2, 'Demo-Standort Pankow', 'Pankow', 'Berlin', 30),
    (3, 3, 'Demo-Standort Spandau', 'Spandau', 'Berlin', 30),
    (4, 4, 'Demo-Standort Neukoelln', 'Neukoelln', 'Berlin', 30),
    (5, 5, 'Demo-Standort Lichtenberg', 'Lichtenberg', 'Berlin', 30);

INSERT INTO mitarbeiter (id, standort_id, name, email) VALUES
    (1, 1, 'Demo-Team 1', 'team1@example.org'),
    (2, 2, 'Demo-Team 2', 'team2@example.org'),
    (3, 3, 'Demo-Team 3', 'team3@example.org'),
    (4, 4, 'Demo-Team 4', 'team4@example.org'),
    (5, 5, 'Demo-Team 5', 'team5@example.org');

INSERT INTO interessent
(id, pseudonym, email, bezirk, wohnflaeche, garten, etage, aufzug, kinder,
 hund_vorhanden, katze_vorhanden, zeit_stunden, allein_stunden, erfahrung,
 budget, medizin_bereit, aktivitaet)
VALUES
(1, 'Profil 1', 'profil1@example.org', 'Mitte', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 1),
(2, 'Profil 2', 'profil2@example.org', 'Pankow', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 2),
(3, 'Profil 3', 'profil3@example.org', 'Spandau', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 3),
(4, 'Profil 4', 'profil4@example.org', 'Neukoelln', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 4),
(5, 'Profil 5', 'profil5@example.org', 'Lichtenberg', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 5),
(6, 'Profil 6', 'profil6@example.org', 'Mitte', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 1),
(7, 'Profil 7', 'profil7@example.org', 'Pankow', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 2),
(8, 'Profil 8', 'profil8@example.org', 'Spandau', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 3),
(9, 'Profil 9', 'profil9@example.org', 'Neukoelln', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 4),
(10, 'Profil 10', 'profil10@example.org', 'Lichtenberg', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 5),
(11, 'Profil 11', 'profil11@example.org', 'Mitte', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 1),
(12, 'Profil 12', 'profil12@example.org', 'Pankow', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 2),
(13, 'Profil 13', 'profil13@example.org', 'Spandau', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 3),
(14, 'Profil 14', 'profil14@example.org', 'Neukoelln', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 4),
(15, 'Profil 15', 'profil15@example.org', 'Lichtenberg', 80, 1, 0, 0, 0, 0, 0, 6, 2, 4, 400, 1, 5),
(16, 'Profil 16', 'profil16@example.org', 'Mitte', 60, 0, 3, 1, 0, 0, 1, 4, 6, 2, 250, 0, 2),
(17, 'Profil 17', 'profil17@example.org', 'Pankow', 100, 1, 0, 0, 1, 1, 0, 8, 3, 4, 500, 1, 4),
(18, 'Profil 18', 'profil18@example.org', 'Spandau', 75, 0, 2, 1, 0, 0, 0, 5, 8, 1, 300, 1, 3),
(19, 'Profil 19', 'profil19@example.org', 'Neukoelln', 90, 1, 0, 0, 0, 0, 1, 7, 4, 3, 400, 1, 5),
(20, 'Profil 20', 'profil20@example.org', 'Lichtenberg', 55, 0, 4, 0, 0, 1, 1, 3, 10, 0, 200, 0, 1);

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
    (16, 2), (16, 6), (17, 1), (18, 3), (18, 8),
    (19, 2), (19, 8), (20, 4), (20, 6);

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

INSERT INTO interessent_beduerfnis (interessent_id, beduerfnis_id, bestaetigt) VALUES
    (1, 1, 1),
    (2, 2, 1),
    (3, 3, 1),
    (4, 4, 1),
    (5, 5, 1),
    (17, 6, 1),
    (16, 7, 1),
    (18, 8, 1),
    (19, 6, 1),
    (20, 7, 1);

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
