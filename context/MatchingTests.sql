-- MatchingTests.sql
-- Paws & Match: Kontrollabfragen für die Match-Logik
-- Enthält SELECT-Abfragen und Aufrufe der Vorschlagsprozeduren.
-- Diese Datei wurde noch nicht als erfolgreicher Gesamttest ausgeführt.

USE paws_match;

-- 1. Alle Match-Ergebnisse mit Eignung, Score und Datenabdeckung
SELECT tiername, pseudonym, eignung, tierstatus, match_prozent, datenabdeckung_prozent
FROM v_match_score
ORDER BY interessent_id, match_prozent DESC, tier_id;

-- 2. Geeignete und verfügbare Tiere
SELECT tiername, pseudonym, match_prozent, datenabdeckung_prozent
FROM v_vorschlaege
ORDER BY interessent_id, match_prozent DESC, tier_id;

-- 3. Ausgeschlossene Kombinationen mit Begründungen
SELECT tiername, pseudonym, eignung, `begründungen`
FROM v_match_begruendungen
WHERE eignung = 'ausgeschlossen'
ORDER BY interessent_id, tier_id;

-- 4. Kombinationen mit offenen Prüfungen
SELECT tiername, pseudonym, eignung, `begründungen`
FROM v_match_begruendungen
WHERE eignung = 'pruefung_offen'
ORDER BY interessent_id, tier_id;

-- 5. Passung der einzelnen Kriterien
SELECT tier_id, interessent_id, kriterium, passung_prozent, gewicht
FROM v_match_details
ORDER BY interessent_id, tier_id, kriterium;

-- 6. Auslastung der Standorte
SELECT name, kapazitaet, aktuelle_tiere, auslastung_prozent
FROM v_auslastung
ORDER BY auslastung_prozent DESC;

-- 7. Offene Bewerbungen
SELECT id, status, tier, pseudonym, standort_id, erstellt_am
FROM v_offene_bewerbungen
ORDER BY erstellt_am;

-- 8. Vorschläge für Interessent 17
CALL sp_vorschlaege_fuer_interessent(17);

-- 9. Vorschläge für Tier 16
CALL sp_vorschlaege_fuer_tier(16);
