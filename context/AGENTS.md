# AGENTS.md – Developer handover

Audience: coding agents and new contributors working in this repo.
Human-facing documentation: [../README.md](../README.md). Install order: [../paws_and_match/README.md](../paws_and_match/README.md).

## 1. What we are building

**Paws & Match** is a university database project (HWR, course "Datenbanken"): a MySQL
database for Berlin animal shelters that matches shelter animals (`tier`) with adopters
(`interessent`) and supports the adoption process (watchlist -> application -> appointment
-> placement).

Goals:
- Clean relational model (3NF, junction tables for n:m, FKs, CHECK constraints).
- Explainable matching: hard exclusion rules with reasons + a graded 0-100 score.
- Everything in plain SQL (views, procedures, triggers), no application layer.
- Reproducible: one install sequence on an empty server, self-checking tests.
- Presentable: the team will build a presentation from `README.md`.

## 2. Hard constraints and conventions

- **Target:** MySQL >= 8.0.16 (CHECK, CTE, JSON_TABLE). Verified on **MySQL 8.4.13** only.
- **Language:** identifiers, comments, messages in German **without umlauts**
  (`ae/oe/ue/ss`), e.g. `beduerfnis`, `groesse`. Keep SQL files ASCII, except
  `01_grundlage/02_orte_anlegen.sql` (official place names) and `07_tests/01_orts_tests.sql`
  (umlaut test cases); those are UTF-8 and must be executed as UTF-8.
- **Collation:** database uses `utf8mb4_0900_ai_ci` (MySQL 8 client default). String literals
  inside routines get the creating session's collation; `COALESCE(fn_x(...), '')` produced
  `utf8mb4_bin/NONE` and error 1267 in `REGEXP_REPLACE` – assign function results to a
  variable first and do not add `COLLATE` clauses.
- **Naming:** tables singular snake_case; constraints `fk_<table>_<ref>`, `ck_<table>_<rule>`,
  `uq_<...>`; procedures `sp_...`; functions `fn_...`; triggers `trg_...`; test helpers `test_...`.
- **Booleans:** `BOOLEAN` + `CHECK (col IN (0, 1))`. Logic compares with `= 1` / `= 0`;
  `NULL` means "unknown" and is handled explicitly.
- **Files** are numbered and executed in the exact order listed in
  `paws_and_match/README.md`, in **one session** (Workbench or `mysql` CLI). If you add or
  rename a file, update that list (the verification step parses it).
- **Idempotency:** step 1 runs `DROP DATABASE IF EXISTS paws_match` (full reinstall).
  Views: `CREATE OR REPLACE VIEW`. Procedures: `DROP PROCEDURE IF EXISTS` first.
  Tables use plain `CREATE TABLE` (fresh DB guaranteed by step 1).
- Procedures/triggers use `DELIMITER $$ ... $$` and end with `DELIMITER ;`.
- Comments: one short line, only for what the code cannot say.
- Do not add a separate application layer, ORMs or non-SQL tooling unless asked.

## 3. Repository layout

```
README.md                         human documentation (tables, algorithm, presentation material)
context/AGENTS.md                 this file
paws_and_match/README.md          install order + short technical notes
paws_and_match/01_grundlage/      DB, location model (bundesland/ort/bezirk + detection functions),
                                  17 base tables, 2 triggers, master data
paws_and_match/02_profil_ergaenzungen/  profile extensions (9 tables + ALTER tier/interessent)
paws_and_match/03_demo_daten/     fictional demo data (20 animals, 20 adopters)
paws_and_match/04_matching/       views: matching_entscheidung, matching_kriterien,
                                  matching_score, matching_vorschlaege (+ table matching_gewichtung)
paws_and_match/05_prozeduren/     one file per procedure, named after it: 01 sp_vorschlaege_fuer_interessent,
                                  02 sp_vorschlaege_fuer_tier, 03 sp_vermitteln, 04 sp_interessent_loeschen
paws_and_match/06_ausgabe/        demo output for adopter 17 with suggestion status
paws_and_match/07_tests/          self-asserting tests in build order: 01 location (50), 02 matching (30),
                                  03 procedures (43)
```

Database objects after install: **32 tables, 6 views, 4 procedures, 4 functions, 6 triggers**.

## 4. Matching pipeline (source of truth = SQL files)

