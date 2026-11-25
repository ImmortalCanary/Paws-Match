"""Anmeldung fuer Mitarbeitende und Administration."""

from __future__ import annotations

import streamlit as st

import auth
import bausteine
import db


def zeige() -> None:
    st.title("Anmeldung für Mitarbeitende")
    st.caption(
        "Interessentinnen und Interessenten brauchen kein Konto – für sie genügt das Profil."
    )

    with st.form("anmeldung"):
        email = st.text_input("E-Mail-Adresse")
        passwort = st.text_input("Passwort", type="password")
        abgeschickt = st.form_submit_button("Anmelden", type="primary")

    if abgeschickt:
        try:
            konto = auth.pruefe_anmeldung(email, passwort)
        except db.DatenbankFehler as fehler:
            bausteine.fehler_anzeigen(fehler)
            return
        if konto is None:
            st.error("E-Mail-Adresse oder Passwort stimmt nicht, oder das Konto ist gesperrt.")
            return
        auth.anmelden(konto)
        st.success(f"Willkommen, {konto.get('mitarbeiter_name') or konto['email']}!")
        bausteine.zur_seite("uebersicht" if konto["rolle"] == auth.MITARBEITER else "matching")

    with st.expander("Demokonten für die Vorführung"):
        st.markdown(
            """
| Konto | Rolle | Passwort |
|---|---|---|
| `team1@example.org` … `team5@example.org` | Mitarbeitende (je ein Standort) | `paws2026` |
| `admin@example.org` | Administration | `paws2026` |

Die Konten legt das Skript `paws_and_match/08_oberflaeche/01_benutzerkonten.sql` an.
Sie gelten ausschließlich für den lokalen Testbetrieb.
            """
        )
