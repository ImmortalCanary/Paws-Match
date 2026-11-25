"""Gemeinsame Vorbereitung der Tests.

Die Tests laufen gegen die installierte Demodatenbank. Ist sie nicht erreichbar,
werden sie uebersprungen statt zu scheitern.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

UI = Path(__file__).resolve().parents[1]
if str(UI) not in sys.path:
    sys.path.insert(0, str(UI))

import db  # noqa: E402

# Testdaten bekommen IDs ab 9001, genau wie in den SQL-Tests.
TEST_ID_AB = 9001


@pytest.fixture(scope="session", autouse=True)
def datenbank_vorhanden() -> None:
    """Ohne installierte Datenbank mit Demodaten haben diese Tests keine Grundlage."""
    erreichbar, meldung = db.ist_erreichbar()
    if not erreichbar:
        pytest.skip(f"Datenbank nicht erreichbar: {meldung}", allow_module_level=True)

    try:
        tiere = int(db.ein_wert("SELECT COUNT(*) FROM tier") or 0)
        profile = int(db.ein_wert("SELECT COUNT(*) FROM interessent") or 0)
    except db.DatenbankFehler as fehler:
        pytest.skip(f"Datenbank unvollstaendig: {fehler.nachricht}", allow_module_level=True)
    if tiere == 0 or profile == 0:
        pytest.skip(
            "Keine Demodaten vorhanden. Bitte die SQL-Skripte aus paws_and_match/README.md "
            "ausfuehren (Schritte 1-21).",
            allow_module_level=True,
        )

    try:
        db.ein_wert("SELECT COUNT(*) FROM benutzerkonto")
    except db.DatenbankFehler:
        pytest.skip(
            "Tabelle benutzerkonto fehlt. Nach jeder Neuinstallation der Datenbank muss "
            "paws_and_match/08_oberflaeche/01_benutzerkonten.sql erneut laufen.",
            allow_module_level=True,
        )


@pytest.fixture()
def aufraeumen():
    """Legt die IDs fest, die nach dem Test wieder verschwinden muessen."""
    ids: list[int] = []
    yield ids
    for interessent_id in ids:
        with db.transaktion() as cursor:
            cursor.execute("DELETE FROM merkliste WHERE interessent_id = %s", (interessent_id,))
            cursor.execute("DELETE FROM bewerbung WHERE interessent_id = %s", (interessent_id,))
            cursor.execute("DELETE FROM interessent WHERE id = %s", (interessent_id,))
