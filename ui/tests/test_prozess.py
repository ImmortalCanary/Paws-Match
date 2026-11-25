"""Der Vermittlungsprozess, so wie die Oberflaeche ihn ausloest.

Die Prozeduren setzen intern COMMIT, deshalb wird mit eigenen Testdaten gearbeitet
(IDs ab 9001) und am Ende aufgeraeumt - wie in den SQL-Tests.
"""

from __future__ import annotations

import pytest

import db
import queries


@pytest.fixture()
def vorgang():
    """Legt Tier, Profil und Bewerbung an und raeumt danach alles wieder weg."""
    standort_id = int(db.ein_wert("SELECT standort_id FROM mitarbeiter WHERE id = 1"))
    with db.transaktion() as cursor:
        cursor.execute(
            "INSERT INTO tier (id, standort_id, tierart_id, name, status)"
            " VALUES (9001, %s, 1, 'Testtier', 'verfuegbar')",
            (standort_id,),
        )
        cursor.execute(
            "INSERT INTO interessent (id, pseudonym, email, bezirk_id, aktiv)"
            " VALUES (9001, 'Testprofil', 'prozess9001@example.org', 1, 1)"
        )
        cursor.execute(
            "INSERT INTO bewerbung (id, interessent_id, tier_id) VALUES (9001, 9001, 9001)"
        )

    daten = {"tier_id": 9001, "interessent_id": 9001, "bewerbung_id": 9001,
             "mitarbeiter_id": 1, "standort_id": standort_id}
    yield daten

    with db.transaktion() as cursor:
        cursor.execute("UPDATE tier SET reserviert_fuer_bewerbung_id = NULL, "
                       "status = 'verfuegbar' WHERE id = 9001")
        cursor.execute("DELETE FROM vermittlung WHERE tier_id = 9001")
        cursor.execute("DELETE FROM termin WHERE bewerbung_id = 9001")
        cursor.execute("DELETE FROM bewerbung WHERE id = 9001")
        cursor.execute("DELETE FROM tier WHERE id = 9001")
        cursor.execute("DELETE FROM interessent WHERE id = 9001")


def _tierstatus() -> str:
    return db.ein_wert("SELECT status FROM tier WHERE id = 9001")


def _bewerbungsstatus() -> str:
    return db.ein_wert("SELECT status FROM bewerbung WHERE id = 9001")


def test_reservieren_vermitteln_beenden(vorgang) -> None:
    queries.reservieren(vorgang["bewerbung_id"], vorgang["mitarbeiter_id"])
    assert _tierstatus() == "reserviert"
    assert _bewerbungsstatus() == "in_pruefung"
    assert int(db.ein_wert(
        "SELECT reserviert_fuer_bewerbung_id FROM tier WHERE id = 9001")) == 9001

    queries.reservierung_aufheben(vorgang["tier_id"], vorgang["mitarbeiter_id"])
    assert _tierstatus() == "verfuegbar"

    queries.vermitteln(vorgang["bewerbung_id"], vorgang["mitarbeiter_id"])
    assert _tierstatus() == "vermittelt"
    assert _bewerbungsstatus() == "angenommen"

    vermittlung_id = int(db.ein_wert("SELECT id FROM vermittlung WHERE tier_id = 9001"))
    queries.vermittlung_beenden(vermittlung_id, vorgang["mitarbeiter_id"], "rueckgabe",
                                "Test: Rueckgabe")
    assert _tierstatus() == "verfuegbar", "Nach einer Rückgabe muss das Tier wieder verfügbar sein"


def test_vermitteln_durch_fremden_standort_wird_abgelehnt(vorgang) -> None:
    """Die Prozedur prueft den Standort - die Meldung muss in der Oberflaeche ankommen."""
    fremder = db.ein_wert(
        "SELECT id FROM mitarbeiter WHERE standort_id <> %s LIMIT 1", [vorgang["standort_id"]]
    )
    if fremder is None:
        pytest.skip("Es gibt nur einen Standort mit Mitarbeitenden")

    with pytest.raises(db.DatenbankFehler) as fehler:
        queries.vermitteln(vorgang["bewerbung_id"], int(fremder))

    assert fehler.value.nachricht, "Die Prozedur muss eine verständliche Meldung liefern"
    assert _tierstatus() == "verfuegbar", "Nach dem Fehler darf nichts geändert sein"
    assert int(db.ein_wert("SELECT COUNT(*) FROM vermittlung WHERE tier_id = 9001")) == 0


def test_vermittlung_von_hand_wird_blockiert(vorgang) -> None:
    """Trigger trg_vermittlung_pruefen: eine Vermittlung geht nur ueber sp_vermitteln."""
    with pytest.raises(db.DatenbankFehler):
        with db.transaktion() as cursor:
            cursor.execute(
                "INSERT INTO vermittlung (bewerbung_id, tier_id, mitarbeiter_id)"
                " VALUES (9001, 9001, 1)"
            )
    assert int(db.ein_wert("SELECT COUNT(*) FROM vermittlung WHERE tier_id = 9001")) == 0


def test_termin_anlegen(vorgang) -> None:
    import datetime as dt

    termin_id = queries.termin_anlegen(
        vorgang["bewerbung_id"], vorgang["mitarbeiter_id"],
        dt.datetime.now() + dt.timedelta(days=1), "gespraech",
    )
    assert termin_id
    termine = queries.termine(bewerbung_id=vorgang["bewerbung_id"])
    assert len(termine) == 1
    assert termine[0]["art"] == "gespraech"
