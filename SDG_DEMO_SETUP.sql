-- 1. ACCOUNT SETTINGS
USE ROLE ACCOUNTADMIN;

ALTER ACCOUNT SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER ACCOUNT SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE RESOURCE MONITOR IF NOT EXISTS SDG_ACCT_MONITOR
    WITH CREDIT_QUOTA = 50 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
         TRIGGERS ON 50  PERCENT DO NOTIFY
                  ON 90  PERCENT DO NOTIFY
                  ON 100 PERCENT DO SUSPEND;

ALTER ACCOUNT SET RESOURCE_MONITOR = SDG_ACCT_MONITOR;


-- 2. ROLES
USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS SDG_DATA_ANALYST;
CREATE ROLE IF NOT EXISTS SDG_DATA_ENGINEER;
CREATE ROLE IF NOT EXISTS SDG_AI_ANALYST;
GRANT ROLE SDG_DATA_ANALYST  TO ROLE SDG_DATA_ENGINEER;
GRANT ROLE SDG_AI_ANALYST    TO ROLE SDG_DATA_ENGINEER;
GRANT ROLE SDG_DATA_ENGINEER TO ROLE SYSADMIN;


-- 3. WAREHOUSES
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SDG_TRANSFORM_WH
    WITH WAREHOUSE_SIZE = 'X-SMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;

CREATE WAREHOUSE IF NOT EXISTS SDG_AI_WH
    WITH WAREHOUSE_SIZE = 'X-SMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;

USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS SDG_TRANSFORM_WH_MONITOR
    WITH CREDIT_QUOTA = 20 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
         TRIGGERS ON 80 PERCENT DO NOTIFY ON 100 PERCENT DO SUSPEND;

CREATE RESOURCE MONITOR IF NOT EXISTS SDG_AI_WH_MONITOR
    WITH CREDIT_QUOTA = 10 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
         TRIGGERS ON 80 PERCENT DO NOTIFY ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE SDG_TRANSFORM_WH SET RESOURCE_MONITOR = SDG_TRANSFORM_WH_MONITOR;
ALTER WAREHOUSE SDG_AI_WH        SET RESOURCE_MONITOR = SDG_AI_WH_MONITOR;

USE ROLE SYSADMIN;

GRANT USAGE ON WAREHOUSE SDG_TRANSFORM_WH TO ROLE SDG_DATA_ANALYST;
GRANT USAGE ON WAREHOUSE SDG_TRANSFORM_WH TO ROLE SDG_DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE SDG_AI_WH        TO ROLE SDG_AI_ANALYST;
GRANT USAGE ON WAREHOUSE SDG_AI_WH        TO ROLE SDG_DATA_ENGINEER;


-- 4. DATABASES & SCHEMAS
USE ROLE SYSADMIN;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE SDG_DATA_ENGINEER;

USE ROLE SDG_DATA_ENGINEER;

CREATE DATABASE IF NOT EXISTS SDG_BRZ;
CREATE DATABASE IF NOT EXISTS SDG_SLV;
CREATE DATABASE IF NOT EXISTS SDG_GLD;
CREATE DATABASE IF NOT EXISTS SDG_SYS_CONFIG;

ALTER DATABASE SDG_BRZ        SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER DATABASE SDG_SLV        SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER DATABASE SDG_GLD        SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER DATABASE SDG_SYS_CONFIG SET DATA_RETENTION_TIME_IN_DAYS = 1;

CREATE SCHEMA IF NOT EXISTS SDG_BRZ.SOURCE_A;
CREATE SCHEMA IF NOT EXISTS SDG_BRZ.SOURCE_B;
CREATE SCHEMA IF NOT EXISTS SDG_SLV.BASE;
CREATE SCHEMA IF NOT EXISTS SDG_SLV.DOCTORS;
CREATE SCHEMA IF NOT EXISTS SDG_SLV.APPOINTMENTS;
CREATE SCHEMA IF NOT EXISTS SDG_GLD.ANALYTICS;
CREATE SCHEMA IF NOT EXISTS SDG_SYS_CONFIG.DBT;
CREATE SCHEMA IF NOT EXISTS SDG_SYS_CONFIG.SECURITY;


