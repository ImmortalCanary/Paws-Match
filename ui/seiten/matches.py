"""Meine Matches: Vorschlaege mit Begruendung, plus der ehrliche Blick auf alle anderen Tiere."""

from __future__ import annotations

from typing import Any

import streamlit as st

import auth
import bausteine
import db
import labels
import queries


def zeige() -> None:
    profil_id = auth.interessent_id()
    if profil_id is None:
        st.title("Meine Matches")
        st.info("Dafür brauchen wir zuerst Ihr Profil.")
        if st.button("Profil ausfüllen", type="primary"):
            bausteine.zur_seite("profil")
        return

    profil = queries.interessent(profil_id)
    if profil is None:
        auth.abmelden()
        st.warning("Das Profil gibt es nicht mehr.")
        return

    st.title(f"Passt zu {profil['pseudonym']}")
    st.caption(
        "Berechnet aus Ihren Angaben – jede Empfehlung lässt sich aufklappen und nachlesen."
    )

    try:
        vorschlaege_alle = queries.vorschlaege_fuer_interessent(profil_id)
        uebersicht_alle = queries.uebersicht_fuer_interessent(profil_id)
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    _einzelnes_tier(profil_id, uebersicht_alle)

    vorschlaege, uebersicht = _filter_anwenden(vorschlaege_alle, uebersicht_alle)

    reiter_a, reiter_b = st.tabs(
        [f"Meine Vorschläge ({len(vorschlaege)})", f"Alle Tiere ({len(uebersicht)})"]
    )

    with reiter_a:
        if not vorschlaege_alle:
            st.info(
                "Im Moment gibt es keinen Vorschlag. Im Reiter „Alle Tiere“ steht bei jedem "
                "Tier, woran es liegt – oft fehlen nur ein paar Angaben im Profil."
            )
        elif not vorschlaege:
            st.info("Mit diesen Filtern ist gerade kein Vorschlag zu sehen. Bitte Filter anpassen.")
        gemerkt = queries.gemerkte_ids(profil_id)
        beworben = {b["tier_id"] for b in queries.bewerbungen(interessent_id=profil_id)}
        for vorschlag in vorschlaege:
            _vorschlagskarte(profil_id, vorschlag, vorschlag["tier_id"] in gemerkt,
                             vorschlag["tier_id"] in beworben)

    with reiter_b:
        st.caption(
            "Warum ein Tier nicht vorgeschlagen wird, ist genauso wichtig wie der Vorschlag "
            "selbst. 🟢 geeignet · 🟡 Angaben fehlen · 🔴 ausgeschlossen"
        )
        eignungen = sorted({z["eignung"] for z in uebersicht})
        gewaehlte_eignung = st.multiselect(
            "Status",
            eignungen,
            format_func=lambda e: f"{labels.EIGNUNG_AMPEL.get(e, '')} {labels.mit_umlauten(e)}".strip(),
            key="matches_filter_eignung",
        )
        sichtbar = [
            z for z in uebersicht if not gewaehlte_eignung or z["eignung"] in gewaehlte_eignung
        ]
        if not uebersicht:
            st.info("Mit diesen Filtern ist gerade kein Tier zu sehen. Bitte Filter anpassen.")
        elif not sichtbar:
            st.info("Mit diesem Status ist gerade kein Tier zu sehen. Bitte Auswahl anpassen.")
        for zeile in sichtbar:
            _uebersichtszeile(zeile, profil_id)


