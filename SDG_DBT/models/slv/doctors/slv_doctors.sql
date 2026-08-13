-- SILVER | Doctors — conformed provider dimension.
-- The business-facing definition of a provider. Downstream models join here,
-- not to the raw source.

SELECT
    doctor_id,
    doctor_name,
    specialty,
    department,
    hire_date,
    _loaded_at,
    _source,
    DATEDIFF('year', hire_date, CURRENT_DATE()) AS years_of_service
FROM {{ ref('slv_base_doctors') }}
