-- GOLD | Analytics — one row per provider. Consumption-ready aggregate that
-- backs the semantic view and the Cortex agent.

WITH appointments AS (
    SELECT * FROM {{ ref('slv_appointments') }}
)

SELECT
    doctor_id,
    doctor_name,
    specialty,
    department,
    COUNT(*)                                                        AS total_appointments,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END)           AS completed,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END)           AS cancelled,
    SUM(CASE WHEN status = 'scheduled' THEN 1 ELSE 0 END)           AS scheduled,
    ROUND(SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0) * 100, 1)                           AS completion_rate_pct,
    ROUND(SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0) * 100, 1)                           AS cancellation_rate_pct,
    COUNT(DISTINCT appointment_date)                                AS active_days,
    ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT appointment_date), 0), 1) AS avg_appointments_per_day
FROM appointments
GROUP BY doctor_id, doctor_name, specialty, department
