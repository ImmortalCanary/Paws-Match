"""Klickpfade: was passiert, wenn jemand die Oberflaeche wirklich bedient."""

from __future__ import annotations

from pathlib import Path

from streamlit.testing.v1 import AppTest

import auth
import queries

UI = Path(__file__).resolve().parents[1]
DEMO_PASSWORT = "paws2026"


def _lauf(seite: str, zustand: dict | None = None) -> AppTest:
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
    return test.run()


def test_anmeldung_ueber_das_formular_setzt_die_rolle() -> None:
    test = _lauf("anmelden")
    test.text_input[0].input("team1@example.org")
    test.text_input[1].input(DEMO_PASSWORT)
    test.button[0].click().run()

    assert not test.exception
    assert test.session_state["rolle"] == auth.MITARBEITER
    assert test.session_state["konto"]["mitarbeiter_id"] == 1


def test_falsches_passwort_meldet_fehler_und_meldet_niemanden_an() -> None:
    test = _lauf("anmelden")
    test.text_input[0].input("team1@example.org")
    test.text_input[1].input("falsch")
    test.button[0].click().run()

    assert not test.exception
    assert test.error, "Es muss eine Fehlermeldung erscheinen"
    assert "rolle" not in test.session_state or test.session_state["rolle"] == auth.BESUCHER


def test_galerie_filtert_nach_tierart() -> None:
    hund = next(t for t in queries.tierarten() if t["name"] == "Hund")
    erwartet = len(queries.tiere(tierart_id=hund["id"]))

    test = _lauf("galerie")
    test.selectbox[0].select(hund["id"]).run()

    assert not test.exception
    texte = [m.value for m in test.markdown]
    assert any(f"**{erwartet}** Tiere gefunden" in t for t in texte), texte[:5]


def test_besucher_sieht_in_der_galerie_keinen_score() -> None:
    test = _lauf("galerie")
    inhalt = " ".join(m.value for m in test.markdown)
    assert "Übereinstimmung" not in inhalt
    assert any("Passt das zu mir?" in b.label for b in test.button)


def test_interessent_ohne_profil_wird_zum_fragebogen_geschickt() -> None:
    test = _lauf("matches")
    assert not test.exception
    assert any("Profil" in b.label for b in test.button)
    inhalt = " ".join(i.value for i in test.info)
    assert "Profil" in inhalt


def test_profilseite_zeigt_die_gespeicherten_werte() -> None:
    """Profil 17 aus den Demodaten muss im Formular auftauchen."""
    test = _lauf("fragebogen", {"rolle": auth.INTERESSENT, "interessent_id": 17,
                                "interessent_email": "profil17@example.org"})
    assert not test.exception
    profil = queries.interessent(17)
    werte = [t.value for t in test.text_input]
    assert profil["pseudonym"] in werte
    assert profil["email"] in werte
