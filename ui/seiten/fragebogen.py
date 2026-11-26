"""Interessentenprofil: der Fragebogen, aus dem das Matching entsteht."""

from __future__ import annotations

from typing import Any

import streamlit as st

import auth
import bausteine
import db
import formulare
import labels
import queries


def zeige() -> None:
    profil_id = auth.interessent_id()

    if profil_id is None:
        _einstieg()
        if st.session_state.get("fragebogen_neu") is not True:
            return

    try:
        profil = queries.interessent(profil_id) if profil_id else {}
        wuensche = queries.interessent_wuensche(profil_id) if profil_id else {}
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    if profil_id:
        st.title("Mein Profil")
        st.caption(
            "Je vollständiger die Angaben, desto genauer das Matching. "
            "Was Sie offen lassen, wird nicht geraten – es erscheint als „Prüfung offen“."
        )
    else:
        st.title("Ihr Profil – in fünf Schritten zum Match")
        st.caption(
            "Keine Anmeldung nötig. Ihre E-Mail-Adresse dient nur dazu, Ihr Profil "
            "wiederzufinden. Angezeigt wird im Tierheim nur Ihr Anzeigename."
        )

    _formular(profil_id, profil or {}, wuensche or {})

    if profil_id:
        st.divider()
        _profil_loeschen(profil_id)


def _einstieg() -> None:
    """Profil ueber die E-Mail-Adresse wiederfinden oder neu anlegen."""
    st.title("Ihr Profil")
    links, rechts = st.columns(2)

    with links:
        with st.container(border=True):
            st.markdown("#### Ich war schon einmal hier")
            email = st.text_input("E-Mail-Adresse", key="wieder_email")
            if st.button("Profil laden", use_container_width=True):
                try:
                    profil = auth.profil_nach_email(email)
                except db.DatenbankFehler as fehler:
                    bausteine.fehler_anzeigen(fehler)
                    return
                if profil is None:
                    st.warning("Zu dieser Adresse gibt es noch kein Profil.")
                elif not profil["aktiv"]:
                    st.warning(
                        "Dieses Profil wurde gelöscht bzw. anonymisiert und kann nicht mehr "
                        "verwendet werden."
                    )
                else:
                    auth.profil_uebernehmen(profil)
                    st.rerun()

    with rechts:
        with st.container(border=True):
            st.markdown("#### Ich bin neu hier")
            st.write(
                "Fünf kurze Abschnitte zu Wohnung, Haushalt, Alltag und Wünschen – "
                "danach sehen Sie sofort Ihre Vorschläge."
            )
            if st.button("Profil anlegen", type="primary", use_container_width=True):
                st.session_state["fragebogen_neu"] = True
                st.rerun()


