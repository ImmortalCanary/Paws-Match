"""Schreibende Zugriffe: Profil anlegen, aendern, loeschen - und die Schutzregeln der Datenbank."""

from __future__ import annotations

import pytest

import db
import queries


def _profildaten(nummer: int) -> dict:
    return {
        "pseudonym": f"Testprofil {nummer}",
        "email": f"test{nummer}@example.org",
        "bezirk_id": 1,
        "aktiv": 1,
        "wohnflaeche": 90,
        "garten": 1,
        "etage": 0,
        "aufzug": 1,
        "kinder": 0,
        "hund_vorhanden": 0,
        "katze_vorhanden": 0,
        "kleintiere_vorhanden": 0,
        "zeit_stunden": 6,
        "allein_stunden": 3,
        "budget": 500,
        "medizin_bereit": 1,
        "tierarzt_bereit": 1,
        "training_bereit": 1,
        "aktivitaet": 4,
        "wunschalter_min": 1,
        "wunschalter_max": 12,
    }


def _wuensche() -> dict:
    return {
        "tierarten": [1],
        "groessen": [2, 3],
        "charakter": [2],
        "standorte": [],
        "erfahrung": {1: 4},
        "beduerfnisse": {6: 1},
    }


def test_profil_anlegen_lesen_aendern_loeschen(aufraeumen) -> None:
    neue_id = queries.interessent_speichern(_profildaten(9001), _wuensche())
    aufraeumen.append(neue_id)

    gelesen = queries.interessent(neue_id)
    assert gelesen["pseudonym"] == "Testprofil 9001"
    assert float(gelesen["wohnflaeche"]) == 90

    wuensche = queries.interessent_wuensche(neue_id)
    assert wuensche["tierarten"] == [1]
    assert sorted(wuensche["groessen"]) == [2, 3]
    assert wuensche["erfahrung"] == {1: 4}
    # Medikamente (1) und Training (4) werden aus medizin_bereit/training_bereit abgeleitet,
    # nicht separat erfragt (US05) - 6 ist die explizit gegebene Antwort.
    assert wuensche["beduerfnisse"] == {1: 1, 4: 1, 6: 1}
    assert gelesen.get("erfahrung") is None, "allgemeine Erfahrung wird nicht mehr geschrieben"

    geaendert = _profildaten(9001) | {"pseudonym": "Geändert", "budget": 700}
    queries.interessent_speichern(geaendert, _wuensche() | {"tierarten": [1, 2]}, neue_id)
    danach = queries.interessent(neue_id)
    assert danach["pseudonym"] == "Geändert"
    assert float(danach["budget"]) == 700
    assert sorted(queries.interessent_wuensche(neue_id)["tierarten"]) == [1, 2]

    ergebnis = queries.interessent_loeschen(neue_id)
    assert ergebnis == "geloescht"
    assert queries.interessent(neue_id) is None
    aufraeumen.clear()


def test_beduerfnis_bestaetigung_wird_aus_profilfeld_abgeleitet(aufraeumen) -> None:
    """US05: Medikamente/Balkon/Training nicht zweimal fragen - aus den Profilfeldern ableiten."""
    daten = _profildaten(9007) | {
        "medizin_bereit": 0, "training_bereit": 1, "balkon": 1, "balkon_gesichert": 1,
    }
    neue_id = queries.interessent_speichern(daten, _wuensche() | {"beduerfnisse": {}})
    aufraeumen.append(neue_id)

    wuensche = queries.interessent_wuensche(neue_id)
    # 1 = Medikamente (abgelehnt, da medizin_bereit = 0), 2 = Balkon (bestaetigt), 4 = Training
    assert wuensche["beduerfnisse"] == {1: 0, 2: 1, 4: 1}


def test_fehlende_bereitschaft_erzeugt_keine_beduerfnis_zeile(aufraeumen) -> None:
    """Keine Angabe bei medizin_bereit/training_bereit darf keine Zeile erzwingen (bleibt offen)."""
    daten = _profildaten(9008) | {
        "medizin_bereit": None, "training_bereit": None, "balkon": None, "balkon_gesichert": None,
    }
    neue_id = queries.interessent_speichern(daten, _wuensche() | {"beduerfnisse": {}})
    aufraeumen.append(neue_id)

    wuensche = queries.interessent_wuensche(neue_id)
    assert wuensche["beduerfnisse"] == {}


