"""Reine Unit-Tests fuer ui/bausteine.py, ohne Datenbankzugriff noetig.

Insbesondere foto_url_gueltig(): die Plausibilitaetspruefung, die den gespeicherten
XSS ueber foto_url schliesst (P2-3). Diese Tests laufen bewusst ohne DB-Interaktion,
brauchen aber trotzdem eine erreichbare Testdatenbank, weil die session-weite,
autouse-Fixture in conftest.py das fuer das ganze Testverzeichnis voraussetzt.
"""

from __future__ import annotations

import bausteine


def test_foto_url_gueltig_akzeptiert_leeren_wert() -> None:
    assert bausteine.foto_url_gueltig(None) is True
    assert bausteine.foto_url_gueltig("") is True
    assert bausteine.foto_url_gueltig("   ") is True


def test_foto_url_gueltig_akzeptiert_legitime_bild_url() -> None:
    assert bausteine.foto_url_gueltig("https://example.org/tiere/bello.jpg") is True
    assert bausteine.foto_url_gueltig("http://example.org/bello.PNG") is True
    assert bausteine.foto_url_gueltig("https://example.org/bello.jpg?v=3#foto") is True


def test_foto_url_gueltig_lehnt_falsches_protokoll_ab() -> None:
    assert bausteine.foto_url_gueltig("javascript:alert(1)") is False
    assert bausteine.foto_url_gueltig("data:image/png;base64,abc") is False
    assert bausteine.foto_url_gueltig("ftp://example.org/bello.jpg") is False
    assert bausteine.foto_url_gueltig("//example.org/bello.jpg") is False


def test_foto_url_gueltig_lehnt_html_injektion_ab() -> None:
    # Winkelklammern/Anfuehrungszeichen wuerden aus dem src="..."-Attribut ausbrechen.
    assert bausteine.foto_url_gueltig('https://example.org/bello.jpg"><script>alert(1)</script>') is False
    assert bausteine.foto_url_gueltig("https://example.org/bello.jpg onerror=alert(1)") is False
    assert bausteine.foto_url_gueltig("https://example.org/<script>.jpg") is False


def test_foto_url_gueltig_lehnt_unbekannte_endung_ab() -> None:
    assert bausteine.foto_url_gueltig("https://example.org/bello") is False
    assert bausteine.foto_url_gueltig("https://example.org/bello.exe") is False
    assert bausteine.foto_url_gueltig("https://example.org/bello.html") is False