def _formular(profil_id: int | None, profil: dict[str, Any], wuensche: dict[str, Any]) -> None:
    # Alle Katalog-/Stammdaten vor dem Formular laden, damit ein DB-Fehler hier verstaendlich
    # abgefangen werden kann, statt das Formular halb aufgebaut abstuerzen zu lassen (analog
    # mitarbeiter_tiere.py._formular).
    try:
        tierarten = queries.tierarten()
        bezirke = queries.bezirke()
        suchzonen = queries.suchzonen()
        wohnformen = queries.wohnformen()
        pflegeaufwaende = queries.pflegeaufwaende()
        arbeitsmodelle = queries.arbeitsmodelle()
        groessen = queries.groessen()
        charakterzuege = queries.charakterzuege()
        standorte = queries.standorte()
        beduerfnisse = queries.beduerfnisse()
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    daten: dict[str, Any] = {}
    neue_wuensche: dict[str, Any] = {}

    with st.form("profil"):
        schritte = st.tabs([
            "1 · Kontakt & Ort", "2 · Wohnen", "3 · Haushalt", "4 · Alltag & Mittel",
            "5 · Wünsche",
        ])

        with schritte[0]:
            daten["pseudonym"] = st.text_input(
                "Anzeigename", value=profil.get("pseudonym") or "",
                help="Unter diesem Namen erscheinen Sie beim Tierheim. Ein Spitzname genügt.",
            )
            daten["email"] = st.text_input(
                "E-Mail-Adresse", value=profil.get("email") or "",
                help="Damit finden Sie Ihr Profil später wieder.",
            )
            daten["bezirk_id"] = formulare.auswahl(
                "Wohnbezirk", bezirke, profil.get("bezirk_id"),
                idfeld="bezirk_id", namensfeld="bezirk", leer_text="Bitte wählen",
                hilfe="Wird für die Entfernung zum Tierheim gebraucht.",
            )
            spalte_a, spalte_b = st.columns(2)
            with spalte_a:
                daten["max_suchzone_id"] = formulare.auswahl(
                    "Wie weit darf gesucht werden?", suchzonen,
                    profil.get("max_suchzone_id"), leer_text="Egal",
                    hilfe="Berlin, Berliner Umland oder ganz Brandenburg. Die Auswahl ist eine feste Grenze.",
                )
            with spalte_b:
                daten["max_entfernung_km"] = formulare.entfernung(
                    "Höchste Entfernung", profil.get("max_entfernung_km"),
                    hilfe="Optionaler Höchstradius ab dem Mittelpunkt Ihres Bezirks. Ohne Angabe gibt es keine Entfernungsgrenze.",
                )

        with schritte[1]:
            spalte_a, spalte_b = st.columns(2)
            with spalte_a:
                daten["wohnflaeche"] = formulare.zahl(
                    "Wohnfläche in m²", profil.get("wohnflaeche"), maximum=1000.0, schritt=5.0)
                daten["wohnform_id"] = formulare.auswahl(
                    "Wohnform", wohnformen, profil.get("wohnform_id"))
                daten["etage"] = formulare.zahl(
                    "Etage", profil.get("etage"), maximum=50.0, schritt=1.0,
                    hilfe="0 bedeutet Erdgeschoss.")
            with spalte_b:
                daten["garten"] = formulare.ja_nein("Garten vorhanden?", profil.get("garten"))
                daten["aufzug"] = formulare.ja_nein("Aufzug vorhanden?", profil.get("aufzug"))
            daten["balkon"] = formulare.ja_nein("Balkon vorhanden?", profil.get("balkon"))
            daten["balkon_gesichert"] = formulare.ja_nein(
                "Falls ja: ist der Balkon gesichert?", profil.get("balkon_gesichert"),
                hilfe="Manche Katzen dürfen nur in Wohnungen mit gesichertem Balkon.")

        with schritte[2]:
            spalte_a, spalte_b = st.columns(2)
            with spalte_a:
                daten["haushaltsgroesse"] = formulare.zahl(
                    "Personen im Haushalt", profil.get("haushaltsgroesse"), minimum=1.0,
                    maximum=20.0, schritt=1.0)
                daten["kinder"] = formulare.ja_nein("Kinder im Haushalt?", profil.get("kinder"))
            with spalte_b:
                daten["hund_vorhanden"] = formulare.ja_nein(
                    "Hund im Haushalt?", profil.get("hund_vorhanden"))
                daten["katze_vorhanden"] = formulare.ja_nein(
                    "Katze im Haushalt?", profil.get("katze_vorhanden"))
                daten["kleintiere_vorhanden"] = formulare.ja_nein(
                    "Kleintiere im Haushalt?", profil.get("kleintiere_vorhanden"))

        with schritte[3]:
            spalte_a, spalte_b = st.columns(2)
            with spalte_a:
                daten["zeit_stunden"] = formulare.zahl(
                    "Zeit für das Tier (Stunden pro Tag)", profil.get("zeit_stunden"),
                    maximum=24.0, schritt=0.5)
                daten["allein_stunden"] = formulare.zahl(
                    "So lange wäre das Tier allein (Stunden pro Tag)",
                    profil.get("allein_stunden"), maximum=24.0, schritt=0.5,
                    hilfe="Zeit und Alleinzeit dürfen zusammen höchstens 24 Stunden ergeben.")
                daten["arbeitsmodell_id"] = formulare.auswahl(
                    "Arbeitssituation", arbeitsmodelle, profil.get("arbeitsmodell_id"))
                daten["budget"] = formulare.zahl(
                    "Budget pro Monat in €", profil.get("budget"), maximum=5000.0, schritt=10.0)
            with spalte_b:
                daten["aktivitaet"] = formulare.stufe(
                    "Eigenes Aktivitätslevel", profil.get("aktivitaet"), minimum=1, maximum=5,
                    hilfe="1 = ruhig, 5 = sehr aktiv.")
                pflege_optionen = pflegeaufwaende
                daten["max_pflegeaufwand_id"] = formulare.auswahl(
                    "Höchster Pflegeaufwand, den Sie leisten möchten",
                    pflege_optionen, profil.get("max_pflegeaufwand_id"),
                    hilfe="Wie viel tägliche Zuwendung über die Grundversorgung hinaus "
                         "Sie leisten können und möchten.")
                _pflegeaufwand_erklaerung(pflege_optionen, daten["max_pflegeaufwand_id"])
            st.markdown("**Wozu wären Sie bereit?**")
            bereit_a, bereit_b, bereit_c = st.columns(3)
            with bereit_a:
                daten["medizin_bereit"] = formulare.ja_nein(
                    "Medikamente geben", profil.get("medizin_bereit"))
            with bereit_b:
                daten["tierarzt_bereit"] = formulare.ja_nein(
                    "Regelmäßig zum Tierarzt", profil.get("tierarzt_bereit"))
            with bereit_c:
                daten["training_bereit"] = formulare.ja_nein(
                    "Training mitmachen", profil.get("training_bereit"))

        with schritte[4]:
            neue_wuensche["tierarten"] = formulare.mehrfachauswahl(
                "Welche Tierarten kommen infrage?", tierarten, wuensche.get("tierarten", []),
                hilfe="Ohne Angabe bleibt die Prüfung offen – es gibt dann keine Vorschläge.")
            neue_wuensche["groessen"] = formulare.mehrfachauswahl(
                "Bevorzugte Tiergröße (mehrere möglich)", groessen,
                wuensche.get("groessen", []),
                hilfe="Nur auswählen, wenn Ihnen die Größe wichtig ist. Ohne Auswahl spielt "
                     "sie beim Matching keine Rolle.")
            st.markdown("**Gewünschtes Alter bei der Aufnahme**")
            st.caption(
                "Wie alt das Tier jetzt sein darf, wenn es zu Ihnen zieht – nicht, wie lange "
                "es voraussichtlich noch lebt."
            )
            spalte_a, spalte_b = st.columns(2)
            with spalte_a:
                daten["wunschalter_min"] = formulare.zahl(
                    "mindestens … Jahre alt", profil.get("wunschalter_min"),
                    maximum=40.0, schritt=1.0)
            with spalte_b:
                daten["wunschalter_max"] = formulare.zahl(
                    "höchstens … Jahre alt", profil.get("wunschalter_max"),
                    maximum=40.0, schritt=1.0)
            neue_wuensche["charakter"] = formulare.mehrfachauswahl(
                "Gewünschte Charakterzüge", charakterzuege,
                wuensche.get("charakter", []))
            neue_wuensche["standorte"] = formulare.mehrfachauswahl(
                "Wunschstandorte (optional)", standorte, wuensche.get("standorte", []))

            st.markdown("**Erfahrung mit dieser Tierart**")
            st.caption(
                "Nur je Tierart – so zählt z. B. Erfahrung mit Kleintieren nicht als "
                "Hundeerfahrung. Ohne Angabe gilt die Prüfung als offen, nicht als Ablehnung; "
                "bei Tieren ohne besondere Anforderung spielt das keine Rolle."
            )
            erfahrung_alt = wuensche.get("erfahrung", {}) or {}
            erfahrungen: dict[int, Any] = {}
            spalten = st.columns(min(3, len(tierarten)) or 1)
            for nummer, tierart in enumerate(tierarten):
                with spalten[nummer % len(spalten)]:
                    erfahrungen[tierart["id"]] = formulare.erfahrung(
                        labels.mit_umlauten(tierart["name"]), erfahrung_alt.get(tierart["id"]),
                        key=f"erf_{tierart['id']}")
            neue_wuensche["erfahrung"] = erfahrungen

            st.markdown("**Besondere Bedürfnisse**")
            st.caption(
                "Manche Tiere brauchen z. B. Vergesellschaftung, Spezialfutter oder einen "
                "ruhigen Haushalt. Was Sie hier bestätigen, kann das Matching berücksichtigen; "
                "was Sie ablehnen, schließt die betroffenen Tiere aus. Medikamente, Training "
                "und gesicherter Balkon stehen schon oben bei „Alltag & Mittel“ bzw. „Wohnen“ "
                "und werden hier nicht noch einmal gefragt."
            )
            beduerfnis_alt = wuensche.get("beduerfnisse", {}) or {}
            antworten: dict[int, Any] = {}
            for beduerfnis in beduerfnisse:
                if beduerfnis["id"] in queries.BEDUERFNIS_MIT_EIGENEM_FELD:
                    continue
                antworten[beduerfnis["id"]] = formulare.ja_nein(
                    labels.mit_umlauten(beduerfnis["name"]), beduerfnis_alt.get(beduerfnis["id"]),
                    key=f"bed_{beduerfnis['id']}")
            neue_wuensche["beduerfnisse"] = antworten

        gespeichert = st.form_submit_button(
            "Profil speichern und Matches ansehen" if profil_id is None else "Änderungen speichern",
            type="primary",
        )

    if not gespeichert:
        return

    if not daten["pseudonym"].strip() or not daten["email"].strip():
        st.error("Anzeigename und E-Mail-Adresse werden gebraucht.")
        return
    if not bausteine.email_gueltig(daten["email"]):
        st.error("Bitte eine gültige E-Mail-Adresse angeben.")
        return
    if daten["bezirk_id"] is None:
        st.error("Bitte einen Wohnbezirk auswählen – ohne ihn kann das Profil nicht aktiv sein.")
        return
    if (
        daten["wunschalter_min"] is not None
        and daten["wunschalter_max"] is not None
        and daten["wunschalter_min"] > daten["wunschalter_max"]
    ):
        st.error(
            "Beim gewünschten Alter darf der Mindestwert nicht über dem Höchstwert liegen."
        )
        return
    if (
        daten["zeit_stunden"] is not None
        and daten["allein_stunden"] is not None
        and daten["zeit_stunden"] + daten["allein_stunden"] > 24
    ):
        st.error("Betreuungszeit und Alleinzeit dürfen zusammen höchstens 24 Stunden ergeben.")
        return

    daten["aktiv"] = 1
    try:
        neue_id = queries.interessent_speichern(daten, neue_wuensche, profil_id)
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    st.session_state.pop("fragebogen_neu", None)
    auth.profil_uebernehmen({"id": neue_id, "email": daten["email"]})
    bausteine.flash_setzen("Profil gespeichert.")
    bausteine.zur_seite("matches")


