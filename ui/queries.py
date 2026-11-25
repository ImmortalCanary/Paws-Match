"""Alle SQL-Anweisungen der Oberflaeche an einer Stelle.

Grundsatz: Die Oberflaeche rechnet nichts selbst. Vorschlaege kommen aus der View
matching_vorschlaege bzw. den Vorschlagsprozeduren, Statuswechsel ausschliesslich aus den
Prozeduren der Datenbank.
"""

from __future__ import annotations

from typing import Any, Iterable, Sequence

from db import abfrage, ein_wert, eine_zeile, erste_zeilen, prozedur_mit_rueckgabe, transaktion

# --- Kataloge (Auswahllisten) -----------------------------------------------------------


def tierarten() -> list[dict[str, Any]]:
    return abfrage("SELECT id, name FROM tierart ORDER BY name")


def rassen(tierart_id: int | None = None) -> list[dict[str, Any]]:
    if tierart_id is None:
        return abfrage(
            "SELECT r.id, r.name, r.tierart_id, t.name AS tierart "
            "FROM tier_rasse r JOIN tierart t ON t.id = r.tierart_id ORDER BY t.name, r.name"
        )
    return abfrage(
        "SELECT id, name, tierart_id FROM tier_rasse WHERE tierart_id = %s ORDER BY name",
        [tierart_id],
    )


def charakterzuege() -> list[dict[str, Any]]:
    return abfrage("SELECT id, name FROM charakter ORDER BY name")


def beduerfnisse() -> list[dict[str, Any]]:
    return abfrage("SELECT id, name FROM beduerfnis ORDER BY id")


def groessen() -> list[dict[str, Any]]:
    return abfrage("SELECT id, name, rang FROM tier_groesse ORDER BY rang")


def pflegeaufwaende() -> list[dict[str, Any]]:
    return abfrage("SELECT id, name, rang FROM pflegeaufwand ORDER BY rang")


def wohnformen() -> list[dict[str, Any]]:
    return abfrage("SELECT id, name FROM wohnform ORDER BY id")


def arbeitsmodelle() -> list[dict[str, Any]]:
    return abfrage("SELECT id, name, anwesenheit FROM arbeitsmodell ORDER BY id")


def gesundheitsmerkmale() -> list[dict[str, Any]]:
    return abfrage("SELECT id, name, beschreibung, belastend FROM gesundheitsmerkmal ORDER BY name")


def bezirke() -> list[dict[str, Any]]:
    """Dropdown aus der vorhandenen View bezirk_auswahl (nur freigeschaltete Orte)."""
    return abfrage(
        "SELECT bezirk_id, bezirk, ort, bundesland FROM bezirk_auswahl ORDER BY ort, bezirk"
    )


def suchzonen() -> list[dict[str, Any]]:
    return abfrage("SELECT id, name, reihenfolge FROM suchzone ORDER BY reihenfolge")


def standorte() -> list[dict[str, Any]]:
    return abfrage(
        """
        SELECT s.id, s.name, s.art, s.plz, s.strasse, s.kapazitaet,
               th.name AS tierheim, b.name AS bezirk, o.name AS ort
        FROM standort s
        JOIN tierheim th ON th.id = s.tierheim_id
        JOIN ort o ON o.id = s.ort_id
        LEFT JOIN bezirk b ON b.id = s.bezirk_id
        ORDER BY o.name, s.name
        """
    )


def mitarbeitende() -> list[dict[str, Any]]:
    return abfrage(
        """
        SELECT m.id, m.name, m.email, m.standort_id, s.name AS standort
        FROM mitarbeiter m JOIN standort s ON s.id = m.standort_id
        ORDER BY s.name, m.name
        """
    )


# --- Startseite -------------------------------------------------------------------------


def kennzahlen() -> dict[str, Any]:
    return eine_zeile(
        """
        SELECT
            (SELECT COUNT(*) FROM tier WHERE status = 'verfuegbar')          AS tiere_verfuegbar,
            (SELECT COUNT(*) FROM tier)                                       AS tiere_gesamt,
            (SELECT COUNT(*) FROM standort)                                   AS standorte,
            (SELECT COUNT(*) FROM interessent WHERE aktiv = 1)                AS profile_aktiv,
            (SELECT COUNT(*) FROM matching_vorschlaege)                       AS vorschlaege,
            (SELECT ROUND(AVG(match_prozent), 1) FROM matching_vorschlaege)   AS score_schnitt,
            (SELECT COUNT(*) FROM vermittlung WHERE beendet_am IS NULL)       AS vermittlungen_aktiv
        """
    ) or {}


