"""Paws & Match - Oberflaeche zur Tierheim-Datenbank.

Start:  streamlit run ui/app.py   (aus dem Projektordner, mit aktivem .venv)
"""

from __future__ import annotations

import sys
from pathlib import Path

import streamlit as st

sys.path.insert(0, str(Path(__file__).resolve().parent))

import auth  # noqa: E402
import bausteine  # noqa: E402
import db  # noqa: E402

st.set_page_config(
    page_title="Paws & Match",
    page_icon="🐾",
    layout="wide",
    initial_sidebar_state="expanded",
)
bausteine.stil_laden()

from seiten import (  # noqa: E402
    admin_auswertung,
    admin_konten,
    admin_matching,
    anmelden,
    fragebogen,
    galerie,
    matches,
    meine_bewerbungen,
    mitarbeiter_prozess,
    mitarbeiter_tiere,
    mitarbeiter_uebersicht,
    start,
    tierdetail,
)


def seitenleiste() -> None:
    with st.sidebar:
        st.markdown("## 🐾 Paws & Match")
        rolle = auth.rolle()

        if rolle == auth.INTERESSENT:
            st.success(f"Angemeldet als Profil: {st.session_state.get('interessent_email', '')}")
        elif rolle in (auth.MITARBEITER, auth.ADMIN):
            konto = auth.konto() or {}
            name = konto.get("mitarbeiter_name") or konto.get("email")
            st.success(f"{auth.ROLLENNAMEN[rolle]}: {name}")
            if konto.get("standort"):
                st.caption(f"Standort: {konto['standort']}")
        else:
            st.caption("Nicht angemeldet")

        if rolle != auth.BESUCHER and st.button("Abmelden", use_container_width=True):
            auth.abmelden()
            st.rerun()

        st.divider()
        erreichbar, meldung = db.ist_erreichbar()
        if erreichbar:
            st.caption("Datenbank verbunden")
        else:
            st.error(meldung)


def seiten() -> dict[str, list[st.Page]]:
    rolle = auth.rolle()

    oeffentlich = [
        # Die Startseite liegt auf "/", ein eigener url_path waere dort eine tote Adresse.
        st.Page(start.zeige, title="Start", icon="🏠", default=True),
        st.Page(galerie.zeige, title="Tiere entdecken", icon="🐾", url_path="tiere"),
        st.Page(tierdetail.zeige, title="Tierprofil", icon="🔎", url_path="tierdetail"),
    ]
    bereiche: dict[str, list[st.Page]] = {"Entdecken": oeffentlich}

    if rolle == auth.INTERESSENT:
        bereiche["Mein Bereich"] = [
            st.Page(matches.zeige, title="Meine Matches", icon="💛", url_path="matches"),
            st.Page(fragebogen.zeige, title="Mein Profil", icon="📝", url_path="profil"),
            st.Page(meine_bewerbungen.zeige, title="Meine Bewerbungen", icon="📬",
                    url_path="bewerbungen"),
        ]
    elif rolle == auth.BESUCHER:
        bereiche["Mein Bereich"] = [
            st.Page(fragebogen.zeige, title="Profil anlegen", icon="📝", url_path="profil"),
        ]

    if auth.darf(rolle, auth.MITARBEITER):
        bereiche["Tierheim"] = [
            st.Page(mitarbeiter_uebersicht.zeige, title="Übersicht", icon="📊",
                    url_path="uebersicht"),
            st.Page(mitarbeiter_tiere.zeige, title="Tiere verwalten", icon="🏠",
                    url_path="tiere-verwalten"),
            st.Page(mitarbeiter_prozess.zeige, title="Bewerbungen & Vermittlung", icon="🤝",
                    url_path="vermittlung"),
        ]

    if auth.darf(rolle, auth.ADMIN):
        bereiche["Administration"] = [
            st.Page(admin_matching.zeige, title="Matching-Einstellungen", icon="⚖️",
                    url_path="matching"),
            st.Page(admin_auswertung.zeige, title="Auswertung", icon="📈", url_path="auswertung"),
            st.Page(admin_konten.zeige, title="Konten & Stammdaten", icon="🔑", url_path="konten"),
        ]

    if rolle in (auth.BESUCHER, auth.INTERESSENT):
        bereiche["Intern"] = [
            st.Page(anmelden.zeige, title="Für Mitarbeitende", icon="🔒", url_path="anmelden"),
        ]

    return bereiche


seitenleiste()

bereiche = seiten()
# Damit Buttons auf anderen Seiten gezielt umschalten koennen (bausteine.zur_seite).
st.session_state["seiten"] = {
    seite.url_path: seite for liste in bereiche.values() for seite in liste
}
navigation = st.navigation(bereiche)

# Nach einem Rollenwechsel (Anmeldung, Profil geladen) steht hier das gewuenschte Ziel.
ziel = st.session_state.pop("ziel", None)
if ziel and ziel in st.session_state["seiten"]:
    st.switch_page(st.session_state["seiten"][ziel])

navigation.run()
