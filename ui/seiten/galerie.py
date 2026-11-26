"""Oeffentliche Tiergalerie: stoebern ohne Profil, Score gibt es erst mit Profil."""

from __future__ import annotations

from typing import Any

import streamlit as st

import auth
import bausteine
import db
import labels
import queries


def zeige() -> None:
    st.title("Tiere entdecken")
    st.caption(
        "Alle Tiere, die gerade ein Zuhause suchen. Wie gut eines davon zu Ihnen passt, "
        "sagt Ihnen das Matching – dafür brauchen wir Ihr Profil."
    )

    try:
        f1, f2, f3, f4 = st.columns(4)
        with f1:
            tierart_id = _auswahl("Tierart", queries.tierarten())
        with f2:
            groesse_id = _auswahl("Größe", queries.groessen())
        with f3:
            bezirk_id = _auswahl(
                "Bezirk", queries.bezirke(), idfeld="bezirk_id", namensfeld="bezirk")
        with f4:
            standort_id = _auswahl("Standort", queries.standorte())

        tiere = queries.tiere(
            nur_verfuegbar=True, tierart_id=tierart_id, groesse_id=groesse_id,
            bezirk_id=bezirk_id, standort_id=standort_id,
        )

        gemerkt: set[int] = set()
        profil_id = auth.interessent_id()
        if profil_id:
            gemerkt = queries.gemerkte_ids(profil_id)
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    st.write(f"**{len(tiere)}** Tiere gefunden.")
    if not tiere:
        st.info("Mit diesen Filtern wartet gerade kein Tier. Bitte Filter zurücksetzen.")
        return

    spalten = st.columns(3)
    for nummer, tier in enumerate(tiere):
        with spalten[nummer % 3]:
            _karte(tier, profil_id, tier["id"] in gemerkt)


def _auswahl(label: str, eintraege: list[dict[str, Any]], idfeld: str = "id",
             namensfeld: str = "name") -> Any:
    ids: list[Any] = [None] + [e[idfeld] for e in eintraege]
    namen = {e[idfeld]: str(e[namensfeld]) for e in eintraege}
    return st.selectbox(
        label, ids, format_func=lambda s: "Alle" if s is None else namen[s], key=f"filter_{label}"
    )


def _karte(tier: dict[str, Any], profil_id: int | None, ist_gemerkt: bool) -> None:
    with st.container(border=True):
        bausteine.tier_kopf(tier)
        if st.button(f"🔎 {tier['tiername']}", key=f"detail_{tier['id']}",
                     help="Ganzes Tierprofil ansehen"):
            bausteine.zu_tier(tier["id"])
        st.caption(bausteine.tier_merkmale(tier))
        beschreibung = (tier.get("beschreibung") or "").strip()
        if beschreibung:
            st.write(beschreibung[:160] + ("…" if len(beschreibung) > 160 else ""))
        ort = tier.get("bezirk") or tier.get("ort")
        st.caption(
            f"{labels.anzeige(tier.get('geschlecht'), labels.GESCHLECHT)} · "
            f"{tier.get('standort')}" + (f" ({ort})" if ort else "")
        )

        if profil_id:
            links, rechts = st.columns(2)
            with links:
                if ist_gemerkt:
                    if st.button("Gemerkt ✓", key=f"merk_{tier['id']}", use_container_width=True):
                        try:
                            queries.merken_entfernen(profil_id, tier["id"])
                        except db.DatenbankFehler as fehler:
                            bausteine.fehler_anzeigen(fehler)
                        else:
                            st.rerun()
                elif st.button("Merken", key=f"merk_{tier['id']}", use_container_width=True):
                    try:
                        queries.merken(profil_id, tier["id"])
                    except db.DatenbankFehler as fehler:
                        bausteine.fehler_anzeigen(fehler)
                    else:
                        st.rerun()
            with rechts:
                if st.button("Passt das?", key=f"match_{tier['id']}", use_container_width=True,
                             type="primary"):
                    st.session_state["match_tier_id"] = tier["id"]
                    bausteine.zur_seite("matches")
        elif st.button("Passt das zu mir?", key=f"cta_{tier['id']}", use_container_width=True,
                       type="primary"):
            bausteine.zur_seite("profil")
