"""Rollentrennung: wer darf was sehen."""

from __future__ import annotations

import pytest

import auth

DEMO_PASSWORT = "paws2026"


@pytest.mark.parametrize(
    "rolle,bereich,erwartet",
    [
        # Interessenten kommen in keinen internen Bereich.
        (auth.INTERESSENT, auth.MITARBEITER, False),
        (auth.INTERESSENT, auth.ADMIN, False),
        (auth.INTERESSENT, auth.INTERESSENT, True),
        # Besucher ebenso wenig.
        (auth.BESUCHER, auth.MITARBEITER, False),
        (auth.BESUCHER, auth.ADMIN, False),
        (auth.BESUCHER, auth.BESUCHER, True),
        # Mitarbeitende duerfen ausdruecklich nicht in die Adminsicht.
        (auth.MITARBEITER, auth.MITARBEITER, True),
        (auth.MITARBEITER, auth.ADMIN, False),
        (auth.MITARBEITER, auth.INTERESSENT, False),
        # Admin darf alles.
        (auth.ADMIN, auth.MITARBEITER, True),
        (auth.ADMIN, auth.ADMIN, True),
        (auth.ADMIN, auth.INTERESSENT, True),
        # Unbekannte Rolle darf nichts Internes.
        (None, auth.MITARBEITER, False),
    ],
)
def test_zugriffsmatrix(rolle, bereich, erwartet) -> None:
    assert auth.darf(rolle, bereich) is erwartet


def test_anmeldung_mit_richtigem_passwort() -> None:
    konto = auth.pruefe_anmeldung("team3@example.org", DEMO_PASSWORT)
    assert konto is not None
    assert konto["rolle"] == auth.MITARBEITER
    assert konto["standort_id"] is not None
    assert "passwort_hash" not in konto, "Der Hash darf die Datenschicht nicht verlassen"


def test_anmeldung_mit_falschem_passwort() -> None:
    assert auth.pruefe_anmeldung("team3@example.org", "falsch") is None
    assert auth.pruefe_anmeldung("gibtsnicht@example.org", DEMO_PASSWORT) is None
    assert auth.pruefe_anmeldung("", "") is None


def test_adminkonto_haengt_an_keinem_standort() -> None:
    konto = auth.pruefe_anmeldung("admin@example.org", DEMO_PASSWORT)
    assert konto is not None
    assert konto["rolle"] == auth.ADMIN
    assert konto["mitarbeiter_id"] is None


def test_passwort_hash_ist_kein_klartext() -> None:
    hash_wert = auth.passwort_hashen("geheim")
    assert hash_wert != "geheim"
    assert auth.passwort_stimmt("geheim", hash_wert)
    assert not auth.passwort_stimmt("anders", hash_wert)
    assert not auth.passwort_stimmt("geheim", "kein-hash")


def test_profil_wird_ueber_email_gefunden() -> None:
    profil = auth.profil_nach_email("profil17@example.org")
    assert profil is not None and profil["id"] == 17
    assert auth.profil_nach_email("niemand@example.org") is None