# --- Tiere ------------------------------------------------------------------------------

_TIER_BASIS = """
    SELECT t.id, t.name AS tiername, t.status, t.geschlecht, t.beschreibung, t.foto_url,
           t.geburtsdatum, t.geburt_geschaetzt, t.gewicht_kg, t.aktivitaet,
           ta.id AS tierart_id, ta.name AS tierart,
           r.name AS rasse, g.name AS groesse, g.rang AS groesse_rang,
           p.name AS pflegeaufwand,
           s.id AS standort_id, s.name AS standort, s.art AS standortart,
           b.id AS bezirk_id, b.name AS bezirk, o.name AS ort,
           th.name AS tierheim,
           TIMESTAMPDIFF(YEAR, t.geburtsdatum, CURDATE()) AS alter_jahre
    FROM tier t
    JOIN tierart ta ON ta.id = t.tierart_id
    JOIN standort s ON s.id = t.standort_id
    JOIN tierheim th ON th.id = s.tierheim_id
    JOIN ort o ON o.id = s.ort_id
    LEFT JOIN bezirk b ON b.id = s.bezirk_id
    LEFT JOIN tier_rasse r ON r.id = t.rasse_id
    LEFT JOIN tier_groesse g ON g.id = t.groesse_id
    LEFT JOIN pflegeaufwand p ON p.id = t.pflegeaufwand_id
"""


def tiere(
    nur_verfuegbar: bool = True,
    tierart_id: int | None = None,
    groesse_id: int | None = None,
    bezirk_id: int | None = None,
    standort_id: int | None = None,
    status: str | None = None,
) -> list[dict[str, Any]]:
    bedingungen: list[str] = []
    werte: list[Any] = []
    if status:
        bedingungen.append("t.status = %s")
        werte.append(status)
    elif nur_verfuegbar:
        bedingungen.append("t.status = 'verfuegbar'")
    if tierart_id:
        bedingungen.append("t.tierart_id = %s")
        werte.append(tierart_id)
    if groesse_id:
        bedingungen.append("t.groesse_id = %s")
        werte.append(groesse_id)
    if bezirk_id:
        bedingungen.append("s.bezirk_id = %s")
        werte.append(bezirk_id)
    if standort_id:
        bedingungen.append("t.standort_id = %s")
        werte.append(standort_id)
    wo = (" WHERE " + " AND ".join(bedingungen)) if bedingungen else ""
    return abfrage(_TIER_BASIS + wo + " ORDER BY t.name", werte)


def tier(tier_id: int) -> dict[str, Any] | None:
    return eine_zeile(_TIER_BASIS + " WHERE t.id = %s", [tier_id])


def tier_rohdaten(tier_id: int) -> dict[str, Any] | None:
    """Alle Spalten der Tabelle tier, fuer das Bearbeitungsformular."""
    return eine_zeile("SELECT * FROM tier WHERE id = %s", [tier_id])


def tier_charakter(tier_id: int) -> list[dict[str, Any]]:
    return abfrage(
        """
        SELECT c.id, c.name FROM tier_charakter tc
        JOIN charakter c ON c.id = tc.charakter_id
        WHERE tc.tier_id = %s ORDER BY c.name
        """,
        [tier_id],
    )


def tier_beduerfnisse(tier_id: int) -> list[dict[str, Any]]:
    return abfrage(
        """
        SELECT b.id, b.name, tb.hinweis FROM tier_beduerfnis tb
        JOIN beduerfnis b ON b.id = tb.beduerfnis_id
        WHERE tb.tier_id = %s ORDER BY b.id
        """,
        [tier_id],
    )


def tier_gesundheit(tier_id: int) -> list[dict[str, Any]]:
    return abfrage(
        """
        SELECT g.id, g.name, g.belastend, tg.bestaetigt, tg.geprueft_am, tg.hinweis
        FROM tier_gesundheit tg
        JOIN gesundheitsmerkmal g ON g.id = tg.gesundheitsmerkmal_id
        WHERE tg.tier_id = %s ORDER BY g.name
        """,
        [tier_id],
    )


