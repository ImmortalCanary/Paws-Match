"""Uebersetzt die Bezeichner aus der Datenbank (ASCII, ohne Umlaute) in Anzeigetexte.

In der Datenbank gilt die Konvention ae/oe/ue/ss. Die Oberflaeche zeigt richtiges Deutsch.
"""

from __future__ import annotations

import re

# --- Aufzaehlungen aus der Datenbank ----------------------------------------------------

TIERSTATUS = {
    "verfuegbar": "Verfügbar",
    "reserviert": "Reserviert",
    "vermittelt": "Vermittelt",
    "nicht_vermittelbar": "Nicht vermittelbar",
    "geloescht": "Archiviert",
}

EIGNUNG = {
    "geeignet": "Geeignet",
    "pruefung_offen": "Prüfung offen",
    "ausgeschlossen": "Ausgeschlossen",
}

EIGNUNG_AMPEL = {
    "geeignet": "🟢",
    "pruefung_offen": "🟡",
    "ausgeschlossen": "🔴",
}

BEWERBUNGSSTATUS = {
    "offen": "Offen",
    "in_pruefung": "In Prüfung",
    "abgelehnt": "Abgelehnt",
    "zurueckgezogen": "Zurückgezogen",
    "angenommen": "Angenommen",
}

TERMINART = {
    "gespraech": "Gespräch",
    "kennenlernen": "Kennenlernen",
    "nachkontrolle": "Nachkontrolle",
}

BEENDIGUNGSGRUND = {
    "rueckgabe": "Rückgabe",
    "verstorben": "Verstorben",
    "sonstiges": "Sonstiges",
}

GESCHLECHT = {
    "weiblich": "Weiblich",
    "maennlich": "Männlich",
    "unbekannt": "Unbekannt",
}

STANDORTART = {
    "tierheim": "Tierheim",
    "auffangstation": "Auffangstation",
    "katzenhaus": "Katzenhaus",
    "pflegestellen": "Pflegestellen",
}

# Erfahrungsstufen 0-5 (Datenbank-Skala unveraendert, nur die Anzeige ist Text statt Zahl).
# Fuenf vom Nutzer genannte Stufen (Keine/Wenig/Mittlere/Viel/Sehr viel) plus eine zusaetzliche
# Zwischenstufe "Etwas Erfahrung", damit alle sechs erlaubten Werte (CHECK 0-5) abgedeckt sind.
ERFAHRUNG = {
    0: "Keine Erfahrung",
    1: "Wenig Erfahrung",
    2: "Etwas Erfahrung",
    3: "Mittlere Erfahrung",
    4: "Viel Erfahrung",
    5: "Sehr viel Erfahrung",
}

# Was der jeweilige Pflegeaufwand in der Praxis bedeuten kann (Beispiele, keine Vorschrift).
PFLEGEAUFWAND_ERKLAERUNG = {
    "niedrig": "Grundversorgung reicht meist aus: füttern, gelegentlich bürsten, "
               "selten zum Tierarzt.",
    "mittel": "Regelmäßige Pflege nötig, z. B. tägliches Bürsten, feste Auslaufzeiten "
              "oder gelegentliche Medikamentengabe.",
    "hoch": "Deutlich mehr Zeit und Aufmerksamkeit nötig, z. B. tägliche Medikamente, "
            "häufige Tierarztbesuche oder regelmäßiges Training.",
}

# Score-Kategorien aus matching_kategorie
KATEGORIE = {
    "Tierart": "Tierart",
    "Aktivitaet": "Aktivität",
    "Zeit": "Zeit",
    "Wohnsituation": "Wohnsituation",
    "Erfahrung": "Erfahrung",
    "Vertraeglichkeit": "Verträglichkeit",
    "Gesundheit": "Gesundheit",
    "Alltagsrhythmus": "Alltagsrhythmus",
    "Budget": "Budget",
    "Charakter": "Charakter",
    "Naehe": "Nähe",
}

