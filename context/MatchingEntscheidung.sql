-- MatchingEntscheidung.sql
-- Voraussetzung: Basis, TierprofileErweitern.sql,
-- InteressentenprofileErweitern.sql und MatchingVoraussetzungen.sql.
-- MySQL ab 8.0.16. Noch nicht ausgeführt oder getestet.
-- Neue zentrale Entscheidung; bestehende Score-Views werden NICHT umgestellt.
-- Kein Score; ausgeschlossen bedeutet später 0 %, offen bedeutet keinen Score.
-- Bedarfskatalog der Grundlage: 1=Medikamentengabe, 2=gesicherter Balkon,
-- 4=Training. Diese IDs dürfen nicht umgedeutet werden.
-- Der Bedarfskatalog eines Tieres muss vollständig gepflegt sein.
-- Medizinbedarf erfordert hier auch Bereitschaft zu Tierarztbesuchen.
-- Keine automatischen Anforderungen aus Rasse, Foto oder Gesundheitsmerkmalen.
USE paws_match;
SET NAMES utf8mb4;

CREATE VIEW MatchingEntscheidung AS
WITH P AS (
 SELECT t.*, i.id AS InteressentId, i.pseudonym AS Pseudonym,
 i.aktiv AS Aktiv, i.garten AS Garten, i.etage AS Etage,
 i.aufzug AS Aufzug, i.kinder AS Kinder,
 i.hund_vorhanden AS HundVorhanden, i.katze_vorhanden AS KatzeVorhanden,
 i.wohnflaeche AS Wohnflaeche, i.zeit_stunden AS Zeit,
 i.allein_stunden AS Alleinzeit, i.budget AS Budget,
 i.medizin_bereit AS MedizinBereit, i.KleintiereVorhanden,
 i.Balkon, i.BalkonGesichert, i.TrainingBereit, i.TierarztBereit,
 e.Erfahrungslevel, pf.Rang AS PflegeBedarf,
 ipf.Rang AS PflegeBereitschaft,
 EXISTS(SELECT 1 FROM interessent_tierart it WHERE it.interessent_id=i.id) AS TierwunschErfasst,
 EXISTS(SELECT 1 FROM interessent_tierart it WHERE it.interessent_id=i.id AND it.tierart_id=t.tierart_id) AS TierartPasst,
 EXISTS(SELECT 1 FROM tier_beduerfnis tb WHERE tb.tier_id=t.id AND tb.beduerfnis_id=2) AS BalkonBedarf,
 EXISTS(SELECT 1 FROM tier_beduerfnis tb WHERE tb.tier_id=t.id AND tb.beduerfnis_id=4) AS TrainingBedarf,
 CASE WHEN t.medizin_noetig=1 OR EXISTS(
   SELECT 1 FROM tier_beduerfnis tb WHERE tb.tier_id=t.id AND tb.beduerfnis_id=1
 ) THEN 1 WHEN t.medizin_noetig=0 THEN 0 ELSE NULL END AS MedizinBedarf,
 EXISTS(
   SELECT 1 FROM tier_beduerfnis tb
   JOIN interessent_beduerfnis ib ON ib.beduerfnis_id=tb.beduerfnis_id AND ib.interessent_id=i.id
   WHERE tb.tier_id=t.id AND ib.bestaetigt=0
 ) AS BedarfAbgelehnt,
 EXISTS(
   SELECT 1 FROM tier_beduerfnis tb WHERE tb.tier_id=t.id AND NOT EXISTS(
     SELECT 1 FROM interessent_beduerfnis ib
     WHERE ib.interessent_id=i.id AND ib.beduerfnis_id=tb.beduerfnis_id
   )
 ) AS BedarfOffen
 FROM tier t CROSS JOIN interessent i
 LEFT JOIN InteressentTiererfahrung e ON e.InteressentId=i.id AND e.TierartId=t.tierart_id
 LEFT JOIN Pflegeaufwand pf ON pf.Id=t.PflegeaufwandId
 LEFT JOIN Pflegeaufwand ipf ON ipf.Id=i.MaxPflegeaufwandId
)
SELECT P.id AS TierId, P.InteressentId, P.name AS Tiername, P.Pseudonym,
 P.status AS Tierstatus, (P.status='verfuegbar') AS TierVerfuegbar,
 P.Aktiv AS InteressentAktiv,
 CASE WHEN MAX(R.Ergebnis)=2 THEN 'ausgeschlossen'
      WHEN MAX(R.Ergebnis)=1 THEN 'pruefung_offen'
      ELSE 'geeignet' END AS Eignung,
 GROUP_CONCAT(CASE WHEN R.Ergebnis=2 THEN CONCAT(R.Kriterium, ': Anforderung nicht erfüllt') END
   ORDER BY R.Position SEPARATOR ' | ') AS Ausschlussgruende,
 GROUP_CONCAT(CASE WHEN R.Ergebnis=1 THEN CONCAT(R.Kriterium, ': erforderliche Angaben oder Bestätigungen fehlen') END
   ORDER BY R.Position SEPARATOR ' | ') AS OffenePruefungen
