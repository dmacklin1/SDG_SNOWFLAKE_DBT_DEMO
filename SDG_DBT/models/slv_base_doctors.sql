-- SILVER | Base — provider records, cleaned and keyed.

SELECT
    TRIM(doctor_id)                 AS doctor_id,
    INITCAP(TRIM(doctor_name))      AS doctor_name,
    INITCAP(TRIM(specialty))        AS specialty,
    INITCAP(TRIM(department))       AS department,
    hire_date,
    _loaded_at,
    _source
FROM {{ ref('brz_doctors') }}
WHERE doctor_id IS NOT NULL
