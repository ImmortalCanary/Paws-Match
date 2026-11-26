"""Auswertung: was das Matching ueber den gesamten Bestand sagt."""

from __future__ import annotations

import altair as alt
import pandas as pd
import streamlit as st

import auth
import bausteine
import db
import labels
import queries

# Statusfarben (fest, nie fuer Serien verwendet) - an das Farbsystem aus bausteine.py
# angelehnt (dieselben Toene wie die Score-Badges): Salbeigruen fuer "gut"/Mengenbalken,
# Bernstein fuer "offen", gedaempftes Rot fuer "kritisch". Bewusst kein zusaetzlicher
# Blauton mehr, um nicht eine weitere Farbfamilie einzufuehren (Meeting-Feedback P6-1).
FARBE_GUT = "#3D7A5F"
FARBE_OFFEN = "#D79B3D"
FARBE_KRITISCH = "#B8463E"
FARBE_MENGE = "#4F8670"

INK = "#52514e"
MUTED = "#898781"
GITTER = "#e1e0d9"
ACHSE = "#c3c2b7"


def _grundform(diagramm: alt.Chart) -> alt.Chart:
    """Einheitliche, zurueckhaltende Achsen und Gitterlinien."""
    return (
        diagramm.configure_view(stroke=None)
        .configure_axis(
            labelColor=INK, titleColor=MUTED, labelFontSize=12, titleFontSize=11,
            gridColor=GITTER, domainColor=ACHSE, tickColor=ACHSE, labelPadding=6,
        )
        .configure_axisY(grid=False)
        .configure_text(color=INK)
    )


def zeige() -> None:
    auth.require(auth.ADMIN)

    st.title("Auswertung")
    st.caption("Alle Zahlen kommen direkt aus den Views der Datenbank.")

    try:
        eignung = queries.eignungsverteilung()
        scores = queries.score_verteilung()
        je_standort = queries.vorschlaege_je_standort()
        tierstatus = queries.tiere_je_status()
        vermittlungen = queries.vermittlungen_je_standort()
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    gesamt = sum(int(z["paare"]) for z in eignung)
    kennzahlen = st.columns(4)
    bausteine.kennzahl(kennzahlen[0], gesamt, "Geprüfte Paare")
    bausteine.kennzahl(kennzahlen[1], len(scores), "Vorschläge")
    if scores:
        werte = [float(z["match_prozent"]) for z in scores]
        bausteine.kennzahl(kennzahlen[2], f"{sum(werte) / len(werte):.1f} %", "Ø Übereinstimmung")
        bausteine.kennzahl(kennzahlen[3], f"{max(werte):.1f} %", "Bester Wert")

    st.divider()
    links, rechts = st.columns(2)

    with links:
        st.subheader("Wie die Paare ausgehen")
        st.caption(
            "Dass die meisten Paare ausscheiden, ist gewollt: Schon der Tierartwunsch "
            "sortiert das meiste aus."
        )
        _eignungsdiagramm(eignung, gesamt)

    with rechts:
        st.subheader("Wie gut die Vorschläge passen")
        st.caption("Verteilung der Übereinstimmung über alle Vorschläge.")
        _scorediagramm(scores)

    st.divider()
    links, rechts = st.columns(2)

    with links:
        st.subheader("Vorschläge je Standort")
        _standortdiagramm(je_standort)
    with rechts:
        st.subheader("Tiere nach Status")
        _statusdiagramm(tierstatus)

    st.divider()
    st.subheader("Vermittlungen je Standort")
    bausteine.tabelle(vermittlungen)

    with st.expander("Zahlen als Tabelle"):
        st.markdown("**Eignung**")
        bausteine.tabelle(eignung)
        st.markdown("**Vorschläge je Standort**")
        bausteine.tabelle(je_standort)


