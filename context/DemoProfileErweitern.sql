-- DemoProfileErweitern.sql
-- Paws & Match: Zusätzliche fiktive Demonstrationsdaten
-- Die Daten dienen ausschließlich der Präsentation und Prüfung der Match-Logik.

USE paws_match;

-- Zusätzliche Tierarten
INSERT INTO tierart (id, name)
VALUES (6, 'Reptil'), (7, 'Fisch')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Zusätzliche Charaktere
INSERT INTO charakter (id, name)
VALUES (6, 'aktiv'), (7, 'ruhig'), (8, 'sozial')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Zusätzliche Bedürfnisse
INSERT INTO beduerfnis (id, name)
VALUES (6, 'Täglicher Auslauf'), (7, 'Ruhiger Haushalt'), (8, 'Regelmäßige Pflege')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Zusätzliche Interessentenprofile
INSERT INTO interessent
(id, pseudonym, email, bezirk, wohnflaeche, garten, etage, aufzug, kinder,
 hund_vorhanden, katze_vorhanden, zeit_stunden, allein_stunden, erfahrung,
 budget, medizin_bereit, aktivitaet)
VALUES
(16, 'Profil 16', 'profil16@example.org', 'Mitte', 60, 0, 3, 1, 0, 0, 1, 4, 6, 2, 250, 0, 2),
(17, 'Profil 17', 'profil17@example.org', 'Pankow', 100, 1, 0, 0, 1, 1, 0, 8, 3, 4, 500, 1, 4),
(18, 'Profil 18', 'profil18@example.org', 'Spandau', 75, 0, 2, 1, 0, 0, 0, 5, 8, 1, 300, 1, 3),
(19, 'Profil 19', 'profil19@example.org', 'Neukoelln', 90, 1, 0, 0, 0, 0, 1, 7, 4, 3, 400, 1, 5),
(20, 'Profil 20', 'profil20@example.org', 'Lichtenberg', 55, 0, 4, 0, 0, 1, 1, 3, 10, 0, 200, 0, 1);

-- Tierart-Präferenzen
INSERT INTO interessent_tierart (interessent_id, tierart_id)
VALUES
(16, 2), (16, 3),
(17, 1), (17, 3),
(18, 4), (18, 5),
(19, 1), (19, 2),
(20, 3), (20, 4);

-- Charakter-Präferenzen
INSERT INTO interessent_charakter (interessent_id, charakter_id)
VALUES
(16, 1), (16, 3),
(17, 2), (17, 4),
(18, 1), (18, 5),
(19, 2), (19, 6),
(20, 1), (20, 7);

-- Zusätzliche Tiere
INSERT INTO tier
(id, standort_id, tierart_id, name, geburtsdatum, geburt_geschaetzt, geschlecht,
 gewicht_kg, beschreibung, aktivitaet, min_wohnflaeche, garten_noetig,
 treppen_vermeiden, kinder_ok, hund_ok, katze_ok, min_zeit, max_allein,
 min_erfahrung, monatskosten, medizin_noetig)
VALUES
(16, 1, 1, 'Bello', '2020-03-15', 1, 'maennlich', 18,
 'Fiktiver, aktiver Hund für die Projektpräsentation.', 5, 70, 1, 0, 1, 1, 0, 3, 4, 3, 350, 0),
(17, 2, 2, 'Minka', '2022-07-01', 1, 'weiblich', 4,
 'Fiktive, ruhige Katze für die Projektpräsentation.', 1, 40, 0, 0, 1, 1, 1, 1, 8, 1, 120, 0),
(18, 3, 3, 'Hopsi', '2023-01-10', 1, 'unbekannt', 2,
 'Fiktives Kaninchen für die Projektpräsentation.', 2, 35, 0, 0, 1, 1, 1, 2, 6, 1, 90, 0),
(19, 4, 4, 'Nussi', '2022-11-20', 1, 'unbekannt', 1,
 'Fiktives Meerschweinchen für die Projektpräsentation.', 2, 30, 0, 0, 1, 1, 1, 1, 5, 1, 70, 0),
(20, 5, 5, 'Pip', '2023-05-05', 1, 'unbekannt', 1,
 'Fiktiver Vogel für die Projektpräsentation.', 3, 30, 0, 0, 1, 1, 1, 1, 4, 1, 60, 0);

-- Charaktere der Tiere
INSERT INTO tier_charakter (tier_id, charakter_id)
VALUES
(16, 2), (16, 6),
(17, 1), (17, 7),
(18, 3), (18, 8),
(19, 2), (19, 8),
(20, 4), (20, 6);

-- Bedürfnisse der Tiere
INSERT INTO tier_beduerfnis (tier_id, beduerfnis_id, hinweis)
VALUES
(16, 6, 'Täglicher Auslauf ist für dieses fiktive Tierprofil vorgesehen.'),
(17, 7, 'Ruhiger Haushalt ist für dieses fiktive Tierprofil vorgesehen.'),
(18, 8, 'Regelmäßige Pflege ist für dieses fiktive Tierprofil vorgesehen.'),
(19, 6, 'Täglicher Auslauf ist für dieses fiktive Tierprofil vorgesehen.'),
(20, 7, 'Ruhiger Haushalt ist für dieses fiktive Tierprofil vorgesehen.');

-- Bestätigungen durch Interessenten
INSERT INTO interessent_beduerfnis (interessent_id, beduerfnis_id, bestaetigt)
VALUES
(17, 6, 1),
(16, 7, 1),
(18, 8, 1),
(19, 6, 1),
(20, 7, 1);

-- Kontrolle der neuen Profile
SELECT id, pseudonym, bezirk, wohnflaeche, aktivitaet
FROM interessent
WHERE id BETWEEN 16 AND 20
ORDER BY id;

SELECT id, name, tierart_id, standort_id, status, aktivitaet
FROM tier
WHERE id BETWEEN 16 AND 20
ORDER BY id;