-- 5. SECURITY POLICIES (NOTE THESE ARE NOT APPLIED BUT IN A REAL ACCOUNT THEY WOULD BE)
USE ROLE SYSADMIN;

GRANT USAGE ON DATABASE SDG_SYS_CONFIG                        TO ROLE SECURITYADMIN;
GRANT USAGE ON SCHEMA   SDG_SYS_CONFIG.SECURITY               TO ROLE SECURITYADMIN;
GRANT CREATE PASSWORD POLICY       ON SCHEMA SDG_SYS_CONFIG.SECURITY TO ROLE SECURITYADMIN;
GRANT CREATE AUTHENTICATION POLICY ON SCHEMA SDG_SYS_CONFIG.SECURITY TO ROLE SECURITYADMIN;

USE ROLE SECURITYADMIN;

CREATE PASSWORD POLICY IF NOT EXISTS SDG_SYS_CONFIG.SECURITY.SDG_PASSWORD_POLICY
    PASSWORD_MIN_LENGTH = 12 PASSWORD_MAX_AGE_DAYS = 90
    PASSWORD_MAX_RETRIES = 5 PASSWORD_LOCKOUT_TIME_MINS = 30;

CREATE AUTHENTICATION POLICY IF NOT EXISTS SDG_SYS_CONFIG.SECURITY.PERSON_AUTH_POLICY
    AUTHENTICATION_METHODS = ('SAML', 'PASSWORD')
    CLIENT_TYPES = ('SNOWFLAKE_UI', 'SNOWSQL', 'DRIVERS')
    MFA_ENROLLMENT = REQUIRED;

CREATE AUTHENTICATION POLICY IF NOT EXISTS SDG_SYS_CONFIG.SECURITY.SERVICE_ACCOUNT_KEYPAIR_POLICY
    AUTHENTICATION_METHODS = ('KEYPAIR')
    CLIENT_TYPES = ('DRIVERS', 'SNOWSQL')
    MFA_ENROLLMENT = OPTIONAL;


-- 6. GRANTS
USE ROLE SYSADMIN;

GRANT USAGE ON DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT USAGE ON DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT USAGE ON DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON ALL SCHEMAS    IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON ALL SCHEMAS    IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON ALL SCHEMAS    IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON ALL TABLES    IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON ALL TABLES    IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON ALL TABLES    IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON ALL VIEWS    IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON ALL VIEWS    IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON ALL VIEWS    IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE VIEWS IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE VIEWS IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE VIEWS IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON DATABASE SDG_GLD                          TO ROLE SDG_AI_ANALYST;
GRANT USAGE  ON SCHEMA   SDG_GLD.ANALYTICS                TO ROLE SDG_AI_ANALYST;
GRANT SELECT ON ALL TABLES    IN SCHEMA SDG_GLD.ANALYTICS TO ROLE SDG_AI_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA SDG_GLD.ANALYTICS TO ROLE SDG_AI_ANALYST;
GRANT REFERENCES, SELECT ON ALL SEMANTIC VIEWS    IN SCHEMA SDG_GLD.ANALYTICS TO ROLE SDG_AI_ANALYST;
GRANT REFERENCES, SELECT ON FUTURE SEMANTIC VIEWS IN SCHEMA SDG_GLD.ANALYTICS TO ROLE SDG_AI_ANALYST;
GRANT CREATE DBT PROJECT ON SCHEMA SDG_SYS_CONFIG.DBT TO ROLE SDG_DATA_ENGINEER;
GRANT CREATE TASK ON SCHEMA SDG_SYS_CONFIG.DBT TO ROLE SDG_DATA_ENGINEER;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SDG_DATA_ENGINEER;

USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SDG_AI_ANALYST;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SDG_DATA_ENGINEER;


