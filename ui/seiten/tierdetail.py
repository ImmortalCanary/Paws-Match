"""Tierprofil im Detail - Sprungziel aus Merkliste, Galerie und Matches.

Zeigt immer die Steckbriefdaten; ist ein Interessentenprofil angemeldet, zusaetzlich Score,
Begruendung und die Aktionen Merken/Bewerben - identisch zu "Meine Matches".
"""

from __future__ import annotations

import auth
import bausteine
import db
import labels
import queries
import streamlit as st


def zeige() -> None:
    tier_id = st.session_state.get("detail_tier_id")
    if tier_id is None:
        st.title("Tierprofil")
        st.info("Kein Tier ausgewählt. Bitte über die Galerie, Merkliste oder Matches öffnen.")
        if st.button("Zu den Tieren", type="primary"):
            bausteine.zur_seite("tiere")
        return

    tier = queries.tier(tier_id)
    if tier is None:
        st.title("Tierprofil")
        st.warning("Dieses Tier gibt es nicht (mehr).")
        return

    if st.button("← Zurück"):
        st.session_state.pop("detail_tier_id", None)
        st.rerun()

    kopf, info = st.columns([1, 2])
    with kopf:
        bausteine.tier_kopf(tier)
    with info:
        st.title(tier["tiername"])
        st.caption(bausteine.tier_merkmale(tier))
        ort = tier.get("bezirk") or tier.get("ort")
        st.markdown(
            f"**Status:** {labels.anzeige(tier['status'], labels.TIERSTATUS)} · "
            f"**Standort:** {tier['standort']}" + (f" ({ort})" if ort else "") + "  \n"
            f"**Geschlecht:** {labels.anzeige(tier.get('geschlecht'), labels.GESCHLECHT)}"
        )
        beschreibung = (tier.get("beschreibung") or "").strip()
        if beschreibung:
            st.write(beschreibung)

    spalte_a, spalte_b, spalte_c = st.columns(3)
    with spalte_a:
        st.markdown("**Charakter**")
        for eintrag in queries.tier_charakter(tier_id):
            st.markdown(f"- {labels.mit_umlauten(eintrag['name'])}")
    with spalte_b:
        st.markdown("**Bedürfnisse**")
        for eintrag in queries.tier_beduerfnisse(tier_id):
            st.markdown(f"- {labels.mit_umlauten(eintrag['name'])}")
    with spalte_c:
        st.markdown("**Gesundheit**")
        for eintrag in queries.tier_gesundheit(tier_id):
            zusatz = "bestätigt" if eintrag["bestaetigt"] else "nicht bestätigt"
            belastend = " · belastend" if eintrag["belastend"] else ""
            st.markdown(f"- {labels.mit_umlauten(eintrag['name'])} ({zusatz}{belastend})")

    st.divider()
    profil_id = auth.interessent_id()
    if profil_id is None:
        st.info("Mit einem Profil sehen Sie hier, wie gut dieses Tier zu Ihnen passt.")
        if st.button("Profil ausfüllen", type="primary"):
            bausteine.zur_seite("profil")
        return

    try:
        paar = queries.paar(tier_id, profil_id) or {}
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    score = paar.get("match_prozent")
    if score is not None:
        st.markdown(
            f'<span class="{bausteine.score_klasse(float(score))}">{float(score):.1f} %'
            "</span> Übereinstimmung mit Ihrem Profil",
            unsafe_allow_html=True,
        )
    with st.expander("Warum passt das (nicht)?", expanded=True):
        bausteine.begruendung_anzeigen(profil_id, tier_id)

    gemerkt = tier_id in queries.gemerkte_ids(profil_id)
    beworben = any(
        b["tier_id"] == tier_id for b in queries.bewerbungen(interessent_id=profil_id)
    )
    links, rechts = st.columns(2)
    with links:
        if gemerkt:
            if st.button("Gemerkt ✓", use_container_width=True):
                queries.merken_entfernen(profil_id, tier_id)
                st.rerun()
        elif st.button("Merken", use_container_width=True):
            queries.merken(profil_id, tier_id)
            st.rerun()
    with rechts:
        if beworben:
            st.button("Bereits beworben", disabled=True, use_container_width=True)
        elif tier["status"] != "verfuegbar":
            st.button("Tier nicht verfügbar", disabled=True, use_container_width=True)
        elif st.button("Jetzt bewerben", type="primary", use_container_width=True):
            st.session_state["bewerbung_fuer"] = tier_id
            st.rerun()

    if st.session_state.get("bewerbung_fuer") == tier_id:
        with st.form("bewerbung_detail"):
            st.markdown(f"**Bewerbung für {tier['tiername']}**")
            notiz = st.text_area(
                "Möchten Sie dem Tierheim etwas mitteilen? (freiwillig)",
                placeholder="Zum Beispiel, wann Sie Zeit für ein Kennenlernen hätten.",
            )
            senden, abbrechen = st.columns(2)
            with senden:
                abgeschickt = st.form_submit_button(
                    "Bewerbung absenden", type="primary", use_container_width=True)
            with abbrechen:
                zurueck = st.form_submit_button("Abbrechen", use_container_width=True)

        if zurueck:
            st.session_state.pop("bewerbung_fuer", None)
            st.rerun()
        if abgeschickt:
            try:
                queries.bewerbung_anlegen(profil_id, tier_id, notiz or None)
            except db.DatenbankFehler as fehler:
                bausteine.fehler_anzeigen(fehler)
                return
            st.session_state.pop("bewerbung_fuer", None)
            bausteine.flash_setzen(
                f"Ihre Bewerbung für {tier['tiername']} ist beim Tierheim eingegangen."
            )
            st.rerun()
