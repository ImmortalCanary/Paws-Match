# Paws & Match: Benutzungsoberfläche

Eine Streamlit-Anwendung auf der Datenbank `paws_match`. Sie ist bewusst eine **dünne
Schicht**: Das Matching, der Vermittlungsprozess und alle Prüfungen bleiben in der Datenbank
(Views, Prozeduren, Trigger, CHECK-Constraints). Die Oberfläche liest aus den Views, ruft die
Prozeduren auf und zeigt deren Meldungen an.

## Starten

```bash
# einmalig: Umgebung anlegen und Pakete installieren
python -m venv .venv
.venv/Scripts/python.exe -m pip install -r ui/requirements.txt

# einmalig: Zugangsdaten eintragen
cp ui/.env.example ui/.env        # Host, Port, Benutzer, Passwort anpassen

# starten (aus dem Projektordner)
.venv/Scripts/python.exe -m streamlit run ui/app.py
```

Die App öffnet sich unter <http://localhost:8501>.

**Voraussetzung:** Die Datenbank ist installiert (die 21 Skripte aus
[../paws_and_match/README.md](../paws_and_match/README.md)) **und** danach einmal
`../paws_and_match/08_oberflaeche/01_benutzerkonten.sql` (Schritt 22, legt die Anmeldekonten
an). Skript 1 löscht die Datenbank komplett – nach jeder Neuinstallation muss Schritt 22
deshalb erneut laufen.

## Rollen

| Rolle | Zugang | Sieht |
|---|---|---|
| Besucher | kein Login | Startseite, Tiergalerie |
| Interessent | E-Mail-Adresse, kein Passwort | zusätzlich Profil, Matches mit Begründung, eigene Bewerbungen |
| Mitarbeitende | E-Mail + Passwort | interne Übersicht, Tiere verwalten, Bewerbungen und Vermittlung – **keine** Adminsicht |
| Administration | E-Mail + Passwort | alles, zusätzlich Gewichte, Mindestscore, Auswertung, Konten |

Demokonten (nur lokal): `team1@example.org` … `team5@example.org` und `admin@example.org`,
Passwort jeweils `paws2026`. Interessentenprofile aus den Demodaten findet man über
`profil1@example.org` … `profil20@example.org`.

## Aufbau

| Datei | Aufgabe |
|---|---|
| `app.py` | Einstieg, Navigation, Seitenleiste; blendet je Rolle nur die erlaubten Seiten ein |
| `db.py` | Verbindung (Pool), Abfragen, Prozeduraufrufe, Übersetzung der MySQL-Fehler in verständliche Sätze |
| `queries.py` | **alle** SQL-Anweisungen der Oberfläche an einer Stelle |
| `auth.py` | Anmeldung (bcrypt), Rollenprüfung `darf()` und `require()` |
| `labels.py` | ASCII-Bezeichner der Datenbank → Anzeigetext mit Umlauten |
| `bausteine.py` | Tierkarten, Score-Anzeige, Begründungsbalken, Tabellen, CSS |
| `formulare.py` | Eingabebausteine; „Keine Angabe“ wird als NULL gespeichert |
| `seiten/` | eine Datei je Seite mit einer Funktion `zeige()` |
| `tests/` | pytest gegen die laufende Datenbank |

## Grundsätze

- **Keine Logik doppelt.** Vorschläge kommen aus `matching_vorschlaege` bzw.
  `sp_vorschlaege_fuer_interessent` / `sp_vorschlaege_fuer_tier`. Statuswechsel laufen
  ausschließlich über `sp_reservieren`, `sp_reservierung_aufheben`, `sp_vermitteln`,
  `sp_vermittlung_beenden`, `sp_interessent_loeschen`.
- **Fehlende Angaben bleiben NULL.** Nur so kann die Datenbank „Prüfung offen“ von
  „ausgeschlossen“ unterscheiden. Alle Ja/Nein-Felder haben deshalb eine dritte Möglichkeit.
- **Fehlermeldungen kommen aus der Datenbank.** Was eine Prozedur per `SIGNAL` meldet, wird
  unverändert angezeigt; CHECK- und Schlüsselverletzungen werden in einen Satz übersetzt
  (`db.verstaendlicher_fehler`).
- **Umlaute nur in der Oberfläche.** Die SQL-Dateien bleiben bei der Konvention `ae/oe/ue/ss`.

## Tests

```bash
.venv/Scripts/python.exe -m pytest ui/tests -q
```

| Datei | Prüft |
|---|---|
| `test_lesen.py` | Prozedur und View liefern dasselbe, Score = Summe der gewichteten Teilpassungen, Begründungen werden nicht abgeschnitten |
| `test_schreiben.py` | Profil anlegen/ändern/löschen, CHECK-Constraints, doppelte E-Mail, Bewerbung auf nicht verfügbares Tier |
| `test_prozess.py` | reservieren → vermitteln → beenden, fremder Standort wird abgelehnt, Vermittlung von Hand blockiert |
| `test_rollen.py` | Zugriffsmatrix aller Rollen, Anmeldung mit/ohne richtiges Passwort |
| `test_seiten.py` | jede Seite läuft fehlerfrei; fremde Rollen werden abgewiesen |
| `test_ablauf.py` | Klickpfade: Anmeldung, Galerie-Filter, Weg zum Fragebogen |

Die Tests legen eigene Daten ab ID 9001 an und räumen sie wieder weg; die Demodaten bleiben
unverändert. Ohne laufende Datenbank oder ohne Demodaten überspringen sie sich selbst.