1. `matching_entscheidung` ([01_matching_entscheidung.sql](../paws_and_match/04_matching/01_matching_entscheidung.sql)):
   every animal x every adopter (CROSS JOIN). 19 hard criteria, each evaluated to
   `0 = erfuellt`, `1 = pruefung_offen` (data missing/unconfirmed), `2 = ausgeschlossen`.
   Built with `JSON_TABLE` so each criterion is a row; `MAX(ergebnis)` gives `eignung`.
   Reasons are aggregated with `GROUP_CONCAT` (`ausschlussgruende`, `offene_pruefungen`).
   Set `group_concat_max_len = 65535` in sessions that read the reasons.
2. `matching_kriterien` ([02_matching_score.sql](../paws_and_match/04_matching/02_matching_score.sql)):
   9 weighted categories, each `passung` in [0, 1] or `NULL` (no data). Independent of
   step 1 (computed from base data). Key formula ("reserve"):
   `requirement met exactly = 0.5`, `>= 2x requirement = 1.0`, below requirement = 0.
3. `matching_score`: `match_prozent = ROUND(SUM(passung * gewicht), 1)` with weights summing
   to 100; `ausgeschlossen -> 0`, `pruefung_offen -> NULL`, invalid weights -> `NULL`.
   Missing categories give 0 points; `datenabdeckung_prozent` = weight share with data.
4. `matching_vorschlaege` ([03_matching_vorschlaege.sql](../paws_and_match/04_matching/03_matching_vorschlaege.sql)):
   **single source** for suggestions: `geeignet` AND tier `verfuegbar` AND adopter `aktiv`
   AND weights valid AND score `>= 50.0` (constant in the view). Procedures and output read
   only from here – never duplicate these rules elsewhere.

Special need IDs used in logic (`beduerfnis.id`): `1` medication -> medical need,
`2` secured balcony -> balcony check, `4` training -> training check. Every need of an animal
must be confirmed by the adopter (`interessent_beduerfnis.bestaetigt = 1`), otherwise
`pruefung_offen`; `bestaetigt = 0` -> `ausgeschlossen`.

## 4a. Location model and detection ([02_orte_anlegen.sql](../paws_and_match/01_grundlage/02_orte_anlegen.sql))

- `bundesland` (id = official Laenderschluessel) -> `ort` (AGS, `aktiv` flag) -> `bezirk`
  (smallest selectable unit; Berlin: id/schluessel = Bezirksnummer 1-12) + `bezirk_alias`
  (92 rows: Ortsteile not named like their district + former districts Hohenschoenhausen,
  Treptow; together with district names all 96 Ortsteile resolve). `suchname` is filled by triggers via `fn_text_normalisieren`;
  `UNIQUE (ort_id, suchname)` blocks duplicate spellings.
- `standort.bezirk_id` NOT NULL, `interessent.bezirk_id` required while `aktiv = 1`
  (anonymised profiles: NULL). Matching category Naehe compares `bezirk_id`.
- Dropdown: view `bezirk_auswahl` (only `ort.aktiv = 1`, currently Berlin only).
- Free text: `fn_bezirk_id(text, ort_id_or_NULL)` = normalise (lower, umlauts, strip non
  a-z0-9, leading "bezirk") -> exact match in view `bezirk_suchbegriff` (names, aliases, with
  town name as prefix/suffix) -> Levenshtein fallback (max distance 1 for 4-5 chars, 2 for >= 6,
  best match must be unique) -> else NULL. `fn_bezirk_id_pflicht(text)` raises SQLSTATE 45000.
- Germany later: insert `ort` (+ AGS) and `bezirk` rows, set `aktiv = 1`; towns without
  districts get one `bezirk` named like the town. Pass `ort_id` to avoid ambiguity.

## 5. Business invariants (do not break)

- Placement only via `sp_vermitteln` (trigger `trg_vermittlung_pruefen` blocks direct inserts).
  It locks tier then application (same order as `trg_bewerbung_pruefen`), checks employee
  belongs to the animal's location, adopter active, statuses; sets `vermittelt`, marks
  application `angenommen`, auto-rejects competing open applications with a note.
- Applications only for available animals and active adopters (`trg_bewerbung_pruefen`).
- At most one active placement per animal (generated column `aktives_tier` + UNIQUE).
- History tables (`bewerbung`, `termin`, `vermittlung`) have **no** cascade; profile/junction
  tables cascade on delete of `tier`/`interessent`.
- Deleting an adopter: `sp_interessent_loeschen(id, @out)` -> `'geloescht'` (no history) or
  `'anonymisiert'` (history kept, personal data nulled, open applications withdrawn).
- Weights: exactly 9 rows, each > 0, sum = 100 (checked in views and procedures).

## 6. Tests and their expectations

