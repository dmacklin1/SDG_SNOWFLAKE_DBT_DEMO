{{ config(
    materialized = 'incremental',
    unique_key   = 'appointment_sk'
) }}

-- SILVER | Appointments — conformed appointment fact, enriched with provider
-- attributes from the doctors dimension. This is where Source A and Source B meet.
--
-- INCREMENTAL: watermarked on appointment_date, a stable business column.
-- (_loaded_at is audit metadata only — it refreshes on every rebuild upstream,
--  so it is not safe to use as a watermark.)
--
-- To demo incrementality: append rows to raw_appointments.csv with dates after
-- 2024-01-31, then `dbt build`. Only the new rows are processed.

SELECT
    a.appointment_sk,
    a.patient_id,
    a.patient_name,
    a.doctor_id,
    d.doctor_name,
    d.specialty,
    d.department,
    a.appointment_date,
    a.status,
    a.notes,
    a._loaded_at,
    a._source
FROM {{ ref('slv_base_appointments') }} a
LEFT JOIN {{ ref('slv_doctors') }} d
       ON a.doctor_id = d.doctor_id

{% if is_incremental() %}
WHERE a.appointment_date > (SELECT MAX(appointment_date) FROM {{ this }})
{% endif %}
