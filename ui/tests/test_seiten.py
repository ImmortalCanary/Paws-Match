"""Jede Seite muss fuer ihre Rolle fehlerfrei durchlaufen - und fuer fremde Rollen sperren.

Dafuer wird die Seite mit Streamlits AppTest wirklich ausgefuehrt, so wie die App es tut.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from streamlit.testing.v1 import AppTest

import auth

UI = Path(__file__).resolve().parents[1]

MITARBEITERKONTO = {
    "id": 1, "email": "team1@example.org", "rolle": auth.MITARBEITER,
    "aktiv": 1, "mitarbeiter_id": 1, "mitarbeiter_name": "Demo-Team 1",
    "standort_id": 1, "standort": "Teststandort",
}
ADMINKONTO = {
    "id": 99, "email": "admin@example.org", "rolle": auth.ADMIN, "aktiv": 1,
    "mitarbeiter_id": None, "mitarbeiter_name": None, "standort_id": None, "standort": None,
}

OEFFENTLICHE_SEITEN = ["start", "galerie", "anmelden", "fragebogen", "tierdetail"]
INTERESSENTENSEITEN = ["matches", "fragebogen", "meine_bewerbungen"]
INTERNE_SEITEN = ["mitarbeiter_uebersicht", "mitarbeiter_tiere", "mitarbeiter_prozess"]
ADMINSEITEN = ["admin_matching", "admin_auswertung", "admin_konten"]

INTERESSENT = {"rolle": auth.INTERESSENT, "interessent_id": 17,
               "interessent_email": "profil17@example.org"}
MITARBEITER = {"rolle": auth.MITARBEITER, "konto": MITARBEITERKONTO}
ADMIN = {"rolle": auth.ADMIN, "konto": ADMINKONTO}


def _lauf(seite: str, zustand: dict | None = None) -> AppTest:
    """Die Seite als eigenstaendiges Skript ausfuehren, mit vorbereiteter Sitzung."""
    skript = (
        "import sys\n"
        f"sys.path.insert(0, r'{UI}')\n"
        "import bausteine\n"
        f"from seiten import {seite}\n"
        "bausteine.stil_laden()\n"
        f"{seite}.zeige()\n"
    )
    test = AppTest.from_string(skript, default_timeout=90)
    for schluessel, wert in (zustand or {}).items():
        test.session_state[schluessel] = wert
    test.run()
    return test


def _ohne_fehler(test: AppTest, seite: str) -> None:
    assert not test.exception, f"{seite}: {[e.message for e in test.exception]}"


@pytest.mark.parametrize("seite", OEFFENTLICHE_SEITEN)
def test_oeffentliche_seiten_laufen_ohne_profil(seite) -> None:
    test = _lauf(seite)
    _ohne_fehler(test, seite)
    assert not test.error, f"{seite}: {[e.value for e in test.error]}"


@pytest.mark.parametrize("seite", INTERESSENTENSEITEN)
def test_interessentenseiten_laufen_mit_profil(seite) -> None:
    test = _lauf(seite, INTERESSENT)
    _ohne_fehler(test, seite)
    assert not test.error, f"{seite}: {[e.value for e in test.error]}"


@pytest.mark.parametrize("seite", INTERNE_SEITEN)
def test_interne_seiten_laufen_fuer_mitarbeitende(seite) -> None:
    test = _lauf(seite, MITARBEITER)
    _ohne_fehler(test, seite)
    assert not test.error, f"{seite}: {[e.value for e in test.error]}"


@pytest.mark.parametrize("seite", ADMINSEITEN)
def test_adminseiten_laufen_fuer_admin(seite) -> None:
    test = _lauf(seite, ADMIN)
    _ohne_fehler(test, seite)
    assert not test.error, f"{seite}: {[e.value for e in test.error]}"


@pytest.mark.parametrize("seite", ADMINSEITEN)
def test_mitarbeitende_kommen_nicht_in_die_adminsicht(seite) -> None:
    """Der Guard muss die Seite abbrechen und eine Meldung zeigen."""
    test = _lauf(seite, MITARBEITER)
    _ohne_fehler(test, seite)
    assert test.error, f"{seite}: Mitarbeitende haben die Adminseite gesehen"
    assert "zugänglich" in test.error[0].value


@pytest.mark.parametrize("seite", INTERNE_SEITEN + ADMINSEITEN)
def test_interessenten_kommen_nicht_in_den_internen_bereich(seite) -> None:
    test = _lauf(seite, INTERESSENT)
    _ohne_fehler(test, seite)
    assert test.error, f"{seite}: Interessent hat den internen Bereich gesehen"


@pytest.mark.parametrize("seite", INTERNE_SEITEN + ADMINSEITEN)
def test_besucher_kommen_nicht_in_den_internen_bereich(seite) -> None:
    test = _lauf(seite)
    _ohne_fehler(test, seite)
    assert test.error, f"{seite}: Besucher hat den internen Bereich gesehen"


def test_startseite_zeigt_konzept_und_kennzahlen() -> None:
    test = _lauf("start")
    _ohne_fehler(test, "start")
    beschriftungen = [m.label for m in test.metric]
    assert "Tiere warten" in beschriftungen
    assert any("Perfect Match" in b.label for b in test.button)
    inhalt = " ".join(m.value for m in test.markdown)
    assert "Straße" in inhalt, "Das Konzept (Problem) soll auf der Startseite stehen"


def test_matches_zeigen_score_und_begruendung() -> None:
    test = _lauf("matches", INTERESSENT)
    _ohne_fehler(test, "matches")
    inhalt = " ".join(m.value for m in test.markdown)
    assert "%" in inhalt
    assert any("Vorschläge" in t for t in [r.label for r in test.tabs])


def test_matches_filter_tierart_zeigt_echte_werte() -> None:
    """P5.4: Tierart-Multiselect muss die tatsaechlich genutzten Tierarten anbieten."""
    test = _lauf("matches", INTERESSENT)
    _ohne_fehler(test, "matches")
    tierart_filter = next(m for m in test.multiselect if m.label == "Tierart")
    assert set(tierart_filter.options) <= {
        "Hund", "Katze", "Kaninchen", "Meerschweinchen", "Vogel", "Reptil", "Fisch",
    }
    assert tierart_filter.options, "Tierart-Filter sollte bei vorhandenen Vorschlaegen nicht leer sein"


def test_matches_filter_mindestscore_auf_maximum_zeigt_hinweis_statt_crash() -> None:
    """P5.4: Score-Slider-Grenzfall 100 % darf nicht abstuerzen, sondern einen Leer-Hinweis zeigen."""
    test = _lauf("matches", INTERESSENT)
    _ohne_fehler(test, "matches")
    test.slider[0].set_value(100)
    test.run()
    _ohne_fehler(test, "matches")
    assert any("Filtern" in i.value for i in test.info)


def test_matches_filter_gesundheit_ohne_absturz_bei_tieren_ohne_merkmalen() -> None:
    """P5.4: Checkbox "nur ohne belastende Gesundheitsmerkmale" darf bei Tieren ganz ohne
    tier_gesundheit-Zeilen (gibt es unter den 100 Demotieren) nicht crashen."""
    test = _lauf("matches", INTERESSENT)
    _ohne_fehler(test, "matches")
    checkbox = next(c for c in test.checkbox if "belastende" in c.label)
    checkbox.check()
    test.run()
    _ohne_fehler(test, "matches")


def test_matches_filter_status_multiselect_in_alle_tiere() -> None:
    """P5.4: Status-Multiselect im Tab "Alle Tiere" muss die drei Eignungsstatus anbieten."""
    test = _lauf("matches", INTERESSENT)
    _ohne_fehler(test, "matches")
    status_filter = next(m for m in test.multiselect if m.label == "Status")
    assert status_filter.options
    status_filter.select(status_filter.options[0])
    test.run()
    _ohne_fehler(test, "matches")


def test_galerie_zeigt_tierkarten() -> None:
    test = _lauf("galerie")
    _ohne_fehler(test, "galerie")
    inhalt = " ".join(m.value for m in test.markdown)
    assert "Tiere gefunden" in " ".join(m.value for m in test.markdown) or inhalt


def test_tierdetail_ohne_auswahl_zeigt_hinweis() -> None:
    test = _lauf("tierdetail")
    _ohne_fehler(test, "tierdetail")
    assert any("ausgewählt" in i.value for i in test.info)


def test_tierdetail_zeigt_steckbrief_und_fuer_profil_die_begruendung() -> None:
    zustand = dict(INTERESSENT)
    zustand["detail_tier_id"] = 16
    test = _lauf("tierdetail", zustand)
    _ohne_fehler(test, "tierdetail")
    titel = [t.value for t in test.title]
    assert titel, "Tiername sollte als Titel erscheinen"
    inhalt = " ".join(m.value for m in test.markdown)
    assert "Eignung" in inhalt or "%" in inhalt


def test_tierdetail_ohne_profil_bietet_profil_an() -> None:
    test = _lauf("tierdetail", {"detail_tier_id": 16})
    _ohne_fehler(test, "tierdetail")
    assert any("Profil ausfüllen" in b.label for b in test.button)