- [01_orts_tests.sql](../paws_and_match/07_tests/01_orts_tests.sql) (50 tests),
  [02_matching_tests.sql](../paws_and_match/07_tests/02_matching_tests.sql) (30 tests) and
  [03_prozedur_tests.sql](../paws_and_match/07_tests/03_prozedur_tests.sql) (43 tests).
- Pattern: results go into a `TEMPORARY ... ENGINE = MEMORY` table (survives `ROLLBACK`);
  scenario changes run in `START TRANSACTION ... ROLLBACK`; expected errors are captured by
  helper `test_erwarte_fehler(name, sql, message_substring)` via `PREPARE/EXECUTE` and a
  `CONTINUE HANDLER`. Fixtures use IDs `>= 9001` and are removed; a fingerprint asserts the
  demo data is unchanged. Final row: `ALLE ... TESTS BESTANDEN`.
- `sp_vermitteln` and `sp_interessent_loeschen` COMMIT internally – never call them inside a
  test transaction you want to roll back; use fixtures instead.
- Tests assert concrete demo results. **If you change demo data or formulas, update tests:**
  - scores: adopter 1/animal 1 = 96.0, adopter 17/animal 16 = 80.2, adopter 17/animal 8 = 76.9,
    boundary scenario = 57.5, without character wishes = 77.7 (coverage 95.0)
  - suggestions adopter 17 in rank order = `6,11,16,8,13`; animal 16 -> `17`
  - demo totals: 400 pairs = 42 geeignet / 30 pruefung_offen / 328 ausgeschlossen; 42 suggestions
  - age-based sub-score uses `CURDATE()`; demo age wishes are wide so results stay stable.
  - demo districts are given in varied spellings and must resolve: profiles 7/9/13/16/19 ->
    Pankow/Neukoelln/Spandau/Mitte/Neukoelln; 12 Berlin districts, 16 Bundeslaender.

## 7. Running locally (Windows, as used in this project)

A portable MySQL 8.4.13 lives in `%LOCALAPPDATA%\paws_mysql_test` (not in the repo):
`my.ini` = port 3399, bind 127.0.0.1, root without password (local test only).