TIER_SPALTEN = [
    "standort_id", "tierart_id", "name", "geburtsdatum", "geburt_geschaetzt", "geschlecht",
    "gewicht_kg", "beschreibung", "foto_url", "rasse_id", "groesse_id", "pflegeaufwand_id",
    "aktivitaet", "min_wohnflaeche", "garten_noetig", "treppen_vermeiden", "kinder_ok",
    "hund_ok", "katze_ok", "kleintiere_ok", "min_zeit", "max_allein", "min_erfahrung",
    "monatskosten", "medizin_noetig",
]


def tier_speichern(
    daten: dict[str, Any],
    charakter_ids: Sequence[int],
    beduerfnis_ids: Sequence[int],
    tier_id: int | None = None,
) -> int:
    """Tier anlegen oder aendern, zusammen mit Charakterzuegen und Beduerfnissen."""
    werte = {spalte: daten.get(spalte) for spalte in TIER_SPALTEN}
    with transaktion() as cursor:
        if tier_id is None:
            spalten = ", ".join(werte)
            platzhalter = ", ".join(["%s"] * len(werte))
            cursor.execute(
                f"INSERT INTO tier ({spalten}) VALUES ({platzhalter})", tuple(werte.values())
            )
            tier_id = cursor.lastrowid
        else:
            zuweisung = ", ".join(f"{spalte} = %s" for spalte in werte)
            cursor.execute(
                f"UPDATE tier SET {zuweisung} WHERE id = %s", (*werte.values(), tier_id)
            )
        _zuordnung_setzen(cursor, "tier_charakter", "tier_id", tier_id, "charakter_id", charakter_ids)
        _zuordnung_setzen(cursor, "tier_beduerfnis", "tier_id", tier_id, "beduerfnis_id", beduerfnis_ids)
        return tier_id


def _zuordnung_setzen(
    cursor: Any,
    tabelle: str,
    schluesselspalte: str,
    schluessel: int,
    wertspalte: str,
    werte: Iterable[int],
) -> None:
    """Eine n:m-Zuordnung auf genau die uebergebenen Werte setzen."""
    cursor.execute(f"DELETE FROM {tabelle} WHERE {schluesselspalte} = %s", (schluessel,))
    for wert in dict.fromkeys(werte):
        cursor.execute(
            f"INSERT INTO {tabelle} ({schluesselspalte}, {wertspalte}) VALUES (%s, %s)",
            (schluessel, wert),
        )


# --- Interessenten ----------------------------------------------------------------------

INTERESSENT_SPALTEN = [
    "pseudonym", "email", "bezirk_id", "aktiv", "max_suchzone_id", "max_entfernung_km",
    "wohnflaeche", "wohnform_id", "garten", "balkon", "balkon_gesichert", "etage", "aufzug",
    "haushaltsgroesse", "kinder", "hund_vorhanden", "katze_vorhanden", "kleintiere_vorhanden",
    "zeit_stunden", "allein_stunden", "arbeitsmodell_id", "budget",
    "medizin_bereit", "tierarzt_bereit", "training_bereit", "max_pflegeaufwand_id",
    "aktivitaet", "wunschalter_min", "wunschalter_max",
]
# "erfahrung" (allgemeine Tiererfahrung) wird bewusst NICHT mehr geschrieben: das Matching
# liest ausschliesslich interessent_tiererfahrung (je Tierart); die allgemeine Spalte war
# eine zweite, ungenutzte Abfrage derselben Information (siehe AGENTS.md Abschnitt 9).

# Diese Beduerfnisse haben bereits ein eigenes strukturiertes Feld im Profil und werden daher
# nicht noch einmal einzeln abgefragt; die Bestaetigung wird beim Speichern automatisch daraus
# abgeleitet. IDs wie in AGENTS.md Abschnitt 4 dokumentiert (1 Medikamente, 2 gesicherter
# Balkon, 4 Training) - dieselben IDs, auf die auch matching_entscheidung.sql sich bezieht.
BEDUERFNIS_AUS_PROFILFELD = {
    1: "medizin_bereit",
    2: "balkon_gesichert",
    4: "training_bereit",
}
# Nur die Beduerfnis-IDs, fuer die es ein eigenes Feld gibt (zum Ausblenden in der Wunschliste).
BEDUERFNIS_MIT_EIGENEM_FELD = set(BEDUERFNIS_AUS_PROFILFELD)


