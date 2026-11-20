# Paws Match – SQL

Die Dateien sind in der angegebenen Reihenfolge auszufuehren.

## Ausfuehrungsreihenfolge

1. `sql/01_grundlage/01_datenbank_anlegen.sql`
2. `sql/01_grundlage/02_tabellen_anlegen.sql`
3. `sql/01_grundlage/03_stammdaten_anlegen.sql`
4. `sql/02_profil_ergaenzungen/01_tierprofile_ergaenzen.sql`
5. `sql/02_profil_ergaenzungen/02_interessentenprofile_ergaenzen.sql`
6. `sql/03_demo_daten/01_demo_profile.sql`
7. `sql/04_matching/01_matching_voraussetzungen.sql`
8. `sql/04_matching/02_matching_entscheidung.sql`
9. `sql/04_matching/03_matching_score.sql`
10. `sql/05_prozeduren/01_tier_vorschlaege.sql`
11. `sql/05_prozeduren/02_interessenten_vorschlaege.sql`
12. `sql/06_ausgabe/01_matching_ausgabe.sql`
13. `sql/07_tests/01_matching_tests.sql`
14. `sql/07_tests/02_vorschlagsprozeduren_tests.sql`

## Hinweise

- MySQL 8.0.16 oder neuer wird vorausgesetzt.
- Die Skripte wurden auf GitHub gespeichert, aber noch nicht in MySQL ausgefuehrt.
- Schemaaenderungen sind nicht als Ganzes rueckrollbar.
- Die Prozeduren ersetzen gleichnamige bestehende Prozeduren.
- `main` bleibt unveraendert; alle Aenderungen liegen auf `MatchingErweiterungen`.
