"""US06: systematische Pruefung, dass Katalogtexte und Fehlermeldungen keine ASCII-Umlaut-
Reste mehr enthalten, nachdem sie durch labels.mit_umlauten gelaufen sind.

Woerter, die *zufaellig* ein ae/oe/ue/ss-Muster enthalten, ohne ein verstecktes ae/oe/ue/ss
zu sein (z. B. 'dass', 'muss', 'Prozess'), stehen in _UNBEDENKLICH und werden nicht als
Fehler gewertet. Alles andere, was nach der Korrektur noch wie eine ASCII-Umlaut-Luecke
aussieht, laesst den Test fehlschlagen - mit dem genauen Wort in der Fehlermeldung, damit es
sich gezielt in labels._WOERTER ergaenzen laesst.
"""

from __future__ import annotations

import re

import db
import labels

# Echte deutsche Woerter, die ae/oe/ue/ss enthalten, ohne eine umgeschriebene
# Umlaut-/scharf-s-Stelle zu sein. Diese Liste waechst bei Bedarf.
_UNBEDENKLICH = {
    "dass", "muss", "musste", "müssen".lower(), "prozess", "prozesse", "interessent",
    "interessenten", "interessentenprofil", "interessentenprofile", "interesse",
    "interessiert", "aussen", "ausser", "ausserdem", "aktuell", "klasse", "masse",
    "adresse", "adressen", "wasser", "strasse", "grossbritannien",
    # "ue"/"eu" aus Latein-Wurzeln oder Flexionsendungen, kein Umlaut: individu-ell, neu-e(n/s).
    "individuell", "individuelle", "individuellen", "individuelles", "individuellem",
    "neu", "neue", "neuen", "neues", "neuer", "neuem",
}

# Spalten, die bewusst nicht geprueft werden (Kennungen, keine Fliesstexte).
_IGNORIERTE_SPALTEN = {"email", "foto_url", "website", "ags", "schluessel", "suchname",
                       "plz", "name"}  # 'name' separat behandelt: Eigennamen (Orte) ausgenommen

_MUSTER = re.compile(r"\b[A-Za-zÄÖÜäöüß]*(?:ae|oe|ue|ss)[A-Za-zÄÖÜäöüß]*\b")


def _verdaechtige_woerter(text: str) -> set[str]:
    nach_korrektur = labels.mit_umlauten(text)
    treffer = set()
    for wort in _MUSTER.findall(nach_korrektur):
        klein = wort.lower()
        if klein not in _UNBEDENKLICH and not any(k in klein for k in _UNBEDENKLICH):
            treffer.add(wort)
    return treffer


def _alle_katalogtexte() -> dict[str, list[str]]:
    """Spaltenname -> Werte, fuer alle Katalogtabellen, die die Oberflaeche anzeigt."""
    abfragen = {
        "charakter.name": "SELECT name FROM charakter",
        "beduerfnis.name": "SELECT name FROM beduerfnis",
        "tier_groesse.name": "SELECT name FROM tier_groesse",
        "pflegeaufwand.name": "SELECT name FROM pflegeaufwand",
        "wohnform.name": "SELECT name FROM wohnform",
        "arbeitsmodell.name": "SELECT name FROM arbeitsmodell",
        "gesundheitsmerkmal.name": "SELECT name FROM gesundheitsmerkmal",
        "gesundheitsmerkmal.beschreibung": "SELECT beschreibung FROM gesundheitsmerkmal",
        "tierart.name": "SELECT name FROM tierart",
        "matching_einstellung.beschreibung": "SELECT beschreibung FROM matching_einstellung",
    }
    ergebnis: dict[str, list[str]] = {}
    for spalte, sql in abfragen.items():
        werte = [z[list(z)[0]] for z in db.abfrage(sql) if z[list(z)[0]]]
        ergebnis[spalte] = werte
    return ergebnis


def test_katalogtexte_ohne_ascii_umlaut_reste() -> None:
    fehlerhaft: dict[str, set[str]] = {}
    for spalte, werte in _alle_katalogtexte().items():
        for wert in werte:
            treffer = _verdaechtige_woerter(wert)
            if treffer:
                fehlerhaft.setdefault(spalte, set()).update(treffer)

    assert not fehlerhaft, (
        "Diese Woerter sehen nach labels.mit_umlauten() noch nach ASCII-Umlaut aus - bitte in "
        f"labels._WOERTER ergaenzen: {fehlerhaft}"
    )


def test_signal_meldungen_ohne_ascii_umlaut_reste() -> None:
    """Die Texte aus SIGNAL SQLSTATE '45000' (Prozeduren, Trigger) werden unveraendert
    angezeigt (siehe db.verstaendlicher_fehler) - sie muessen deshalb sauber sein."""
    routinen = db.abfrage(
        """
        SELECT ROUTINE_DEFINITION AS text FROM information_schema.routines
        WHERE routine_schema = DATABASE()
        UNION ALL
        SELECT ACTION_STATEMENT AS text FROM information_schema.triggers
        WHERE trigger_schema = DATABASE()
        """
    )
    meldungen: set[str] = set()
    for routine in routinen:
        text = routine.get("text") or ""
        meldungen.update(re.findall(r"MESSAGE_TEXT\s*=\s*'([^']*)'", text))

    assert meldungen, "Es sollten SIGNAL-Meldungen gefunden werden - Abfrage pruefen."

    fehlerhaft: dict[str, set[str]] = {}
    for meldung in meldungen:
        treffer = _verdaechtige_woerter(meldung)
        if treffer:
            fehlerhaft[meldung] = treffer

    assert not fehlerhaft, (
        "Diese SIGNAL-Meldungen enthalten nach labels.mit_umlauten() noch ASCII-Umlaut-Reste: "
        f"{fehlerhaft}"
    )


def test_bausteine_tabelle_korrigiert_tatsaechlich_gerenderte_zellen() -> None:
    """Regressionstest fuer einen konkreten Bug: pandas >= 3 gibt Text als eigenen
    'str'-Dtyp zurueck statt 'object'. Eine Pruefung auf dtype == object uebersieht das
    und die Korrektur in bausteine.tabelle() wuerde dann still verfehlt."""
    from pathlib import Path

    from streamlit.testing.v1 import AppTest

    ui = Path(__file__).resolve().parents[1]
    skript = (
        "import sys\n"
        f"sys.path.insert(0, r'{ui}')\n"
        "import bausteine\n"
        "bausteine.tabelle([{'name': 'Allergie', "
        "'beschreibung': 'Ausloeser und erforderliche Massnahmen im Hinweis dokumentieren.'}])\n"
    )
    test = AppTest.from_string(skript)
    test.run()

    df = test.dataframe[0].value
    assert df["Beschreibung"][0] == "Auslöser und erforderliche Maßnahmen im Hinweis dokumentieren."


def test_ortsnamen_mit_umlauten_bleiben_unveraendert() -> None:
    """Orts-/Bezirksnamen kommen bereits mit echten Umlauten aus der Datenbank (UTF-8-Datei)
    und duerfen durch labels.mit_umlauten NICHT verfaelscht werden."""
    namen = [z["name"] for z in db.abfrage("SELECT name FROM bezirk")]
    assert any("ö" in n or "ü" in n or "ä" in n for n in namen), (
        "Demodaten sollten Bezirke mit echten Umlauten enthalten (z. B. Köpenick)"
    )
    for name in namen:
        assert labels.mit_umlauten(name) == name
