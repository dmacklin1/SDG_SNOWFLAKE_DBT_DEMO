-- BRONZE | Source A (scheduling system)
-- Type standardisation and audit metadata only. No business logic, no filtering.

SELECT
    patient_id::INTEGER            AS patient_id,
    patient_name::VARCHAR(100)     AS patient_name,
    doctor_id::VARCHAR(10)         AS doctor_id,
    appointment_date::DATE         AS appointment_date,
    status::VARCHAR(20)            AS status,
    notes::VARCHAR(500)            AS notes,
    CURRENT_TIMESTAMP()            AS _loaded_at,
    'SOURCE_A'                     AS _source
FROM {{ ref('raw_appointments') }}
