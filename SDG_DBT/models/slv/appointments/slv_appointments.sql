SELECT
    appointment_sk,
    patient_id,
    patient_name,
    doctor_id,
    appointment_date,
    status,
    notes,
    _loaded_at,
    _source
FROM {{ ref('slv_base_appointments') }}