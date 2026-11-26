"""Gezielte Tests fuer die P0-Punkte aus dem Meeting-Feedback 2026-11-26 (team/tasks.md
Phase 4), soweit sie sich auf UI-Ebene (queries.tier_speichern/tier_loeschen) pruefen lassen:

- P0.1: Idempotenz beim Tier-Anlegen (gleicher anlage_token darf kein zweites Tier erzeugen).
- P0.2: serverseitige Standortberechtigung (Trigger trg_tier_standort_pruefen_insert/_update),
  inkl. des Falls einer "manipulierten Anfrage" direkt per SQL ohne gesetzte Session-Variablen.
- P0.3: der duenne Python-Wrapper queries.tier_loeschen() um sp_tier_loeschen (OUT-Parameter
  korrekt gelesen) - die Fachlogik selbst ist in 07_tests/03_prozedur_tests.sql abgedeckt. Dazu
  ein Regressionstest fuer den vom Code Reviewer gefundenen fk_tier_anlage_token_tier-Bug
  (fehlende ON DELETE-Klausel, s. test_tier_loeschen_mit_anlage_token_cascade).

Fixtures nutzen eigene Tier-IDs (ueber tier_speichern angelegt) und raeumen sich selbst auf,
analog zum Muster in test_schreiben.py/test_prozess.py.
"""

from __future__ import annotations

import uuid

import pytest

import db
import queries


def _tierdaten(name: str, standort_id: int) -> dict:
    # geburt_geschaetzt/geschlecht/status sind NOT NULL ohne Default-Uebernahme bei explizitem
    # NULL - tier_speichern() fuegt immer alle TIER_SPALTEN ein, also muessen diese gesetzt sein.
    return {
        "standort_id": standort_id,
        "tierart_id": 1,
        "name": name,
        "geburt_geschaetzt": 0,
        "geschlecht": "unbekannt",
    }


@pytest.fixture()
def tier_aufraeumen():
    ids: list[int] = []
    yield ids
    if not ids:
        return
    with db.transaktion() as cursor:
        platzhalter = ", ".join(["%s"] * len(ids))
        cursor.execute(f"DELETE FROM tier_charakter WHERE tier_id IN ({platzhalter})", ids)
        cursor.execute(f"DELETE FROM tier_beduerfnis WHERE tier_id IN ({platzhalter})", ids)
        cursor.execute(f"DELETE FROM tier_anlage_token WHERE tier_id IN ({platzhalter})", ids)
        cursor.execute(f"DELETE FROM tier WHERE id IN ({platzhalter})", ids)


# --- P0.1: Idempotenz ---------------------------------------------------------------------


def test_tier_speichern_gleicher_token_erzeugt_nur_ein_tier(tier_aufraeumen) -> None:
    token = uuid.uuid4().hex
    daten = _tierdaten("P0.1 Token-Test", 1)

    erste_id = queries.tier_speichern(
        daten, [], [], mitarbeiter_id=1, ist_admin=True, anlage_token=token
    )
    tier_aufraeumen.append(erste_id)

    zweite_id = queries.tier_speichern(
        daten, [], [], mitarbeiter_id=1, ist_admin=True, anlage_token=token
    )

    assert zweite_id == erste_id, "Zweiter Aufruf mit demselben Token muss dieselbe tier_id liefern"
    anzahl = db.ein_wert(
        "SELECT COUNT(*) FROM tier WHERE standort_id = 1 AND name = 'P0.1 Token-Test'"
    )
    assert int(anzahl) == 1, "Es darf trotz zwei Aufrufen nur ein Tier-Datensatz entstehen"