def _pflegeaufwand_erklaerung(optionen: list[dict[str, Any]], gewaehlt: int | None) -> None:
    """Kurze Erklaerung zur gewaehlten Pflegeaufwand-Kategorie (niedrig/mittel/hoch)."""
    if gewaehlt is None:
        return
    name = next((o["name"] for o in optionen if o["id"] == gewaehlt), None)
    erklaerung = labels.PFLEGEAUFWAND_ERKLAERUNG.get(name)
    if erklaerung:
        st.caption(f"ℹ️ {erklaerung}")


def _profil_loeschen(profil_id: int) -> None:
    with st.expander("Profil löschen"):
        st.write(
            "Ohne Bewerbungen wird das Profil vollständig gelöscht. Gibt es Bewerbungen, "
            "bleibt die Vorgeschichte beim Tierheim erhalten, Ihre persönlichen Daten werden "
            "aber entfernt und offene Bewerbungen zurückgezogen."
        )
        if st.button("Profil endgültig löschen"):
            try:
                ergebnis = queries.interessent_loeschen(profil_id)
            except db.DatenbankFehler as fehler:
                bausteine.fehler_anzeigen(fehler)
                return
            auth.abmelden()
            bausteine.flash_setzen(
                "Profil wurde gelöscht." if ergebnis == "geloescht"
                else "Profil wurde anonymisiert, die Vorgeschichte bleibt beim Tierheim."
            )
            st.rerun()
