-- MatchingBegruendungen.sql
-- Paws & Match: Begründungen für Ausschlüsse und offene Prüfungen
-- Diese Datei ergänzt die bestehende Match-Logik, ohne bestehende Views zu verändern.

USE paws_match;

CREATE OR REPLACE VIEW v_match_begruendungen AS
SELECT
    t.id AS tier_id,
    i.id AS interessent_id,
    t.name AS tiername,
    i.pseudonym,
    t.status AS tierstatus,
    b.eignung,
    GROUP_CONCAT(DISTINCT u.begründung ORDER BY u.reihenfolge SEPARATOR ' | ') AS begründungen
FROM tier t
JOIN standort s ON s.id = t.standort_id
CROSS JOIN interessent i
JOIN v_match_basis b
    ON b.tier_id = t.id
   AND b.interessent_id = i.id
LEFT JOIN (
    SELECT
        t.id AS tier_id,
        i.id AS interessent_id,
        1 AS reihenfolge,
        'Gewünschte Tierart nicht enthalten' AS begründung
    FROM tier t
    CROSS JOIN interessent i
    WHERE NOT EXISTS (
        SELECT 1
        FROM interessent_tierart p
        WHERE p.interessent_id = i.id
          AND p.tierart_id = t.tierart_id
    )

    UNION ALL

    SELECT
        t.id, i.id, 2,
        'Garten erforderlich, aber nicht vorhanden'
    FROM tier t
    CROSS JOIN interessent i
    WHERE t.garten_noetig = 1
      AND i.garten = 0

    UNION ALL

    SELECT
        t.id, i.id, 3,
        'Treppen sollten vermieden werden, aber kein Aufzug vorhanden'
    FROM tier t
    CROSS JOIN interessent i
    WHERE t.treppen_vermeiden = 1
      AND i.etage > 0
      AND i.aufzug = 0

    UNION ALL

    SELECT
        t.id, i.id, 4,
        'Kinder im Haushalt, Tier ist nicht kindgerecht'
    FROM tier t
    CROSS JOIN interessent i
    WHERE t.kinder_ok = 0
      AND i.kinder = 1

    UNION ALL

    SELECT
        t.id, i.id, 5,
        'Hund im Haushalt, Tier ist nicht hundgeeignet'
    FROM tier t
    CROSS JOIN interessent i
    WHERE t.hund_ok = 0
      AND i.hund_vorhanden = 1

    UNION ALL

    SELECT
        t.id, i.id, 6,
        'Katze im Haushalt, Tier ist nicht katzengeeignet'
    FROM tier t
    CROSS JOIN interessent i
    WHERE t.katze_ok = 0
      AND i.katze_vorhanden = 1

    UNION ALL

    SELECT
        t.id, i.id, 7,
        'Wohnfläche zu klein'
    FROM tier t
    CROSS JOIN interessent i
    WHERE i.wohnflaeche < t.min_wohnflaeche

    UNION ALL

    SELECT
        t.id, i.id, 8,
        'Zu wenig verfügbare Zeit'
    FROM tier t
    CROSS JOIN interessent i
    WHERE i.zeit_stunden < t.min_zeit

    UNION ALL

    SELECT
        t.id, i.id, 9,
        'Tier darf zu lange nicht allein bleiben'
    FROM tier t
    CROSS JOIN interessent i
    WHERE i.allein_stunden > t.max_allein

    UNION ALL

    SELECT
        t.id, i.id, 10,
        'Erfahrung reicht nicht aus'
    FROM tier t
    CROSS JOIN interessent i
    WHERE i.erfahrung < t.min_erfahrung

    UNION ALL

    SELECT
        t.id, i.id, 11,
        'Monatliches Budget reicht nicht aus'
    FROM tier t
    CROSS JOIN interessent i
    WHERE i.budget < t.monatskosten

    UNION ALL

    SELECT
        t.id, i.id, 12,
        'Medizinische Versorgung erforderlich, aber nicht zugesagt'
    FROM tier t
    CROSS JOIN interessent i
    WHERE t.medizin_noetig = 1
      AND i.medizin_bereit = 0

    UNION ALL

    SELECT
        t.id, i.id, 13,
        'Bedürfnis noch nicht bestätigt'
    FROM tier t
    CROSS JOIN interessent i
    JOIN tier_beduerfnis tb
        ON tb.tier_id = t.id
    LEFT JOIN interessent_beduerfnis ib
        ON ib.interessent_id = i.id
       AND ib.beduerfnis_id = tb.beduerfnis_id
    WHERE ib.interessent_id IS NULL
       OR ib.bestaetigt = 0
) u
    ON u.tier_id = t.id
   AND u.interessent_id = i.id
GROUP BY
    t.id,
    i.id,
    t.name,
    i.pseudonym,
    t.status,
    b.eignung;

-- Kontrolle: Begründungen pro Tier-Interessent-Kombination
SELECT *
FROM v_match_begruendungen
ORDER BY interessent_id, tier_id;
