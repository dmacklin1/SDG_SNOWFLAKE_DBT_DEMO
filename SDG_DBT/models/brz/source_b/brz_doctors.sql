-- BRONZE | Source B (HR / credentialing system)
-- Type standardisation and audit passthrough.

SELECT
    doctor_id::VARCHAR(10)         AS doctor_id,
    doctor_name::VARCHAR(100)      AS doctor_name,
    specialty::VARCHAR(50)         AS specialty,
    department::VARCHAR(50)        AS department,
    hire_date::DATE                AS hire_date,
    _loaded_at                     AS _loaded_at,
    _source_system                 AS _source
FROM {{ source('source_b', 'raw_doctors') }}
