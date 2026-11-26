"""Lesende Zugriffe: Die Oberflaeche muss dasselbe zeigen wie die Datenbank.

Es werden bewusst keine festen Zahlen aus der Dokumentation geprueft (die aendern sich
mit den Demodaten), sondern die Uebereinstimmung zwischen Prozedur, View und Anzeige.
"""

from __future__ import annotations

import db
import labels
import queries

PROFIL = 17


def test_vorschlagsprozedur_entspricht_der_view() -> None:
    """sp_vorschlaege_fuer_interessent darf nichts anderes liefern als matching_vorschlaege."""
    aus_prozedur = [z["tier_id"] for z in queries.vorschlaege_fuer_interessent(PROFIL)]
    aus_view = [
        z["tier_id"]
        for z in db.abfrage(
            "SELECT tier_id FROM matching_vorschlaege WHERE interessent_id = %s "
            "ORDER BY match_prozent DESC, datenabdeckung_prozent DESC, tier_id",
            [PROFIL],
        )
    ]
    assert aus_prozedur == aus_view
    assert aus_prozedur, "Profil 17 sollte in den Demodaten Vorschlaege haben"


def test_vorschlaege_sind_absteigend_sortiert() -> None:
    werte = [float(z["match_prozent"]) for z in queries.vorschlaege_fuer_interessent(PROFIL)]
    assert werte == sorted(werte, reverse=True)


def test_vorschlag_erfuellt_die_regeln_der_view() -> None:
    mindestscore = float(queries.mindestscore())
    for vorschlag in queries.vorschlaege_fuer_interessent(PROFIL):
        assert vorschlag["eignung"] == "geeignet"
        assert vorschlag["tierstatus"] == "verfuegbar"
        assert float(vorschlag["match_prozent"]) >= mindestscore


def test_kriterien_ergeben_den_score() -> None:
    """Der Score ist die Summe aus Teilpassung mal Gewicht - nachgerechnet."""
    vorschlaege = queries.vorschlaege_fuer_interessent(PROFIL)
    assert vorschlaege
    vorschlag = vorschlaege[0]
    kriterien = queries.kriterien(vorschlag["tier_id"], PROFIL)
    summe = sum(float(z["punkte"]) for z in kriterien)
    assert round(summe, 1) == float(vorschlag["match_prozent"])


def test_jede_kategorie_hat_ein_gewicht_und_die_summe_ist_100() -> None:
    gewichte = queries.gewichtung()
    assert all(z["gewicht"] is not None for z in gewichte)
    assert sum(float(z["gewicht"]) for z in gewichte) == 100


def test_uebersicht_enthaelt_alle_tiere_mit_grund() -> None:
    uebersicht = queries.uebersicht_fuer_interessent(PROFIL)
    anzahl_tiere = int(db.ein_wert("SELECT COUNT(*) FROM tier"))
    assert len(uebersicht) == anzahl_tiere
    for zeile in uebersicht:
        if zeile["eignung"] == "ausgeschlossen":
            assert zeile["ausschlussgruende"], f"Tier {zeile['tier_id']} ohne Begruendung"
        if zeile["eignung"] == "pruefung_offen":
            assert zeile["offene_pruefungen"]


def test_begruendungen_werden_nicht_abgeschnitten() -> None:
    """group_concat_max_len muss gesetzt sein, sonst fehlen Gruende ab 1024 Zeichen."""
    assert int(db.ein_wert("SELECT @@session.group_concat_max_len")) >= 65535


def test_kennzahlen_der_startseite_stimmen() -> None:
    zahlen = queries.kennzahlen()
    assert zahlen["tiere_verfuegbar"] == int(
        db.ein_wert("SELECT COUNT(*) FROM tier WHERE status = 'verfuegbar'")
    )
    assert zahlen["vorschlaege"] == int(db.ein_wert("SELECT COUNT(*) FROM matching_vorschlaege"))


def test_umlaute_in_begruendungen() -> None:
    text = labels.mit_umlauten("Kindervertraeglichkeit: Anforderung nicht erfuellt")
    assert text == "Kinderverträglichkeit: Anforderung nicht erfüllt"
    assert labels.gruende_als_liste("A: x | B: y") == ["A: x", "B: y"]
    assert labels.anzeige("pruefung_offen", labels.EIGNUNG) == "Prüfung offen"


def test_tiergalerie_zeigt_nur_verfuegbare_tiere() -> None:
    assert all(t["status"] == "verfuegbar" for t in queries.tiere())
