-- Neuinstallation: eine vorhandene Datenbank paws_match wird samt Daten entfernt.
DROP DATABASE IF EXISTS paws_match;

-- Standardkollation von MySQL 8 (wie Workbench/Konsole), sonst Konflikte bei Textvergleichen in Funktionen.
CREATE DATABASE paws_match
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE paws_match;