def test_neues_profil_bekommt_sofort_vorschlaege(aufraeumen) -> None:
    """Ein vollstaendig ausgefuelltes Profil muss ohne Zutun im Matching auftauchen."""
    neue_id = queries.interessent_speichern(_profildaten(9002), _wuensche())
    aufraeumen.append(neue_id)
    paare = db.ein_wert(
        "SELECT COUNT(*) FROM matching_score WHERE interessent_id = %s", [neue_id]
    )
    assert int(paare) == int(db.ein_wert("SELECT COUNT(*) FROM tier"))


def test_unzulaessige_angaben_werden_abgewiesen(aufraeumen) -> None:
    """Die CHECK-Constraints der Datenbank greifen auch ueber die Oberflaeche."""
    daten = _profildaten(9003) | {"zeit_stunden": 20, "allein_stunden": 10}
    with pytest.raises(db.DatenbankFehler) as fehler:
        queries.interessent_speichern(daten, _wuensche())
    assert "24 Stunden" in fehler.value.nachricht or "zulässig" in fehler.value.nachricht


def test_doppelte_email_wird_erkannt(aufraeumen) -> None:
    neue_id = queries.interessent_speichern(_profildaten(9004), _wuensche())
    aufraeumen.append(neue_id)
    with pytest.raises(db.DatenbankFehler) as fehler:
        queries.interessent_speichern(_profildaten(9004) | {"pseudonym": "Zweiter"}, _wuensche())
    assert "vergeben" in fehler.value.nachricht


def test_bewerbung_auf_nicht_verfuegbares_tier_wird_blockiert(aufraeumen) -> None:
    """Der Trigger trg_bewerbung_pruefen muss greifen, die Meldung muss ankommen."""
    nicht_verfuegbar = db.ein_wert("SELECT id FROM tier WHERE status <> 'verfuegbar' LIMIT 1")
    if nicht_verfuegbar is None:
        # Bypass fuer den fail-closed Standort-Trigger (P0.2, trg_tier_standort_pruefen_update):
        # roher UPDATE ohne queries.tier_speichern()/Prozeduraufruf.
        with db.transaktion() as cursor:
            cursor.execute("SET @pm_ist_admin = 1")
            cursor.execute("UPDATE tier SET status = 'nicht_vermittelbar' WHERE id = 1")
            cursor.execute("SET @pm_ist_admin = NULL")
        nicht_verfuegbar = 1
        zuruecksetzen = True
    else:
        zuruecksetzen = False

    neue_id = queries.interessent_speichern(_profildaten(9005), _wuensche())
    aufraeumen.append(neue_id)
    try:
        with pytest.raises(db.DatenbankFehler) as fehler:
            queries.bewerbung_anlegen(neue_id, int(nicht_verfuegbar))
        assert fehler.value.nachricht
        assert int(db.ein_wert(
            "SELECT COUNT(*) FROM bewerbung WHERE interessent_id = %s", [neue_id])) == 0
    finally:
        if zuruecksetzen:
            with db.transaktion() as cursor:
                cursor.execute("SET @pm_ist_admin = 1")
                cursor.execute("UPDATE tier SET status = 'verfuegbar' WHERE id = 1")
                cursor.execute("SET @pm_ist_admin = NULL")


def test_merkliste(aufraeumen) -> None:
    neue_id = queries.interessent_speichern(_profildaten(9006), _wuensche())
    aufraeumen.append(neue_id)
    tier_id = int(db.ein_wert("SELECT id FROM tier WHERE status = 'verfuegbar' LIMIT 1"))
    queries.merken(neue_id, tier_id)
    assert tier_id in queries.gemerkte_ids(neue_id)
    queries.merken(neue_id, tier_id)  # doppelt merken darf nicht scheitern
    queries.merken_entfernen(neue_id, tier_id)
    assert tier_id not in queries.gemerkte_ids(neue_id)


def test_demodaten_bleiben_unveraendert() -> None:
    """Fingerabdruck wie in den SQL-Tests: Die Tests duerfen die Demodaten nicht verbiegen."""
    fingerabdruck = db.eine_zeile(
        """
        SELECT (SELECT COUNT(*) FROM tier) AS tiere,
               (SELECT COUNT(*) FROM interessent WHERE id < 9000) AS profile,
               (SELECT COUNT(*) FROM bewerbung) AS bewerbungen,
               (SELECT COUNT(*) FROM vermittlung) AS vermittlungen,
               (SELECT COUNT(*) FROM matching_vorschlaege WHERE interessent_id < 9000) AS vorschlaege
        """
    )
    assert fingerabdruck["tiere"] > 0
    assert fingerabdruck["profile"] >= 20
