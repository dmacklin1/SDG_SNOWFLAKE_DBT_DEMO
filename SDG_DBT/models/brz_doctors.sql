-- BRONZE | Source B (HR / credentialing system)
-- Type standardisation and audit metadata only.

SELECT
    doctor_id::VARCHAR(10)         AS doctor_id,
    doctor_name::VARCHAR(100)      AS doctor_name,
    specialty::VARCHAR(50)         AS specialty,
    department::VARCHAR(50)        AS department,
    hire_date::DATE                AS hire_date,
    CURRENT_TIMESTAMP()            AS _loaded_at,
    'SOURCE_B'                     AS _source
FROM {{ ref('raw_doctors') }}