def interessent_nach_email(email: str) -> dict[str, Any] | None:
    return eine_zeile("SELECT * FROM interessent WHERE email = %s", [email])


def interessent(interessent_id: int) -> dict[str, Any] | None:
    return eine_zeile(
        """
        SELECT i.*, b.name AS bezirk, sz.name AS suchzone, w.name AS wohnform,
               a.name AS arbeitsmodell, p.name AS max_pflegeaufwand
        FROM interessent i
        LEFT JOIN bezirk b ON b.id = i.bezirk_id
        LEFT JOIN suchzone sz ON sz.id = i.max_suchzone_id
        LEFT JOIN wohnform w ON w.id = i.wohnform_id
        LEFT JOIN arbeitsmodell a ON a.id = i.arbeitsmodell_id
        LEFT JOIN pflegeaufwand p ON p.id = i.max_pflegeaufwand_id
        WHERE i.id = %s
        """,
        [interessent_id],
    )


def interessenten(nur_aktive: bool = True) -> list[dict[str, Any]]:
    wo = "WHERE i.aktiv = 1" if nur_aktive else ""
    return abfrage(
        f"""
        SELECT i.id, i.pseudonym, i.email, i.aktiv, b.name AS bezirk,
               (SELECT COUNT(*) FROM bewerbung w WHERE w.interessent_id = i.id) AS bewerbungen,
               (SELECT COUNT(*) FROM matching_vorschlaege v WHERE v.interessent_id = i.id) AS vorschlaege
        FROM interessent i
        LEFT JOIN bezirk b ON b.id = i.bezirk_id
        {wo}
        ORDER BY i.id
        """
    )


def interessent_wuensche(interessent_id: int) -> dict[str, list[Any]]:
    """Alle n:m-Angaben eines Profils gebuendelt."""
    return {
        "tierarten": [z["tierart_id"] for z in abfrage(
            "SELECT tierart_id FROM interessent_tierart WHERE interessent_id = %s", [interessent_id])],
        "groessen": [z["groesse_id"] for z in abfrage(
            "SELECT groesse_id FROM interessent_groesse WHERE interessent_id = %s", [interessent_id])],
        "charakter": [z["charakter_id"] for z in abfrage(
            "SELECT charakter_id FROM interessent_charakter WHERE interessent_id = %s", [interessent_id])],
        "standorte": [z["standort_id"] for z in abfrage(
            "SELECT standort_id FROM interessent_standort WHERE interessent_id = %s", [interessent_id])],
        "erfahrung": {z["tierart_id"]: z["erfahrungslevel"] for z in abfrage(
            "SELECT tierart_id, erfahrungslevel FROM interessent_tiererfahrung WHERE interessent_id = %s",
            [interessent_id])},
        "beduerfnisse": {z["beduerfnis_id"]: z["bestaetigt"] for z in abfrage(
            "SELECT beduerfnis_id, bestaetigt FROM interessent_beduerfnis WHERE interessent_id = %s",
            [interessent_id])},
    }


