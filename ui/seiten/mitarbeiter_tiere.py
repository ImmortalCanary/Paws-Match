"""Tiere verwalten: anlegen, bearbeiten und passende Menschen finden."""

from __future__ import annotations

import datetime as dt
import uuid
from typing import Any

import streamlit as st

import auth
import bausteine
import db
import formulare
import labels
import queries

_FLASH_KEY = "_flash_tiere"


def zeige() -> None:
    auth.require(auth.MITARBEITER)
    standort_id = auth.standort_id()

    st.title("Tiere verwalten")

    # Flash-Pattern: st.success() unmittelbar vor st.rerun() wuerde nie sichtbar gerendert
    # werden (der Rerun bricht den aktuellen Durchlauf sofort ab). Die Meldung wird deshalb
    # beim Speichern/Loeschen nur in session_state abgelegt und hier, am Anfang des naechsten
    # Durchlaufs, einmalig ausgelesen, angezeigt und wieder entfernt.
    flash = st.session_state.pop(_FLASH_KEY, None)
    if flash:
        st.success(flash)

    reiter_liste, reiter_neu = st.tabs(["Tiere am Standort", "Neues Tier aufnehmen"])

    with reiter_liste:
        _liste(standort_id)
    with reiter_neu:
        _formular(None, standort_id)


def _liste(standort_id: int | None) -> None:
    status = st.selectbox(
        "Status", [None, "verfuegbar", "reserviert", "vermittelt", "nicht_vermittelbar"],
        format_func=lambda w: "Alle" if w is None else labels.TIERSTATUS[w],
    )
    try:
        tiere = queries.tiere(nur_verfuegbar=False, standort_id=standort_id, status=status)
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    if not tiere:
        st.info("Keine Tiere gefunden.")
        return

    auswahl = st.selectbox(
        "Tier auswählen",
        [t["id"] for t in tiere],
        format_func=lambda i: next(
            f"{t['tiername']} ({t['tierart']}) – {labels.anzeige(t['status'], labels.TIERSTATUS)}"
            for t in tiere if t["id"] == i
        ),
    )
    bausteine.tabelle(
        tiere, ["id", "tiername", "tierart", "rasse", "groesse", "status", "alter_jahre"]
    )

    if auswahl is None:
        return
    st.divider()
    _detail(auswahl)


def _detail(tier_id: int) -> None:
    tier = queries.tier(tier_id)
    if tier is None:
        return

    kopf, rest = st.columns([1, 3])
    with kopf:
        bausteine.tier_kopf(tier)
    with rest:
        st.markdown(f"### {tier['tiername']}")
        st.caption(bausteine.tier_merkmale(tier))
        st.markdown(
            f"**Status:** {labels.anzeige(tier['status'], labels.TIERSTATUS)} · "
            f"**Standort:** {tier['standort']} · "
            f"**Geschlecht:** {labels.anzeige(tier['geschlecht'], labels.GESCHLECHT)}"
        )
        if tier.get("beschreibung"):
            st.write(tier["beschreibung"])

    merkmale = st.columns(3)
    with merkmale[0]:
        st.markdown("**Charakter**")
        for eintrag in queries.tier_charakter(tier_id):
            st.markdown(f"- {labels.mit_umlauten(eintrag['name'])}")
    with merkmale[1]:
        st.markdown("**Bedürfnisse**")
        for eintrag in queries.tier_beduerfnisse(tier_id):
            st.markdown(f"- {labels.mit_umlauten(eintrag['name'])}")
    with merkmale[2]:
        st.markdown("**Gesundheit**")
        for eintrag in queries.tier_gesundheit(tier_id):
            zusatz = "bestätigt" if eintrag["bestaetigt"] else "nicht bestätigt"
            belastend = " · belastend" if eintrag["belastend"] else ""
            st.markdown(f"- {labels.mit_umlauten(eintrag['name'])} ({zusatz}{belastend})")

    with st.expander("Passende Menschen zu diesem Tier"):
        try:
            vorschlaege = queries.vorschlaege_fuer_tier(tier_id)
        except db.DatenbankFehler as fehler:
            bausteine.fehler_anzeigen(fehler)
            vorschlaege = []
        if not vorschlaege:
            st.caption("Keine Vorschläge – das Tier ist nicht verfügbar oder niemand passt.")
        for vorschlag in vorschlaege:
            score = float(vorschlag["match_prozent"])
            with st.container(border=True):
                oben, wert = st.columns([4, 1])
                with oben:
                    st.markdown(f"**{vorschlag['pseudonym']}** (Profil {vorschlag['interessent_id']})")
                    st.caption(
                        f"Wohnbezirk: {vorschlag.get('interessenten_bezirk') or 'unbekannt'}"
                        + (f" · rund {float(vorschlag['entfernung_km']):.0f} km"
                           if vorschlag.get("entfernung_km") is not None else "")
                    )
                with wert:
                    st.markdown(
                        f'<span class="{bausteine.score_klasse(score)}">{score:.1f} %</span>',
                        unsafe_allow_html=True,
                    )
                bausteine.kriterien_anzeigen(
                    queries.kriterien(tier_id, vorschlag["interessent_id"])
                )

    with st.expander("Tier bearbeiten"):
        _formular(tier_id, tier["standort_id"])

    with st.expander("Tier löschen"):
        st.write(
            "Ohne vorhandene Bewerbungshistorie wird das Tier vollständig gelöscht. Gab es "
            "schon mindestens eine Bewerbung, wird es stattdessen archiviert und bleibt in "
            "der Vorgeschichte beim Tierheim erhalten – ein Hard-Delete ist dann nicht "
            "möglich."
        )
        sicher = st.checkbox(
            "Ich bin sicher, dass dieses Tier gelöscht werden soll.",
            key=f"loeschen_sicher_{tier_id}",
        )
        if st.button(
            "Tier endgültig löschen", disabled=not sicher, key=f"loeschen_btn_{tier_id}"
        ):
            try:
                with st.spinner("Wird gelöscht …"):
                    ergebnis = queries.tier_loeschen(
                        tier_id, auth.mitarbeiter_id(), auth.rolle() == auth.ADMIN
                    )
            except db.DatenbankFehler as fehler:
                bausteine.fehler_anzeigen(fehler)
            else:
                st.session_state[_FLASH_KEY] = (
                    "Tier wurde gelöscht." if ergebnis == "geloescht"
                    else "Tier wurde archiviert, die Vorgeschichte bleibt beim Tierheim erhalten."
                )
                st.rerun()


