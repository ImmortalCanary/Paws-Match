USE paws_match;
SET NAMES utf8mb4;

INSERT INTO tierart (id, name) VALUES
    (1, 'Hund'), (2, 'Katze'), (3, 'Kaninchen'), (4, 'Meerschweinchen'),
    (5, 'Vogel'), (6, 'Reptil'), (7, 'Fisch');

INSERT INTO charakter (id, name) VALUES
    (1, 'ruhig'), (2, 'verspielt'), (3, 'schuechtern'), (4, 'kontaktfreudig'),
    (5, 'eigenstaendig'), (6, 'aktiv'), (8, 'sozial');

INSERT INTO beduerfnis (id, name) VALUES
    (1, 'taegliche Medikamentengabe'), (2, 'gesicherter Balkon'),
    (3, 'Vergesellschaftung erforderlich'), (4, 'Training erforderlich'),
    (5, 'Spezialfutter'), (6, 'Taeglicher Auslauf'),
    (7, 'Ruhiger Haushalt'), (8, 'Regelmaessige Pflege');
