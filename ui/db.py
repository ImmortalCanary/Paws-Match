"""Verbindung zur Datenbank, Abfragen, Prozeduraufrufe und verstaendliche Fehlermeldungen.

Diese Schicht enthaelt bewusst keine Fachlogik: Das Matching, die Vermittlungsregeln und
alle Pruefungen stehen in der Datenbank (Views, Prozeduren, Trigger, CHECK-Constraints).
"""

from __future__ import annotations

import os
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator, Sequence

import mysql.connector
from dotenv import load_dotenv
from mysql.connector import pooling

ORDNER = Path(__file__).resolve().parent
load_dotenv(ORDNER / ".env")

# Standardwerte passen zum portablen Testserver aus context/ENTWICKLUNG.md, Abschnitt 7.
EINSTELLUNGEN = {
    "host": os.getenv("PAWS_DB_HOST", "127.0.0.1"),
    "port": int(os.getenv("PAWS_DB_PORT", "3399")),
    "user": os.getenv("PAWS_DB_USER", "root"),
    "password": os.getenv("PAWS_DB_PASSWORD", ""),
    "database": os.getenv("PAWS_DB_NAME", "paws_match"),
}

_pool: pooling.MySQLConnectionPool | None = None


class DatenbankFehler(Exception):
    """Fehler der Datenbank, uebersetzt in einen Satz fuer die Oberflaeche."""

    def __init__(self, nachricht: str, original: Exception | None = None) -> None:
        super().__init__(nachricht)
        self.nachricht = nachricht
        self.original = original


def _pool_holen() -> pooling.MySQLConnectionPool:
    global _pool
    if _pool is None:
        try:
            _pool = pooling.MySQLConnectionPool(
                pool_name="paws_match_ui",
                pool_size=5,
                pool_reset_session=True,
                charset="utf8mb4",
                collation="utf8mb4_0900_ai_ci",
                autocommit=True,
                time_zone="+00:00",
                **EINSTELLUNGEN,
            )
        except mysql.connector.Error as fehler:
            raise DatenbankFehler(verstaendlicher_fehler(fehler), fehler) from fehler
    return _pool


def verbindung_zuruecksetzen() -> None:
    """Pool verwerfen, damit beim naechsten Zugriff neu verbunden wird."""
    global _pool
    _pool = None


@contextmanager
def verbindung() -> Iterator[mysql.connector.MySQLConnection]:
    """Eine Verbindung aus dem Pool, danach zurueck in den Pool."""
    try:
        conn = _pool_holen().get_connection()
    except mysql.connector.Error as fehler:
        raise DatenbankFehler(verstaendlicher_fehler(fehler), fehler) from fehler
    try:
        # Ohne diese Zeile schneidet MySQL die Ausschlussgruende nach 1024 Zeichen ab.
        with conn.cursor() as cursor:
            cursor.execute("SET SESSION group_concat_max_len = 65535")
        yield conn
    finally:
        conn.close()


@contextmanager
def transaktion() -> Iterator[mysql.connector.cursor.MySQLCursorDict]:
    """Mehrere Schreibschritte als eine Einheit: bei einem Fehler wird nichts gespeichert.

    Nicht fuer Prozeduren verwenden - sp_reservieren, sp_vermitteln, sp_vermittlung_beenden
    und sp_interessent_loeschen setzen selbst COMMIT ab.
    """
    with verbindung() as conn:
        conn.start_transaction()
        cursor = conn.cursor(dictionary=True)
        try:
            yield cursor
            conn.commit()
        except mysql.connector.Error as fehler:
            conn.rollback()
            raise DatenbankFehler(verstaendlicher_fehler(fehler), fehler) from fehler
        except Exception:
            conn.rollback()
            raise
        finally:
            cursor.close()