def _filter_anwenden(
    vorschlaege: list[dict[str, Any]], uebersicht: list[dict[str, Any]]
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Rein python-seitige Filterung der bereits von der Datenbank gelieferten Listen.

    Keine neue Matching-Logik: es werden nur Zeilen aus `vorschlaege`/`uebersicht`
    (bzw. je Tier `queries.tier_gesundheit`) weggelassen, nichts neu berechnet.
    """
    tierarten = sorted({z["tierart"] for z in uebersicht if z.get("tierart")})

    with st.container(border=True):
        st.markdown("**Filter**")
        spalte_a, spalte_b, spalte_c = st.columns([2, 2, 2])
        with spalte_a:
            gewaehlte_tierarten = st.multiselect(
                "Tierart", tierarten, key="matches_filter_tierart"
            )
        with spalte_b:
            mindestscore = st.slider(
                "Mindest-Score (%)", 0, 100, 0, step=5, key="matches_filter_score"
            )
        with spalte_c:
            nur_ohne_belastung = st.checkbox(
                "Nur ohne belastende Gesundheitsmerkmale", key="matches_filter_gesundheit"
            )

    belastete_tiere: set[int] = set()
    if nur_ohne_belastung:
        alle_tier_ids = {z["tier_id"] for z in uebersicht} | {v["tier_id"] for v in vorschlaege}
        for tier_id in alle_tier_ids:
            try:
                merkmale = queries.tier_gesundheit(tier_id)
            except db.DatenbankFehler as fehler:
                bausteine.fehler_anzeigen(fehler)
                nur_ohne_belastung = False
                belastete_tiere.clear()
                break
            if any(m.get("belastend") for m in merkmale):
                belastete_tiere.add(tier_id)

    def _behalten(zeile: dict[str, Any]) -> bool:
        if gewaehlte_tierarten and zeile.get("tierart") not in gewaehlte_tierarten:
            return False
        if mindestscore > 0:
            score = zeile.get("match_prozent")
            if score is None or float(score) < mindestscore:
                return False
        if nur_ohne_belastung and zeile["tier_id"] in belastete_tiere:
            return False
        return True

    return (
        [v for v in vorschlaege if _behalten(v)],
        [z for z in uebersicht if _behalten(z)],
    )


def _einzelnes_tier(profil_id: int, uebersicht: list[dict[str, Any]]) -> None:
    """Wenn aus der Galerie ein bestimmtes Tier gewaehlt wurde, dieses zuerst zeigen."""
    tier_id = st.session_state.pop("match_tier_id", None)
    if tier_id is None:
        return
    treffer = next((z for z in uebersicht if z["tier_id"] == tier_id), None)
    if treffer is None:
        return
    with st.container(border=True):
        ampel = labels.EIGNUNG_AMPEL.get(treffer["eignung"], "")
        st.markdown(f"### {ampel} {treffer['tiername']} – {labels.mit_umlauten(treffer['vorschlagsstatus'])}")
        bausteine.begruendung_anzeigen(profil_id, treffer["tier_id"])


def _vorschlagskarte(profil_id: int, vorschlag: dict[str, Any], gemerkt: bool,
                     beworben: bool) -> None:
    tier = queries.tier(vorschlag["tier_id"]) or {}
    score = float(vorschlag["match_prozent"]) if vorschlag.get("match_prozent") is not None else None

    with st.container(border=True):
        bild, text, wert = st.columns([1, 3, 1])
        with bild:
            bausteine.tier_kopf(tier)
        with text:
            st.markdown(f"#### {vorschlag['tiername']}")
            st.caption(bausteine.tier_merkmale(tier))
            entfernung = vorschlag.get("entfernung_km")
            ort = vorschlag["standort"]
            if vorschlag.get("standort_bezirk"):
                ort += f" ({vorschlag['standort_bezirk']})"
            if entfernung is not None:
                ort += f" · rund {float(entfernung):.0f} km entfernt"
            st.caption(ort)
            beschreibung = (tier.get("beschreibung") or "").strip()
            if beschreibung:
                st.write(beschreibung)
        with wert:
            st.markdown(
                f'<div style="text-align:center"><span class="{bausteine.score_klasse(score)}">'
                f'{score:.1f} %</span><br><span style="font-size:.78rem;color:#7A7262">'
                f'Übereinstimmung</span></div>',
                unsafe_allow_html=True,
            )
            abdeckung = vorschlag.get("datenabdeckung_prozent")
            if abdeckung is not None:
                st.caption(f"Datenbasis: {float(abdeckung):.0f} %")

        with st.expander("Warum passt das?"):
            bausteine.begruendung_anzeigen(profil_id, vorschlag["tier_id"])

        links, rechts = st.columns(2)
        with links:
            if gemerkt:
                if st.button("Gemerkt ✓", key=f"vm_{vorschlag['tier_id']}",
                             use_container_width=True):
                    queries.merken_entfernen(profil_id, vorschlag["tier_id"])
                    st.rerun()
            elif st.button("Merken", key=f"vm_{vorschlag['tier_id']}", use_container_width=True):
                queries.merken(profil_id, vorschlag["tier_id"])
                st.rerun()
        with rechts:
            if beworben:
                st.button("Bereits beworben", key=f"vb_{vorschlag['tier_id']}", disabled=True,
                          use_container_width=True)
            elif st.button("Jetzt bewerben", key=f"vb_{vorschlag['tier_id']}", type="primary",
                           use_container_width=True):
                st.session_state["bewerbung_fuer"] = vorschlag["tier_id"]
                st.rerun()

        if st.session_state.get("bewerbung_fuer") == vorschlag["tier_id"]:
            _bewerbungsformular(profil_id, vorschlag["tier_id"], vorschlag["tiername"])


def _bewerbungsformular(profil_id: int, tier_id: int, tiername: str) -> None:
    with st.form(f"bewerbung_{tier_id}"):
        st.markdown(f"**Bewerbung für {tiername}**")
        notiz = st.text_area(
            "Möchten Sie dem Tierheim etwas mitteilen? (freiwillig)",
            placeholder="Zum Beispiel, wann Sie Zeit für ein Kennenlernen hätten.",
        )
        senden, abbrechen = st.columns(2)
        with senden:
            abgeschickt = st.form_submit_button("Bewerbung absenden", type="primary",
                                                use_container_width=True)
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
        bausteine.flash_setzen(f"Ihre Bewerbung für {tiername} ist beim Tierheim eingegangen.")
        st.rerun()


def _uebersichtszeile(zeile: dict[str, Any], profil_id: int) -> None:
    ampel = labels.EIGNUNG_AMPEL.get(zeile["eignung"], "")
    score = zeile.get("match_prozent")
    score_text = f"{float(score):.1f} %" if score is not None else "kein Score"
    titel = (
        f"{ampel} {zeile['tiername']} ({zeile['tierart']}) – {score_text} · "
        f"{labels.mit_umlauten(zeile['vorschlagsstatus'])}"
    )
    with st.expander(titel):
        bausteine.gruende_anzeigen(zeile)
        if zeile["eignung"] != "ausgeschlossen":
            bausteine.kriterien_anzeigen(queries.kriterien(zeile["tier_id"], profil_id))