FROM P
-- Ergebnis je Kriterium: 0=erfüllt, 1=offen, 2=ausgeschlossen.
JOIN JSON_TABLE(JSON_ARRAY(
 JSON_ARRAY('Tierartwunsch', CASE WHEN TierwunschErfasst=0 THEN 1 WHEN TierartPasst=1 THEN 0 ELSE 2 END),
 JSON_ARRAY('Garten', CASE WHEN garten_noetig=0 OR Garten=1 THEN 0 WHEN garten_noetig=1 AND Garten=0 THEN 2 ELSE 1 END),
 JSON_ARRAY('Treppen', CASE WHEN treppen_vermeiden=0 OR Etage=0 OR Aufzug=1 THEN 0 WHEN treppen_vermeiden=1 AND Etage>0 AND Aufzug=0 THEN 2 ELSE 1 END),
 JSON_ARRAY('Kinderverträglichkeit', CASE WHEN kinder_ok=1 OR Kinder=0 THEN 0 WHEN kinder_ok=0 AND Kinder=1 THEN 2 ELSE 1 END),
 JSON_ARRAY('Hundeverträglichkeit', CASE WHEN hund_ok=1 OR HundVorhanden=0 THEN 0 WHEN hund_ok=0 AND HundVorhanden=1 THEN 2 ELSE 1 END),
 JSON_ARRAY('Katzenverträglichkeit', CASE WHEN katze_ok=1 OR KatzeVorhanden=0 THEN 0 WHEN katze_ok=0 AND KatzeVorhanden=1 THEN 2 ELSE 1 END),
 JSON_ARRAY('Kleintierverträglichkeit', CASE WHEN KleintiereOk=1 OR KleintiereVorhanden=0 THEN 0 WHEN KleintiereOk=0 AND KleintiereVorhanden=1 THEN 2 ELSE 1 END),
 JSON_ARRAY('Wohnfläche', CASE WHEN min_wohnflaeche=0 THEN 0 WHEN Wohnflaeche<min_wohnflaeche THEN 2 WHEN Wohnflaeche IS NULL OR min_wohnflaeche IS NULL THEN 1 ELSE 0 END),
 JSON_ARRAY('Betreuungszeit', CASE WHEN min_zeit=0 THEN 0 WHEN Zeit<min_zeit THEN 2 WHEN Zeit IS NULL OR min_zeit IS NULL THEN 1 ELSE 0 END),
 JSON_ARRAY('Alleinzeit', CASE WHEN Alleinzeit>max_allein THEN 2 WHEN Alleinzeit IS NULL OR max_allein IS NULL THEN 1 ELSE 0 END),
 JSON_ARRAY('Tierartspezifische Erfahrung', CASE WHEN min_erfahrung=0 THEN 0 WHEN Erfahrungslevel<min_erfahrung THEN 2 WHEN Erfahrungslevel IS NULL OR min_erfahrung IS NULL THEN 1 ELSE 0 END),
 JSON_ARRAY('Monatliches Budget', CASE WHEN monatskosten=0 THEN 0 WHEN Budget<monatskosten THEN 2 WHEN Budget IS NULL OR monatskosten IS NULL THEN 1 ELSE 0 END),
 JSON_ARRAY('Medizinische Versorgung', CASE WHEN MedizinBedarf=0 OR MedizinBereit=1 THEN 0 WHEN MedizinBedarf=1 AND MedizinBereit=0 THEN 2 ELSE 1 END),
 JSON_ARRAY('Tierarztbereitschaft', CASE WHEN MedizinBedarf=0 OR TierarztBereit=1 THEN 0 WHEN MedizinBedarf=1 AND TierarztBereit=0 THEN 2 ELSE 1 END),
 JSON_ARRAY('Notwendiges Training', CASE WHEN TrainingBedarf=0 OR TrainingBereit=1 THEN 0 WHEN TrainingBereit=0 THEN 2 ELSE 1 END),
 JSON_ARRAY('Pflegeaufwand', CASE WHEN PflegeBereitschaft<PflegeBedarf THEN 2 WHEN PflegeBereitschaft IS NULL OR PflegeBedarf IS NULL THEN 1 ELSE 0 END),
 JSON_ARRAY('Erforderlicher gesicherter Balkon', CASE WHEN BalkonBedarf=0 THEN 0 WHEN Balkon=0 OR BalkonGesichert=0 THEN 2 WHEN Balkon=1 AND BalkonGesichert=1 THEN 0 ELSE 1 END),
 JSON_ARRAY('Verbindliches Bedürfnis ausdrücklich abgelehnt', IF(BedarfAbgelehnt,2,0)),
 JSON_ARRAY('Bestätigung verbindlicher Bedürfnisse', IF(BedarfOffen,1,0))
), '$[*]' COLUMNS (
 Position FOR ORDINALITY,
 Kriterium VARCHAR(100) PATH '$[0]',
 Ergebnis INT PATH '$[1]'
)) AS R ON TRUE
GROUP BY P.id, P.InteressentId, P.name, P.Pseudonym, P.status, P.Aktiv;

-- GROUP_CONCAT umfasst hier höchstens 19 begrenzte Meldungen.
-- Für vollständige Hinweise muss die abfragende Sitzung genug Platz bereitstellen.
SET SESSION group_concat_max_len=65535;
SELECT * FROM MatchingEntscheidung ORDER BY InteressentId, TierId;

-- Soll: keine Zeilen. Bekannte Ausschlüsse haben Vorrang.
SELECT * FROM MatchingEntscheidung
WHERE (Ausschlussgruende IS NOT NULL AND Eignung<>'ausgeschlossen')
   OR (Eignung='ausgeschlossen' AND Ausschlussgruende IS NULL)
   OR (Eignung='pruefung_offen' AND OffenePruefungen IS NULL)
   OR (Eignung='geeignet' AND (Ausschlussgruende IS NOT NULL OR OffenePruefungen IS NOT NULL));

-- Verfügbarkeit und Aktivierung separat filtern, ohne Eignung umzudeuten.
-- Der spätere Score und Mindestscore fehlen hier bewusst noch.
SELECT * FROM MatchingEntscheidung
WHERE Eignung='geeignet' AND TierVerfuegbar=1 AND InteressentAktiv=1
ORDER BY InteressentId, TierId;