def test_tier_speichern_unterschiedliche_tokens_legen_zwei_tiere_an(tier_aufraeumen) -> None:
    """Negativkontrolle: der Mechanismus darf nicht generell einen zweiten Aufruf blockieren."""
    daten = _tierdaten("P0.1 Zwei-Tiere-Test", 1)

    erste_id = queries.tier_speichern(
        daten, [], [], mitarbeiter_id=1, ist_admin=True, anlage_token=uuid.uuid4().hex
    )
    tier_aufraeumen.append(erste_id)
    zweite_id = queries.tier_speichern(
        daten, [], [], mitarbeiter_id=1, ist_admin=True, anlage_token=uuid.uuid4().hex
    )
    tier_aufraeumen.append(zweite_id)

    assert erste_id != zweite_id, "Unterschiedliche Tokens muessen zwei eigene Tiere anlegen"


# --- P0.2: Standortberechtigung ------------------------------------------------------------


def _fremder_mitarbeiter(standort_id: int) -> int:
    fremder = db.ein_wert(
        "SELECT id FROM mitarbeiter WHERE standort_id <> %s LIMIT 1", [standort_id]
    )
    if fremder is None:
        pytest.skip("Es gibt nur einen Standort mit Mitarbeitenden")
    return int(fremder)


def test_tier_anlegen_fremder_standort_wird_blockiert(tier_aufraeumen) -> None:
    ziel_standort = 1
    fremder = _fremder_mitarbeiter(ziel_standort)
    daten = _tierdaten("P0.2 Fremder Standort", ziel_standort)

    with pytest.raises(db.DatenbankFehler) as fehler:
        queries.tier_speichern(daten, [], [], mitarbeiter_id=fremder, ist_admin=False)
    assert "Mitarbeiter gehoert nicht zum Standort des Tieres" in fehler.value.nachricht

    anzahl = db.ein_wert(
        "SELECT COUNT(*) FROM tier WHERE standort_id = %s AND name = 'P0.2 Fremder Standort'",
        [ziel_standort],
    )
    assert int(anzahl) == 0, "Der blockierte Versuch darf keine Zeile hinterlassen"


def test_tier_anlegen_als_admin_funktioniert_unabhaengig_vom_standort(tier_aufraeumen) -> None:
    ziel_standort = 1
    fremder = _fremder_mitarbeiter(ziel_standort)
    daten = _tierdaten("P0.2 Admin-Bypass", ziel_standort)

    tier_id = queries.tier_speichern(daten, [], [], mitarbeiter_id=fremder, ist_admin=True)
    tier_aufraeumen.append(tier_id)

    gelesen = queries.tier(tier_id)
    assert gelesen["standort_id"] == ziel_standort


def test_tier_bearbeiten_als_mitarbeiter_anderen_standorts_wird_blockiert(tier_aufraeumen) -> None:
    """Nicht nur Anlegen, auch das Bearbeiten (UPDATE) eines fremden Tiers muss blockieren."""
    ziel_standort = 1
    tier_id = queries.tier_speichern(
        _tierdaten("P0.2 Update-Test", ziel_standort), [], [], mitarbeiter_id=1, ist_admin=True
    )
    tier_aufraeumen.append(tier_id)
    fremder = _fremder_mitarbeiter(ziel_standort)

    geaendert = _tierdaten("P0.2 Update-Test geaendert", ziel_standort)
    with pytest.raises(db.DatenbankFehler) as fehler:
        queries.tier_speichern(
            geaendert, [], [], tier_id=tier_id, mitarbeiter_id=fremder, ist_admin=False
        )
    assert "Mitarbeiter gehoert nicht zum Standort des Tieres" in fehler.value.nachricht

    unveraendert = queries.tier(tier_id)
    assert unveraendert["tiername"] == "P0.2 Update-Test", "Nach dem Fehler darf nichts geaendert sein"


def test_tier_loeschen_wrapper_ohne_historie(tier_aufraeumen) -> None:
    """queries.tier_loeschen() muss das OUT-Parameter-Ergebnis 'geloescht' korrekt durchreichen."""
    tier_id = queries.tier_speichern(
        _tierdaten("P0.3 Wrapper ohne Historie", 1), [], [], mitarbeiter_id=1, ist_admin=True
    )
    tier_aufraeumen.append(tier_id)

    ergebnis = queries.tier_loeschen(tier_id, mitarbeiter_id=1, ist_admin=False)
    assert ergebnis == "geloescht"
    assert queries.tier(tier_id) is None
    tier_aufraeumen.remove(tier_id)  # schon weg, sonst wuerde das Aufraeumen ins Leere laufen