def interessent_speichern(
    daten: dict[str, Any],
    wuensche: dict[str, Any],
    interessent_id: int | None = None,
) -> int:
    """Profil anlegen oder aendern, zusammen mit allen Wuenschen. Alles in einer Transaktion."""
    werte = {spalte: daten.get(spalte) for spalte in INTERESSENT_SPALTEN}
    werte["aktiv"] = 1 if daten.get("aktiv", 1) else 0

    with transaktion() as cursor:
        if interessent_id is None:
            spalten = ", ".join(werte)
            platzhalter = ", ".join(["%s"] * len(werte))
            cursor.execute(
                f"INSERT INTO interessent ({spalten}) VALUES ({platzhalter})", tuple(werte.values())
            )
            interessent_id = cursor.lastrowid
        else:
            zuweisung = ", ".join(f"{spalte} = %s" for spalte in werte)
            cursor.execute(
                f"UPDATE interessent SET {zuweisung} WHERE id = %s",
                (*werte.values(), interessent_id),
            )

        _zuordnung_setzen(cursor, "interessent_tierart", "interessent_id", interessent_id,
                          "tierart_id", wuensche.get("tierarten", []))
        _zuordnung_setzen(cursor, "interessent_groesse", "interessent_id", interessent_id,
                          "groesse_id", wuensche.get("groessen", []))
        _zuordnung_setzen(cursor, "interessent_charakter", "interessent_id", interessent_id,
                          "charakter_id", wuensche.get("charakter", []))
        _zuordnung_setzen(cursor, "interessent_standort", "interessent_id", interessent_id,
                          "standort_id", wuensche.get("standorte", []))

        cursor.execute("DELETE FROM interessent_tiererfahrung WHERE interessent_id = %s",
                       (interessent_id,))
        for tierart_id, stufe in (wuensche.get("erfahrung") or {}).items():
            if stufe is not None:
                cursor.execute(
                    "INSERT INTO interessent_tiererfahrung (interessent_id, tierart_id, erfahrungslevel)"
                    " VALUES (%s, %s, %s)",
                    (interessent_id, tierart_id, stufe),
                )

        # Bestaetigungen: zuerst die direkt im Fragebogen beantworteten Beduerfnisse,
        # dann fuer Medikamente/Balkon/Training automatisch aus den entsprechenden
        # Profilfeldern ableiten - damit niemand zweimal dasselbe angeben muss.
        beduerfnis_antworten = dict(wuensche.get("beduerfnisse") or {})
        for beduerfnis_id, feld in BEDUERFNIS_AUS_PROFILFELD.items():
            wert = werte.get(feld)
            if wert is not None:
                beduerfnis_antworten[beduerfnis_id] = bool(wert)

        cursor.execute("DELETE FROM interessent_beduerfnis WHERE interessent_id = %s",
                       (interessent_id,))
        for beduerfnis_id, bestaetigt in beduerfnis_antworten.items():
            if bestaetigt is not None:
                cursor.execute(
                    "INSERT INTO interessent_beduerfnis (interessent_id, beduerfnis_id, bestaetigt)"
                    " VALUES (%s, %s, %s)",
                    (interessent_id, beduerfnis_id, 1 if bestaetigt else 0),
                )
        return interessent_id


def interessent_loeschen(interessent_id: int) -> str:
    """sp_interessent_loeschen: 'geloescht' oder 'anonymisiert'."""
    ergebnis = prozedur_mit_rueckgabe("sp_interessent_loeschen", (interessent_id, ""))
    return str(ergebnis[1]) if len(ergebnis) > 1 else ""


# --- Matching ---------------------------------------------------------------------------


def vorschlaege_fuer_interessent(interessent_id: int) -> list[dict[str, Any]]:
    return erste_zeilen("sp_vorschlaege_fuer_interessent", (interessent_id,))


def vorschlaege_fuer_tier(tier_id: int) -> list[dict[str, Any]]:
    return erste_zeilen("sp_vorschlaege_fuer_tier", (tier_id,))


def uebersicht_fuer_interessent(interessent_id: int) -> list[dict[str, Any]]:
    """Alle Tiere mit Eignung, Score und Grund - die Abfrage aus 06_ausgabe."""
    return abfrage(
        """
        SELECT s.tier_id, s.tiername, s.tierstatus, s.eignung, s.match_prozent,
               s.datenabdeckung_prozent, s.entfernung_km,
               ta.name AS tierart, st.name AS standort,
               CASE
                   WHEN v.tier_id IS NOT NULL THEN 'Als Vorschlag anzeigen'
                   WHEN s.eignung = 'ausgeschlossen' THEN 'Kein Vorschlag: Ausschlusskriterium'
                   WHEN s.eignung = 'pruefung_offen' THEN 'Kein Vorschlag: Angaben pruefen'
                   WHEN s.tier_verfuegbar = 0 THEN 'Kein Vorschlag: Tier nicht verfuegbar'
                   WHEN s.interessent_aktiv = 0 THEN 'Kein Vorschlag: Profil inaktiv'
                   WHEN s.gewichtung_vollstaendig = 0 THEN 'Kein Vorschlag: Gewichtung unvollstaendig'
                   ELSE CONCAT('Kein Vorschlag: Mindestscore ',
                               (SELECT wert FROM matching_einstellung WHERE schluessel = 'mindestscore'),
                               ' nicht erreicht')
               END AS vorschlagsstatus,
               s.ausschlussgruende, s.offene_pruefungen
        FROM matching_score s
        JOIN tier t ON t.id = s.tier_id
        JOIN tierart ta ON ta.id = t.tierart_id
        JOIN standort st ON st.id = t.standort_id
        LEFT JOIN matching_vorschlaege v
               ON v.tier_id = s.tier_id AND v.interessent_id = s.interessent_id
        WHERE s.interessent_id = %s
        ORDER BY CASE WHEN v.tier_id IS NOT NULL THEN 0 ELSE 1 END,
                 s.match_prozent DESC, s.tier_id
        """,
        [interessent_id],
    )