-- 7. SOURCE DATA
USE ROLE SDG_DATA_ENGINEER;
USE WAREHOUSE SDG_TRANSFORM_WH;

CREATE OR REPLACE TABLE SDG_BRZ.SOURCE_A.RAW_APPOINTMENTS (
    PATIENT_ID       VARCHAR(20),
    PATIENT_NAME     VARCHAR(100),
    DOCTOR_ID        VARCHAR(10),
    APPOINTMENT_DATE VARCHAR(20),
    STATUS           VARCHAR(20),
    NOTES            VARCHAR(500),
    _LOADED_AT       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _SOURCE_SYSTEM   VARCHAR(20)   DEFAULT 'SOURCE_A'
);

INSERT INTO SDG_BRZ.SOURCE_A.RAW_APPOINTMENTS
    (PATIENT_ID, PATIENT_NAME, DOCTOR_ID, APPOINTMENT_DATE, STATUS, NOTES)
VALUES
    (1001, 'Marcus Webb', 'D002', '2024-01-15', 'cancelled', 'New patient intake'),
    (1018, 'Jonas Lindqvist', 'D002', '2024-01-15', 'completed', 'Referral consult'),
    (1035, 'Hana Suzuki', 'D001', '2024-01-15', 'scheduled', 'Symptom evaluation'),
    (1002, 'Priya Raman', 'D002', '2024-01-16', 'cancelled', 'Preventive screening'),
    (1019, 'Rosa Marquez', 'D003', '2024-01-16', 'completed', 'Lab results discussion'),
    (1036, 'Isaac Levin', 'D003', '2024-01-16', 'cancelled', 'Chronic care check-in'),
    (1003, 'Tomas Ferreira', 'D002', '2024-01-17', 'completed', 'Lab results discussion'),
    (1020, 'Devin Ashford', 'D001', '2024-01-17', 'completed', 'New patient intake'),
    (1037, 'Camille Dubois', 'D003', '2024-01-17', 'completed', 'Post-op check'),
    (1004, 'Grace Okonkwo', 'D001', '2024-01-18', 'completed', 'New patient intake'),
    (1021, 'Farida Nasser', 'D003', '2024-01-18', 'completed', 'Medication review'),
    (1038, 'Nathan Okafor', 'D001', '2024-01-18', 'completed', 'Chronic care check-in'),
    (1005, 'Liam Doherty', 'D001', '2024-01-19', 'completed', 'Symptom evaluation'),
    (1022, 'Peter Kowalski', 'D002', '2024-01-19', 'completed', 'Chronic care check-in'),
    (1039, 'Lucia Ferrari', 'D002', '2024-01-19', 'completed', 'Routine follow-up'),
    (1006, 'Yuki Tanaka', 'D003', '2024-01-20', 'completed', 'Referral consult'),
    (1023, 'Anika Sharma', 'D002', '2024-01-20', 'completed', 'Symptom evaluation'),
    (1040, 'Dmitri Volkov', 'D003', '2024-01-20', 'completed', 'Annual physical'),
    (1007, 'Aisha Mensah', 'D002', '2024-01-21', 'completed', 'Symptom evaluation'),
    (1024, 'Bruno Machado', 'D003', '2024-01-21', 'completed', 'Annual physical'),
    (1041, 'Jasmine Carr', 'D001', '2024-01-21', 'completed', 'Chronic care check-in'),
    (1008, 'Diego Salazar', 'D001', '2024-01-22', 'completed', 'Medication review'),
    (1025, 'Sofia Kallio', 'D003', '2024-01-22', 'completed', 'Routine follow-up'),
    (1042, 'Andres Pinto', 'D003', '2024-01-22', 'completed', 'Post-op check'),
    (1009, 'Hannah Wexler', 'D002', '2024-01-23', 'completed', 'Post-op check'),
    (1026, 'Theo Bernard', 'D002', '2024-01-23', 'scheduled', 'Annual physical'),
    (1043, 'Beatrix Nagy', 'D001', '2024-01-23', 'cancelled', 'Lab results discussion'),
    (1010, 'Omar Haddad', 'D001', '2024-01-24', 'completed', 'Medication review'),
    (1027, 'Leila Haddadi', 'D002', '2024-01-24', 'completed', 'Medication review'),
    (1044, 'Kwame Asante', 'D001', '2024-01-24', 'cancelled', 'Annual physical'),
    (1011, 'Ingrid Solberg', 'D002', '2024-01-25', 'completed', 'New patient intake'),
    (1028, 'Gavin Pruitt', 'D002', '2024-01-25', 'completed', 'Medication review'),
    (1045, 'Sienna Marsh', 'D001', '2024-01-25', 'completed', 'Post-op check'),
    (1012, 'Rafael Costa', 'D002', '2024-01-26', 'completed', 'Chronic care check-in'),
    (1029, 'Noor Rahman', 'D002', '2024-01-26', 'completed', 'Referral consult'),
    (1046, 'Pavel Novak', 'D001', '2024-01-26', 'completed', 'Referral consult'),
    (1013, 'Nadia Petrov', 'D001', '2024-01-27', 'cancelled', 'Chronic care check-in'),
    (1030, 'Mateo Rivas', 'D003', '2024-01-27', 'completed', 'Preventive screening'),
    (1047, 'Talia Grossman', 'D001', '2024-01-27', 'completed', 'Medication review'),
    (1014, 'Colin Brady', 'D001', '2024-01-28', 'completed', 'Post-op check'),
    (1031, 'Ellie Sandoval', 'D003', '2024-01-28', 'completed', 'Annual physical'),
    (1048, 'Ronan Fitzgerald', 'D001', '2024-01-28', 'completed', 'Symptom evaluation'),
    (1015, 'Mei Ling Zhao', 'D003', '2024-01-29', 'completed', 'Preventive screening'),
    (1032, 'Viktor Ivanov', 'D003', '2024-01-29', 'scheduled', 'Referral consult'),
    (1049, 'Mira Chaudhry', 'D001', '2024-01-29', 'completed', 'Routine follow-up'),
    (1016, 'Samuel Adeyemi', 'D003', '2024-01-30', 'scheduled', 'Referral consult'),
    (1033, 'Amelia Boateng', 'D002', '2024-01-30', 'completed', 'Referral consult'),
    (1050, 'Felix Hartmann', 'D003', '2024-01-30', 'completed', 'Post-op check'),
    (1017, 'Clara Vogt', 'D001', '2024-01-31', 'scheduled', 'Preventive screening'),
    (1034, 'Rowan Kelly', 'D003', '2024-01-31', 'cancelled', 'Preventive screening');

