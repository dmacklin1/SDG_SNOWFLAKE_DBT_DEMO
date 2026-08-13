-- SILVER | Base — one row per source record, type-cast, cleaned, and keyed.
-- Combines type standardisation (from raw VARCHAR landing) with cleaning,
-- surrogate key, and null handling. Still 1:1 with the source.

SELECT
    MD5(CAST(patient_id AS VARCHAR) || '|' ||
        CAST(appointment_date AS VARCHAR) || '|' ||
        doctor_id)                                          AS appointment_sk,
    patient_id::INTEGER                                     AS patient_id,
    INITCAP(TRIM(patient_name::VARCHAR(100)))               AS patient_name,
    TRIM(doctor_id::VARCHAR(10))                            AS doctor_id,
    appointment_date::DATE                                  AS appointment_date,
    LOWER(TRIM(status::VARCHAR(20)))                        AS status,
    COALESCE(NULLIF(TRIM(notes::VARCHAR(500)), ''), 'No notes provided') AS notes,
    _loaded_at                                              AS _loaded_at,
    _source_system                                          AS _source
FROM {{ source('source_a', 'raw_appointments') }}
WHERE patient_id IS NOT NULL
  AND status     IS NOT NULL
