"""Anmeldung und Rollentrennung.

Rollen:
- besucher     - nicht angemeldet, sieht nur Startseite und Tiergalerie
- interessent  - hat ein Profil (Wiedererkennung ueber die E-Mail-Adresse, kein Passwort)
- mitarbeiter  - Konto in der Tabelle benutzerkonto, sieht die interne Verwaltung
- admin        - Konto in der Tabelle benutzerkonto, sieht zusaetzlich die Einstellungen

Die reinen Pruefungen (pruefe_anmeldung, darf) kommen ohne Streamlit aus, damit sie
unabhaengig getestet werden koennen.
"""

from __future__ import annotations

from typing import Any

import bcrypt

from db import abfrage, eine_zeile, transaktion
from queries import interessent_nach_email

BESUCHER = "besucher"
INTERESSENT = "interessent"
MITARBEITER = "mitarbeiter"
ADMIN = "admin"

ROLLENNAMEN = {
    BESUCHER: "Besucher",
    INTERESSENT: "Interessent",
    MITARBEITER: "Mitarbeitende",
    ADMIN: "Administration",
}


# --- reine Logik ------------------------------------------------------------------------


def darf(rolle: str | None, benoetigt: str) -> bool:
    """Darf jemand mit dieser Rolle einen Bereich sehen?

    Admin darf alles. Mitarbeitende duerfen ausdruecklich NICHT in die Adminsicht,
    Interessenten in keinen internen Bereich.
    """
    if rolle == ADMIN:
        return True
    if rolle is None:
        rolle = BESUCHER
    if benoetigt == BESUCHER:
        return True
    return rolle == benoetigt


def passwort_hashen(passwort: str) -> str:
    return bcrypt.hashpw(passwort.encode("utf-8"), bcrypt.gensalt(rounds=10)).decode("utf-8")


def passwort_stimmt(passwort: str, hash_wert: str) -> bool:
    try:
        return bcrypt.checkpw(passwort.encode("utf-8"), hash_wert.encode("utf-8"))
    except ValueError:
        return False


def pruefe_anmeldung(email: str, passwort: str) -> dict[str, Any] | None:
    """Konto suchen und Passwort pruefen. Gibt das Konto zurueck oder None."""
    if not email or not passwort:
        return None
    konto = eine_zeile(
        """
        SELECT k.id, k.email, k.passwort_hash, k.rolle, k.aktiv,
               k.mitarbeiter_id, m.name AS mitarbeiter_name,
               m.standort_id, s.name AS standort
        FROM benutzerkonto k
        LEFT JOIN mitarbeiter m ON m.id = k.mitarbeiter_id
        LEFT JOIN standort s ON s.id = m.standort_id
        WHERE k.email = %s
        """,
        [email.strip()],
    )
    if konto is None or not konto["aktiv"]:
        return None
    if not passwort_stimmt(passwort, konto["passwort_hash"]):
        return None
    konto.pop("passwort_hash", None)
    return konto


def profil_nach_email(email: str) -> dict[str, Any] | None:
    """Interessentenprofil ueber die E-Mail-Adresse wiederfinden."""
    if not email:
        return None
    return interessent_nach_email(email.strip())


# --- Kontenverwaltung (Adminbereich) ----------------------------------------------------


def konten() -> list[dict[str, Any]]:
    return abfrage(
        """
        SELECT k.id, k.email, k.rolle, k.aktiv, k.angelegt_am,
               m.name AS mitarbeiter, s.name AS standort
        FROM benutzerkonto k
        LEFT JOIN mitarbeiter m ON m.id = k.mitarbeiter_id
        LEFT JOIN standort s ON s.id = m.standort_id
        ORDER BY k.rolle, k.email
        """
    )


def konto_anlegen(email: str, passwort: str, rolle: str, mitarbeiter_id: int | None) -> int:
    with transaktion() as cursor:
        cursor.execute(
            "INSERT INTO benutzerkonto (email, passwort_hash, rolle, mitarbeiter_id)"
            " VALUES (%s, %s, %s, %s)",
            (email.strip(), passwort_hashen(passwort), rolle, mitarbeiter_id),
        )
        return cursor.lastrowid


def konto_passwort_setzen(konto_id: int, passwort: str) -> None:
    with transaktion() as cursor:
        cursor.execute(
            "UPDATE benutzerkonto SET passwort_hash = %s WHERE id = %s",
            (passwort_hashen(passwort), konto_id),
        )


def konto_aktiv_setzen(konto_id: int, aktiv: bool) -> None:
    with transaktion() as cursor:
        cursor.execute(
            "UPDATE benutzerkonto SET aktiv = %s WHERE id = %s", (1 if aktiv else 0, konto_id)
        )


# --- Sitzung (nur innerhalb von Streamlit) ----------------------------------------------


def _sitzung() -> Any:
    import streamlit as st

    return st.session_state


def anmelden(konto: dict[str, Any]) -> None:
    sitzung = _sitzung()
    sitzung["konto"] = konto
    sitzung["rolle"] = konto["rolle"]
    sitzung.pop("interessent_id", None)


def profil_uebernehmen(profil: dict[str, Any]) -> None:
    """Ein Interessentenprofil in die Sitzung legen (kein Passwort noetig)."""
    sitzung = _sitzung()
    sitzung["interessent_id"] = profil["id"]
    sitzung["interessent_email"] = profil["email"]
    sitzung["rolle"] = INTERESSENT
    sitzung.pop("konto", None)


def abmelden() -> None:
    sitzung = _sitzung()
    for schluessel in ("konto", "rolle", "interessent_id", "interessent_email", "fragebogen"):
        sitzung.pop(schluessel, None)


def rolle() -> str:
    return _sitzung().get("rolle", BESUCHER)


def konto() -> dict[str, Any] | None:
    return _sitzung().get("konto")


def interessent_id() -> int | None:
    return _sitzung().get("interessent_id")


def mitarbeiter_id() -> int | None:
    angemeldet = konto()
    return angemeldet.get("mitarbeiter_id") if angemeldet else None


def standort_id() -> int | None:
    angemeldet = konto()
    return angemeldet.get("standort_id") if angemeldet else None


def require(benoetigt: str) -> None:
    """Zugriffsschutz am Anfang jeder geschuetzten Seite."""
    import streamlit as st

    if darf(rolle(), benoetigt):
        return
    st.error(
        f"Dieser Bereich ist nur für {ROLLENNAMEN.get(benoetigt, benoetigt)} zugänglich. "
        "Bitte melden Sie sich mit einem passenden Konto an."
    )
    st.stop()
