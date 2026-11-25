"""Startseite: das Konzept erklaeren und zum Profil fuehren."""

from __future__ import annotations

import streamlit as st

import auth
import bausteine
import db
import queries


def zeige() -> None:
    erreichbar, meldung = db.ist_erreichbar()

    st.markdown(
        """
        <div class="pm-held">
            <h1>Jedes Tier hat ein Zuhause,<br>das wirklich zu ihm passt.</h1>
            <p>Paws &amp; Match bringt Tiere aus dem Tierheim mit Menschen zusammen,
               zu deren Leben sie passen – nachvollziehbar, mit Begründung für jede
               Empfehlung.</p>
        </div>
        """,
        unsafe_allow_html=True,
    )

    links, rechts = st.columns([1, 1])
    with links:
        if st.button("💛 Jetzt Perfect Match finden", type="primary", use_container_width=True):
            bausteine.zur_seite("profil")
    with rechts:
        if st.button("🐾 Erst einmal Tiere ansehen", use_container_width=True):
            bausteine.zur_seite("tiere")

    st.write("")
    st.subheader("Warum es das braucht")
    st.markdown(
        "Viele Tiere kommen zurück ins Tierheim oder landen auf der Straße, weil die "
        "Vermittlung nicht gepasst hat: zu wenig Zeit, die falsche Wohnung, Ärger mit den "
        "Tieren, die schon da sind. **Unser Ziel ist, genau das seltener zu machen** – ein "
        "Match, das hält, statt einer schnellen Vermittlung."
    )

    st.write("")
    st.subheader("So funktioniert es")
    schritte = st.columns(3)
    texte = [
        ("Profil ausfüllen",
         "Sie beschreiben Ihre Wohnsituation, Ihren Alltag und Ihre Wünsche. "
         "Was Sie nicht wissen, lassen Sie offen – geraten wird nichts."),
        ("Passende Tiere erhalten",
         "Die Datenbank prüft zuerst harte Kriterien (z. B. „braucht einen Garten“) und "
         "bewertet danach, wie gut Sie und das Tier zusammenpassen – von 0 bis 100 %."),
        ("Begründung lesen und bewerben",
         "Zu jedem Vorschlag sehen Sie, woraus sich der Wert ergibt. Passt es, bewerben Sie "
         "sich direkt beim Tierheim."),
    ]
    for nummer, (spalte, (titel, text)) in enumerate(zip(schritte, texte, strict=False), start=1):
        with spalte:
            st.markdown(
                f'<div class="pm-schritt"><div class="pm-nummer">{nummer}</div>'
                f"<h4>{titel}</h4><p>{text}</p></div>",
                unsafe_allow_html=True,
            )

    st.write("")
    if not erreichbar:
        st.warning(
            "Die Zahlen unten stammen aus der Datenbank, die gerade nicht erreichbar ist: "
            + meldung
        )
        return

    st.subheader("Paws & Match in Zahlen")
    zahlen = queries.kennzahlen()
    spalten = st.columns(5)
    bausteine.kennzahl(spalten[0], zahlen.get("tiere_verfuegbar"), "Tiere warten")
    bausteine.kennzahl(spalten[1], zahlen.get("standorte"), "Standorte")
    bausteine.kennzahl(spalten[2], zahlen.get("profile_aktiv"), "Aktive Profile")
    bausteine.kennzahl(spalten[3], zahlen.get("vorschlaege"), "Passende Paare")
    schnitt = zahlen.get("score_schnitt")
    bausteine.kennzahl(spalten[4], f"{float(schnitt):.1f} %" if schnitt else "–",
                       "Ø Übereinstimmung")

    st.write("")
    with st.expander("Wie das Matching funktioniert (für Neugierige)"):
        st.markdown(
            """
**Stufe 1 – harte Kriterien.** Jedes Paar aus Tier und Mensch wird gegen Kriterien wie
Garten, Treppen, Verträglichkeit mit Kindern und anderen Tieren, Wohnfläche, Zeit, Erfahrung,
Budget und Entfernung geprüft. Ein einziges nicht erfülltes Kriterium schließt das Paar aus –
mit Begründung. Fehlen Angaben, heißt das Ergebnis „Prüfung offen“, nicht „passt“.

**Stufe 2 – der Score.** Für alle geeigneten Paare bewerten gewichtete Kategorien, *wie gut*
es passt: Tierart, Aktivität, Zeit, Wohnsituation, Erfahrung, Verträglichkeit, Gesundheit,
Alltagsrhythmus, Budget, Charakter und Nähe. Wer die Mindestanforderung genau erfüllt, bekommt
die halbe Punktzahl, wer deutlich mehr bietet, die volle.

**Stufe 3 – der Vorschlag.** Vorgeschlagen wird, was geeignet ist, verfügbar ist und den vom
Tierheim eingestellten Mindestscore erreicht.
            """
        )

    if auth.rolle() == auth.BESUCHER:
        st.info(
            "Sie arbeiten in einem Tierheim? Über „Für Mitarbeitende“ in der Seitenleiste "
            "geht es zur internen Ansicht."
        )