def _eignungsdiagramm(eignung: list[dict], gesamt: int) -> None:
    if not eignung:
        st.info("Keine Daten.")
        return
    reihenfolge = ["geeignet", "pruefung_offen", "ausgeschlossen"]
    symbole = {"geeignet": "🟢", "pruefung_offen": "🟡", "ausgeschlossen": "🔴"}
    daten = pd.DataFrame(
        [
            {
                "Eignung": f"{symbole[z['eignung']]} {labels.EIGNUNG[z['eignung']]}",
                "Paare": int(z["paare"]),
                "Anteil": f"{100 * int(z['paare']) / gesamt:.1f} %" if gesamt else "",
                "_reihe": reihenfolge.index(z["eignung"]),
                "_farbe": {"geeignet": FARBE_GUT, "pruefung_offen": FARBE_OFFEN,
                           "ausgeschlossen": FARBE_KRITISCH}[z["eignung"]],
            }
            for z in eignung
            if z["eignung"] in reihenfolge
        ]
    ).sort_values("_reihe")

    balken = (
        alt.Chart(daten)
        .mark_bar(height=26, cornerRadiusEnd=4)
        .encode(
            x=alt.X("Paare:Q", title="Paare"),
            y=alt.Y("Eignung:N", sort=list(daten["Eignung"]), title=None,
                    axis=alt.Axis(labelLimit=260)),
            color=alt.Color("_farbe:N", scale=None, legend=None),
            tooltip=["Eignung", "Paare", "Anteil"],
        )
    )
    beschriftung = balken.mark_text(align="left", dx=6, fontSize=12, color=INK).encode(
        text=alt.Text("Anteil:N"), color=alt.value(INK)
    )
    st.altair_chart(_grundform((balken + beschriftung).properties(height=60 + 40 * len(daten))),
                    use_container_width=True)


def _scorediagramm(scores: list[dict]) -> None:
    if not scores:
        st.info("Zurzeit gibt es keine Vorschläge.")
        return
    daten = pd.DataFrame({"Übereinstimmung": [float(z["match_prozent"]) for z in scores]})
    diagramm = (
        alt.Chart(daten)
        .mark_bar(cornerRadiusEnd=4, color=FARBE_MENGE)
        .encode(
            x=alt.X("Übereinstimmung:Q", bin=alt.Bin(step=5), title="Übereinstimmung in %",
                    axis=alt.Axis(format="d")),
            y=alt.Y("count():Q", title="Vorschläge"),
            tooltip=[alt.Tooltip("count():Q", title="Vorschläge")],
        )
        .properties(height=240)
    )
    st.altair_chart(_grundform(diagramm), use_container_width=True)


def _standortdiagramm(je_standort: list[dict]) -> None:
    if not je_standort:
        st.info("Keine Vorschläge.")
        return
    daten = pd.DataFrame(
        [
            {"Standort": z["standort"], "Vorschläge": int(z["vorschlaege"]),
             "Ø Match": f"{float(z['schnitt']):.1f} %"}
            for z in je_standort[:10]
        ]
    )
    balken = (
        alt.Chart(daten)
        .mark_bar(height=24, cornerRadiusEnd=4, color=FARBE_MENGE)
        .encode(
            x=alt.X("Vorschläge:Q", title="Vorschläge"),
            y=alt.Y("Standort:N", sort="-x", title=None,
                    axis=alt.Axis(labelLimit=260)),
            tooltip=["Standort", "Vorschläge", "Ø Match"],
        )
    )
    beschriftung = balken.mark_text(align="left", dx=6, fontSize=12).encode(
        text=alt.Text("Vorschläge:Q"), color=alt.value(INK)
    )
    # Je Zeile genug Platz, sonst laesst Vega Beschriftungen weg.
    hoehe = 60 + 40 * len(daten)
    st.altair_chart(_grundform((balken + beschriftung).properties(height=hoehe)),
                    use_container_width=True)


def _statusdiagramm(tierstatus: list[dict]) -> None:
    if not tierstatus:
        st.info("Keine Tiere.")
        return
    daten = pd.DataFrame(
        [{"Status": labels.TIERSTATUS.get(z["status"], z["status"]), "Tiere": int(z["anzahl"])}
         for z in tierstatus]
    )
    balken = (
        alt.Chart(daten)
        .mark_bar(height=24, cornerRadiusEnd=4, color=FARBE_MENGE)
        .encode(
            x=alt.X("Tiere:Q", title="Tiere"),
            y=alt.Y("Status:N", sort="-x", title=None,
                    axis=alt.Axis(labelLimit=260)),
            tooltip=["Status", "Tiere"],
        )
    )
    beschriftung = balken.mark_text(align="left", dx=6, fontSize=12).encode(
        text=alt.Text("Tiere:Q"), color=alt.value(INK)
    )
    # Je Zeile genug Platz, sonst laesst Vega Beschriftungen weg.
    hoehe = 60 + 40 * len(daten)
    st.altair_chart(_grundform((balken + beschriftung).properties(height=hoehe)),
                    use_container_width=True)
