USE paws_match;
SET NAMES utf8mb4;
SET SESSION group_concat_max_len = 65535;

CREATE VIEW matching_entscheidung AS
WITH profil AS (
    SELECT
        t.*,
        i.id AS interessent_id,
        i.pseudonym,
        i.aktiv AS interessent_aktiv,
        i.garten,
        i.etage,
        i.aufzug,
        i.kinder,
        i.hund_vorhanden,
        i.katze_vorhanden,
        i.wohnflaeche,
        i.zeit_stunden,
        i.allein_stunden,
        i.budget,
        i.medizin_bereit,
        i.kleintiere_vorhanden,
        i.balkon,
        i.balkon_gesichert,
        i.training_bereit,
        i.tierarzt_bereit,
        e.erfahrungslevel,
        pf.rang AS pflege_bedarf,
        ipf.rang AS pflege_bereitschaft,
        EXISTS (
            SELECT 1
            FROM interessent_tierart it
            WHERE it.interessent_id = i.id
        ) AS tierwunsch_erfasst,
        EXISTS (
            SELECT 1
            FROM interessent_tierart it
            WHERE it.interessent_id = i.id
              AND it.tierart_id = t.tierart_id
        ) AS tierart_passt,
        EXISTS (
            SELECT 1
            FROM tier_beduerfnis tb
            WHERE tb.tier_id = t.id
              AND tb.beduerfnis_id = 2
        ) AS balkon_bedarf,
        EXISTS (
            SELECT 1
            FROM tier_beduerfnis tb
            WHERE tb.tier_id = t.id
              AND tb.beduerfnis_id = 4
        ) AS training_bedarf,
        CASE
            WHEN t.medizin_noetig = 1
              OR EXISTS (
                    SELECT 1
                    FROM tier_beduerfnis tb
                    WHERE tb.tier_id = t.id
                      AND tb.beduerfnis_id = 1
              )
                THEN 1
            WHEN t.medizin_noetig = 0 THEN 0
            ELSE NULL
        END AS medizin_bedarf,
        EXISTS (
            SELECT 1
            FROM tier_beduerfnis tb
            JOIN interessent_beduerfnis ib
                ON ib.beduerfnis_id = tb.beduerfnis_id
               AND ib.interessent_id = i.id
            WHERE tb.tier_id = t.id
              AND ib.bestaetigt = 0
        ) AS bedarf_abgelehnt,
        EXISTS (
            SELECT 1
            FROM tier_beduerfnis tb
            WHERE tb.tier_id = t.id
              AND NOT EXISTS (
                    SELECT 1
                    FROM interessent_beduerfnis ib
                    WHERE ib.interessent_id = i.id
                      AND ib.beduerfnis_id = tb.beduerfnis_id
              )
        ) AS bedarf_offen
    FROM tier t
    CROSS JOIN interessent i
    LEFT JOIN interessent_tiererfahrung e
        ON e.interessent_id = i.id
       AND e.tierart_id = t.tierart_id
    LEFT JOIN pflegeaufwand pf
        ON pf.id = t.pflegeaufwand_id
    LEFT JOIN pflegeaufwand ipf
        ON ipf.id = i.max_pflegeaufwand_id
),
kriterien AS (
    SELECT
        JSON_ARRAY('Tierartwunsch',
            CASE
                WHEN tierwunsch_erfasst = 0 THEN 1
                WHEN tierart_passt = 1 THEN 0
                ELSE 2
            END
        ) AS kriterium,
        JSON_ARRAY('Garten',
            CASE
                WHEN garten_noetig = 0 OR garten = 1 THEN 0
                WHEN garten_noetig = 1 AND garten = 0 THEN 2
                ELSE 1
            END
        ) AS kriterium,
        JSON_ARRAY('Treppen',
            CASE
                WHEN treppen_vermeiden = 0 OR etage = 0 OR aufzug = 1 THEN 0
                WHEN treppen_vermeiden = 1 AND etage > 0 AND aufzug = 0 THEN 2
                ELSE 1
            END
        ) AS kriterium,
        JSON_ARRAY('Kindervertraeglichkeit',
            CASE
                WHEN kinder_ok = 1 OR kinder = 0 THEN 0
                WHEN kinder_ok = 0 AND kinder = 1 THEN 2
                ELSE 1
            END
        ) AS kriterium,
        JSON_ARRAY('Hundevertraeglichkeit',
            CASE
                WHEN hund_ok = 1 OR hund_vorhanden = 0 THEN 0
                WHEN hund_ok = 0 AND hund_vorhanden = 1 THEN 2
                ELSE 1
            END
        ) AS kriterium,
        JSON_ARRAY('Katzenvertraeglichkeit',
            CASE
                WHEN katze_ok = 1 OR katze_vorhanden = 0 THEN 0
                WHEN katze_ok = 0 AND katze_vorhanden = 1 THEN 2
                ELSE 1
            END
        ) AS kriterium,
        JSON_ARRAY('Kleintiervertraeglichkeit',
            CASE
                WHEN kleintiere_ok = 1 OR kleintiere_vorhanden = 0 THEN 0
                WHEN kleintiere_ok = 0 AND kleintiere_vorhanden = 1 THEN 2
                ELSE 1
            END
        ) AS kriterium,
        JSON_ARRAY('Wohnflaeche',
            CASE
                WHEN min_wohnflaeche = 0 THEN 0
                WHEN wohnflaeche < min_wohnflaeche THEN 2
                WHEN wohnflaeche IS NULL OR min_wohnflaeche IS NULL THEN 1
                ELSE 0
            END
        ) AS kriterium,
        JSON_ARRAY('Betreuungszeit',
            CASE
                WHEN min_zeit = 0 THEN 0
                WHEN zeit_stunden < min_zeit THEN 2
                WHEN zeit_stunden IS NULL OR min_zeit IS NULL THEN 1
                ELSE 0
            END
        ) AS kriterium,
        JSON_ARRAY('Alleinzeit',
            CASE
                WHEN allein_stunden > max_allein THEN 2
                WHEN allein_stunden IS NULL OR max_allein IS NULL THEN 1
                ELSE 0
            END
        ) AS kriterium,
        JSON_ARRAY('Tierartspezifische Erfahrung',
            CASE
                WHEN min_erfahrung = 0 THEN 0
                WHEN erfahrungslevel < min_erfahrung THEN 2
                WHEN erfahrungslevel IS NULL OR min_erfahrung IS NULL THEN 1
                ELSE 0
            END
        ) AS kriterium,
        JSON_ARRAY('Monatliches Budget',
            CASE
                WHEN monatskosten = 0 THEN 0
                WHEN budget < monatskosten THEN 2
                WHEN budget IS NULL OR monatskosten IS NULL THEN 1
                ELSE 0
            END
        ) AS kriterium,
        JSON_ARRAY('Medizinische Versorgung',
            CASE
                WHEN medizin_bedarf = 0 OR medizin_bereit = 1 THEN 0
                WHEN medizin_bedarf = 1 AND medizin_bereit = 0 THEN 2
                ELSE 1
            END
        ) AS kriterium,
        JSON_ARRAY('Tierarztbereitschaft',
            CASE
                WHEN medizin_bedarf = 0 OR tierarzt_bereit = 1 THEN 0
                WHEN medizin_bedarf = 1 AND tierarzt_bereit = 0 THEN 2
                ELSE 1
            END
        ) AS kriterium,
        JSON_ARRAY('Notwendiges Training',
            CASE
                WHEN training_bedarf = 0 OR training_bereit = 1 THEN 0
                WHEN training_bedarf = 0 THEN 2
                ELSE 1
            END
        ) AS kriterium,
        JSON_ARRAY('Pflegeaufwand',
            CASE
                WHEN pflege_bereitschaft < pflege_bedarf THEN 2
                WHEN pflege_bereitschaft IS NULL OR pflege_bedarf IS NULL THEN 1
                ELSE 0
            END
        ) AS kriterium,
        JSON_ARRAY('Erforderlicher gesicherter Balkon',
            CASE
                WHEN balkon_bedarf = 0 THEN 0
                WHEN balkon = 0 OR balkon_gesichert = 0 THEN 2
                WHEN balkon = 1 AND balkon_gesichert = 1 THEN 0
                ELSE 1
            END
        ) AS kriterium,
        JSON_ARRAY('Verbindliches Beduerfnis ausdruecklich abgelehnt',
            IF(bedarf_abgelehnt, 2, 0)
        ) AS kriterium,
        JSON_ARRAY('Bestaetigung verbindlicher Beduerfnisse',
            IF(bedarf_offen, 1, 0)
        ) AS kriterium
    FROM profil
)
SELECT
    p.id AS tier_id,
    p.interessent_id,
    p.name AS tiername,
    p.pseudonym,
    p.status AS tierstatus,
    (p.status = 'verfuegbar') AS tier_verfuegbar,
    p.interessent_aktiv,
    CASE
        WHEN MAX(r.ergebnis) = 2 THEN 'ausgeschlossen'
        WHEN MAX(r.ergebnis) = 1 THEN 'pruefung_offen'
        ELSE 'geeignet'
    END AS eignung,
    GROUP_CONCAT(
        CASE
            WHEN r.ergebnis = 2
                THEN CONCAT(r.kriterium, ': Anforderung nicht erfuellt')
        END
        ORDER BY r.position
        SEPARATOR ' | '
    ) AS ausschlussgruende,
    GROUP_CONCAT(
        CASE
            WHEN r.ergebnis = 1
                THEN CONCAT(r.kriterium, ': erforderliche Angaben oder Bestaetigungen fehlen')
        END
        ORDER BY r.position
        SEPARATOR ' | '
    ) AS offene_pruefungen
