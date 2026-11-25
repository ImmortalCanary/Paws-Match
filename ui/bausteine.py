"""Wiederverwendbare Anzeigebausteine: Tierkarten, Score-Anzeige, Begruendungen, Tabellen."""

from __future__ import annotations

from typing import Any, Sequence

import pandas as pd
import streamlit as st

import labels
import queries

CSS = """
<style>
.block-container { padding-top: 2.2rem; max-width: 1150px; }

.pm-held {
    background: linear-gradient(135deg, #E0603C 0%, #F0A15E 100%);
    color: #FFFBF5; border-radius: 22px; padding: 2.6rem 2.4rem; margin-bottom: 1.6rem;
}
.pm-held h1 { color: #FFFBF5; font-size: 2.6rem; margin: 0 0 .6rem 0; line-height: 1.15; }
.pm-held p { font-size: 1.12rem; margin: 0; opacity: .95; }

.pm-karte {
    background: #FFFFFF; border: 1px solid #F0DFCD; border-radius: 16px;
    padding: 1.1rem 1.2rem; margin-bottom: .9rem; height: 100%;
}
.pm-karte h4 { margin: 0 0 .25rem 0; font-size: 1.18rem; }
.pm-karte .pm-unterzeile { color: #7A6A5D; font-size: .9rem; margin-bottom: .5rem; }
.pm-karte p { margin: .25rem 0; font-size: .94rem; }

.pm-schritt {
    background: #FFFFFF; border: 1px solid #F0DFCD; border-radius: 16px;
    padding: 1.1rem 1.2rem; height: 100%;
}
.pm-schritt .pm-nummer {
    display: inline-flex; align-items: center; justify-content: center;
    width: 2rem; height: 2rem; border-radius: 50%;
    background: #E0603C; color: #fff; font-weight: 700; margin-bottom: .5rem;
}

.pm-score {
    display: inline-block; border-radius: 999px; padding: .18rem .8rem;
    font-weight: 700; font-size: 1rem; background: #E0603C; color: #fff;
}
.pm-score-mittel { background: #E09B3C; }
.pm-score-niedrig { background: #9C8878; }

.pm-marke {
    display: inline-block; border-radius: 999px; padding: .1rem .6rem;
    font-size: .8rem; background: #FDF0E3; color: #7A5A42; margin-right: .3rem;
}
.pm-foto {
    width: 100%; height: 170px; object-fit: cover; border-radius: 12px; margin-bottom: .6rem;
}
.pm-foto-leer {
    width: 100%; height: 170px; border-radius: 12px; margin-bottom: .6rem;
    background: #FDF0E3; display: flex; align-items: center; justify-content: center;
    font-size: 3rem;
}
</style>
"""

TIERART_SYMBOL = {
    "Hund": "🐕", "Katze": "🐈", "Kaninchen": "🐇", "Meerschweinchen": "🐹",
    "Vogel": "🐦", "Reptil": "🦎", "Fisch": "🐠",
}


def stil_laden() -> None:
    st.markdown(CSS, unsafe_allow_html=True)


def symbol(tierart: str | None) -> str:
    return TIERART_SYMBOL.get(tierart or "", "🐾")


def score_klasse(wert: float | None) -> str:
    if wert is None:
        return "pm-score pm-score-niedrig"
    if wert >= 80:
        return "pm-score"
    if wert >= 60:
        return "pm-score pm-score-mittel"
    return "pm-score pm-score-niedrig"


def alter_text(zeile: dict[str, Any]) -> str:
    jahre = zeile.get("alter_jahre")
    if jahre is None:
        return "Alter unbekannt"
    etwa = "ca. " if zeile.get("geburt_geschaetzt") else ""
    return f"{etwa}{jahre} Jahr" + ("e" if jahre != 1 else "")


def tier_kopf(zeile: dict[str, Any]) -> None:
    """Foto bzw. Platzhalter, Name und Kurzangaben eines Tieres."""
    foto = zeile.get("foto_url")
    if foto:
        st.markdown(f'<img class="pm-foto" src="{foto}">', unsafe_allow_html=True)
    else:
        st.markdown(
            f'<div class="pm-foto-leer">{symbol(zeile.get("tierart"))}</div>',
            unsafe_allow_html=True,
        )