# Kurze Erklaerung je Kategorie, fuer die Aufklappen-Ansicht "Warum passt das?"
KATEGORIE_ERKLAERUNG = {
    "Tierart": "Gewünschte Tierart, Größe und Alter",
    "Aktivitaet": "Wie gut die Energielevel zusammenpassen",
    "Zeit": "Betreuungszeit und wie lange das Tier allein wäre",
    "Wohnsituation": "Wohnfläche im Verhältnis zur Mindestfläche",
    "Erfahrung": "Erfahrung mit dieser Tierart über der Mindestanforderung",
    "Vertraeglichkeit": "Verträglichkeit mit Kindern, Hunden, Katzen und Kleintieren",
    "Gesundheit": "Belastende Gesundheitsmerkmale und die Bereitschaft, sie zu tragen",
    "Alltagsrhythmus": "Alleinzeit des Tieres gegen die Anwesenheit zu Hause",
    "Budget": "Budget im Verhältnis zu den Monatskosten",
    "Charakter": "Anteil der gewünschten Charakterzüge, die das Tier hat",
    "Naehe": "Wunschstandort, gleicher Bezirk oder Entfernung",
}

# --- Spaltenueberschriften fuer Tabellen -------------------------------------------------

SPALTEN = {
    "tier_id": "Tier-Nr.",
    "interessent_id": "Profil-Nr.",
    "tiername": "Tier",
    "tierart": "Tierart",
    "rasse": "Rasse",
    "pseudonym": "Profil",
    "standort": "Standort",
    "standort_bezirk": "Bezirk des Standorts",
    "interessenten_bezirk": "Wohnbezirk",
    "bezirk": "Bezirk",
    "eignung": "Eignung",
    "tierstatus": "Status",
    "status": "Status",
    "match_prozent": "Match",
    "datenabdeckung_prozent": "Datenabdeckung",
    "mindestscore": "Mindestscore",
    "begruendung": "Begründung",
    "ausschlussgruende": "Ausschlussgründe",
    "offene_pruefungen": "Offene Prüfungen",
    "vorschlagsstatus": "Vorschlag?",
    "entfernung_km": "Entfernung (km)",
    "kriterium": "Kategorie",
    "passung": "Teilpassung",
    "gewicht": "Gewicht",
    "alter_jahre": "Alter",
    "groesse": "Größe",
    "geschlecht": "Geschlecht",
    "erstellt_am": "Erstellt am",
    "zeitpunkt": "Zeitpunkt",
    "art": "Art",
    "name": "Name",
    "email": "E-Mail",
    "notiz": "Notiz",
    "vermittelt_am": "Vermittelt am",
    "beendet_am": "Beendet am",
    "beendigungsgrund": "Grund der Beendigung",
}

# --- Freitext aus der Datenbank (Begruendungen, Fehlermeldungen) ------------------------