FROM profil p
JOIN JSON_TABLE(
    JSON_ARRAY(
        JSON_ARRAY('Tierartwunsch',
            CASE
                WHEN tierwunsch_erfasst = 0 THEN 1
                WHEN tierart_passt = 1 THEN 0
                ELSE 2
            END),
        JSON_ARRAY('Garten',
            CASE
                WHEN garten_noetig = 0 OR garten = 1 THEN 0
                WHEN garten_noetig = 1 AND garten = 0 THEN 2
                ELSE 1
            END),
        JSON_ARRAY('Treppen',
            CASE
                WHEN treppen_vermeiden = 0 OR etage = 0 OR aufzug = 1 THEN 0
                WHEN treppen_vermeiden = 1 AND etage > 0 AND aufzug = 0 THEN 2
                ELSE 1
            END),
        JSON_ARRAY('Kindervertraeglichkeit',
            CASE
                WHEN kinder_ok = 1 OR kinder = 0 THEN 0
                WHEN kinder_ok = 0 AND kinder = 1 THEN 2
                ELSE 1
            END),
        JSON_ARRAY('Hundevertraeglichkeit',
            CASE
                WHEN hund_ok = 1 OR hund_vorhanden = 0 THEN 0
                WHEN hund_ok = 0 AND hund_vorhanden = 1 THEN 2
                ELSE 1
            END),
        JSON_ARRAY('Katzenvertraeglichkeit',
            CASE
                WHEN katze_ok = 1 OR katze_vorhanden = 0 THEN 0
                WHEN katze_ok = 0 AND katze_vorhanden = 1 THEN 2
                ELSE 1
            END),
        JSON_ARRAY('Kleintiervertraeglichkeit',
            CASE
                WHEN kleintiere_ok = 1 OR kleintiere_vorhanden = 0 THEN 0
                WHEN kleintiere_ok = 0 AND kleintiere_vorhanden = 1 THEN 2
                ELSE 1
            END),
        JSON_ARRAY('Wohnflaeche',
            CASE
                WHEN min_wohnflaeche = 0 THEN 0
                WHEN wohnflaeche < min_wohnflaeche THEN 2
                WHEN wohnflaeche IS NULL OR min_wohnflaeche IS NULL THEN 1
                ELSE 0
            END),
        JSON_ARRAY('Betreuungszeit',
            CASE
                WHEN min_zeit = 0 THEN 0
                WHEN zeit_stunden < min_zeit THEN 2
                WHEN zeit_stunden IS NULL OR min_zeit IS NULL THEN 1
                ELSE 0
            END),
        JSON_ARRAY('Alleinzeit',
            CASE
                WHEN allein_stunden > max_allein THEN 2
                WHEN allein_stunden IS NULL OR max_allein IS NULL THEN 1
                ELSE 0
            END),
        JSON_ARRAY('Tierartspezifische Erfahrung',
            CASE
                WHEN min_erfahrung = 0 THEN 0
                WHEN erfahrungslevel < min_erfahrung THEN 2
                WHEN erfahrungslevel IS NULL OR min_erfahrung IS NULL THEN 1
                ELSE 0
            END),
        JSON_ARRAY('Monatliches Budget',
            CASE
                WHEN monatskosten = 0 THEN 0
                WHEN budget < monatskosten THEN 2
                WHEN budget IS NULL OR monatskosten IS NULL THEN 1
                ELSE 0
            END),
        JSON_ARRAY('Medizinische Versorgung',
            CASE
                WHEN medizin_bedarf = 0 OR medizin_bereit = 1 THEN 0
                WHEN medizin_bedarf = 1 AND medizin_bereit = 0 THEN 2
                ELSE 1
            END),
        JSON_ARRAY('Tierarztbereitschaft',
            CASE
                WHEN medizin_bedarf = 0 OR tierarzt_bereit = 1 THEN 0
                WHEN medizin_bedarf = 1 AND tierarzt_bereit = 0 THEN 2
                ELSE 1
            END),
        JSON_ARRAY('Notwendiges Training',
            CASE
                WHEN training_bedarf = 0 OR training_bereit = 1 THEN 0
                WHEN training_bedarf = 0 THEN 2
                ELSE 1
            END),
        JSON_ARRAY('Pflegeaufwand',
            CASE
                WHEN pflege_bereitschaft < pflege_bedarf THEN 2
                WHEN pflege_bereitschaft IS NULL OR pflege_bedarf IS NULL THEN 1
                ELSE 0
            END),
        JSON_ARRAY('Erforderlicher gesicherter Balkon',
            CASE
                WHEN balkon_bedarf = 0 THEN 0
                WHEN balkon = 0 OR balkon_gesichert = 0 THEN 2
                WHEN balkon = 1 AND balkon_gesichert = 1 THEN 0
                ELSE 1
            END),
        JSON_ARRAY('Verbindliches Beduerfnis ausdruecklich abgelehnt',
            IF(bedarf_abgelehnt, 2, 0)),
        JSON_ARRAY('Bestaetigung verbindlicher Beduerfnisse',
            IF(bedarf_offen, 1, 0))
    ),
    '$[*]'
    COLUMNS (
        position FOR ORDINALITY,
        kriterium VARCHAR(100) PATH '$[0]',
        ergebnis INT PATH '$[1]'
    )
) AS r ON TRUE
GROUP BY
    p.id,
    p.interessent_id,
    p.name,
    p.pseudonym,
    p.status,
    p.interessent_aktiv;