```powershell
# start server (keep running in its own terminal)
& "$env:LOCALAPPDATA\paws_mysql_test\mysql-8.4.13-winx64\bin\mysqld.exe" --defaults-file="$env:LOCALAPPDATA\paws_mysql_test\my.ini" --console
# run one script (cmd redirect avoids PowerShell quoting/encoding problems)
$m = "$env:LOCALAPPDATA\paws_mysql_test\mysql-8.4.13-winx64\bin\mysql.exe"
cmd /c "`"$m`" -uroot -h127.0.0.1 -P3399 --default-character-set=utf8mb4 --table < `"paws_and_match\07_tests\02_matching_tests.sql`""
```

Gotchas: PowerShell execution policy blocks `.ps1` files (define functions inline, do not
bypass the policy); `mysql -e "..."` gets mangled by PowerShell 5.1 quoting – use files.
If the folder is missing: download the MySQL 8.4 ZIP from dev.mysql.com, verify MD5,
`mysqld --initialize-insecure`, start as above.

Full verification = run all 18 files in README order on the server, twice in a row
(idempotency), then the three test files again (re-run safety). Expect zero `ERROR` lines.

## 8. Change log (2026-11-22)

Starting point: `e5aa3a3` (= `origin/MatchingErweiterungen`). The old monolithic script
`context/Paws and Match.sql` from `93e2c84` was replaced by the numbered files in
`paws_and_match/`. The changes below were committed on top of `e5aa3a3` and `main` was
fast-forwarded to it; `origin/MatchingErweiterungen` still points to `e5aa3a3`.

Analysis found (all fixed and verified on MySQL 8.4.13):

| # | Problem | Fix |
|---|---|---|
| 1 | Commit `4621909` deleted all 17 base tables from `02_tabellen_anlegen.sql` (plus `DELIMITER $$` and `trg_bewerbung_pruefen`) – install failed at script 2 | Restored tables + trigger + delimiter |
| 2 | `sp_vermitteln` left competing applications open, no employee/location or active check, unused variable | Rewritten (checks, lock order, auto-reject with note) |
| 3 | View `matching_zusatzpruefung` duplicated logic and was unused | Removed; `kleintiere_ok` moved to `02_profil_ergaenzungen/01_tierprofile_ergaenzen.sql` |
| 4 | Training criterion returned `pruefung_offen` even when adopter was willing | Fixed CASE |
| 5 | 6 of 9 score categories were just copies of "geeignet" (binary) | Graded per-category formulas |
| 6 | Score used artificial base `70 + points` (min ~41 %) | Removed; score = weighted sum |
| 7 | Coverage only measured presence; implausible values possible | CHECKs for booleans, e-mail, 24-h rule; missing data = 0 points |
| 8 | Scripts not repeatable (duplicate keys) | `DROP DATABASE` in step 1, `CREATE OR REPLACE VIEW` |
| 9 | Demo data left all new profile fields empty -> every pair `pruefung_offen`, **zero suggestions** | Demo data completed with deliberate positive/negative cases |
| 10 | Suggestion rules duplicated in 2 procedures + output + tests | New view `matching_vorschlaege` as single source; procedures simplified (no session-variable juggling) |
| 11 | Tests were manual (no assertions, error cases commented out) | Self-asserting tests incl. negative cases, fixtures, fingerprint |
| 12 | No deletion strategy | Cascades on dependent tables, history protected, `sp_interessent_loeschen` |
| 13 | Weight sum not validated | Must be exactly 100 (views + procedures) |
| 14 | `06_ausgabe` could truncate reasons (GROUP_CONCAT 1024) | Sets `group_concat_max_len` |

File moves: `04_matching/02_matching_entscheidung.sql -> 01_...`, `03_matching_score.sql -> 02_...`,
`07_tests/02_vorschlagsprozeduren_tests.sql -> 02_prozedur_tests.sql`; deleted
`04_matching/01_matching_voraussetzungen.sql`; new `04_matching/03_matching_vorschlaege.sql`,
`05_prozeduren/03_interessent_loeschen.sql`.

Follow-up (location model, requested to prepare real data imports):

| # | Problem | Fix |
|---|---|---|
| 15 | `bezirk` was free text: spelling variants (umlaut vs `oe`, typos like "Neukoeln") break Naehe and imports | Lookup tables `bundesland`/`ort`/`bezirk`/`bezirk_alias`, FKs from `standort`/`interessent`, dropdown view |
| 16 | No way to map external free text to districts | `fn_text_normalisieren`, `fn_levenshtein`, `fn_bezirk_id`, `fn_bezirk_id_pflicht`; demo data uses varied spellings |
| 17 | DB collation `utf8mb4_unicode_ci` clashed with client default in function comparisons | DB collation `utf8mb4_0900_ai_ci` |

File moves: `01_grundlage/02_tabellen_anlegen.sql -> 03_...`, `03_stammdaten_anlegen.sql -> 04_...`;
new `01_grundlage/02_orte_anlegen.sql`, `07_tests/03_orts_tests.sql`.

Cleanup (numbering follows build order, comments/docs reworded in plain language):
- `sp_vermitteln` moved from `01_grundlage/03_tabellen_anlegen.sql` to `05_prozeduren/03_vermitteln.sql`
- `05_prozeduren`: `01_tier_vorschlaege -> 01_vorschlaege_fuer_interessent`,
  `02_interessenten_vorschlaege -> 02_vorschlaege_fuer_tier`, `03_interessent_loeschen -> 04_...`
- `07_tests`: `03_orts_tests -> 01_...`, `01_matching_tests -> 02_...`, `02_prozedur_tests -> 03_...`
- every SQL file starts with a one-line description comment; README files have no emojis

## 9. Known gaps / ideas (not implemented, ask before doing)

- Stored but not used by matching: `tier_gesundheit`, `tier_rasse` (no demo rows),
  `interessent.erfahrung` (general experience), `wohnform_id`, `haushaltsgroesse`,
  `arbeitsmodell_id`, `foto_url`, `gewicht_kg`.
- Garden and stairs are only hard criteria (no score contribution).
- Minimum score 50 is a constant in `matching_vorschlaege` (no settings table).
- No flow for ending a placement (`beendet_am`) and returning the animal to `verfuegbar`.
- Status `reserviert` is not linked to a specific application.
- `termin` does not check that the employee works at the animal's location.
- Compatibility with MySQL 8.0.16-8.3 not tested (only 8.4.13).
- Performance: views CROSS JOIN all animals x adopters – fine for demo size, not for large data.
- Naehe only knows same/different district (no distance); `ort.aktiv` controls dropdown and
  detection but is not enforced on FKs; fuzzy detection scans all active candidates (pass
  `ort_id` once many towns are loaded). Germany data (AGS directory, postcodes) not loaded yet.

## 10. Rules for agents

1. Read the relevant SQL file before editing; the SQL is the source of truth, docs follow.
2. Keep the matching pipeline layering (decision -> criteria -> score -> suggestions).
3. After any change: full reinstall + all three test files must end with `... BESTANDEN`.
4. Update `README.md` (human) and this file when behaviour, tables or numbers change.
5. Never commit, push, rewrite history or drop non-test databases without user approval.
