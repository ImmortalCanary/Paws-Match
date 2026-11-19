-- MatchingScore.sql
-- Nach allen Voraussetzungen von MatchingEntscheidung.sql und dieser Datei ausführen.
-- Gemeint ist: zuerst MatchingEntscheidung.sql, danach MatchingScore.sql.
-- Einmalige Installation, MySQL ab 8.0.16; noch nicht getestet.
-- Bestehende Score-Views, Vorschlagsprozeduren und Gewichte bleiben unverändert.
-- Neue Namen: MatchingGewichtung, MatchingKriterien, MatchingScore.
-- Verfügbarkeit und Aktivierung ändern den fachlichen Score nicht.
USE paws_match;
SET NAMES utf8mb4;
SET SESSION group_concat_max_len=65535;

CREATE TABLE MatchingGewichtung (
 Kriterium ENUM('Tierart','Aktivitaet','Zeit','Wohnsituation','Erfahrung',
                'Vertraeglichkeit','Budget','Charakter','Naehe') PRIMARY KEY,
 Gewicht DECIMAL(6,2) NOT NULL,
 CHECK (Gewicht>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO MatchingGewichtung (Kriterium,Gewicht) VALUES
 ('Tierart',20),('Aktivitaet',15),('Zeit',15),('Wohnsituation',15),
 ('Erfahrung',10),('Vertraeglichkeit',10),('Budget',5),('Charakter',5),('Naehe',5);

-- Harte Mindestbedingungen: nach bestätigter Gesamteignung jeweils 1.
-- Kein Bonus für mehr Geld, größere Wohnung oder mehr Erfahrung.
-- Diese sechs Kriterien sind bei geeigneten Paaren somit konstant.
-- Die Rangfolge entsteht aus Aktivität, Charakter und Nähe.
CREATE VIEW MatchingKriterien AS
WITH B AS (
 SELECT d.TierId,d.InteressentId,
   CASE WHEN d.Eignung='geeignet' THEN 1.0 ELSE NULL END AS MindestPassung,
   CASE WHEN t.aktivitaet BETWEEN 1 AND 5 AND i.aktivitaet BETWEEN 1 AND 5
        THEN 1.0-ABS(t.aktivitaet-i.aktivitaet)/4.0 ELSE NULL END AS AktivitaetPassung,
   CASE WHEN EXISTS(SELECT 1 FROM interessent_charakter ic WHERE ic.interessent_id=i.id)
         AND EXISTS(SELECT 1 FROM tier_charakter tc WHERE tc.tier_id=t.id)
        THEN (SELECT COUNT(*) FROM interessent_charakter ic
              JOIN tier_charakter tc ON tc.charakter_id=ic.charakter_id
              WHERE ic.interessent_id=i.id AND tc.tier_id=t.id)*1.0
             / NULLIF((SELECT COUNT(*) FROM interessent_charakter ic
                       WHERE ic.interessent_id=i.id),0)
        ELSE NULL END AS CharakterPassung,
   CASE WHEN EXISTS(SELECT 1 FROM InteressentStandort isp
                    WHERE isp.InteressentId=i.id AND isp.StandortId=t.standort_id)
        THEN 1.0
        WHEN NULLIF(TRIM(i.bezirk),'') IS NOT NULL
         AND NULLIF(TRIM(s.bezirk),'') IS NOT NULL
        THEN CASE WHEN i.bezirk=s.bezirk THEN 1.0 ELSE 0.0 END
        WHEN EXISTS(SELECT 1 FROM InteressentStandort isp WHERE isp.InteressentId=i.id)
        THEN 0.0 ELSE NULL END AS NaehePassung
 FROM MatchingEntscheidung d
 JOIN tier t ON t.id=d.TierId
 JOIN interessent i ON i.id=d.InteressentId
 JOIN standort s ON s.id=t.standort_id
)
SELECT TierId,InteressentId,'Tierart' AS Kriterium,MindestPassung AS Passung FROM B
UNION ALL SELECT TierId,InteressentId,'Aktivitaet',AktivitaetPassung FROM B
UNION ALL SELECT TierId,InteressentId,'Zeit',MindestPassung FROM B
UNION ALL SELECT TierId,InteressentId,'Wohnsituation',MindestPassung FROM B
UNION ALL SELECT TierId,InteressentId,'Erfahrung',MindestPassung FROM B
UNION ALL SELECT TierId,InteressentId,'Vertraeglichkeit',MindestPassung FROM B
UNION ALL SELECT TierId,InteressentId,'Budget',MindestPassung FROM B
UNION ALL SELECT TierId,InteressentId,'Charakter',CharakterPassung FROM B
UNION ALL SELECT TierId,InteressentId,'Naehe',NaehePassung FROM B;

-- Alter, Größe, Rasse, Foto und Arbeitsmodell ändern diese neun Teilwerte nicht.
-- Alters- und Größenwünsche benötigen später eine ausdrücklich vereinbarte
-- weiche Bewertungsregel oder einen zusätzlichen optionalen Suchfilter.
-- Fehlende Charakterdaten sind unbekannt; bekannte Daten ohne Überschneidung sind 0.
-- Nähe: bevorzugter Standort ODER gleicher Bezirk ergibt 1; sonst 0 bei bekannter Grundlage.

CREATE VIEW MatchingScore AS
WITH G AS (
 SELECT COUNT(*) AS AnzahlGewichte,SUM(Gewicht) AS Gesamtgewicht
 FROM MatchingGewichtung
), A AS (
 SELECT k.TierId,k.InteressentId,
   SUM(CASE WHEN k.Passung IS NOT NULL THEN k.Passung*g.Gewicht ELSE 0 END) AS Punkte,
   SUM(CASE WHEN k.Passung IS NOT NULL THEN g.Gewicht ELSE 0 END) AS ErfasstesGewicht
 FROM MatchingKriterien k
 LEFT JOIN MatchingGewichtung g ON g.Kriterium=k.Kriterium
 GROUP BY k.TierId,k.InteressentId
)
SELECT d.TierId,d.InteressentId,d.Tiername,d.Pseudonym,d.Tierstatus,
 d.TierVerfuegbar,d.InteressentAktiv,d.Eignung,d.Ausschlussgruende,d.OffenePruefungen,
 (g.AnzahlGewichte=9 AND g.Gesamtgewicht>0) AS GewichtungVollstaendig,
 CASE WHEN d.Eignung='ausgeschlossen' THEN 0
      WHEN d.Eignung='pruefung_offen' THEN NULL
      WHEN g.AnzahlGewichte<>9 OR g.Gesamtgewicht IS NULL OR g.Gesamtgewicht<=0 THEN NULL
      ELSE ROUND(100.0*a.Punkte/NULLIF(a.ErfasstesGewicht,0),1)
 END AS MatchProzent,
 -- Datenabdeckung nur für geeignete Paare ausweisen:
 -- Bei anderen Paaren werden harte Teilwerte bewusst nicht freigegeben.
 CASE WHEN d.Eignung='geeignet' AND g.AnzahlGewichte=9 AND g.Gesamtgewicht>0
      THEN ROUND(100.0*a.ErfasstesGewicht/g.Gesamtgewicht,1)
      ELSE NULL END AS DatenabdeckungProzent
FROM MatchingEntscheidung d
JOIN A a ON a.TierId=d.TierId AND a.InteressentId=d.InteressentId
CROSS JOIN G g;

-- Beispiele, noch kein Testnachweis und keine Mindestscore-Filterung.
SELECT * FROM MatchingScore
WHERE InteressentId=17 ORDER BY MatchProzent DESC,TierId;
SELECT * FROM MatchingScore
WHERE TierId=16 ORDER BY MatchProzent DESC,InteressentId;

-- Einzelbeiträge zur Prüfung.
SELECT k.*,g.Gewicht,ROUND(100*k.Passung,1) AS PassungProzent,
       k.Passung*g.Gewicht AS GewichtetePunkte
FROM MatchingKriterien k
LEFT JOIN MatchingGewichtung g ON g.Kriterium=k.Kriterium
WHERE k.InteressentId=17 ORDER BY k.TierId,k.Kriterium;

-- Soll: keine Zeilen. Alle neun Gewichte müssen vorhanden sein.
SELECT COUNT(*) AS AnzahlGewichte FROM MatchingGewichtung HAVING COUNT(*)<>9;
-- Soll: keine Zeilen. Jede Kombination hat genau neun Kriterien.
SELECT TierId,InteressentId FROM MatchingKriterien
GROUP BY TierId,InteressentId
HAVING COUNT(*)<>9 OR COUNT(DISTINCT Kriterium)<>9;
-- Soll: keine Zeilen. Bekannte Teilwerte liegen zwischen 0 und 1.
SELECT * FROM MatchingKriterien WHERE Passung<0 OR Passung>1;
-- Soll: keine Zeilen. Status und Score sind konsistent.
SELECT * FROM MatchingScore
WHERE (Eignung='ausgeschlossen' AND (MatchProzent IS NULL OR MatchProzent<>0))
 OR (Eignung='pruefung_offen' AND MatchProzent IS NOT NULL)
 OR (Eignung='geeignet' AND GewichtungVollstaendig=1 AND MatchProzent IS NULL)
 OR MatchProzent<0 OR MatchProzent>100
 OR DatenabdeckungProzent<0 OR DatenabdeckungProzent>100;