CREATE OR REPLACE TABLE SDG_BRZ.SOURCE_B.RAW_DOCTORS (
    DOCTOR_ID      VARCHAR(10),
    DOCTOR_NAME    VARCHAR(100),
    SPECIALTY      VARCHAR(50),
    DEPARTMENT     VARCHAR(50),
    HIRE_DATE      VARCHAR(20),
    _LOADED_AT     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _SOURCE_SYSTEM VARCHAR(20)   DEFAULT 'SOURCE_B'
);

INSERT INTO SDG_BRZ.SOURCE_B.RAW_DOCTORS
    (DOCTOR_ID, DOCTOR_NAME, SPECIALTY, DEPARTMENT, HIRE_DATE)
VALUES
    ('D001', 'Dr. Amara Patel', 'Cardiology', 'Internal Medicine', '2016-03-14'),
    ('D002', 'Dr. Wei Chen', 'Endocrinology', 'Internal Medicine', '2019-07-01'),
    ('D003', 'Dr. Elena Lopez', 'Family Medicine', 'Primary Care', '2021-01-11');


-- 8. GIT INTEGRATION & dbt PROJECT
USE ROLE SDG_DATA_ENGINEER;
CREATE SCHEMA IF NOT EXISTS SDG_SYS_CONFIG.SECRETS;

