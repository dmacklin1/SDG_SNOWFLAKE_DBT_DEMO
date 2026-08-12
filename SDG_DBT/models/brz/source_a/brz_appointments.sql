-- BRONZE | Source A (scheduling system)
-- Type standardisation and audit passthrough. No business logic, no filtering.
--
-- The landing table is all VARCHAR, so these casts are the actual contract
-- between "what arrived" and "what the warehouse guarantees".
--
-- _loaded_at is passed through from the landing table, not recomputed. It is a
-- real landing timestamp and stays identical no matter how often this rebuilds.

SELECT
    patient_id::INTEGER            AS patient_id,
    patient_name::VARCHAR(100)     AS patient_name,
    doctor_id::VARCHAR(10)         AS doctor_id,
    appointment_date::DATE         AS appointment_date,
    status::VARCHAR(20)            AS status,
    notes::VARCHAR(500)            AS notes,
    _loaded_at                     AS _loaded_at,
    _source_system                 AS _source
FROM {{ source('source_a', 'raw_appointments') }}
