"""Bewerbungen und Vermittlung.

Jeder Statuswechsel laeuft ueber die Prozeduren der Datenbank. Deren Pruefungen und
Fehlermeldungen werden unveraendert angezeigt - sie sind die eigentliche Absicherung.
"""

from __future__ import annotations

import datetime as dt
from typing import Any

import streamlit as st

import auth
import bausteine
import db
import labels
import queries


def zeige() -> None:
    auth.require(auth.MITARBEITER)
    standort_id = auth.standort_id()
    mitarbeiter_id = auth.mitarbeiter_id()

    st.title("Bewerbungen & Vermittlung")
    if mitarbeiter_id is None:
        st.info(
            "Sie sind als Administration angemeldet und keinem Standort zugeordnet. "
            "Die Prozeduren prüfen, ob der Mitarbeiter zum Standort des Tieres gehört – "
            "zum Ausführen bitte ein Mitarbeiterkonto verwenden."
        )

    reiter_bewerbungen, reiter_vermittlungen = st.tabs(["Bewerbungen", "Vermittlungen"])

    with reiter_bewerbungen:
        _bewerbungen(standort_id, mitarbeiter_id)
    with reiter_vermittlungen:
        _vermittlungen(standort_id, mitarbeiter_id)


def _bewerbungen(standort_id: int | None, mitarbeiter_id: int | None) -> None:
    nur_laufende = st.checkbox("Nur laufende Bewerbungen", value=True)
    try:
        bewerbungen = queries.bewerbungen(standort_id=standort_id, nur_laufende=nur_laufende)
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    if not bewerbungen:
        st.info("Keine Bewerbungen.")
        return

    # Nach Tier gruppieren: konkurrierende Bewerbungen auf dasselbe Tier stehen so
    # sichtbar beieinander, statt chronologisch durchmischt mit anderen Tieren.
    nach_tier: dict[int, list[dict[str, Any]]] = {}
    reihenfolge: list[int] = []
    for bewerbung in bewerbungen:
        tier_id = bewerbung["tier_id"]
        if tier_id not in nach_tier:
            nach_tier[tier_id] = []
            reihenfolge.append(tier_id)
        nach_tier[tier_id].append(bewerbung)

    for tier_id in reihenfolge:
        gruppe = sorted(
            nach_tier[tier_id],
            key=lambda b: (b.get("match_prozent") is None, -(float(b["match_prozent"] or 0))),
        )
        erste = gruppe[0]
        anzahl = len(gruppe)
        st.markdown(
            f"### {erste['tiername']} ({erste['tierart']}) · "
            f"{labels.anzeige(erste['tierstatus'], labels.TIERSTATUS)}"
            + (f" · {anzahl} Bewerbungen" if anzahl > 1 else "")
        )
        for bewerbung in gruppe:
            _bewerbungskarte(bewerbung, mitarbeiter_id)
        st.write("")


def _bewerbungskarte(bewerbung: dict[str, Any], mitarbeiter_id: int | None) -> None:
    score = bewerbung.get("match_prozent")
    reserviert_fuer_diese = bewerbung["reserviert_fuer_bewerbung_id"] == bewerbung["id"]

    with st.container(border=True):
        kopf, wert = st.columns([4, 1])
        with kopf:
            st.markdown(
                f"**{bewerbung['pseudonym']}** (Profil {bewerbung['interessent_id']}) · "
                f"Bewerbung Nr. {bewerbung['id']}"
            )
            st.caption(
                f"{bewerbung['standort']}"
                + (" · für diese Bewerbung reserviert" if reserviert_fuer_diese else "")
                + f" · Status: {labels.anzeige(bewerbung['status'], labels.BEWERBUNGSSTATUS)}"
                + f" · eingegangen {bewerbung['erstellt_am']:%d.%m.%Y}"
            )
            bausteine.notiz_anzeigen(bewerbung.get("notiz"))
        with wert:
            if score is not None:
                st.markdown(
                    f'<span class="{bausteine.score_klasse(float(score))}">'
                    f"{float(score):.1f} %</span>",
                    unsafe_allow_html=True,
                )
            else:
                st.caption(labels.anzeige(bewerbung.get("eignung"), labels.EIGNUNG))

        with st.expander("Passung im Detail"):
            bausteine.kriterien_anzeigen(
                queries.kriterien(bewerbung["tier_id"], bewerbung["interessent_id"])
            )
            paar = queries.paar(bewerbung["tier_id"], bewerbung["interessent_id"]) or {}
            bausteine.gruende_anzeigen(paar)

        with st.expander(f"Termine ({bewerbung['termine']})"):
            for termin in queries.termine(bewerbung_id=bewerbung["id"]):
                st.markdown(
                    f"- {termin['zeitpunkt']:%d.%m.%Y %H:%M} · "
                    f"{labels.anzeige(termin['art'], labels.TERMINART)} mit {termin['mitarbeiter']}"
                )
            _terminformular(bewerbung["id"], mitarbeiter_id)

        _aktionen(bewerbung, mitarbeiter_id, reserviert_fuer_diese)