USE ROLE ACCOUNTADMIN;

CREATE SECRET IF NOT EXISTS SDG_SYS_CONFIG.SECRETS.SDG_GIT_SECRET
    TYPE = PASSWORD USERNAME = 'dmacklin1'
    PASSWORD = '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';

CREATE OR REPLACE API INTEGRATION SDG_GIT_API
    API_PROVIDER = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/dmacklin1')
    ALLOWED_AUTHENTICATION_SECRETS = (SDG_SYS_CONFIG.SECRETS.SDG_GIT_SECRET)
    ENABLED = TRUE;

USE ROLE SECURITYADMIN;
GRANT USAGE ON INTEGRATION SDG_GIT_API TO ROLE SDG_DATA_ENGINEER;
GRANT USAGE ON SECRET SDG_SYS_CONFIG.SECRETS.SDG_GIT_SECRET TO ROLE SDG_DATA_ENGINEER;

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SDG_TRANSFORM_WH;

CREATE GIT REPOSITORY IF NOT EXISTS SDG_SYS_CONFIG.DBT.SDG_DEMO_REPO
    API_INTEGRATION = SDG_GIT_API
    GIT_CREDENTIALS = SDG_SYS_CONFIG.SECRETS.SDG_GIT_SECRET
    ORIGIN = 'https://github.com/dmacklin1/SDG_SNOWFLAKE_DBT_DEMO.git';

ALTER GIT REPOSITORY SDG_SYS_CONFIG.DBT.SDG_DEMO_REPO FETCH;

USE ROLE SDG_DATA_ENGINEER;
CREATE OR REPLACE DBT PROJECT SDG_SYS_CONFIG.DBT.SDG_DEMO
    FROM '@SDG_SYS_CONFIG.DBT.SDG_DEMO_REPO/branches/main/SDG_DBT/'
    DBT_VERSION = '1.9.4';

EXECUTE DBT PROJECT SDG_SYS_CONFIG.DBT.SDG_DEMO ARGS = 'build';

CREATE OR REPLACE TASK SDG_SYS_CONFIG.DBT.RUN_SDG_DEMO_DAILY
    WAREHOUSE = SDG_TRANSFORM_WH
    SCHEDULE = 'USING CRON 0 6 * * * America/New_York'
AS
    EXECUTE DBT PROJECT SDG_SYS_CONFIG.DBT.SDG_DEMO ARGS = 'build';

ALTER TASK SDG_SYS_CONFIG.DBT.RUN_SDG_DEMO_DAILY RESUME;

-- Verify dbt output before building semantic view
SELECT * FROM SDG_GLD.ANALYTICS.GLD_DOCTOR_METRICS;


-- 9. SEMANTIC VIEW
USE ROLE SDG_DATA_ENGINEER;
USE WAREHOUSE SDG_TRANSFORM_WH;

