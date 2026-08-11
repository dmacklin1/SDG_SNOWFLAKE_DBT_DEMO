-- SILVER | Base — one row per source record, cleaned and keyed.
-- Cleaning, surrogate key, null handling. Still 1:1 with the source.

SELECT
    MD5(CAST(patient_id AS VARCHAR) || '|' ||
        CAST(appointment_date AS VARCHAR) || '|' ||
        doctor_id)                                          AS appointment_sk,
    patient_id,
    INITCAP(TRIM(patient_name))                             AS patient_name,
    TRIM(doctor_id)                                         AS doctor_id,
    appointment_date,
    LOWER(TRIM(status))                                     AS status,
    COALESCE(NULLIF(TRIM(notes), ''), 'No notes provided')  AS notes,
    _loaded_at,
    _source
FROM {{ ref('brz_appointments') }}
WHERE patient_id IS NOT NULL
  AND status     IS NOT NULL
