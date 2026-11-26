"""Formularbausteine.

Wichtig fuer das Matching: "Keine Angabe" wird als NULL gespeichert, nicht als Nein.
Nur so kann die Datenbank "Pruefung offen" von "ausgeschlossen" unterscheiden.
"""

from __future__ import annotations

from typing import Any, Sequence

import streamlit as st

import labels

JA_NEIN_OPTIONEN = ["Ja", "Nein", "Keine Angabe"]


def ja_nein(label: str, wert: Any = None, hilfe: str | None = None, key: str | None = None) -> int | None:
    """Ja/Nein/Keine Angabe. Gibt 1, 0 oder None zurueck."""
    vorauswahl = 2 if wert is None else (0 if int(wert) == 1 else 1)
    antwort = st.radio(label, JA_NEIN_OPTIONEN, index=vorauswahl, horizontal=True,
                       help=hilfe, key=key)
    return {"Ja": 1, "Nein": 0, "Keine Angabe": None}[antwort]


def zahl(
    label: str,
    wert: Any = None,
    minimum: float = 0.0,
    maximum: float | None = None,
    schritt: float = 1.0,
    hilfe: str | None = None,
    key: str | None = None,
) -> float | None:
    """Zahleneingabe, die leer bleiben darf (dann NULL)."""
    return st.number_input(
        label,
        min_value=minimum,
        max_value=maximum,
        value=float(wert) if wert is not None else None,
        step=schritt,
        help=hilfe,
        key=key,
        placeholder="keine Angabe",
    )


def auswahl(
    label: str,
    eintraege: Sequence[dict[str, Any]],
    wert: Any = None,
    namensfeld: str = "name",
    idfeld: str = "id",
    leer_text: str = "Keine Angabe",
    hilfe: str | None = None,
    key: str | None = None,
) -> Any:
    """Dropdown ueber eine Katalogtabelle. Gibt die ID zurueck oder None."""
    ids: list[Any] = [None] + [eintrag[idfeld] for eintrag in eintraege]
    namen = {eintrag[idfeld]: labels.mit_umlauten(str(eintrag[namensfeld]))
             for eintrag in eintraege}
    index = ids.index(wert) if wert in ids else 0
    return st.selectbox(
        label, ids, index=index,
        format_func=lambda schluessel: leer_text if schluessel is None else namen[schluessel],
        help=hilfe, key=key,
    )


def mehrfachauswahl(
    label: str,
    eintraege: Sequence[dict[str, Any]],
    werte: Sequence[Any] = (),
    namensfeld: str = "name",
    idfeld: str = "id",
    hilfe: str | None = None,
    key: str | None = None,
) -> list[Any]:
    ids = [eintrag[idfeld] for eintrag in eintraege]
    namen = {eintrag[idfeld]: labels.mit_umlauten(str(eintrag[namensfeld]))
             for eintrag in eintraege}
    return st.multiselect(
        label, ids, default=[w for w in werte if w in ids],
        format_func=lambda schluessel: namen[schluessel], help=hilfe, key=key,
        placeholder="Bitte auswählen",
    )


def stufe(label: str, wert: Any = None, minimum: int = 0, maximum: int = 5,
          hilfe: str | None = None, key: str | None = None) -> int | None:
    """Stufenauswahl 0-5 bzw. 1-5, mit der Moeglichkeit, nichts anzugeben."""
    optionen: list[Any] = [None] + list(range(minimum, maximum + 1))
    index = optionen.index(wert) if wert in optionen else 0
    return st.selectbox(
        label, optionen, index=index,
        format_func=lambda w: "Keine Angabe" if w is None else str(w),
        help=hilfe, key=key,
    )


def erfahrung(label: str, wert: Any = None, hilfe: str | None = None,
             key: str | None = None) -> int | None:
    """Erfahrungsstufe 0-5 als Textkategorie (Keine/Wenig/.../Sehr viel), nicht als Zahl.

    Die Datenbank speichert weiterhin 0-5 (CHECK-Constraint, Score-Formel "Reserve"),
    nur die Anzeige wechselt von Ziffern auf verstaendliche Begriffe.
    """
    optionen: list[Any] = [None] + list(range(0, 6))
    index = optionen.index(wert) if wert in optionen else 0
    return st.selectbox(
        label, optionen, index=index,
        format_func=lambda w: "Keine Angabe" if w is None else labels.ERFAHRUNG[w],
        help=hilfe, key=key,
    )


def entfernung(label: str, wert: Any = None, hilfe: str | None = None,
               key: str | None = None) -> int | None:
    """Die Datenbank erlaubt 5 bis 250 km in Schritten von 5 (ck_interessent_max_entfernung)."""
    optionen: list[Any] = [None] + list(range(5, 255, 5))
    index = optionen.index(int(wert)) if wert is not None and int(wert) in optionen else 0
    return st.selectbox(
        label, optionen, index=index,
        format_func=lambda w: "Egal" if w is None else f"bis {w} km",
        help=hilfe, key=key,
    )
