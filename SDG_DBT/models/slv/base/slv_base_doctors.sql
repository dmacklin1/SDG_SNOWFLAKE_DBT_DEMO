-- SILVER | Base — provider records, type-cast and cleaned.
-- Combines type standardisation (from raw VARCHAR landing) with cleaning.

SELECT
    TRIM(doctor_id::VARCHAR(10))            AS doctor_id,
    INITCAP(TRIM(doctor_name::VARCHAR(100))) AS doctor_name,
    INITCAP(TRIM(specialty::VARCHAR(50)))    AS specialty,
    INITCAP(TRIM(department::VARCHAR(50)))   AS department,
    hire_date::DATE                          AS hire_date,
    _loaded_at                              AS _loaded_at,
    _source_system                          AS _source
FROM {{ source('source_b', 'raw_doctors') }}
WHERE doctor_id IS NOT NULL
