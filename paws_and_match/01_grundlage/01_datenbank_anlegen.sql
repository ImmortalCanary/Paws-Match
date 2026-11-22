-- Neuinstallation: eine vorhandene Datenbank paws_match wird samt Daten entfernt.
DROP DATABASE IF EXISTS paws_match;

CREATE DATABASE paws_match
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE paws_match;