CREATE OR REPLACE SEMANTIC VIEW SDG_GLD.ANALYTICS.SDG_DOCTOR_PERFORMANCE

  TABLES (
    doctor_metrics AS SDG_GLD.ANALYTICS.GLD_DOCTOR_METRICS
      PRIMARY KEY (doctor_id)
      COMMENT = 'One row per provider. January 2024. Grain: one row per doctor_id.'
  )

  FACTS (
    doctor_metrics.total_appointments AS total_appointments
      COMMENT = 'Total appointments booked with this provider, all statuses.',
    doctor_metrics.completed AS completed
      COMMENT = 'Appointments with status = completed.',
    doctor_metrics.cancelled AS cancelled
      COMMENT = 'Appointments with status = cancelled.',
    doctor_metrics.scheduled AS scheduled
      COMMENT = 'Appointments still in scheduled status.',
    doctor_metrics.completion_rate_pct AS completion_rate_pct
      COMMENT = 'Percentage 0-100 for this provider only. Do not average across providers.',
    doctor_metrics.cancellation_rate_pct AS cancellation_rate_pct
      COMMENT = 'Percentage 0-100 for this provider only.',
    doctor_metrics.active_days AS active_days
      COMMENT = 'Distinct calendar days with at least one appointment.',
    doctor_metrics.avg_appointments_per_day AS avg_appointments_per_day
      COMMENT = 'Ratio: total_appointments / active_days.'
  )

  DIMENSIONS (
    doctor_metrics.doctor_id AS doctor_id
      COMMENT = 'Provider identifier. Format Dnnn.',
    doctor_metrics.doctor_name AS doctor_name
      WITH SYNONYMS = ('doctor', 'physician', 'provider', 'clinician', 'name')
      COMMENT = 'Full display name of the provider.',
    doctor_metrics.specialty AS specialty
      WITH SYNONYMS = ('specialty', 'speciality', 'practice area')
      COMMENT = 'Clinical specialty.',
    doctor_metrics.department AS department
      WITH SYNONYMS = ('department', 'division', 'service line')
      COMMENT = 'Department the provider reports into.'
  )

  METRICS (
    total_appointment_count AS SUM(doctor_metrics.total_appointments)
      COMMENT = 'Total appointments across all providers in scope.',
    total_completed AS SUM(doctor_metrics.completed)
      COMMENT = 'Total completed appointments across all providers.',
    total_cancelled AS SUM(doctor_metrics.cancelled)
      COMMENT = 'Total cancelled appointments across all providers.',
    overall_completion_rate_pct AS
        SUM(doctor_metrics.completed) / NULLIF(SUM(doctor_metrics.total_appointments), 0) * 100
      COMMENT = 'Volume-weighted completion rate. Use for clinic-wide questions.',
    overall_cancellation_rate_pct AS
        SUM(doctor_metrics.cancelled) / NULLIF(SUM(doctor_metrics.total_appointments), 0) * 100
      COMMENT = 'Volume-weighted cancellation rate.',
    avg_doctor_completion_rate_pct AS AVG(doctor_metrics.completion_rate_pct)
      COMMENT = 'Unweighted mean of per-provider rates. Only for typical-doctor questions.'
  );


-- 10. CORTEX AGENT
USE ROLE SDG_DATA_ENGINEER;

CREATE OR REPLACE AGENT SDG_GLD.ANALYTICS.SDG_APPOINTMENT_ANALYST
  FROM SPECIFICATION $$
models:
  orchestration: auto

instructions:
  response: |
    You are an appointment analytics assistant for a clinic operations team.
    1. Always give specific numbers.
    2. State percentages to one decimal place with % sign.
    3. For clinic-wide questions, use overall_completion_rate_pct or overall_cancellation_rate_pct.
    4. When comparing providers, show volumes alongside rates.
    5. The dataset covers January 2024 only. Decline questions about other periods.
    6. Be concise. Lead with the answer.

  orchestration: |
    Prefer a single query with ORDER BY and LIMIT for top-N questions.

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: DoctorPerformance
      description: >
        One row per provider (doctor_id). Three providers, January 2024.
        Dimensions: doctor_id, doctor_name, specialty, department.
        Counts: total_appointments, completed, cancelled, scheduled, active_days.
        Per-provider rates (already 0-100): completion_rate_pct, cancellation_rate_pct.
        Clinic-wide metrics: overall_completion_rate_pct, overall_cancellation_rate_pct.

tool_resources:
  DoctorPerformance:
    execution_environment:
      type: warehouse
      warehouse: SDG_AI_WH
    semantic_view: SDG_GLD.ANALYTICS.SDG_DOCTOR_PERFORMANCE
$$;

USE ROLE ACCOUNTADMIN;
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    ADD AGENT SDG_GLD.ANALYTICS.SDG_APPOINTMENT_ANALYST;

GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE SDG_AI_ANALYST;

USE ROLE SECURITYADMIN;
GRANT USAGE ON AGENT SDG_GLD.ANALYTICS.SDG_APPOINTMENT_ANALYST TO ROLE SDG_AI_ANALYST;


