# Paws & Match: SQL-Skripte

Die Skripte muessen genau in dieser Reihenfolge und in **einer** Sitzung laufen
(MySQL Workbench oder `mysql`-Konsole).

## Reihenfolge

1. `paws_and_match/01_grundlage/01_datenbank_anlegen.sql`
2. `paws_and_match/01_grundlage/02_orte_anlegen.sql`
3. `paws_and_match/01_grundlage/03_tabellen_anlegen.sql`
4. `paws_and_match/01_grundlage/04_stammdaten_anlegen.sql`
5. `paws_and_match/02_profil_ergaenzungen/01_tierprofile_ergaenzen.sql`
6. `paws_and_match/02_profil_ergaenzungen/02_interessentenprofile_ergaenzen.sql`
7. `paws_and_match/03_demo_daten/01_demo_profile.sql`
8. `paws_and_match/04_matching/01_matching_entscheidung.sql`
9. `paws_and_match/04_matching/02_matching_score.sql`
10. `paws_and_match/04_matching/03_matching_vorschlaege.sql`
11. `paws_and_match/05_prozeduren/01_vorschlaege_fuer_interessent.sql`
12. `paws_and_match/05_prozeduren/02_vorschlaege_fuer_tier.sql`
13. `paws_and_match/05_prozeduren/03_vermitteln.sql`
14. `paws_and_match/05_prozeduren/04_interessent_loeschen.sql`
15. `paws_and_match/06_ausgabe/01_matching_ausgabe.sql`
16. `paws_and_match/07_tests/01_orts_tests.sql`
17. `paws_and_match/07_tests/02_matching_tests.sql`
18. `paws_and_match/07_tests/03_prozedur_tests.sql`

## Gut zu wissen

- Man braucht MySQL 8.0.16 oder neuer (wegen CHECK-Constraints, CTEs und JSON_TABLE).
  Wir haben alles mit MySQL 8.4.13 getestet: Installation zweimal hintereinander,
  danach alle Tests (50 + 30 + 43 bestanden).
- Bitte als UTF-8 ausfuehren, die Ortsnamen enthalten Umlaute.
- Schritt 1 loescht eine vorhandene Datenbank `paws_match` komplett. Dadurch kann man die
  Installation beliebig oft wiederholen, alte Daten sind dann aber weg.
- Views werden mit `CREATE OR REPLACE` angelegt, Prozeduren vorher mit `DROP ... IF EXISTS` entfernt.

## Datenmodell kurz

- Organisation: `tierheim`, `standort`, `mitarbeiter`
- Orte: `bundesland` > `ort` > `bezirk`, dazu `bezirk_alias` fuer Ortsteile. Standorte und
  Interessenten zeigen per Fremdschluessel auf einen Bezirk. Das Dropdown liefert die View
  `bezirk_auswahl`, im Moment nur mit Berlin.
- Profile: `tier` und `interessent` mit Ergaenzungen (Rasse, Groesse, Pflegeaufwand,
  Gesundheit, Wohnform, Arbeitsmodell, Wunschgroesse, Wunschstandort, Tiererfahrung)
- Ablauf: `merkliste`, `bewerbung`, `termin`, `vermittlung`
- CHECK-Constraints sorgen fuer gueltige Werte (Wertebereiche, Ja/Nein-Felder, E-Mail-Format,
  Betreuungszeit plus Alleinzeit hoechstens 24 Stunden).

## Matching kurz

1. `matching_entscheidung`: harte Kriterien fuer jedes Paar aus Tier und Interessent.
   Ergebnis ist `geeignet`, `pruefung_offen` (Angaben fehlen) oder `ausgeschlossen`, jeweils mit Grund.
2. `matching_kriterien`: neun Kategorien, jede mit einem Wert von 0 bis 1 (NULL = keine Daten).
   Wer die Mindestanforderung genau erfuellt, bekommt 0,5, wer doppelt so viel bietet, 1,0.
   - Tierart: Tierartwunsch, Wunschgroesse, Wunschalter
   - Aktivitaet: wie weit die Aktivitaetsstufen auseinanderliegen
   - Zeit: Reserve bei Betreuungszeit und Alleinzeit
   - Wohnsituation: Reserve bei der Wohnflaeche
   - Erfahrung: Erfahrung mit der Tierart ueber dem Minimum
   - Vertraeglichkeit: Kinder, Hunde, Katzen, Kleintiere (unvertraeglich, aber nicht im
     Haushalt = 0,5)
   - Budget: Reserve beim Budget
   - Charakter: Anteil der gewuenschten Charakterzuege, die das Tier hat
   - Naehe: Wunschstandort oder gleicher Bezirk
3. `matching_score`: `match_prozent` = Summe aus Wert mal Gewicht. Die Gewichte muessen
   vollstaendig sein und zusammen 100 ergeben. Fehlende Kategorien geben 0 Punkte,
   `datenabdeckung_prozent` zeigt, wie viel vom Gewicht echte Daten hat.
4. `matching_vorschlaege`: hier stehen die Regeln fuer Vorschlaege (geeignet, Tier verfuegbar,
   Profil aktiv, Gewichtung in Ordnung, Score mindestens 50). Die Prozeduren
   `sp_vorschlaege_fuer_interessent` und `sp_vorschlaege_fuer_tier` lesen nur daraus.

## Bezirke aus Freitext erkennen (z. B. fuer Importe)

- `fn_bezirk_id(text, ort_id)` gibt die Bezirk-ID zurueck oder NULL, wenn nichts oder
  mehreres passt. Dafuer wird die Schreibweise vereinheitlicht (Gross/klein, Umlaute,
  Sonderzeichen), dann exakt in Bezirken und Ortsteilen gesucht und zum Schluss mit
  Tippfehlern (1 Fehler bei 4-5 Buchstaben, sonst 2).
- `fn_bezirk_id_pflicht(text)` macht dasselbe, gibt aber einen Fehler aus statt NULL.
- Neue Orte: Zeilen in `ort` und `bezirk` eintragen und `ort.aktiv = 1` setzen.

## Vermitteln und Loeschen

- `sp_vermitteln(bewerbung, mitarbeiter)` prueft Standort, aktives Profil und Status,
  vermittelt alles in einer Transaktion und lehnt andere offene Bewerbungen fuer das Tier ab.
  Direkt in `vermittlung` schreiben oder sich auf ein nicht verfuegbares Tier bewerben
  verhindern Trigger.
- `sp_interessent_loeschen(id, @ergebnis)`: ohne Bewerbungen wird das Profil geloescht
  (Wuensche usw. per Cascade), mit Bewerbungen werden nur die persoenlichen Daten entfernt
  und offene Bewerbungen zurueckgezogen.
- Bewerbungen, Termine und Vermittlungen sind Historie. Tiere oder Interessenten mit
  Historie lassen sich deshalb nicht loeschen.

## Tests

Die drei Testskripte pruefen sich selbst und zeigen am Ende eine Zusammenfassung
(`ALLE ... TESTS BESTANDEN`). Aenderungen laufen in Transaktionen, die zurueckgerollt werden,
oder mit eigenen Testdaten ab ID 9001, die am Ende wieder geloescht werden. Die Demodaten
bleiben also gleich.