def paar(tier_id: int, interessent_id: int) -> dict[str, Any] | None:
    return eine_zeile(
        "SELECT * FROM matching_score WHERE tier_id = %s AND interessent_id = %s",
        [tier_id, interessent_id],
    )


def kriterien(tier_id: int, interessent_id: int) -> list[dict[str, Any]]:
    """Die Teilpassungen je Kategorie, zusammen mit dem Gewicht."""
    return abfrage(
        """
        SELECT k.kriterium, k.passung, g.gewicht,
               ROUND(COALESCE(k.passung, 0) * g.gewicht, 2) AS punkte
        FROM matching_kriterien k
        LEFT JOIN matching_gewichtung g ON g.kriterium = k.kriterium
        JOIN matching_kategorie mk ON mk.name = k.kriterium
        WHERE k.tier_id = %s AND k.interessent_id = %s
        ORDER BY g.gewicht DESC, k.kriterium
        """,
        [tier_id, interessent_id],
    )


# --- Merkliste und Bewerbungen ----------------------------------------------------------


def merkliste(interessent_id: int) -> list[dict[str, Any]]:
    return abfrage(
        """
        SELECT m.tier_id, m.erstellt_am, t.name AS tiername, t.status AS tierstatus,
               ta.name AS tierart, s.name AS standort
        FROM merkliste m
        JOIN tier t ON t.id = m.tier_id
        JOIN tierart ta ON ta.id = t.tierart_id
        JOIN standort s ON s.id = t.standort_id
        WHERE m.interessent_id = %s
        ORDER BY m.erstellt_am DESC
        """,
        [interessent_id],
    )


def gemerkte_ids(interessent_id: int) -> set[int]:
    return {z["tier_id"] for z in abfrage(
        "SELECT tier_id FROM merkliste WHERE interessent_id = %s", [interessent_id])}


def merken(interessent_id: int, tier_id: int) -> None:
    with transaktion() as cursor:
        cursor.execute(
            "INSERT IGNORE INTO merkliste (interessent_id, tier_id) VALUES (%s, %s)",
            (interessent_id, tier_id),
        )


def merken_entfernen(interessent_id: int, tier_id: int) -> None:
    with transaktion() as cursor:
        cursor.execute(
            "DELETE FROM merkliste WHERE interessent_id = %s AND tier_id = %s",
            (interessent_id, tier_id),
        )


def bewerbung_anlegen(interessent_id: int, tier_id: int, notiz: str | None = None) -> int:
    """Die Trigger trg_bewerbung_pruefen pruefen Verfuegbarkeit und aktives Profil."""
    with transaktion() as cursor:
        cursor.execute(
            "INSERT INTO bewerbung (interessent_id, tier_id, notiz) VALUES (%s, %s, %s)",
            (interessent_id, tier_id, notiz),
        )
        return cursor.lastrowid


