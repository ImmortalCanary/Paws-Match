"""US12: Admin-Funktionen wirklich ausueben, nicht nur laden lassen.

Jede Aenderung stellt den vorherigen Wert hinterher wieder her, damit die Einstellungen des
Tierheims (bzw. das, was beim Ausprobieren in der App gerade eingestellt wurde) unangetastet
bleiben.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from streamlit.testing.v1 import AppTest

import auth
import queries

UI = Path(__file__).resolve().parents[1]
ADMIN = {"rolle": auth.ADMIN, "konto": {
    "id": 99, "email": "admin@example.org", "rolle": auth.ADMIN, "aktiv": 1,
    "mitarbeiter_id": None, "mitarbeiter_name": None, "standort_id": None, "standort": None,
}}


def _lauf(seite: str, zustand: dict) -> AppTest:
    skript = (
        "import sys\n"
        f"sys.path.insert(0, r'{UI}')\n"
        "import bausteine\n"
        f"from seiten import {seite}\n"
        "bausteine.stil_laden()\n"
        # Reihenfolge wie in app.py: flash_zeigen() vor dem Seitenaufbau, damit eine mit
        # bausteine.flash_setzen() hinterlegte Meldung (siehe admin_matching.py) nach einem
        # st.rerun() in diesem Testlauf ebenfalls sichtbar wird statt stillschweigend zu
        # verschwinden.
        "bausteine.flash_zeigen()\n"
        f"{seite}.zeige()\n"
    )
    test = AppTest.from_string(skript, default_timeout=90)
    for schluessel, wert in zustand.items():
        test.session_state[schluessel] = wert
    test.run()
    return test


@pytest.fixture()
def alter_mindestscore():
    wert = queries.mindestscore()
    yield wert
    queries.mindestscore_setzen(wert)


@pytest.fixture()
def alte_gewichtung():
    werte = {z["kriterium"]: float(z["gewicht"]) for z in queries.gewichtung()}
    yield werte
    queries.gewichtung_speichern(werte)


def test_mindestscore_slider_speichert_und_wirkt(alter_mindestscore) -> None:
    """US12: eine Admin-Aenderung wird gespeichert und zeigt sich sofort."""
    neuer_wert = 90.0 if alter_mindestscore != 90.0 else 80.0

    test = _lauf("admin_matching", ADMIN)
    assert not test.exception
    test.slider[0].set_value(neuer_wert).run()
    assert not test.exception

    knopf = next(b for b in test.button if "Mindestscore übernehmen" in b.label)
    assert not knopf.disabled
    # admin_matching.py ruft nach dem Speichern bausteine.flash_setzen(...) + st.rerun() auf:
    # die Erfolgsmeldung aus dem Klick-Durchlauf selbst ist dadurch nicht mehr beobachtbar
    # (der Rerun bricht den Durchlauf ab), wohl aber auf dem nachfolgenden Durchlauf - genau das
    # simuliert _lauf() durch den vorangestellten bausteine.flash_zeigen()-Aufruf.
    knopf.click().run()
    assert not test.exception
    assert float(queries.mindestscore()) == neuer_wert
    erfolgsmeldungen = [e.value for e in test.success]
    assert any("Mindestscore steht jetzt auf" in text for text in erfolgsmeldungen), erfolgsmeldungen


def test_gewichtssumme_ungleich_100_wird_nicht_gespeichert(alte_gewichtung) -> None:
    """US12 + Datenqualitaet: eine ungueltige Summe darf nicht in der Datenbank landen."""
    test = _lauf("admin_matching", ADMIN)
    assert not test.exception

    editor = test.get("data_editor")[0]
    ursprung = float(editor.value.loc[0, "Gewicht"])
    # AppTest kann data_editor nicht per set_value() bedienen - der Bearbeitungszustand wird
    # wie im echten Frontend ueber session_state[key] gesetzt (edited_rows/added/deleted).
    test.session_state[editor.key] = {
        "edited_rows": {0: {"Gewicht": ursprung + 5}},  # Summe damit garantiert != 100
        "added_rows": [],
        "deleted_rows": [],
    }
    test.run()

    fehler = [e.value for e in test.error]
    assert any("100" in f for f in fehler)
    speichern = next(b for b in test.button if b.label == "Gewichte speichern")
    assert speichern.disabled, "Bei falscher Summe darf Speichern nicht anklickbar sein"

    # Unveraendert in der Datenbank - kein Klick noetig, disabled haette ihn ohnehin verhindert.
    assert {z["kriterium"]: float(z["gewicht"]) for z in queries.gewichtung()} == alte_gewichtung


def test_benutzerkonto_anlegen_und_sperren() -> None:
    """US12: Konten anlegen, Zugriff danach sperren koennen."""
    email = "test-admin-konto@example.org"

    vorher = {k["email"] for k in auth.konten()}
    assert email not in vorher, "Testkonto sollte vor dem Test nicht existieren"

    # Rolle admin statt mitarbeiter: braucht keinen freien Mitarbeiter (in den Demodaten hat
    # bereits jeder Mitarbeiter ein Konto, uq_benutzerkonto_mitarbeiter wuerde sonst blockieren).
    konto_id = auth.konto_anlegen(email, "testpasswort123", auth.ADMIN, None)

    try:
        angemeldet = auth.pruefe_anmeldung(email, "testpasswort123")
        assert angemeldet is not None

        auth.konto_aktiv_setzen(konto_id, False)
        assert auth.pruefe_anmeldung(email, "testpasswort123") is None, (
            "Ein gesperrtes Konto darf sich nicht mehr anmelden koennen"
        )
    finally:
        with __import__("db").transaktion() as cursor:
            cursor.execute("DELETE FROM benutzerkonto WHERE id = %s", (konto_id,))