def abfrage(sql: str, parameter: Sequence[Any] | None = None) -> list[dict[str, Any]]:
    """Eine lesende Abfrage, Ergebnis als Liste von Zeilen."""
    with verbindung() as conn:
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(sql, tuple(parameter or ()))
            return cursor.fetchall()
        except mysql.connector.Error as fehler:
            raise DatenbankFehler(verstaendlicher_fehler(fehler), fehler) from fehler
        finally:
            cursor.close()


def eine_zeile(sql: str, parameter: Sequence[Any] | None = None) -> dict[str, Any] | None:
    zeilen = abfrage(sql, parameter)
    return zeilen[0] if zeilen else None


def ein_wert(sql: str, parameter: Sequence[Any] | None = None) -> Any:
    zeile = eine_zeile(sql, parameter)
    if zeile is None:
        return None
    return next(iter(zeile.values()))


def schreiben(sql: str, parameter: Sequence[Any] | None = None) -> int:
    """Einzelnes INSERT/UPDATE/DELETE. Gibt die ID bzw. die Zahl der Zeilen zurueck."""
    with transaktion() as cursor:
        cursor.execute(sql, tuple(parameter or ()))
        return cursor.lastrowid or cursor.rowcount


def prozedur(name: str, parameter: Sequence[Any] = ()) -> list[list[dict[str, Any]]]:
    """Prozedur aufrufen und alle Ergebnismengen als Liste von Zeilenlisten zurueckgeben."""
    with verbindung() as conn:
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.callproc(name, tuple(parameter))
            return [list(ergebnis.fetchall()) for ergebnis in cursor.stored_results()]
        except mysql.connector.Error as fehler:
            raise DatenbankFehler(verstaendlicher_fehler(fehler), fehler) from fehler
        finally:
            cursor.close()


def prozedur_mit_rueckgabe(name: str, parameter: Sequence[Any]) -> tuple[Any, ...]:
    """Prozedur mit OUT-Parameter, z. B. sp_interessent_loeschen(id, @ergebnis)."""
    with verbindung() as conn:
        cursor = conn.cursor()
        try:
            return tuple(cursor.callproc(name, tuple(parameter)))
        except mysql.connector.Error as fehler:
            raise DatenbankFehler(verstaendlicher_fehler(fehler), fehler) from fehler
        finally:
            cursor.close()


def erste_zeilen(name: str, parameter: Sequence[Any] = ()) -> list[dict[str, Any]]:
    """Prozedur aufrufen, die genau eine Ergebnismenge liefert."""
    ergebnisse = prozedur(name, parameter)
    return ergebnisse[0] if ergebnisse else []


# --- Fehlermeldungen -------------------------------------------------------------------

_CONSTRAINT_TEXTE = {
    "ck_interessent_tagesstunden":
        "Betreuungszeit und Alleinzeit dürfen zusammen höchstens 24 Stunden ergeben.",
    "ck_interessent_bezirk": "Ein aktives Profil braucht einen Wohnbezirk.",
    "ck_interessent_gesicherter_balkon":
        "Ein gesicherter Balkon setzt voraus, dass überhaupt ein Balkon vorhanden ist.",
    "ck_interessent_wunschalter":
        "Das gewünschte Mindestalter darf nicht über dem Höchstalter liegen.",
    "ck_interessent_max_entfernung":
        "Die Entfernung muss zwischen 5 und 250 km liegen und ein Vielfaches von 5 sein.",
    "ck_interessent_email": "Bitte eine gültige E-Mail-Adresse angeben.",
    "ck_mitarbeiter_email": "Bitte eine gültige E-Mail-Adresse angeben.",
    "ck_benutzerkonto_email": "Bitte eine gültige E-Mail-Adresse angeben.",
    "ck_tierheim_email": "Bitte eine gültige E-Mail-Adresse angeben.",
    "ck_interessent_aktivitaet": "Das Aktivitätslevel muss zwischen 1 und 5 liegen.",
    "ck_interessent_erfahrung": "Die Erfahrung muss zwischen 0 und 5 liegen.",
    "ck_interessent_zeit": "Die Betreuungszeit muss zwischen 0 und 24 Stunden liegen.",
    "ck_interessent_alleinzeit": "Die Alleinzeit muss zwischen 0 und 24 Stunden liegen.",
    "ck_tier_tagesstunden":
        "Mindestbetreuung und Alleinzeit dürfen zusammen höchstens 24 Stunden ergeben.",
    "ck_tier_reservierung":
        "Der Status „reserviert“ geht nur zusammen mit einer laufenden Bewerbung.",
    "ck_tier_aktivitaet": "Das Aktivitätslevel muss zwischen 1 und 5 liegen.",
    "ck_tier_min_erfahrung": "Die nötige Erfahrung muss zwischen 0 und 5 liegen.",
    "ck_tier_gewicht": "Das Gewicht muss größer als 0 sein.",
}