def test_tier_loeschen_mit_anlage_token_cascade(tier_aufraeumen) -> None:
    """Regressionstest fuer einen vom Code Reviewer gefundenen Bug: fk_tier_anlage_token_tier
    hatte keine ON DELETE-Klausel, dadurch schlug der Hard-Delete-Zweig von sp_tier_loeschen mit
    FK-Fehler 1451 fehl, sobald das Tier einen tier_anlage_token-Datensatz hat - nach P0.1 der
    Normalfall fuer jedes ueber die UI angelegte Tier. Fix: ON DELETE CASCADE ergaenzt (konsistent
    mit tier_charakter/tier_beduerfnis/merkliste). Hier: Tier MIT anlage_token anlegen (genau der
    vorher fehlschlagende Fall), ohne Historie loeschen - muss jetzt 'geloescht' liefern, Tier UND
    der zugehoerige tier_anlage_token-Datensatz muessen beide weg sein."""
    token = uuid.uuid4().hex
    tier_id = queries.tier_speichern(
        _tierdaten("P0.3 Cascade-Test", 1), [], [], mitarbeiter_id=1, ist_admin=True,
        anlage_token=token,
    )
    tier_aufraeumen.append(tier_id)

    vorher = db.ein_wert(
        "SELECT COUNT(*) FROM tier_anlage_token WHERE token = %s AND tier_id = %s",
        [token, tier_id],
    )
    assert int(vorher) == 1, "Vorbedingung: der tier_anlage_token-Datensatz muss existieren"

    ergebnis = queries.tier_loeschen(tier_id, mitarbeiter_id=1, ist_admin=False)
    assert ergebnis == "geloescht"
    assert queries.tier(tier_id) is None
    tier_aufraeumen.remove(tier_id)  # schon weg (Cascade), sonst liefe das Aufraeumen ins Leere

    nachher = db.ein_wert("SELECT COUNT(*) FROM tier_anlage_token WHERE token = %s", [token])
    assert int(nachher) == 0, "ON DELETE CASCADE muss auch den tier_anlage_token-Datensatz loeschen"


def test_tier_loeschen_wrapper_fremder_standort_blockiert(tier_aufraeumen) -> None:
    tier_id = queries.tier_speichern(
        _tierdaten("P0.3 Wrapper Standortfehler", 1), [], [], mitarbeiter_id=1, ist_admin=True
    )
    tier_aufraeumen.append(tier_id)
    fremder = _fremder_mitarbeiter(1)

    with pytest.raises(db.DatenbankFehler) as fehler:
        queries.tier_loeschen(tier_id, mitarbeiter_id=fremder, ist_admin=False)
    assert "Mitarbeiter gehoert nicht zum Standort des Tieres" in fehler.value.nachricht
    assert queries.tier(tier_id) is not None, "Der blockierte Versuch darf nichts loeschen"


def test_tier_schreiben_ohne_session_variablen_blockiert_fail_closed() -> None:
    """Eine 'manipulierte Anfrage' direkt per SQL, ganz ohne queries.tier_speichern(): der
    Trigger muss unabhaengig vom Aufrufweg fail-closed blockieren, wenn @pm_mitarbeiter_id/
    @pm_ist_admin gar nicht erst gesetzt wurden (z. B. ein direkter DB-Zugriff am UI vorbei)."""
    with pytest.raises(db.DatenbankFehler) as fehler:
        with db.transaktion() as cursor:
            cursor.execute(
                "INSERT INTO tier (standort_id, tierart_id, name) VALUES (1, 1, 'Ohne Bypass')"
            )
    assert "Mitarbeiter gehoert nicht zum Standort des Tieres" in fehler.value.nachricht
    anzahl = db.ein_wert("SELECT COUNT(*) FROM tier WHERE name = 'Ohne Bypass'")
    assert int(anzahl) == 0
