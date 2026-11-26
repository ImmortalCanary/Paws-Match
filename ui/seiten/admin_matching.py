"""Stellschrauben des Matchings: Gewichte und Mindestscore.

Beides steht in Tabellen (matching_gewichtung, matching_einstellung), nicht im Code.
Diese Seite zeigt, was eine Aenderung sofort bewirkt.
"""

from __future__ import annotations

import pandas as pd
import streamlit as st

import auth
import bausteine
import db
import labels
import queries


def zeige() -> None:
    auth.require(auth.ADMIN)

    st.title("Matching-Einstellungen")
    st.caption(
        "Die Regeln stehen in der Datenbank. Wer hier etwas ändert, ändert das Matching – "
        "ohne dass jemand SQL anfassen muss."
    )

    try:
        gewichte = queries.gewichtung()
        aktueller_mindestscore = float(queries.mindestscore() or 0)
        vorschlaege_jetzt = len(queries.score_verteilung())
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    links, rechts = st.columns([3, 2])

    with links:
        st.subheader("Gewichte der Kategorien")
        st.caption("Die Summe muss genau 100 ergeben, sonst berechnet die Datenbank keinen Score.")

        tabelle = pd.DataFrame(
            [
                {
                    "Kategorie": labels.KATEGORIE.get(z["kriterium"], z["kriterium"]),
                    "Gewicht": float(z["gewicht"]) if z["gewicht"] is not None else 0.0,
                    "_schluessel": z["kriterium"],
                }
                for z in gewichte
            ]
        )
        bearbeitet = st.data_editor(
            tabelle[["Kategorie", "Gewicht"]],
            use_container_width=True,
            hide_index=True,
            # Alle Kategorien ohne Scrollen zeigen, sonst fehlt die letzte Zeile.
            height=38 + 35 * len(tabelle),
            disabled=["Kategorie"],
            column_config={
                "Gewicht": st.column_config.NumberColumn(min_value=0.0, max_value=100.0, step=1.0)
            },
            key="gewichte",
        )
        summe = float(bearbeitet["Gewicht"].sum())
        if abs(summe - 100.0) < 0.001:
            st.success(f"Summe: {summe:.0f} – passt.")
        else:
            st.error(
                f"Summe: {summe:.0f}. Solange sie nicht genau 100 ergibt, gibt es weder "
                "Score noch Vorschläge – gespeichert wird deshalb erst bei 100."
            )

        if st.button("Gewichte speichern", type="primary",
                     disabled=abs(summe - 100.0) >= 0.001):
            neue = {
                tabelle.loc[nummer, "_schluessel"]: float(zeile["Gewicht"])
                for nummer, zeile in bearbeitet.iterrows()
            }
            try:
                queries.gewichtung_speichern(neue)
            except db.DatenbankFehler as fehler:
                bausteine.fehler_anzeigen(fehler)
                return
            bausteine.flash_setzen("Gewichte gespeichert.")
            st.rerun()

    with rechts:
        st.subheader("Mindestscore")
        st.caption(
            "Ab diesem Wert wird ein geeignetes Paar überhaupt vorgeschlagen "
            "(Schlüssel „mindestscore“)."
        )
        neuer_wert = st.slider(
            "Mindestscore in Prozent", 0.0, 100.0, aktueller_mindestscore, step=5.0
        )

        try:
            treffer = queries.vorschlaege_vorschau(neuer_wert)
        except db.DatenbankFehler as fehler:
            bausteine.fehler_anzeigen(fehler)
            return

        spalte_a, spalte_b = st.columns(2)
        bausteine.kennzahl(spalte_a, vorschlaege_jetzt, "Vorschläge jetzt")
        bausteine.kennzahl(
            spalte_b, treffer, f"bei {neuer_wert:.0f} %", f"{treffer - vorschlaege_jetzt:+d}"
        )

        if st.button("Mindestscore übernehmen", disabled=neuer_wert == aktueller_mindestscore):
            try:
                queries.mindestscore_setzen(neuer_wert)
            except db.DatenbankFehler as fehler:
                bausteine.fehler_anzeigen(fehler)
                return
            bausteine.flash_setzen(f"Mindestscore steht jetzt auf {neuer_wert:.0f} %.")
            st.rerun()

        st.divider()
        st.markdown("**Alle Einstellungen**")
        bausteine.tabelle(queries.einstellungen())