def tier_merkmale(zeile: dict[str, Any]) -> str:
    teile = [zeile.get("tierart"), zeile.get("rasse"), zeile.get("groesse"), alter_text(zeile)]
    return " · ".join(labels.mit_umlauten(str(t)) for t in teile if t)


def gruende_anzeigen(zeile: dict[str, Any]) -> None:
    """Ausschlussgruende und offene Pruefungen im Klartext."""
    for grund in labels.gruende_als_liste(zeile.get("ausschlussgruende")):
        st.markdown(f"🔴 {grund}")
    for grund in labels.gruende_als_liste(zeile.get("offene_pruefungen")):
        st.markdown(f"🟡 {grund}")


def kriterien_anzeigen(zeilen: Sequence[dict[str, Any]]) -> None:
    """Die gewichteten Teilpassungen als Balken - das ist die Begruendung des Scores."""
    if not zeilen:
        st.info("Für dieses Paar gibt es keine Teilpassungen (kein Score berechnet).")
        return
    for zeile in zeilen:
        name = labels.KATEGORIE.get(zeile["kriterium"], zeile["kriterium"])
        passung = zeile["passung"]
        gewicht = float(zeile["gewicht"]) if zeile["gewicht"] is not None else 0.0
        spalte_text, spalte_balken, spalte_wert = st.columns([3, 5, 2])
        with spalte_text:
            st.markdown(
                f"**{name}**  \n<span style='color:#7A6A5D;font-size:.8rem'>"
                f"{labels.KATEGORIE_ERKLAERUNG.get(zeile['kriterium'], '')}</span>",
                unsafe_allow_html=True,
            )
        with spalte_balken:
            if passung is None:
                st.markdown(
                    "<span style='color:#9C8878'>keine Angaben – zählt mit 0 Punkten</span>",
                    unsafe_allow_html=True,
                )
            else:
                st.progress(min(1.0, max(0.0, float(passung))))
        with spalte_wert:
            punkte = float(zeile["punkte"]) if zeile.get("punkte") is not None else 0.0
            st.markdown(f"**{punkte:.1f}** / {gewicht:.0f}")


def begruendung_anzeigen(profil_id: int, tier_id: int) -> None:
    """Teilpassungen, Datenabdeckung und - falls vorhanden - die Gruende im Klartext.

    Gemeinsam genutzt von "Meine Matches" und der Tierdetailseite, damit die Begruendung
    ueberall gleich aussieht.
    """
    paar = queries.paar(tier_id, profil_id) or {}
    if paar.get("eignung") != "geeignet":
        st.markdown(
            f"**Eignung:** {labels.EIGNUNG_AMPEL.get(paar.get('eignung'), '')} "
            f"{labels.anzeige(paar.get('eignung'), labels.EIGNUNG)}"
        )
        gruende_anzeigen(paar)
        if paar.get("eignung") == "ausgeschlossen":
            st.caption(
                "Harte Kriterien lassen sich nicht durch gute Werte an anderer Stelle "
                "ausgleichen – deshalb gibt es hier keinen Score."
            )
            return

    st.markdown("**So setzt sich der Wert zusammen** (Punkte je Kategorie / mögliches Gewicht)")
    kriterien_anzeigen(queries.kriterien(tier_id, profil_id))
    abdeckung = paar.get("datenabdeckung_prozent")
    if abdeckung is not None and float(abdeckung) < 100:
        st.caption(
            f"Datenabdeckung {float(abdeckung):.0f} %: Für die fehlenden "
            f"{100 - float(abdeckung):.0f} Gewichtspunkte liegen keine Angaben vor – sie "
            "zählen mit 0 Punkten. Ergänzen Sie Ihr Profil, kann der Wert steigen."
        )


# Vorsilben, mit denen sp_vermitteln / sp_vermittlung_beenden automatisch erzeugte
# Textbausteine an eine Notiz anhaengen (CONCAT_WS mit ' | ').
_SYSTEM_NOTIZ_PRAEFIXE = ("automatisch", "beendet:")


