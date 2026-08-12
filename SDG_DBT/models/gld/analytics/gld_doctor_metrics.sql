-- GOLD | Analytics — one row per provider. Consumption-ready aggregate that
-- backs the semantic view and the Cortex agent.

WITH appointments AS (
    SELECT * FROM {{ ref('slv_appointments') }}
),

doctors AS (
    SELECT * FROM {{ ref('slv_doctors') }}
)

SELECT
    a.doctor_id,
    d.doctor_name,
    d.specialty,
    d.department,
    COUNT(*)                                                            AS total_appointments,
    SUM(CASE WHEN a.status = 'completed' THEN 1 ELSE 0 END)             AS completed,
    SUM(CASE WHEN a.status = 'cancelled' THEN 1 ELSE 0 END)             AS cancelled,
    SUM(CASE WHEN a.status = 'scheduled' THEN 1 ELSE 0 END)             AS scheduled,
    ROUND(SUM(CASE WHEN a.status = 'completed' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0) * 100, 1)                               AS completion_rate_pct,
    ROUND(SUM(CASE WHEN a.status = 'cancelled' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0) * 100, 1)                               AS cancellation_rate_pct,
    COUNT(DISTINCT a.appointment_date)                                   AS active_days,
    ROUND(COUNT(*) / NULLIF(COUNT(DISTINCT a.appointment_date), 0), 1)   AS avg_appointments_per_day
FROM appointments a
JOIN doctors d ON a.doctor_id = d.doctor_id
GROUP BY a.doctor_id, d.doctor_name, d.specialty, d.department
