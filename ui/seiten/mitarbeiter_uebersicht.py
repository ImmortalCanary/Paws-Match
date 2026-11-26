"""Uebersicht fuer Mitarbeitende: Lage am eigenen Standort."""

from __future__ import annotations

import streamlit as st

import auth
import bausteine
import db
import labels
import queries


def zeige() -> None:
    auth.require(auth.MITARBEITER)

    konto = auth.konto() or {}
    standort_id = auth.standort_id()
    st.title("Übersicht")
    st.caption(
        f"Standort: {konto.get('standort', 'alle Standorte')}"
        if standort_id else "Administration: alle Standorte"
    )

    try:
        tiere = queries.tiere(nur_verfuegbar=False, standort_id=standort_id)
        offene = queries.bewerbungen(standort_id=standort_id, nur_laufende=True)
        naechste = queries.termine(standort_id=standort_id, ab_jetzt=True)
        laufende = queries.vermittlungen(standort_id=standort_id, nur_aktive=True)
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    spalten = st.columns(4)
    bausteine.kennzahl(spalten[0], len(tiere), "Tiere am Standort")
    bausteine.kennzahl(
        spalten[1], sum(1 for t in tiere if t["status"] == "verfuegbar"), "davon verfügbar")
    bausteine.kennzahl(spalten[2], len(offene), "Offene Bewerbungen")
    bausteine.kennzahl(spalten[3], len(laufende), "Laufende Vermittlungen")

    st.divider()
    links, rechts = st.columns(2)

    with links:
        st.subheader("Bewerbungen, die auf Sie warten")
        if not offene:
            st.caption("Nichts offen.")
        for bewerbung in offene[:8]:
            score = bewerbung.get("match_prozent")
            st.markdown(
                f"- **{bewerbung['tiername']}** ← {bewerbung['pseudonym']} · "
                f"{labels.anzeige(bewerbung['status'], labels.BEWERBUNGSSTATUS)}"
                + (f" · Match {float(score):.1f} %" if score is not None else "")
            )
        if offene and st.button("Zu den Bewerbungen", type="primary"):
            bausteine.zur_seite("vermittlung")

    with rechts:
        st.subheader("Nächste Termine")
        if not naechste:
            st.caption("Keine Termine geplant.")
        for termin in naechste[:8]:
            st.markdown(
                f"- {termin['zeitpunkt']:%d.%m.%Y %H:%M} · "
                f"{labels.anzeige(termin['art'], labels.TERMINART)}: "
                f"{termin['tiername']} mit {termin['pseudonym']}"
            )

    st.divider()
    st.subheader("Tiere am Standort")
    bausteine.tabelle(
        tiere,
        ["id", "tiername", "tierart", "rasse", "groesse", "status", "alter_jahre", "standort"],
    )