def _terminformular(bewerbung_id: int, mitarbeiter_id: int | None) -> None:
    if mitarbeiter_id is None:
        return
    with st.form(f"termin_{bewerbung_id}"):
        spalte_a, spalte_b, spalte_c = st.columns(3)
        with spalte_a:
            tag = st.date_input("Tag", value=dt.date.today(), format="DD.MM.YYYY",
                                key=f"tt_{bewerbung_id}")
        with spalte_b:
            uhrzeit = st.time_input("Uhrzeit", value=dt.time(10, 0), key=f"tz_{bewerbung_id}")
        with spalte_c:
            art = st.selectbox("Art", list(labels.TERMINART), key=f"ta_{bewerbung_id}",
                               format_func=lambda w: labels.TERMINART[w])
        if st.form_submit_button("Termin eintragen"):
            try:
                queries.termin_anlegen(
                    bewerbung_id, mitarbeiter_id, dt.datetime.combine(tag, uhrzeit), art)
            except db.DatenbankFehler as fehler:
                bausteine.fehler_anzeigen(fehler)
                return
            st.success("Termin eingetragen.")
            st.rerun()


def _aktionen(bewerbung: dict[str, Any], mitarbeiter_id: int | None,
              reserviert_fuer_diese: bool) -> None:
    if mitarbeiter_id is None:
        return

    knopf = st.columns(4)
    schluessel = bewerbung["id"]

    with knopf[0]:
        if st.button("In Prüfung setzen", key=f"pr_{schluessel}", use_container_width=True,
                     disabled=bewerbung["status"] != "offen"):
            _ausfuehren(lambda: queries.bewerbung_status_setzen(schluessel, "in_pruefung"),
                        "Bewerbung ist jetzt in Prüfung.")

    with knopf[1]:
        if reserviert_fuer_diese:
            if st.button("Reservierung aufheben", key=f"ra_{schluessel}",
                         use_container_width=True):
                _ausfuehren(
                    lambda: queries.reservierung_aufheben(bewerbung["tier_id"], mitarbeiter_id),
                    "Reservierung aufgehoben, das Tier ist wieder verfügbar.")
        elif st.button("Tier reservieren", key=f"re_{schluessel}", use_container_width=True,
                       disabled=bewerbung["status"] in ("abgelehnt", "zurueckgezogen")):
            _ausfuehren(lambda: queries.reservieren(schluessel, mitarbeiter_id),
                        "Tier ist für diese Bewerbung reserviert.")

    with knopf[2]:
        # Spiegelt die Vorbedingung aus sp_vermitteln (Tier verfuegbar/reserviert, Bewerbung
        # offen/in_pruefung) - ein Klick, der ohnehin nur eine Fehlermeldung ausloest, wird
        # erst gar nicht anklickbar angeboten.
        vermitteln_moeglich = (
            bewerbung["tierstatus"] in ("verfuegbar", "reserviert")
            and bewerbung["status"] in ("offen", "in_pruefung")
        )
        if st.button("Vermitteln", key=f"ve_{schluessel}", type="primary",
                     use_container_width=True, disabled=not vermitteln_moeglich):
            _ausfuehren(lambda: queries.vermitteln(schluessel, mitarbeiter_id),
                        "Vermittlung abgeschlossen. Andere offene Bewerbungen für dieses Tier "
                        "wurden automatisch abgelehnt.")

    with knopf[3]:
        if st.button("Ablehnen", key=f"ab_{schluessel}", use_container_width=True,
                     disabled=bewerbung["status"] in ("abgelehnt", "angenommen", "zurueckgezogen")):
            _ausfuehren(lambda: queries.bewerbung_status_setzen(schluessel, "abgelehnt"),
                        "Bewerbung abgelehnt.")


def _vermittlungen(standort_id: int | None, mitarbeiter_id: int | None) -> None:
    try:
        vermittlungen = queries.vermittlungen(standort_id=standort_id)
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    if not vermittlungen:
        st.info("Noch keine Vermittlung.")
        return

    for vermittlung in vermittlungen:
        with st.container(border=True):
            st.markdown(
                f"#### {vermittlung['tiername']} → {vermittlung['pseudonym']} "
                f"(Vermittlung {vermittlung['id']})"
            )
            st.caption(
                f"{vermittlung['standort']} · vermittelt am "
                f"{vermittlung['vermittelt_am']:%d.%m.%Y} von {vermittlung['mitarbeiter']}"
            )
            if vermittlung["beendet_am"]:
                st.markdown(
                    f"**Beendet am {vermittlung['beendet_am']:%d.%m.%Y}** – "
                    f"{labels.anzeige(vermittlung['beendigungsgrund'], labels.BEENDIGUNGSGRUND)}"
                )
                # "Beendet: <grund>" steht schon in der Zeile darueber, deshalb hier nicht
                # nochmal als Systemhinweis zeigen - nur eine echte Notiz, falls vorhanden.
                bausteine.notiz_anzeigen(vermittlung.get("notiz"), eigene_vorsilbe="Notiz")
                continue

            if mitarbeiter_id is None:
                continue
            with st.expander("Vermittlung beenden"):
                with st.form(f"beenden_{vermittlung['id']}"):
                    grund = st.selectbox(
                        "Grund", list(labels.BEENDIGUNGSGRUND),
                        format_func=lambda w: labels.BEENDIGUNGSGRUND[w])
                    notiz = st.text_area("Notiz")
                    st.caption(
                        "Bei einer Rückgabe wird das Tier wieder verfügbar, sonst wird es als "
                        "nicht vermittelbar geführt. Die Vermittlung bleibt als Historie stehen."
                    )
                    if st.form_submit_button("Vermittlung beenden", type="primary"):
                        _ausfuehren(
                            lambda: queries.vermittlung_beenden(
                                vermittlung["id"], mitarbeiter_id, grund, notiz),
                            "Vermittlung beendet.")


def _ausfuehren(aktion: Any, erfolgsmeldung: str) -> None:
    """Eine Prozedur aufrufen und das Ergebnis anzeigen."""
    try:
        aktion()
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return
    st.success(erfolgsmeldung)
    st.rerun()
