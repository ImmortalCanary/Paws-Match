-- Achtung: loescht eine vorhandene Datenbank paws_match komplett, damit alles frisch aufgesetzt wird.
DROP DATABASE IF EXISTS paws_match;

-- 0900_ai_ci ist der Standard von MySQL 8. Mit unicode_ci gab es Fehler bei Textvergleichen in Funktionen.
CREATE DATABASE paws_match
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE paws_match;
