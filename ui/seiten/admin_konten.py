"""Konten und Stammdaten: wer darf sich anmelden, und was steht in den Katalogen."""

from __future__ import annotations

import streamlit as st

import auth
import bausteine
import db
import queries


def zeige() -> None:
    auth.require(auth.ADMIN)

    st.title("Konten & Stammdaten")

    reiter_konten, reiter_organisation, reiter_kataloge = st.tabs(
        ["Benutzerkonten", "Tierheime & Mitarbeitende", "Kataloge"]
    )

    with reiter_konten:
        _konten()
    with reiter_organisation:
        _organisation()
    with reiter_kataloge:
        _kataloge()


def _konten() -> None:
    try:
        konten = auth.konten()
    except db.DatenbankFehler as fehler:
        bausteine.fehler_anzeigen(fehler)
        return

    bausteine.tabelle(konten, ["id", "email", "rolle", "mitarbeiter", "standort", "aktiv"])

    st.divider()
    links, rechts = st.columns(2)

    with links:
        st.subheader("Konto anlegen")
        with st.form("konto_neu"):
            email = st.text_input("E-Mail-Adresse")
            passwort = st.text_input("Passwort", type="password")
            rolle = st.selectbox("Rolle", [auth.MITARBEITER, auth.ADMIN],
                                 format_func=lambda r: auth.ROLLENNAMEN[r])
            ohne_konto = [
                m for m in queries.mitarbeitende()
                if m["id"] not in {k.get("mitarbeiter_id") for k in konten}
            ]
            mitarbeiter_id = st.selectbox(
                "Mitarbeiter (nur bei Rolle Mitarbeitende)",
                [None] + [m["id"] for m in queries.mitarbeitende()],
                format_func=lambda i: "–" if i is None else next(
                    f"{m['name']} ({m['standort']})" for m in queries.mitarbeitende()
                    if m["id"] == i),
            )
            if ohne_konto:
                st.caption(
                    "Noch ohne Konto: "
                    + ", ".join(f"{m['name']}" for m in ohne_konto[:5])
                )
            if st.form_submit_button("Konto anlegen", type="primary"):
                if not email or not passwort:
                    st.error("E-Mail und Passwort werden gebraucht.")
                else:
                    try:
                        auth.konto_anlegen(
                            email, passwort, rolle,
                            mitarbeiter_id if rolle == auth.MITARBEITER else None)
                    except db.DatenbankFehler as fehler:
                        bausteine.fehler_anzeigen(fehler)
                    else:
                        st.success("Konto angelegt.")
                        st.rerun()

    with rechts:
        st.subheader("Konto ändern")
        if not konten:
            return
        konto_id = st.selectbox(
            "Konto", [k["id"] for k in konten],
            format_func=lambda i: next(k["email"] for k in konten if k["id"] == i),
        )
        gewaehlt = next(k for k in konten if k["id"] == konto_id)
        neues_passwort = st.text_input("Neues Passwort", type="password", key="pw_neu")
        spalte_a, spalte_b = st.columns(2)
        with spalte_a:
            if st.button("Passwort setzen", disabled=not neues_passwort,
                         use_container_width=True):
                try:
                    auth.konto_passwort_setzen(konto_id, neues_passwort)
                except db.DatenbankFehler as fehler:
                    bausteine.fehler_anzeigen(fehler)
                else:
                    st.success("Passwort geändert.")
        with spalte_b:
            text = "Sperren" if gewaehlt["aktiv"] else "Freischalten"
            if st.button(text, use_container_width=True):
                try:
                    auth.konto_aktiv_setzen(konto_id, not gewaehlt["aktiv"])
                except db.DatenbankFehler as fehler:
                    bausteine.fehler_anzeigen(fehler)
                else:
                    st.rerun()


def _organisation() -> None:
    st.subheader("Standorte")
    bausteine.tabelle(
        queries.standorte(), ["id", "name", "art", "tierheim", "ort", "bezirk", "plz", "kapazitaet"]
    )
    st.subheader("Mitarbeitende")
    bausteine.tabelle(queries.mitarbeitende(), ["id", "name", "email", "standort"])
    st.subheader("Interessentenprofile")
    bausteine.tabelle(
        queries.interessenten(nur_aktive=False),
        ["id", "pseudonym", "email", "bezirk", "aktiv", "bewerbungen", "vorschlaege"],
    )


def _kataloge() -> None:
    kataloge = {
        "Tierarten": queries.tierarten(),
        "Rassen": queries.rassen(),
        "Charakterzüge": queries.charakterzuege(),
        "Bedürfnisse": queries.beduerfnisse(),
        "Größen": queries.groessen(),
        "Pflegeaufwand": queries.pflegeaufwaende(),
        "Wohnformen": queries.wohnformen(),
        "Arbeitsmodelle": queries.arbeitsmodelle(),
        "Gesundheitsmerkmale": queries.gesundheitsmerkmale(),
        "Bezirke": queries.bezirke(),
        "Suchzonen": queries.suchzonen(),
    }
    auswahl = st.selectbox("Katalog", list(kataloge))
    bausteine.tabelle(kataloge[auswahl])