-- 11. DEMO QUERIES - Not possible on trial accounts
--   1. "Which doctor has the highest completion rate?"
--   2. "What is our overall completion rate?"
--   3. "Compare workload across all three doctors."
--   4. "Which department has the most cancellations?"
--   5. "What was the trend in appointments over the last two years?"


-- 12. CLEANUP (run manually to tear down)
USE ROLE ACCOUNTADMIN;
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    REMOVE AGENT SDG_GLD.ANALYTICS.SDG_APPOINTMENT_ANALYST;
DROP TASK IF EXISTS SDG_SYS_CONFIG.DBT.RUN_SDG_DEMO_DAILY;
DROP DBT PROJECT IF EXISTS SDG_SYS_CONFIG.DBT.SDG_DEMO;
DROP GIT REPOSITORY IF EXISTS SDG_SYS_CONFIG.DBT.SDG_DEMO_REPO;
DROP INTEGRATION IF EXISTS SDG_GIT_API;
DROP SECRET IF EXISTS SDG_SYS_CONFIG.SECRETS.SDG_GIT_SECRET;
DROP AGENT IF EXISTS SDG_GLD.ANALYTICS.SDG_APPOINTMENT_ANALYST;
DROP SEMANTIC VIEW IF EXISTS SDG_GLD.ANALYTICS.SDG_DOCTOR_PERFORMANCE;
DROP AUTHENTICATION POLICY IF EXISTS SDG_SYS_CONFIG.SECURITY.SERVICE_ACCOUNT_KEYPAIR_POLICY;
DROP AUTHENTICATION POLICY IF EXISTS SDG_SYS_CONFIG.SECURITY.PERSON_AUTH_POLICY;
DROP PASSWORD POLICY IF EXISTS SDG_SYS_CONFIG.SECURITY.SDG_PASSWORD_POLICY;
DROP DATABASE IF EXISTS SDG_BRZ;
DROP DATABASE IF EXISTS SDG_SLV;
DROP DATABASE IF EXISTS SDG_GLD;
DROP DATABASE IF EXISTS SDG_SYS_CONFIG;
ALTER WAREHOUSE SDG_TRANSFORM_WH SET RESOURCE_MONITOR = NULL;
ALTER WAREHOUSE SDG_AI_WH        SET RESOURCE_MONITOR = NULL;
DROP WAREHOUSE IF EXISTS SDG_TRANSFORM_WH;
DROP WAREHOUSE IF EXISTS SDG_AI_WH;
ALTER ACCOUNT SET RESOURCE_MONITOR = NULL;
DROP RESOURCE MONITOR IF EXISTS SDG_TRANSFORM_WH_MONITOR;
DROP RESOURCE MONITOR IF EXISTS SDG_AI_WH_MONITOR;
DROP RESOURCE MONITOR IF EXISTS SDG_ACCT_MONITOR;
REVOKE CREATE DATABASE ON ACCOUNT FROM ROLE SDG_DATA_ENGINEER;
REVOKE EXECUTE TASK ON ACCOUNT FROM ROLE SDG_DATA_ENGINEER;
REVOKE ROLE SDG_DATA_ANALYST  FROM ROLE SDG_DATA_ENGINEER;
REVOKE ROLE SDG_AI_ANALYST    FROM ROLE SDG_DATA_ENGINEER;
REVOKE ROLE SDG_DATA_ENGINEER FROM ROLE SYSADMIN;
DROP ROLE IF EXISTS SDG_AI_ANALYST;
DROP ROLE IF EXISTS SDG_DATA_ANALYST;
DROP ROLE IF EXISTS SDG_DATA_ENGINEER;
ALTER ACCOUNT UNSET DATA_RETENTION_TIME_IN_DAYS;
ALTER ACCOUNT UNSET STATEMENT_TIMEOUT_IN_SECONDS;
ALTER ACCOUNT UNSET CORTEX_ENABLED_CROSS_REGION;
