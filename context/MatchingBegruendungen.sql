-- MatchingBegruendungen.sql
-- Erklärt die vorhandenen Regeln von v_match_basis, ohne sie zu ändern.
-- Fehlende kritische Angaben werden auch bei bereits ausgeschlossenen Paaren angezeigt.
-- Aktivität und Charakter sind weiche Kriterien, keine kritischen Pflichtangaben.
-- Die Ausgabe enthält aktive Interessenten wie v_match_basis.
-- In MySQL noch nicht als erfolgreicher Gesamttest ausgeführt.
USE paws_match;

CREATE OR REPLACE VIEW v_match_begruendungen AS
SELECT b.tier_id, b.interessent_id, b.tiername, b.pseudonym,
       b.tierstatus, b.eignung,
       NULLIF(CONCAT_WS(' | ',
         IF(NOT EXISTS (
           SELECT 1 FROM interessent_tierart p
           WHERE p.interessent_id=i.id AND p.tierart_id=t.tierart_id
         ), 'Gewünschte Tierart nicht enthalten', NULL),
         IF(t.garten_noetig=1 AND i.garten=0,
            'Garten erforderlich, aber nicht vorhanden', NULL),
         IF(t.treppen_vermeiden=1 AND i.etage>0 AND i.aufzug=0,
            'Treppen müssen vermieden werden; Obergeschoss ohne Aufzug', NULL),
         IF(t.kinder_ok=0 AND i.kinder=1,
            'Tier ist nicht für einen Haushalt mit Kindern geeignet', NULL),
         IF(t.hund_ok=0 AND i.hund_vorhanden=1,
            'Tier ist nicht für einen Haushalt mit vorhandenem Hund geeignet', NULL),
         IF(t.katze_ok=0 AND i.katze_vorhanden=1,
            'Tier ist nicht für einen Haushalt mit vorhandener Katze geeignet', NULL),
         IF(i.wohnflaeche<t.min_wohnflaeche, 'Wohnfläche zu klein', NULL),
         IF(i.zeit_stunden<t.min_zeit, 'Zu wenig verfügbare Zeit', NULL),
         IF(i.allein_stunden>t.max_allein,
            'Geplante Alleinzeit überschreitet die zulässige Höchstdauer', NULL),
         IF(i.erfahrung<t.min_erfahrung, 'Erfahrung reicht nicht aus', NULL),
         IF(i.budget<t.monatskosten, 'Monatliches Budget reicht nicht aus', NULL),
         IF(t.medizin_noetig=1 AND i.medizin_bereit=0,
            'Medizinische Versorgung erforderlich, aber abgelehnt', NULL),
         IF(EXISTS (
           SELECT 1 FROM tier_beduerfnis tb
           JOIN interessent_beduerfnis ib
             ON ib.beduerfnis_id=tb.beduerfnis_id AND ib.interessent_id=i.id
           WHERE tb.tier_id=t.id AND ib.bestaetigt=0
         ), 'Mindestens ein erforderliches Bedürfnis wurde ausdrücklich abgelehnt', NULL),
         IF(EXISTS (
           SELECT 1 FROM tier_beduerfnis tb
           WHERE tb.tier_id=t.id AND NOT EXISTS (
             SELECT 1 FROM interessent_beduerfnis ib
             WHERE ib.interessent_id=i.id AND ib.beduerfnis_id=tb.beduerfnis_id
           )
         ), 'Bestätigung für mindestens ein erforderliches Bedürfnis fehlt', NULL),
         IF(i.wohnflaeche IS NULL, 'Interessent: Wohnfläche fehlt', NULL),
         IF(i.garten IS NULL, 'Interessent: Angabe zum Garten fehlt', NULL),
         IF(i.etage IS NULL, 'Interessent: Etage fehlt', NULL),
         IF(i.aufzug IS NULL, 'Interessent: Angabe zum Aufzug fehlt', NULL),
         IF(i.kinder IS NULL, 'Interessent: Angabe zu Kindern fehlt', NULL),
         IF(i.hund_vorhanden IS NULL, 'Interessent: Angabe zu vorhandenen Hunden fehlt', NULL),
         IF(i.katze_vorhanden IS NULL, 'Interessent: Angabe zu vorhandenen Katzen fehlt', NULL),
         IF(i.zeit_stunden IS NULL, 'Interessent: Verfügbare Zeit fehlt', NULL),
         IF(i.allein_stunden IS NULL, 'Interessent: Geplante Alleinzeit fehlt', NULL),
         IF(i.erfahrung IS NULL, 'Interessent: Erfahrung fehlt', NULL),
         IF(i.budget IS NULL, 'Interessent: Budget fehlt', NULL),
         IF(i.medizin_bereit IS NULL, 'Interessent: Bereitschaft zur medizinischen Versorgung fehlt', NULL),
         IF(t.min_wohnflaeche IS NULL, 'Tier: Mindestwohnfläche fehlt', NULL),
         IF(t.garten_noetig IS NULL, 'Tier: Gartenanforderung fehlt', NULL),
         IF(t.treppen_vermeiden IS NULL, 'Tier: Angabe zur Treppenverträglichkeit fehlt', NULL),
         IF(t.kinder_ok IS NULL, 'Tier: Kinderverträglichkeit fehlt', NULL),
         IF(t.hund_ok IS NULL, 'Tier: Hundeverträglichkeit fehlt', NULL),
         IF(t.katze_ok IS NULL, 'Tier: Katzenverträglichkeit fehlt', NULL),
         IF(t.min_zeit IS NULL, 'Tier: Mindestzeit fehlt', NULL),
         IF(t.max_allein IS NULL, 'Tier: Zulässige Alleinzeit fehlt', NULL),
         IF(t.min_erfahrung IS NULL, 'Tier: Mindestanforderung an Erfahrung fehlt', NULL),
         IF(t.monatskosten IS NULL, 'Tier: Monatliche Kosten fehlen', NULL),
         IF(t.medizin_noetig IS NULL, 'Tier: Angabe zum medizinischen Bedarf fehlt', NULL)
       ), '') AS `begründungen`
FROM v_match_basis b
JOIN tier t ON t.id=b.tier_id
JOIN interessent i ON i.id=b.interessent_id;

-- Übersicht; NULL bedeutet: keine der hier geprüften Beanstandungen.
-- Eignung ist unabhängig von der aktuellen Verfügbarkeit des Tieres.
SELECT * FROM v_match_begruendungen ORDER BY interessent_id, tier_id;

-- Soll-Ergebnis: keine Zeilen; jede offene oder ausgeschlossene Kombination hat einen Hinweis.
SELECT * FROM v_match_begruendungen
WHERE eignung IN ('ausgeschlossen','pruefung_offen') AND `begründungen` IS NULL;

-- Soll-Ergebnis: keine Zeilen; geeignete Kombinationen haben keine kritische Beanstandung.
SELECT * FROM v_match_begruendungen
WHERE eignung='geeignet' AND `begründungen` IS NOT NULL;