def bewerbungen(
    interessent_id: int | None = None,
    standort_id: int | None = None,
    nur_laufende: bool = False,
) -> list[dict[str, Any]]:
    bedingungen: list[str] = []
    werte: list[Any] = []
    if interessent_id:
        bedingungen.append("b.interessent_id = %s")
        werte.append(interessent_id)
    if standort_id:
        bedingungen.append("t.standort_id = %s")
        werte.append(standort_id)
    if nur_laufende:
        bedingungen.append("b.status IN ('offen', 'in_pruefung')")
    wo = (" WHERE " + " AND ".join(bedingungen)) if bedingungen else ""
    return abfrage(
        f"""
        SELECT b.id, b.status, b.erstellt_am, b.notiz,
               b.tier_id, t.name AS tiername, t.status AS tierstatus,
               t.reserviert_fuer_bewerbung_id,
               b.interessent_id, i.pseudonym, i.email, i.aktiv AS profil_aktiv,
               ta.name AS tierart, s.id AS standort_id, s.name AS standort,
               sc.match_prozent, sc.eignung,
               (SELECT COUNT(*) FROM termin te WHERE te.bewerbung_id = b.id) AS termine,
               v.id AS vermittlung_id, v.beendet_am
        FROM bewerbung b
        JOIN tier t ON t.id = b.tier_id
        JOIN tierart ta ON ta.id = t.tierart_id
        JOIN standort s ON s.id = t.standort_id
        JOIN interessent i ON i.id = b.interessent_id
        LEFT JOIN matching_score sc
               ON sc.tier_id = b.tier_id AND sc.interessent_id = b.interessent_id
        LEFT JOIN vermittlung v ON v.bewerbung_id = b.id
        {wo}
        ORDER BY b.erstellt_am DESC, b.id DESC
        """,
        werte,
    )


def bewerbung_status_setzen(bewerbung_id: int, status: str, notiz: str | None = None) -> None:
    with transaktion() as cursor:
        if notiz is None:
            cursor.execute("UPDATE bewerbung SET status = %s WHERE id = %s", (status, bewerbung_id))
        else:
            cursor.execute(
                "UPDATE bewerbung SET status = %s, notiz = %s WHERE id = %s",
                (status, notiz, bewerbung_id),
            )


# --- Termine ----------------------------------------------------------------------------


def termine(bewerbung_id: int | None = None, standort_id: int | None = None,
            ab_jetzt: bool = False) -> list[dict[str, Any]]:
    bedingungen: list[str] = []
    werte: list[Any] = []
    if bewerbung_id:
        bedingungen.append("te.bewerbung_id = %s")
        werte.append(bewerbung_id)
    if standort_id:
        bedingungen.append("t.standort_id = %s")
        werte.append(standort_id)
    if ab_jetzt:
        bedingungen.append("te.zeitpunkt >= NOW()")
    wo = (" WHERE " + " AND ".join(bedingungen)) if bedingungen else ""
    return abfrage(
        f"""
        SELECT te.id, te.zeitpunkt, te.art, te.bewerbung_id,
               t.name AS tiername, i.pseudonym, m.name AS mitarbeiter, s.name AS standort
        FROM termin te
        JOIN bewerbung b ON b.id = te.bewerbung_id
        JOIN tier t ON t.id = b.tier_id
        JOIN standort s ON s.id = t.standort_id
        JOIN interessent i ON i.id = b.interessent_id
        JOIN mitarbeiter m ON m.id = te.mitarbeiter_id
        {wo}
        ORDER BY te.zeitpunkt
        """,
        werte,
    )


def termin_anlegen(bewerbung_id: int, mitarbeiter_id: int, zeitpunkt: Any, art: str) -> int:
    with transaktion() as cursor:
        cursor.execute(
            "INSERT INTO termin (bewerbung_id, mitarbeiter_id, zeitpunkt, art) VALUES (%s, %s, %s, %s)",
            (bewerbung_id, mitarbeiter_id, zeitpunkt, art),
        )
        return cursor.lastrowid


# --- Vermittlungsprozess (ausschliesslich ueber die Prozeduren) --------------------------


def reservieren(bewerbung_id: int, mitarbeiter_id: int) -> None:
    erste_zeilen("sp_reservieren", (bewerbung_id, mitarbeiter_id))


def reservierung_aufheben(tier_id: int, mitarbeiter_id: int) -> None:
    erste_zeilen("sp_reservierung_aufheben", (tier_id, mitarbeiter_id))


def vermitteln(bewerbung_id: int, mitarbeiter_id: int) -> None:
    erste_zeilen("sp_vermitteln", (bewerbung_id, mitarbeiter_id))


