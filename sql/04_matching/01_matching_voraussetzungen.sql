USE paws_match;
SET NAMES utf8mb4;

ALTER TABLE tier
    ADD COLUMN kleintiere_ok BOOLEAN NULL,
    ADD CONSTRAINT ck_tier_kleintiere CHECK (kleintiere_ok IN (0, 1));

CREATE VIEW matching_zusatzpruefung AS
SELECT
    t.id AS tier_id,
    i.id AS interessent_id,
    t.name AS tiername,
    i.pseudonym,
    t.min_erfahrung AS mindest_erfahrung,
    e.erfahrungslevel AS tierart_erfahrung,
    CASE
        WHEN i.kleintiere_vorhanden = 1 AND t.kleintiere_ok = 0
            THEN 'ausgeschlossen'
        WHEN i.kleintiere_vorhanden = 0 OR t.kleintiere_ok = 1
            THEN 'erfuellt'
        ELSE 'pruefung_offen'
    END AS kleintier_pruefung,
    CASE
        WHEN t.min_erfahrung = 0 THEN 'erfuellt'
        WHEN e.erfahrungslevel < t.min_erfahrung THEN 'ausgeschlossen'
        WHEN t.min_erfahrung IS NULL OR e.erfahrungslevel IS NULL
            THEN 'pruefung_offen'
        ELSE 'erfuellt'
    END AS erfahrungs_pruefung,
    NULLIF(CONCAT_WS(' | ',
        CASE
            WHEN i.kleintiere_vorhanden = 1 AND t.kleintiere_ok = 0
                THEN 'Tier ist nicht mit den vorhandenen Kleintieren vertraeglich'
            WHEN i.kleintiere_vorhanden = 0 OR t.kleintiere_ok = 1 THEN NULL
            ELSE CONCAT_WS('; ',
                IF(i.kleintiere_vorhanden IS NULL,
                   'Angabe zu vorhandenen Kleintieren fehlt', NULL),
                IF(t.kleintiere_ok IS NULL,
                   'Kleintiervertraeglichkeit des Tieres fehlt', NULL)
            )
        END,
        CASE
            WHEN t.min_erfahrung = 0 THEN NULL
            WHEN t.min_erfahrung IS NULL
                THEN 'Mindestanforderung an Erfahrung fehlt'
            WHEN e.erfahrungslevel IS NULL
                THEN 'Erfahrung mit dieser Tierart fehlt'
            WHEN e.erfahrungslevel < t.min_erfahrung
                THEN 'Tierartspezifische Erfahrung reicht nicht aus'
            ELSE NULL
        END
    ), '') AS hinweise
FROM tier t
CROSS JOIN interessent i
LEFT JOIN interessent_tiererfahrung e
    ON e.interessent_id = i.id
   AND e.tierart_id = t.tierart_id
WHERE i.aktiv = 1;
