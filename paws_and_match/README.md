# Paws Match – SQL

Die Dateien sind in der angegebenen Reihenfolge in **einer** Sitzung auszufuehren.

## Ausfuehrungsreihenfolge

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
11. `paws_and_match/05_prozeduren/01_tier_vorschlaege.sql`
12. `paws_and_match/05_prozeduren/02_interessenten_vorschlaege.sql`
13. `paws_and_match/05_prozeduren/03_interessent_loeschen.sql`
14. `paws_and_match/06_ausgabe/01_matching_ausgabe.sql`
15. `paws_and_match/07_tests/01_matching_tests.sql`
16. `paws_and_match/07_tests/02_prozedur_tests.sql`
17. `paws_and_match/07_tests/03_orts_tests.sql`

## Hinweise

- MySQL 8.0.16 oder neuer wird vorausgesetzt (CHECK-Constraints, CTEs, JSON_TABLE).
- Getestet mit MySQL Community Server 8.4.13: Neuinstallation, Wiederholung der
  Installation und alle Testskripte laufen fehlerfrei (30 + 43 + 50 Tests bestanden).
- Die Dateien muessen als UTF-8 ausgefuehrt werden (amtliche Ortsnamen mit Umlauten).
- Schritt 1 entfernt eine vorhandene Datenbank `paws_match` vollstaendig. Dadurch ist die
  Installation beliebig wiederholbar; bestehende Daten in `paws_match` gehen dabei verloren.
- Views werden mit `CREATE OR REPLACE`, Prozeduren nach `DROP ... IF EXISTS` angelegt.

## Datenmodell

- Organisation: `tierheim`, `standort`, `mitarbeiter`
- Orte: `bundesland` -> `ort` -> `bezirk` (+ `bezirk_alias` fuer Ortsteile); Standorte und
  Interessenten verweisen per Fremdschluessel auf einen Bezirk (Dropdown: View
  `bezirk_auswahl`, freigeschaltet ist vorerst nur Berlin).
- Profile: `tier`, `interessent` mit Ergaenzungen (Rasse, Groesse, Pflegeaufwand,
  Gesundheit, Wohnform, Arbeitsmodell, Wunschgroesse, Wunschstandort, Tiererfahrung)
- Prozess: `merkliste`, `bewerbung`, `termin`, `vermittlung`
- Plausibilitaet: CHECK-Constraints fuer Wertebereiche, Wahrheitswerte, E-Mail-Format
  und Tagesstunden (Betreuungs- plus Alleinzeit hoechstens 24 h).

## Matching

1. `matching_entscheidung`: harte Kriterien je Tier-Interessent-Paar mit Ergebnis
   `geeignet`, `pruefung_offen` (Angaben fehlen) oder `ausgeschlossen` samt Begruendung.
2. `matching_kriterien`: neun Kategorien mit Teilpassung 0..1 (NULL = keine Daten).
   Mindestanforderung erfuellt = 0,5; Reserve bis zum Doppelten der Anforderung = bis 1,0.
   - Tierart: Tierartwunsch, Wunschgroesse, Wunschalter
   - Aktivitaet: Abstand der Aktivitaetsstufen
   - Zeit: Betreuungszeit- und Alleinzeitreserve
   - Wohnsituation: Wohnflaechenreserve
   - Erfahrung: tierartspezifische Erfahrung ueber dem Minimum
   - Vertraeglichkeit: Kinder, Hunde, Katzen, Kleintiere (unvertraeglich, aber nicht
     vorhanden = 0,5)
   - Budget: Budgetreserve
   - Charakter: Anteil getroffener Charakterwuensche
   - Naehe: Wunschstandort oder gleicher Bezirk
3. `matching_score`: `match_prozent` = Summe(Teilpassung x Gewicht); Gewichte muessen
   vollstaendig sein und 100 ergeben. Fehlende Kategorien erhalten 0 Punkte,
   `datenabdeckung_prozent` zeigt den erfassten Gewichtsanteil.
4. `matching_vorschlaege`: einzige Quelle fuer Vorschlaege (geeignet, Tier verfuegbar,
   Profil aktiv, Gewichtung gueltig, Score mindestens 50). Die Prozeduren
   `sp_vorschlaege_fuer_interessent` und `sp_vorschlaege_fuer_tier` lesen daraus.

## Bezirkserkennung (Freitext, z. B. bei Importen)

- `fn_bezirk_id(text, ort_id)` liefert die Bezirk-ID oder NULL (unbekannt/mehrdeutig):
  Schreibweise vereinheitlichen (Gross/klein, Umlaute, Sonderzeichen), exakt in Bezirken
  und Ortsteilen suchen, danach Tippfehler bis Distanz 1 (4-5 Zeichen) bzw. 2 tolerieren.
- `fn_bezirk_id_pflicht(text)` bricht bei unbekanntem Bezirk mit Meldung ab.
- Erweiterung: Zeilen in `ort`/`bezirk` ergaenzen und `ort.aktiv = 1` setzen.

## Vermittlung und Loeschung

- `sp_vermitteln(bewerbung, mitarbeiter)`: prueft Standort, aktives Profil und Status,
  vermittelt transaktional und lehnt konkurrierende offene Bewerbungen automatisch ab.
  Direkte Inserts in `vermittlung` und Bewerbungen auf nicht verfuegbare Tiere werden
  durch Trigger verhindert.
- `sp_interessent_loeschen(id, @ergebnis)`: ohne Bewerbungshistorie wird das Profil
  geloescht (abhaengige Profildaten per Cascade), mit Historie werden Personendaten
  anonymisiert und offene Bewerbungen zurueckgezogen.
- Bewerbungen, Termine und Vermittlungen sind Historie und blockieren das Loeschen
  von Tieren und Interessenten.

## Tests

Alle drei Testskripte pruefen automatisch und enden mit einer Zusammenfassung
(`ALLE ... TESTS BESTANDEN`). Aenderungen laufen in zurueckgerollten Transaktionen bzw.
mit Testdaten ab ID 9001, die am Ende entfernt werden; die Demodaten bleiben unveraendert.