_WOERTER = {
    # Katalogwerte aus den Stammdaten
    "eigenstaendig": "eigenständig",
    "schuechtern": "schüchtern",
    "gross": "groß",
    "grosse": "große",
    "regelmaessig": "regelmäßig",
    "regelmaessige": "regelmäßige",
    "regelmaessiger": "regelmäßiger",
    "taeglich": "täglich",
    "taegliche": "tägliche",
    "taeglicher": "täglicher",
    "ueberwiegend": "überwiegend",
    "ueber": "über",
    "erwerbstaetigkeit": "Erwerbstätigkeit",
    "haushaltsgroesse": "Haushaltsgröße",
    "wunschgroesse": "Wunschgröße",
    "massnahmen": "Maßnahmen",
    "ausloeser": "Auslöser",
    "mobilitaetsanforderungen": "Mobilitätsanforderungen",
    "beruecksichtigen": "berücksichtigen",
    "einschraenkung": "Einschränkung",
    "einschraenkungen": "Einschränkungen",
    "pruefdatum": "Prüfdatum",
    "geoeffnet": "geöffnet",
    "abschliessen": "abschließen",
    "vorschlaege": "Vorschläge",
    "vorschlag": "Vorschlag",
    "gewuenscht": "gewünscht",
    "gewuenschte": "gewünschte",
    "gewuenschten": "gewünschten",
    "charakterzuege": "Charakterzüge",
    "hoeherer": "höherer",
    # Begruendungen und Meldungen
    "aktivitaet": "Aktivität",
    "alltagsrhythmus": "Alltagsrhythmus",
    "angaben": "Angaben",
    "ausdruecklich": "ausdrücklich",
    "ausschlussgruende": "Ausschlussgründe",
    "bestaetigt": "bestätigt",
    "bestaetigten": "bestätigten",
    "bestaetigung": "Bestätigung",
    "bestaetigungen": "Bestätigungen",
    "beduerfnis": "Bedürfnis",
    "beduerfnisse": "Bedürfnisse",
    "beduerfnisses": "Bedürfnisses",
    "erfuellt": "erfüllt",
    "fuer": "für",
    "gehoert": "gehört",
    "geloescht": "gelöscht",
    "gemaess": "gemäß",
    "groesse": "Größe",
    "gueltig": "gültig",
    "gueltige": "gültige",
    "gruende": "Gründe",
    "hundevertraeglichkeit": "Hundeverträglichkeit",
    "katzenvertraeglichkeit": "Katzenverträglichkeit",
    "kindervertraeglichkeit": "Kinderverträglichkeit",
    "kleintiervertraeglichkeit": "Kleintierverträglichkeit",
    "koennen": "können",
    "loeschen": "löschen",
    "moeglich": "möglich",
    "muessen": "müssen",
    "naechste": "nächste",
    "naehe": "Nähe",
    "pruefen": "prüfen",
    "pruefung": "Prüfung",
    "pruefungen": "Prüfungen",
    "pruefungsstand": "Prüfungsstand",
    "ruecknahme": "Rücknahme",
    "rueckgabe": "Rückgabe",
    "unvollstaendig": "unvollständig",
    "ungueltig": "ungültig",
    "verfuegbar": "verfügbar",
    "vertraeglichkeit": "Verträglichkeit",
    "vollstaendig": "vollständig",
    "wohnflaeche": "Wohnfläche",
    "zurueck": "zurück",
    "zurueckgezogen": "zurückgezogen",
    "zusaetzlich": "zusätzlich",
}

_MUSTER = re.compile(r"\b(" + "|".join(sorted(_WOERTER, key=len, reverse=True)) + r")\b", re.IGNORECASE)


def mit_umlauten(text: str | None) -> str:
    """Setzt in Texten aus der Datenbank die Umlaute wieder ein."""
    if not text:
        return ""

    def ersetzen(treffer: re.Match[str]) -> str:
        wort = treffer.group(0)
        ersatz = _WOERTER[wort.lower()]
        if wort[0].isupper():
            return ersatz[0].upper() + ersatz[1:]
        return ersatz[0].lower() + ersatz[1:]

    return _MUSTER.sub(ersetzen, text)


def gruende_als_liste(text: str | None) -> list[str]:
    """Die mit ' | ' verketteten Gruende aus matching_entscheidung aufteilen."""
    if not text:
        return []
    return [mit_umlauten(teil.strip()) for teil in text.split("|") if teil.strip()]


def anzeige(wert: str | None, zuordnung: dict[str, str]) -> str:
    """Einen Aufzaehlungswert anzeigen, auch wenn er (noch) nicht in der Zuordnung steht."""
    if wert is None:
        return "Keine Angabe"
    return zuordnung.get(wert, mit_umlauten(wert.replace("_", " ")))


def spalten_umbenennen(spalten: list[str]) -> dict[str, str]:
    """Spaltennamen einer Abfrage auf Anzeigetexte abbilden."""
    return {name: SPALTEN.get(name, mit_umlauten(name.replace("_", " ")).strip().capitalize())
            for name in spalten}


def ja_nein(wert: int | bool | None) -> str:
    if wert is None:
        return "Keine Angabe"
    return "Ja" if int(wert) == 1 else "Nein"