def notiz_anzeigen(notiz: str | None, eigene_vorsilbe: str = "Notiz") -> None:
    """Freitext getrennt vom automatisch angehaengten Systemtext anzeigen.

    sp_vermitteln und sp_vermittlung_beenden haengen Systemtexte (z. B. 'Automatisch
    abgelehnt: ...', 'Beendet: rueckgabe') mit ' | ' an eine vorhandene Notiz an
    (CONCAT_WS). Ungetrennt angezeigt liest sich das wie ein einziger, verwirrender Satz -
    deshalb hier aufgeteilt in eigenen Text und Systemhinweis.
    """
    if not notiz:
        return
    teile = [t.strip() for t in notiz.split(" | ") if t.strip()]
    ist_system = lambda t: t.lower().startswith(_SYSTEM_NOTIZ_PRAEFIXE)  # noqa: E731
    system_hinweise = [t for t in teile if ist_system(t)]
    eigene = [t for t in teile if not ist_system(t)]
    if eigene:
        st.caption(f"💬 {eigene_vorsilbe}: {labels.mit_umlauten(' '.join(eigene))}")
    for hinweis in system_hinweise:
        st.caption(f"⚙️ {labels.mit_umlauten(hinweis)}")


def tabelle(zeilen: Sequence[dict[str, Any]], spalten: Sequence[str] | None = None) -> None:
    """Eine Ergebnisliste als Tabelle mit deutschen Spaltenueberschriften."""
    if not zeilen:
        st.info("Keine Einträge.")
        return
    daten = pd.DataFrame(zeilen)
    if spalten:
        daten = daten[[s for s in spalten if s in daten.columns]]
    for spalte, zuordnung in (
        ("eignung", labels.EIGNUNG), ("tierstatus", labels.TIERSTATUS),
        ("status", labels.TIERSTATUS), ("art", labels.TERMINART),
        ("geschlecht", labels.GESCHLECHT), ("beendigungsgrund", labels.BEENDIGUNGSGRUND),
    ):
        if spalte in daten.columns:
            daten[spalte] = daten[spalte].map(lambda w, z=zuordnung: labels.anzeige(w, z))
    # Jede Textspalte durch die Umlaut-Korrektur schicken (kein fest verdrahteter Spaltenname
    # noetig: bei Spalten ohne ASCII-Umlaute aendert sich schlicht nichts). Kennungen wie
    # E-Mail-Adressen oder URLs werden ausgenommen - sie koennten zufaellig ein Wort aus dem
    # Woerterbuch enthalten und duerfen nicht veraendert werden.
    _KEINE_UMLAUTKORREKTUR = {"email", "foto_url", "website", "ags", "schluessel", "suchname"}
    for spalte in daten.columns:
        # pandas >= 3 gibt reinen Text als eigenen "str"-Dtyp zurueck, nicht mehr "object" -
        # pd.api.types.is_string_dtype erkennt beide Faelle.
        if (
            pd.api.types.is_string_dtype(daten[spalte])
            and spalte not in _KEINE_UMLAUTKORREKTUR
        ):
            daten[spalte] = daten[spalte].map(
                lambda w: labels.mit_umlauten(w) if isinstance(w, str) else w
            )
    daten = daten.rename(columns=labels.spalten_umbenennen(list(daten.columns)))
    st.dataframe(daten, use_container_width=True, hide_index=True)


def fehler_anzeigen(fehler: Exception) -> None:
    """Datenbankmeldungen (auch die aus den Prozeduren) verstaendlich ausgeben."""
    nachricht = getattr(fehler, "nachricht", str(fehler))
    st.error(labels.mit_umlauten(nachricht))


def kennzahl(spalte: Any, wert: Any, text: str, nachsatz: str = "") -> None:
    with spalte:
        st.metric(text, wert if wert is not None else "–", nachsatz or None)


def zu_tier(tier_id: int) -> None:
    """Zur Detailseite eines bestimmten Tieres springen (Merkliste, Galerie, Matches)."""
    st.session_state["detail_tier_id"] = tier_id
    zur_seite("tierdetail")


def zur_seite(url_pfad: str) -> None:
    """Zu einer anderen Seite wechseln (app.py legt die Zuordnung in der Sitzung ab).

    Nach einer Anmeldung gibt es die Zielseite in der aktuellen Navigation noch gar nicht
    (sie wurde fuer die alte Rolle aufgebaut). Dann wird das Ziel gemerkt und die App neu
    aufgebaut; app.py springt anschliessend dorthin.
    """
    seite = st.session_state.get("seiten", {}).get(url_pfad)
    if seite is not None:
        st.switch_page(seite)
    st.session_state["ziel"] = url_pfad
    st.rerun()
