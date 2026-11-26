"""Meine Bewerbungen, Termine und die Merkliste."""

from __future__ import annotations

import streamlit as st

import auth
import bausteine
import db
import labels
import queries


def zeige() -> None:
    profil_id = auth.interessent_id()
    if profil_id is None:
        st.title("Meine Bewerbungen")
        st.info("Bitte zuerst das Profil ausfüllen.")
        if st.button("Profil ausfüllen", type="primary"):
            bausteine.zur_seite("profil")
        return

    st.title("Meine Bewerbungen")

    try:
        bewerbungen = queries.bewerbungen(interessent_id=profil_id)
        merkliste = queries.merkliste(profil_id)
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    if not bewerbungen:
        st.info("Noch keine Bewerbung abgeschickt.")
    for bewerbung in bewerbungen:
        with st.container(border=True):
            kopf, status = st.columns([4, 1])
            with kopf:
                st.markdown(f"#### {bewerbung['tiername']} ({bewerbung['tierart']})")
                st.caption(
                    f"{bewerbung['standort']} · eingegangen am "
                    f"{bewerbung['erstellt_am']:%d.%m.%Y}"
                )
            with status:
                st.markdown(
                    f"**{labels.anzeige(bewerbung['status'], labels.BEWERBUNGSSTATUS)}**"
                )
            bausteine.notiz_anzeigen(bewerbung.get("notiz"), eigene_vorsilbe="Ihre Notiz")

            try:
                termine = queries.termine(bewerbung_id=bewerbung["id"])
            except db.DatenbankFehler as fehler:
                bausteine.fehler_anzeigen(fehler)
                termine = []
            if termine:
                st.markdown("**Termine**")
                for termin in termine:
                    st.markdown(
                        f"- {termin['zeitpunkt']:%d.%m.%Y %H:%M} · "
                        f"{labels.anzeige(termin['art'], labels.TERMINART)} mit "
                        f"{termin['mitarbeiter']}"
                    )

            if bewerbung["status"] in ("offen", "in_pruefung"):
                if st.button("Bewerbung zurückziehen", key=f"zurueck_{bewerbung['id']}"):
                    try:
                        queries.bewerbung_status_setzen(bewerbung["id"], "zurueckgezogen")
                    except db.DatenbankFehler as fehler:
                        bausteine.fehler_anzeigen(fehler)
                        return
                    bausteine.flash_setzen("Bewerbung zurückgezogen.")
                    st.rerun()

    st.divider()
    st.subheader("Merkliste")
    if not merkliste:
        st.caption("Noch nichts gemerkt.")
    for eintrag in merkliste:
        spalte_name, spalte_oeffnen, spalte_entfernen = st.columns([4, 1, 1])
        with spalte_name:
            st.markdown(
                f"**{eintrag['tiername']}** ({eintrag['tierart']}) · {eintrag['standort']} · "
                f"{labels.anzeige(eintrag['tierstatus'], labels.TIERSTATUS)}"
            )
        with spalte_oeffnen:
            if st.button("Ansehen", key=f"merk_auf_{eintrag['tier_id']}",
                        use_container_width=True):
                bausteine.zu_tier(eintrag["tier_id"])
        with spalte_entfernen:
            if st.button("Entfernen", key=f"merk_weg_{eintrag['tier_id']}",
                        use_container_width=True):
                try:
                    queries.merken_entfernen(profil_id, eintrag["tier_id"])
                except db.DatenbankFehler as fehler:
                    bausteine.fehler_anzeigen(fehler)
                else:
                    st.rerun()