def vermittlung_beenden(vermittlung_id: int, mitarbeiter_id: int, grund: str, notiz: str) -> None:
    erste_zeilen("sp_vermittlung_beenden", (vermittlung_id, mitarbeiter_id, grund, notiz))


def vermittlungen(standort_id: int | None = None, nur_aktive: bool = False) -> list[dict[str, Any]]:
    bedingungen: list[str] = []
    werte: list[Any] = []
    if standort_id:
        bedingungen.append("t.standort_id = %s")
        werte.append(standort_id)
    if nur_aktive:
        bedingungen.append("v.beendet_am IS NULL")
    wo = (" WHERE " + " AND ".join(bedingungen)) if bedingungen else ""
    return abfrage(
        f"""
        SELECT v.id, v.bewerbung_id, v.vermittelt_am, v.beendet_am, v.beendigungsgrund, v.notiz,
               t.id AS tier_id, t.name AS tiername, t.status AS tierstatus,
               i.pseudonym, m.name AS mitarbeiter, s.name AS standort
        FROM vermittlung v
        JOIN tier t ON t.id = v.tier_id
        JOIN standort s ON s.id = t.standort_id
        JOIN bewerbung b ON b.id = v.bewerbung_id
        JOIN interessent i ON i.id = b.interessent_id
        JOIN mitarbeiter m ON m.id = v.mitarbeiter_id
        {wo}
        ORDER BY v.vermittelt_am DESC
        """,
        werte,
    )


# --- Einstellungen (Admin) ---------------------------------------------------------------


def gewichtung() -> list[dict[str, Any]]:
    return abfrage(
        """
        SELECT k.name AS kriterium, g.gewicht
        FROM matching_kategorie k
        LEFT JOIN matching_gewichtung g ON g.kriterium = k.name
        ORDER BY g.gewicht DESC, k.name
        """
    )


def gewichtung_speichern(gewichte: dict[str, float]) -> None:
    """Alle Gewichte auf einmal setzen. Die Summe muss 100 ergeben, sonst gibt es keine Scores."""
    with transaktion() as cursor:
        for kriterium, gewicht in gewichte.items():
            cursor.execute(
                "UPDATE matching_gewichtung SET gewicht = %s WHERE kriterium = %s",
                (gewicht, kriterium),
            )


def mindestscore() -> float | None:
    return ein_wert("SELECT wert FROM matching_einstellung WHERE schluessel = 'mindestscore'")


def mindestscore_setzen(wert: float) -> None:
    with transaktion() as cursor:
        cursor.execute(
            "UPDATE matching_einstellung SET wert = %s WHERE schluessel = 'mindestscore'", (wert,)
        )


def einstellungen() -> list[dict[str, Any]]:
    return abfrage("SELECT schluessel, wert, beschreibung FROM matching_einstellung ORDER BY schluessel")


# --- Auswertung (Admin) ------------------------------------------------------------------


def eignungsverteilung() -> list[dict[str, Any]]:
    return abfrage("SELECT eignung, COUNT(*) AS paare FROM matching_score GROUP BY eignung")


def score_verteilung() -> list[dict[str, Any]]:
    return abfrage(
        "SELECT match_prozent, datenabdeckung_prozent FROM matching_vorschlaege ORDER BY match_prozent"
    )


def vorschlaege_je_standort() -> list[dict[str, Any]]:
    return abfrage(
        """
        SELECT v.standort, COUNT(*) AS vorschlaege, ROUND(AVG(v.match_prozent), 1) AS schnitt
        FROM matching_vorschlaege v GROUP BY v.standort ORDER BY vorschlaege DESC
        """
    )


def vermittlungen_je_standort() -> list[dict[str, Any]]:
    return abfrage(
        """
        SELECT s.name AS standort,
               COUNT(v.id) AS vermittlungen,
               SUM(v.beendet_am IS NULL) AS laufend
        FROM standort s
        LEFT JOIN tier t ON t.standort_id = s.id
        LEFT JOIN vermittlung v ON v.tier_id = t.id
        GROUP BY s.id, s.name ORDER BY vermittlungen DESC
        """
    )


def tiere_je_status() -> list[dict[str, Any]]:
    return abfrage("SELECT status, COUNT(*) AS anzahl FROM tier GROUP BY status")