_SPALTEN_TEXTE = {
    "interessent.email": "Diese E-Mail-Adresse ist schon vergeben.",
    "mitarbeiter.email": "Diese E-Mail-Adresse ist schon vergeben.",
    "benutzerkonto.email": "Für diese E-Mail-Adresse gibt es schon ein Konto.",
    "uq_bewerbung": "Für dieses Tier gibt es von diesem Profil schon eine Bewerbung.",
    "primary": "Dieser Eintrag ist schon vorhanden.",
}


def verstaendlicher_fehler(fehler: Exception) -> str:
    """MySQL-Fehler in einen Satz uebersetzen, den man in der Oberflaeche anzeigen kann."""
    nummer = getattr(fehler, "errno", None)
    text = (getattr(fehler, "msg", None) or str(fehler)).strip()

    # Eigene Meldungen aus SIGNAL SQLSTATE '45000' (Prozeduren und Trigger) direkt zeigen.
    if nummer in (1644, 1645) or getattr(fehler, "sqlstate", None) == "45000":
        return text

    if nummer == 2003:
        return (
            f"Keine Verbindung zur Datenbank ({EINSTELLUNGEN['host']}:{EINSTELLUNGEN['port']}). "
            "Läuft der MySQL-Server, und stimmen die Angaben in ui/.env?"
        )
    if nummer == 1045:
        return "Anmeldung an der Datenbank fehlgeschlagen: Benutzer oder Passwort in ui/.env prüfen."
    if nummer == 1049:
        return (
            f"Die Datenbank '{EINSTELLUNGEN['database']}' gibt es nicht. "
            "Bitte zuerst die SQL-Skripte aus paws_and_match/README.md ausführen."
        )
    if nummer == 1146:
        return (
            "Eine benötigte Tabelle fehlt. Bitte die SQL-Skripte vollständig ausführen "
            "(einschließlich 08_oberflaeche/01_benutzerkonten.sql)."
        )
    if nummer == 3819:  # CHECK-Constraint verletzt
        for name, satz in _CONSTRAINT_TEXTE.items():
            if name in text:
                return satz
        return f"Die Angaben sind so nicht zulässig ({text})."
    if nummer == 1062:  # UNIQUE verletzt
        klein = text.lower()
        for name, satz in _SPALTEN_TEXTE.items():
            if name in klein:
                return satz
        return "Dieser Eintrag ist schon vorhanden."
    if nummer in (1451, 1452):  # Fremdschluessel
        return (
            "Dieser Eintrag hängt mit anderen Daten zusammen und kann so nicht gespeichert "
            "oder gelöscht werden."
        )
    if nummer == 1048:
        return "Ein Pflichtfeld ist leer geblieben."
    if nummer in (1264, 1366):
        return "Ein Wert passt nicht zum erwarteten Format oder liegt außerhalb des gültigen Bereichs."
    return text


def ist_erreichbar() -> tuple[bool, str]:
    """Fuer die Startseite: laeuft die Datenbank und ist sie installiert?"""
    try:
        ein_wert("SELECT 1")
        return True, ""
    except DatenbankFehler as fehler:
        return False, fehler.nachricht