def _formular(tier_id: int | None, standort_id: int | None) -> None:
    ist_admin = auth.rolle() == auth.ADMIN
    mitarbeiter_id = auth.mitarbeiter_id()

    # Idempotenz-Token fuer das Neuanlegen (tier_id is None): pro Formularinstanz einmal
    # erzeugt und ueber Reruns hinweg wiederverwendet (session_state uebersteht einen
    # st.rerun()), damit ein zweiter Klick/ein haengender Request kein zweites Tier anlegt -
    # siehe queries.tier_speichern/_token_reservieren fuer die eigentliche serverseitige
    # Sperre (tier_anlage_token, PK-Eindeutigkeit als Mutex). Bearbeiten bestehender Tiere
    # braucht keinen Token (UPDATE ist bereits idempotent).
    token_schluessel = f"tier_token_{tier_id or 'neu'}"
    if tier_id is None and token_schluessel not in st.session_state:
        st.session_state[token_schluessel] = uuid.uuid4().hex

    # Alle Katalog-/Stammdaten vor dem Formular laden, damit ein DB-Fehler hier verstaendlich
    # abgefangen werden kann, statt das Formular halb aufgebaut abstuerzen zu lassen.
    try:
        rohdaten: dict[str, Any] = queries.tier_rohdaten(tier_id) if tier_id else {}
        tierarten = queries.tierarten()
        alle_rassen = [
            {"id": r["id"], "name": f"{r['tierart']}: {r['name']}"} for r in queries.rassen()
        ]
        groessen = queries.groessen()
        pflegeaufwaende = queries.pflegeaufwaende()
        standorte = queries.standorte()
        charakterzuege = queries.charakterzuege()
        beduerfnisse = queries.beduerfnisse()
        tier_charakter_ids = (
            [e["id"] for e in queries.tier_charakter(tier_id)] if tier_id else []
        )
        tier_beduerfnis_ids = (
            [e["id"] for e in queries.tier_beduerfnisse(tier_id)] if tier_id else []
        )
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    daten: dict[str, Any] = {}

    with st.form(f"tier_{tier_id or 'neu'}"):
        reiter = st.tabs(["Steckbrief", "Anforderungen", "Charakter & Bedürfnisse"])

        with reiter[0]:
            spalte_a, spalte_b = st.columns(2)
            with spalte_a:
                daten["name"] = st.text_input("Name", value=rohdaten.get("name") or "")
                daten["tierart_id"] = formulare.auswahl(
                    "Tierart", tierarten, rohdaten.get("tierart_id"), leer_text="Bitte wählen")
                # Alle Rassen mit Tierart davor: die Auswahl oben wirkt erst nach dem
                # Speichern, und die Datenbank prueft ohnehin, dass beides zusammenpasst.
                daten["rasse_id"] = formulare.auswahl(
                    "Rasse", alle_rassen, rohdaten.get("rasse_id"))
                daten["groesse_id"] = formulare.auswahl(
                    "Größe", groessen, rohdaten.get("groesse_id"))
                daten["pflegeaufwand_id"] = formulare.auswahl(
                    "Pflegeaufwand", pflegeaufwaende, rohdaten.get("pflegeaufwand_id"))
            with spalte_b:
                # Standortberechtigung: normale Mitarbeitende duerfen nur am eigenen Standort
                # anlegen/bearbeiten - das Dropdown zeigt ihnen deshalb gar nicht erst eine
                # Auswahl ueber alle Standorte. Die eigentliche Durchsetzung liegt serverseitig
                # im DB-Trigger (tier_speichern setzt @pm_mitarbeiter_id/@pm_ist_admin); dies
                # hier ist nur die passende UI dazu, keine zusaetzliche Sicherheitsgrenze.
                eigener_standort_id = rohdaten.get("standort_id") or standort_id
                if ist_admin:
                    daten["standort_id"] = formulare.auswahl(
                        "Standort", standorte, eigener_standort_id, leer_text="Bitte wählen")
                else:
                    eigener_name = next(
                        (s["name"] for s in standorte if s["id"] == eigener_standort_id),
                        "unbekannt",
                    )
                    st.text_input(
                        "Standort", value=eigener_name, disabled=True,
                        help="Mitarbeitende können Tiere nur am eigenen Standort anlegen "
                             "oder bearbeiten.",
                    )
                    daten["standort_id"] = eigener_standort_id
                daten["geburtsdatum"] = st.date_input(
                    "Geburtsdatum", value=rohdaten.get("geburtsdatum"),
                    min_value=dt.date(1990, 1, 1), max_value=dt.date.today(), format="DD.MM.YYYY")
                daten["geburt_geschaetzt"] = 1 if st.checkbox(
                    "Geburtsdatum geschätzt", value=bool(rohdaten.get("geburt_geschaetzt"))) else 0
                daten["geschlecht"] = st.selectbox(
                    "Geschlecht", ["weiblich", "maennlich", "unbekannt"],
                    index=["weiblich", "maennlich", "unbekannt"].index(
                        rohdaten.get("geschlecht") or "unbekannt"),
                    format_func=lambda w: labels.GESCHLECHT[w])
                daten["gewicht_kg"] = formulare.zahl(
                    "Gewicht in kg", rohdaten.get("gewicht_kg"), maximum=200.0, schritt=0.5)
            daten["beschreibung"] = st.text_area(
                "Beschreibung", value=rohdaten.get("beschreibung") or "")
            daten["foto_url"] = st.text_input(
                "Foto (Adresse im Netz)", value=rohdaten.get("foto_url") or "")

        with reiter[1]:
            spalte_a, spalte_b = st.columns(2)
            with spalte_a:
                daten["aktivitaet"] = formulare.stufe(
                    "Aktivitätslevel", rohdaten.get("aktivitaet"), minimum=1, maximum=5)
                daten["min_wohnflaeche"] = formulare.zahl(
                    "Mindestwohnfläche in m²", rohdaten.get("min_wohnflaeche"), maximum=500.0,
                    schritt=5.0)
                daten["min_zeit"] = formulare.zahl(
                    "Mindestbetreuung in Stunden/Tag", rohdaten.get("min_zeit"), maximum=24.0,
                    schritt=0.5)
                daten["max_allein"] = formulare.zahl(
                    "Höchstens allein in Stunden/Tag", rohdaten.get("max_allein"), maximum=24.0,
                    schritt=0.5)
                daten["min_erfahrung"] = formulare.erfahrung(
                    "Nötige Erfahrung mit dieser Tierart", rohdaten.get("min_erfahrung"),
                    hilfe="Bei Tieren ohne besondere Anforderung „Keine Erfahrung“ wählen – "
                         "dann blockiert fehlende Angabe beim Interessenten kein Matching.")
                daten["monatskosten"] = formulare.zahl(
                    "Erwartete Kosten pro Monat in €", rohdaten.get("monatskosten"),
                    maximum=3000.0, schritt=10.0)
            with spalte_b:
                daten["garten_noetig"] = formulare.ja_nein(
                    "Garten nötig?", rohdaten.get("garten_noetig"), key=f"g_{tier_id}")
                daten["treppen_vermeiden"] = formulare.ja_nein(
                    "Treppen vermeiden?", rohdaten.get("treppen_vermeiden"), key=f"t_{tier_id}")
                daten["medizin_noetig"] = formulare.ja_nein(
                    "Medizinische Versorgung nötig?", rohdaten.get("medizin_noetig"),
                    key=f"m_{tier_id}")
            st.markdown("**Verträglichkeit**")
            vertraeglich = st.columns(4)
            with vertraeglich[0]:
                daten["kinder_ok"] = formulare.ja_nein("Kinder", rohdaten.get("kinder_ok"),
                                                       key=f"ki_{tier_id}")
            with vertraeglich[1]:
                daten["hund_ok"] = formulare.ja_nein("Hunde", rohdaten.get("hund_ok"),
                                                     key=f"hu_{tier_id}")
            with vertraeglich[2]:
                daten["katze_ok"] = formulare.ja_nein("Katzen", rohdaten.get("katze_ok"),
                                                      key=f"ka_{tier_id}")
            with vertraeglich[3]:
                daten["kleintiere_ok"] = formulare.ja_nein(
                    "Kleintiere", rohdaten.get("kleintiere_ok"), key=f"kl_{tier_id}")

        with reiter[2]:
            charakter_ids = formulare.mehrfachauswahl(
                "Charakterzüge", charakterzuege, tier_charakter_ids, key=f"ch_{tier_id}")
            beduerfnis_ids = formulare.mehrfachauswahl(
                "Verbindliche Bedürfnisse", beduerfnisse, tier_beduerfnis_ids,
                key=f"be_{tier_id}",
                hilfe="Diese Bedürfnisse müssen Interessenten ausdrücklich bestätigen.")

        gespeichert = st.form_submit_button(
            "Änderungen speichern" if tier_id else "Tier aufnehmen", type="primary")

    if not gespeichert:
        return
    if not daten["name"].strip() or not daten["tierart_id"] or not daten["standort_id"]:
        st.error("Name, Tierart und Standort werden gebraucht.")
        return
    # Clientseitige Vorwegnahme von ck_tier_tagesstunden (analog fragebogen.py) - erspart
    # eine Runde zur Datenbank, wenn beides zusammen schon offensichtlich zu viel ist.
    if (
        daten["min_zeit"] is not None
        and daten["max_allein"] is not None
        and daten["min_zeit"] + daten["max_allein"] > 24
    ):
        st.error(
            "Mindestbetreuung und Alleinzeit dürfen zusammen höchstens 24 Stunden ergeben."
        )
        return

    # Gespeicherten XSS ueber foto_url verhindern: nur plausible Bild-URLs akzeptieren statt
    # jeden Text ungeprueft zu uebernehmen (siehe bausteine.foto_url_gueltig).
    foto_url = (daten.get("foto_url") or "").strip()
    daten["foto_url"] = foto_url or None
    if foto_url and not bausteine.foto_url_gueltig(foto_url):
        st.error(
            "Die Foto-Adresse muss mit http:// oder https:// beginnen und auf eine "
            "Bilddatei verweisen (z. B. .jpg, .jpeg, .png, .gif, .webp)."
        )
        return

    anlage_token = st.session_state.get(token_schluessel) if tier_id is None else None
    try:
        with st.spinner("Wird gespeichert …"):
            neue_id = queries.tier_speichern(
                daten, charakter_ids, beduerfnis_ids, tier_id,
                mitarbeiter_id=mitarbeiter_id, ist_admin=ist_admin, anlage_token=anlage_token,
            )
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return
    if tier_id is None:
        # Verbrauchten Token entfernen, damit das naechste "Neues Tier aufnehmen" einen neuen
        # bekommt - sonst wuerde ein zweites, tatsaechlich neues Tier wegen desselben Tokens
        # faelschlich als Duplikat der Idempotenzsperre behandelt.
        st.session_state.pop(token_schluessel, None)
    # Flash-Pattern statt st.success() direkt vor st.rerun() (siehe zeige()) - sonst wird die
    # Meldung durch den sofortigen Rerun nie sichtbar gerendert.
    st.session_state[_FLASH_KEY] = f"Gespeichert (Tier-Nr. {neue_id})."
    st.rerun()
