-- ############################################################################
-- SDG SNOWFLAKE + dbt + CORTEX DEMO — SINGLE SETUP SCRIPT
-- ############################################################################
--
-- Run top to bottom in a Snowsight worksheet on a fresh Snowflake trial account.
-- Sections 1-7 are pure Snowflake DDL. Section 8 hands off to the dbt project.
-- Sections 9-11 build the semantic layer and agent on top of what dbt produced.
--
-- PREREQUISITES
--   - Snowflake trial account, Enterprise edition
--   - ACCOUNTADMIN (the default role on a new trial)
--   - The dbt/ folder from this repo, loaded into a Snowflake Workspace
--     (no seed files — source data is created by section 7 of this script)
--
-- OBJECT NAMING
--   SDG_BRZ / SDG_SLV / SDG_GLD   medallion layers, one database each
--   SDG_SYS_CONFIG                 platform objects (dbt project, security policies)
--
-- THIS IS A DEMO SCRIPT, NOT A PRODUCTION TEMPLATE.
-- Single environment, no service accounts, no CI/CD, no key-pair auth.
-- See section 13 for what changes in a real deployment.
--
-- ############################################################################


-- ============================================================================
-- 1. ACCOUNT SETTINGS
-- ============================================================================
-- Account-wide defaults. Everything below is inherited by objects created later
-- unless explicitly overridden.

USE ROLE ACCOUNTADMIN;

ALTER ACCOUNT SET DATA_RETENTION_TIME_IN_DAYS = 1; -- Time travel 
ALTER ACCOUNT SET STATEMENT_TIMEOUT_IN_SECONDS = 900;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- Account-level spend guardrail.
CREATE RESOURCE MONITOR IF NOT EXISTS SDG_ACCT_MONITOR
    WITH CREDIT_QUOTA   = 50
         FREQUENCY      = MONTHLY
         START_TIMESTAMP = IMMEDIATELY
         TRIGGERS
             ON 50  PERCENT DO NOTIFY
             ON 90  PERCENT DO NOTIFY
             ON 100 PERCENT DO SUSPEND;

ALTER ACCOUNT SET RESOURCE_MONITOR = SDG_ACCT_MONITOR;


-- ============================================================================
-- 2. ROLES
-- ============================================================================
--     SYSADMIN
--        └── SDG_DATA_ENGINEER      build and own objects
--              ├── SDG_DATA_ANALYST  read the medallion layers
--              └── SDG_AI_ANALYST    consume the semantic view and agent

USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS SDG_DATA_ANALYST COMMENT = 'Read-only access across the medallion layers';
CREATE ROLE IF NOT EXISTS SDG_DATA_ENGINEER COMMENT = 'Builds and owns all data objects; runs dbt';
CREATE ROLE IF NOT EXISTS SDG_AI_ANALYST COMMENT = 'Consumes the Gold semantic view and Cortex agent';

USE ROLE SYSADMIN;

GRANT ROLE SDG_DATA_ANALYST  TO ROLE SDG_DATA_ENGINEER;
GRANT ROLE SDG_AI_ANALYST    TO ROLE SDG_DATA_ENGINEER;
GRANT ROLE SDG_DATA_ENGINEER TO ROLE SYSADMIN;

-- ============================================================================
-- 3. WAREHOUSES & RESOURCE MONITORS
-- ============================================================================
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SDG_TRANSFORM_WH
    WITH WAREHOUSE_SIZE = 'X-SMALL'
         AUTO_SUSPEND         = 60
         AUTO_RESUME          = TRUE
         INITIALLY_SUSPENDED  = TRUE
         COMMENT = 'dbt transformations across BRZ / SLV / GLD';

CREATE WAREHOUSE IF NOT EXISTS SDG_AI_WH
    WITH WAREHOUSE_SIZE = 'X-SMALL'
         AUTO_SUSPEND         = 60
         AUTO_RESUME          = TRUE
         INITIALLY_SUSPENDED  = TRUE
         COMMENT = 'Cortex Analyst / agent query execution';

USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS SDG_TRANSFORM_WH_MONITOR
    WITH CREDIT_QUOTA = 20 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
         TRIGGERS ON 80 PERCENT DO NOTIFY
                  ON 100 PERCENT DO SUSPEND;

CREATE RESOURCE MONITOR IF NOT EXISTS SDG_AI_WH_MONITOR
    WITH CREDIT_QUOTA = 10 FREQUENCY = MONTHLY START_TIMESTAMP = IMMEDIATELY
         TRIGGERS ON 80 PERCENT DO NOTIFY
                  ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE SDG_TRANSFORM_WH SET RESOURCE_MONITOR = SDG_TRANSFORM_WH_MONITOR;
ALTER WAREHOUSE SDG_AI_WH        SET RESOURCE_MONITOR = SDG_AI_WH_MONITOR;

USE ROLE SYSADMIN;

GRANT USAGE ON WAREHOUSE SDG_TRANSFORM_WH TO ROLE SDG_DATA_ANALYST;
GRANT USAGE ON WAREHOUSE SDG_TRANSFORM_WH TO ROLE SDG_DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE SDG_AI_WH        TO ROLE SDG_AI_ANALYST;
GRANT USAGE ON WAREHOUSE SDG_AI_WH        TO ROLE SDG_DATA_ENGINEER;


-- ============================================================================
-- 4. DATABASES & SCHEMAS
-- ============================================================================
-- One database per medallion layer. Schemas inside each layer carry meaning:
--
--   SDG_BRZ         SOURCE_A       raw landing from the scheduling system
--                   SOURCE_B       raw landing from the HR / credentialing system
--   SDG_SLV         BASE           1:1 cleaned records, surrogate-keyed
--                   DOCTORS        conformed provider dimension
--                   APPOINTMENTS   conformed appointment fact
--   SDG_GLD         ANALYTICS      consumption-ready aggregates
--   SDG_SYS_CONFIG  DBT            dbt project object
--                   SECURITY       password and authentication policies
--
-- BRZ is organised by SOURCE. SLV is organised by SUBJECT. GLD by END CONSUMPTION.


USE ROLE SYSADMIN;

GRANT CREATE DATABASE ON ACCOUNT TO ROLE SDG_DATA_ENGINEER;

USE ROLE SDG_DATA_ENGINEER;

CREATE DATABASE IF NOT EXISTS SDG_BRZ        COMMENT = 'Bronze — raw landing, organised by source system';
CREATE DATABASE IF NOT EXISTS SDG_SLV        COMMENT = 'Silver — cleaned and conformed, organised by subject';
CREATE DATABASE IF NOT EXISTS SDG_GLD        COMMENT = 'Gold — consumption-ready aggregates';
CREATE DATABASE IF NOT EXISTS SDG_SYS_CONFIG COMMENT = 'Platform configuration and security objects';

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


-- ============================================================================
-- 5. SECURITY POLICIES  (CREATED, DELIBERATELY NOT APPLIED)
-- ============================================================================
-- These are the policy objects a real deployment attaches to users. They are created here so you can see and discuss the shape of them.
-- >>> DO NOT UNCOMMENT THE ALTER USER STATEMENTS ON A DEMO ACCOUNT. <<<


USE ROLE SYSADMIN;

GRANT USAGE ON DATABASE SDG_SYS_CONFIG                        TO ROLE SECURITYADMIN;
GRANT USAGE ON SCHEMA   SDG_SYS_CONFIG.SECURITY               TO ROLE SECURITYADMIN;
GRANT CREATE PASSWORD POLICY       ON SCHEMA SDG_SYS_CONFIG.SECURITY TO ROLE SECURITYADMIN;
GRANT CREATE AUTHENTICATION POLICY ON SCHEMA SDG_SYS_CONFIG.SECURITY TO ROLE SECURITYADMIN;

USE ROLE SECURITYADMIN;

CREATE PASSWORD POLICY IF NOT EXISTS SDG_SYS_CONFIG.SECURITY.SDG_PASSWORD_POLICY
    PASSWORD_MIN_LENGTH        = 12
    PASSWORD_MAX_AGE_DAYS      = 90
    PASSWORD_MAX_RETRIES       = 5
    PASSWORD_LOCKOUT_TIME_MINS = 30
    COMMENT = 'Human user password standard';

CREATE AUTHENTICATION POLICY IF NOT EXISTS SDG_SYS_CONFIG.SECURITY.PERSON_AUTH_POLICY
    AUTHENTICATION_METHODS = ('SAML', 'PASSWORD')
    CLIENT_TYPES           = ('SNOWFLAKE_UI', 'SNOWSQL', 'DRIVERS')
    MFA_ENROLLMENT         = REQUIRED
    COMMENT = 'Human users: SSO or password, MFA mandatory';

CREATE AUTHENTICATION POLICY IF NOT EXISTS SDG_SYS_CONFIG.SECURITY.SERVICE_ACCOUNT_KEYPAIR_POLICY
    AUTHENTICATION_METHODS = ('KEYPAIR')
    CLIENT_TYPES           = ('DRIVERS', 'SNOWSQL')
    MFA_ENROLLMENT         = OPTIONAL
    COMMENT = 'Service accounts: key-pair only, no interactive login';

-- Production only. Left commented on purpose.
-- ALTER USER <human_user>   SET AUTHENTICATION POLICY SDG_SYS_CONFIG.SECURITY.PERSON_AUTH_POLICY;
-- ALTER USER <service_user> SET AUTHENTICATION POLICY SDG_SYS_CONFIG.SECURITY.SERVICE_ACCOUNT_KEYPAIR_POLICY;


-- ============================================================================
-- 6. GRANTS
-- ============================================================================
-- ALL + FUTURE on every object class. FUTURE is what stops the "dbt created a
-- new model and now the analyst can't see it" support ticket.

USE ROLE SYSADMIN;

-- ---- ANALYST: read-only across all three layers ----------------------------
GRANT USAGE ON DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT USAGE ON DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT USAGE ON DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;

GRANT USAGE  ON ALL SCHEMAS    IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON ALL SCHEMAS    IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON ALL SCHEMAS    IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;

GRANT SELECT ON ALL TABLES     IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON ALL TABLES     IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON ALL TABLES     IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES  IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES  IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES  IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;

GRANT SELECT ON ALL VIEWS      IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON ALL VIEWS      IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON ALL VIEWS      IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE VIEWS   IN DATABASE SDG_BRZ TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE VIEWS   IN DATABASE SDG_SLV TO ROLE SDG_DATA_ANALYST;
GRANT SELECT ON FUTURE VIEWS   IN DATABASE SDG_GLD TO ROLE SDG_DATA_ANALYST;

-- ---- AI ANALYST: Gold only, plus semantic view and agent access -------------
GRANT USAGE  ON DATABASE SDG_GLD                                  TO ROLE SDG_AI_ANALYST;
GRANT USAGE  ON SCHEMA   SDG_GLD.ANALYTICS                        TO ROLE SDG_AI_ANALYST;
GRANT SELECT ON ALL TABLES    IN SCHEMA SDG_GLD.ANALYTICS         TO ROLE SDG_AI_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA SDG_GLD.ANALYTICS         TO ROLE SDG_AI_ANALYST;

GRANT REFERENCES, SELECT ON ALL SEMANTIC VIEWS    IN SCHEMA SDG_GLD.ANALYTICS TO ROLE SDG_AI_ANALYST;
GRANT REFERENCES, SELECT ON FUTURE SEMANTIC VIEWS IN SCHEMA SDG_GLD.ANALYTICS TO ROLE SDG_AI_ANALYST;

-- Cortex access. CORTEX_USER is granted to PUBLIC by default on most accounts,
-- but grant it explicitly so the role is self-describing.
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SDG_AI_ANALYST;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SDG_DATA_ENGINEER;


-- ============================================================================
-- 7. SOURCE DATA  (landing tables)
-- ============================================================================
-- Stands in for what a real ingestion tool would land. At SMA this is Qlik
-- Replicate CDC writing into BRZ; here it is a DDL + INSERT so nobody has to
-- stage a file.
--
-- Everything lands as VARCHAR, the way a file or CDC feed actually arrives.
-- Typing is the Bronze layer's job, not the landing zone's — which is why the
-- casts in BRZ_APPOINTMENTS are real work rather than decoration.
--
-- _LOADED_AT defaults at INSERT time and never moves again. That makes it a
-- genuine landing timestamp that flows unchanged through every downstream
-- model, instead of a CURRENT_TIMESTAMP() that re-evaluates on every rebuild.

USE ROLE SDG_DATA_ENGINEER;
USE WAREHOUSE SDG_TRANSFORM_WH;

-- ---- SOURCE A: scheduling system -------------------------------------------
CREATE OR REPLACE TABLE SDG_BRZ.SOURCE_A.RAW_APPOINTMENTS (
    PATIENT_ID        VARCHAR(20),
    PATIENT_NAME      VARCHAR(100),
    DOCTOR_ID         VARCHAR(10),
    APPOINTMENT_DATE  VARCHAR(20),
    STATUS            VARCHAR(20),
    NOTES             VARCHAR(500),
    _LOADED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _SOURCE_SYSTEM    VARCHAR(20)   DEFAULT 'SOURCE_A'
)
COMMENT = 'Raw appointment records as landed from the scheduling system. Untyped by design.';

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

-- ---- SOURCE B: HR / credentialing system -----------------------------------
CREATE OR REPLACE TABLE SDG_BRZ.SOURCE_B.RAW_DOCTORS (
    DOCTOR_ID       VARCHAR(10),
    DOCTOR_NAME     VARCHAR(100),
    SPECIALTY       VARCHAR(50),
    DEPARTMENT      VARCHAR(50),
    HIRE_DATE       VARCHAR(20),
    _LOADED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _SOURCE_SYSTEM  VARCHAR(20)   DEFAULT 'SOURCE_B'
)
COMMENT = 'Raw provider reference data as landed from the HR system. Untyped by design.';

INSERT INTO SDG_BRZ.SOURCE_B.RAW_DOCTORS
    (DOCTOR_ID, DOCTOR_NAME, SPECIALTY, DEPARTMENT, HIRE_DATE)
VALUES
    ('D001', 'Dr. Amara Patel', 'Cardiology', 'Internal Medicine', '2016-03-14'),
    ('D002', 'Dr. Wei Chen', 'Endocrinology', 'Internal Medicine', '2019-07-01'),
    ('D003', 'Dr. Elena Lopez', 'Family Medicine', 'Primary Care', '2021-01-11');


-- ============================================================================
-- 8. dbt PROJECT 
-- ============================================================================
-- Everything from here to section 8 happens in a Snowflake Workspace, not in
-- this worksheet.
--
--   1. Projects -> Workspaces -> + Workspace
--   2. Add the contents of the dbt/ folder from this repo
--   3. Open the terminal and run:
--
--        dbt build
--
-- Expected: 7 models, 31 tests, 0 seeds. All PASS.
--
-- The two RAW_ tables from section 7 are declared as dbt SOURCES, not seeds.
-- dbt reads them, it does not create them — which is how it works anywhere the
-- data arrives from an ingestion tool rather than a CSV in the repo.
--
-- WHAT GETS BUILT
--   (SDG_BRZ.SOURCE_A.RAW_APPOINTMENTS           source, created in section 7)
--   (SDG_BRZ.SOURCE_B.RAW_DOCTORS                source, created in section 7)
--   SDG_BRZ.SOURCE_A.BRZ_APPOINTMENTS            view    50
--   SDG_BRZ.SOURCE_B.BRZ_DOCTORS                 view     3
--   SDG_SLV.BASE.SLV_BASE_APPOINTMENTS           table   50
--   SDG_SLV.BASE.SLV_BASE_DOCTORS                table    3
--   SDG_SLV.DOCTORS.SLV_DOCTORS                  table    3
--   SDG_SLV.APPOINTMENTS.SLV_APPOINTMENTS        incr    50
--   SDG_GLD.ANALYTICS.GLD_DOCTOR_METRICS         table    3
--
-- Useful variants once the first build succeeds:
--   dbt run --select +gld_doctor_metrics     gold and everything upstream
--   dbt run --select brz_appointments+       that model and everything downstream
--   dbt run --full-refresh                   rebuild incrementals from scratch
--
-- INCREMENTAL DEMO: uncomment the extra INSERT at the end of section 7, run it,
-- then `dbt build` again. SLV_APPOINTMENTS processes only the two new rows.

-- ============================================================================
-- 9. SEMANTIC VIEW
-- ============================================================================
-- The translation layer between column names and business language.
--
-- The COMMENT on each field is not documentation — it is the prompt. Cortex
-- Analyst reads these to decide which column answers a question. Vague comments
-- produce wrong SQL. This is where most of the accuracy work actually happens.
--
-- Note the two rate metrics below. They answer the same English question and
-- return different numbers. Defining both, explicitly, is the job.

USE ROLE SDG_DATA_ENGINEER;
USE WAREHOUSE SDG_TRANSFORM_WH;

CREATE OR REPLACE SEMANTIC VIEW SDG_GLD.ANALYTICS.SDG_DOCTOR_PERFORMANCE

  TABLES (
    doctor_metrics AS SDG_GLD.ANALYTICS.GLD_DOCTOR_METRICS
      PRIMARY KEY (doctor_id)
      COMMENT = 'One row per provider. Aggregated appointment activity for a single
                 clinic over January 2024, joined to provider reference data
                 (specialty, department). Grain: one row per doctor_id.'
  )

  FACTS (
    doctor_metrics.total_appointments AS total_appointments
      COMMENT = 'COUNT (integer, not a rate): total appointments booked with this
                 provider, all statuses included.',
    doctor_metrics.completed AS completed
      COMMENT = 'COUNT (integer): appointments with status = completed.',
    doctor_metrics.cancelled AS cancelled
      COMMENT = 'COUNT (integer): appointments with status = cancelled.',
    doctor_metrics.scheduled AS scheduled
      COMMENT = 'COUNT (integer): appointments still in scheduled status, not yet
                 completed or cancelled.',
    doctor_metrics.completion_rate_pct AS completion_rate_pct
      COMMENT = 'PERCENTAGE 0-100 for THIS PROVIDER ONLY: completed / total * 100.
                 Already a percentage — never multiply by 100 again. Do NOT average
                 this column across providers to get an overall rate; use the
                 overall_completion_rate_pct metric instead.',
    doctor_metrics.cancellation_rate_pct AS cancellation_rate_pct
      COMMENT = 'PERCENTAGE 0-100 for THIS PROVIDER ONLY: cancelled / total * 100.
                 Already a percentage. Same averaging caveat as completion_rate_pct.',
    doctor_metrics.active_days AS active_days
      COMMENT = 'COUNT (integer): distinct calendar days on which this provider had
                 at least one appointment.',
    doctor_metrics.avg_appointments_per_day AS avg_appointments_per_day
      COMMENT = 'RATIO (not a percentage): total_appointments / active_days. A rough
                 daily workload indicator.'
  )

  DIMENSIONS (
    doctor_metrics.doctor_id AS doctor_id
      COMMENT = 'Provider identifier from the HR system. Format Dnnn.',
    doctor_metrics.doctor_name AS doctor_name
      WITH SYNONYMS = ('doctor', 'physician', 'provider', 'clinician', 'name')
      COMMENT = 'Full display name of the attending provider, e.g. "Dr. Wei Chen".
                 Use this when a user names a doctor.',
    doctor_metrics.specialty AS specialty
      WITH SYNONYMS = ('specialty', 'speciality', 'practice area')
      COMMENT = 'Clinical specialty, e.g. Cardiology, Endocrinology, Family Medicine.',
    doctor_metrics.department AS department
      WITH SYNONYMS = ('department', 'division', 'service line')
      COMMENT = 'Organisational department the provider reports into.'
  )

  METRICS (
    total_appointment_count AS SUM(doctor_metrics.total_appointments)
      COMMENT = 'Total appointments across all providers in scope.',
    total_completed AS SUM(doctor_metrics.completed)
      COMMENT = 'Total completed appointments across all providers in scope.',
    total_cancelled AS SUM(doctor_metrics.cancelled)
      COMMENT = 'Total cancelled appointments across all providers in scope.',
    overall_completion_rate_pct AS
        SUM(doctor_metrics.completed) / NULLIF(SUM(doctor_metrics.total_appointments), 0) * 100
      COMMENT = 'THE DEFAULT ANSWER for "what is our completion rate" or any question
                 about the clinic overall. Volume-weighted: total completed divided by
                 total appointments. Use this metric, not an average of the per-provider
                 completion_rate_pct column.',
    overall_cancellation_rate_pct AS
        SUM(doctor_metrics.cancelled) / NULLIF(SUM(doctor_metrics.total_appointments), 0) * 100
      COMMENT = 'THE DEFAULT ANSWER for "what is our cancellation rate" overall.
                 Volume-weighted.',
    avg_doctor_completion_rate_pct AS AVG(doctor_metrics.completion_rate_pct)
      COMMENT = 'UNWEIGHTED mean of the per-provider completion rates. Every provider
                 counts equally regardless of how many appointments they had. Only use
                 this when the user explicitly asks about the typical or average DOCTOR,
                 not about the clinic overall. For clinic-wide questions use
                 overall_completion_rate_pct.'
  )

  COMMENT = 'Provider performance for natural language querying via Cortex Analyst.';

SHOW SEMANTIC VIEWS IN SCHEMA SDG_GLD.ANALYTICS;


-- ============================================================================
-- 10. CORTEX AGENT
-- ============================================================================
-- The agent wraps the semantic view with orchestration and response behaviour.
-- Registering it with Snowflake Intelligence gives a real chat surface instead
-- of parsing JSON out of a worksheet.
USE ROLE SDG_DATA_ENGINEER;

CREATE OR REPLACE AGENT SDG_GLD.ANALYTICS.SDG_APPOINTMENT_ANALYST
  COMMENT = 'Answers natural language questions about provider appointment performance'
  FROM SPECIFICATION $$
models:
  orchestration: auto

instructions:
  response: |
    You are an appointment analytics assistant for a clinic operations team.
    Answer questions about provider workload, completion rates, cancellations,
    and scheduling patterns.

    1. Always give specific numbers. Never say "high" or "low" without the figure.
    2. State percentages to one decimal place and include the % sign.
    3. When a question is about the clinic OVERALL, use overall_completion_rate_pct
       or overall_cancellation_rate_pct. Do not average the per-provider rate columns.
    4. When comparing providers, show the underlying appointment volumes alongside
       the rates — a 100% completion rate on 2 appointments is not comparable to
       92% on 500.
    5. Flag concerning patterns without being asked: cancellation rates above 15%,
       or a workload spread where one provider carries more than 40% of volume.
    6. The dataset covers a single clinic for January 2024 only. If asked about
       trends over time, other periods, or patient-level detail, say plainly that
       the data does not support it rather than inferring.
    7. Be concise. Lead with the answer, then the supporting numbers.

  orchestration: |
    Prefer a single query with ORDER BY and LIMIT for "top N", "highest", "lowest",
    and "most/least" questions. Do not run multiple passes and reconcile them.

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: DoctorPerformance
      description: >
        SDG_DOCTOR_PERFORMANCE (SDG_GLD.ANALYTICS):
        - Grain: one row per provider (doctor_id). Three providers, January 2024.
        - DIMENSIONS: doctor_id, doctor_name, specialty, department.
        - COUNTS (integers): total_appointments, completed, cancelled, scheduled,
          active_days.
        - PER-PROVIDER RATES (already 0-100 percentages): completion_rate_pct,
          cancellation_rate_pct. Do not multiply by 100. Do not average across rows.
        - CLINIC-WIDE METRICS: overall_completion_rate_pct and
          overall_cancellation_rate_pct are volume-weighted and are the correct
          answer for any question about the clinic as a whole.
          avg_doctor_completion_rate_pct is unweighted and only answers questions
          about the typical individual doctor.
        - RATIO: avg_appointments_per_day is appointments per active day, not a
          percentage.

tool_resources:
  DoctorPerformance:
    execution_environment:
      type: warehouse
      warehouse: SDG_AI_WH
    semantic_view: SDG_GLD.ANALYTICS.SDG_DOCTOR_PERFORMANCE
$$;

-- Register with Snowflake Intelligence (CoWork) and grant to the consumption role.
USE ROLE ACCOUNTADMIN;
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    ADD AGENT SDG_GLD.ANALYTICS.SDG_APPOINTMENT_ANALYST;

GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT
    TO ROLE SDG_AI_ANALYST;

USE ROLE SECURITYADMIN;
GRANT USAGE ON AGENT SDG_GLD.ANALYTICS.SDG_APPOINTMENT_ANALYST
    TO ROLE SDG_AI_ANALYST;

SHOW AGENTS IN SCHEMA SDG_GLD.ANALYTICS;


-- ============================================================================
-- 11. DEMO
-- ============================================================================
-- Switch to SDG_AI_ANALYST, open Snowflake Intelligence, pick
-- SDG_APPOINTMENT_ANALYST, and ask these in order.
--
USE ROLE SDG_AI_ANALYST;
USE WAREHOUSE SDG_AI_WH;

SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
        'SDG_GLD.ANALYTICS.SDG_APPOINTMENT_ANALYST',
        $${ "messages": [{ "role": "user", "content": [{ "type": "text", "text": "Which doctor has the highest completion rate?" }] }] }$$
    )
) AS response;

SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-70b',
    'Which doctor has the highest completion rate?'
);

SELECT SNOWFLAKE.CORTEX.ANALYST(
    'SDG_GLD.ANALYTICS.SDG_DOCTOR_PERFORMANCE',
    'Which doctor has the highest completion rate?'
);

--   1. "Which doctor has the highest completion rate?"
--        Warm-up. Confirms the agent resolves names and rates.
--
--   2. "What is our overall completion rate?"
--        The one that matters. Should return the volume-weighted figure, not
--        the average of the three per-doctor rates. Ask it to show the SQL.
--
--   3. "Compare workload across all three doctors."
--        Exercises the "show volumes alongside rates" instruction.
--
--   4. "Which department has the most cancellations?"
--        Proves the Source B join is real — department only exists because
--        Silver conformed two separate sources.
--
--   5. "What was the trend in appointments over the last two years?"
--        Should decline, citing the January 2024 scope. This is the segment
--        worth planning for: refusing to fabricate is the trust demo.
--
-- Note the role you are running as. Try SDG_AI_ANALYST and confirm it cannot
-- read Bronze or Silver — the agent inherits the caller's privileges, which is
-- the whole governance story in one query:
--
--   USE ROLE SDG_AI_ANALYST;
--   SELECT * FROM SDG_SLV.APPOINTMENTS.SLV_APPOINTMENTS LIMIT 1;   -- fails
--   SELECT * FROM SDG_GLD.ANALYTICS.GLD_DOCTOR_METRICS LIMIT 1;    -- works


-- ============================================================================
-- 12. GIT INTEGRATION  
-- ============================================================================

USE ROLE SDG_DATA_ENGINEER;
CREATE SCHEMA IF NOT EXISTS SDG_SYS_CONFIG.SECRETS;

USE ROLE ACCOUNTADMIN;
CREATE SECRET IF NOT EXISTS SDG_SYS_CONFIG.SECRETS.SDG_GIT_SECRET
    TYPE     = PASSWORD
    USERNAME = 'dmacklin1'
    PASSWORD = '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'; -- fine-grained read-only to empty and public repo

ALTER SECRET SDG_SYS_CONFIG.SECRETS.SDG_GIT_SECRET
    SET PASSWORD = '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';

USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE API INTEGRATION SDG_GIT_API
    API_PROVIDER = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/dmacklin1')
    ALLOWED_AUTHENTICATION_SECRETS = (SDG_SYS_CONFIG.SECRETS.SDG_GIT_SECRET)
    ENABLED = TRUE;

-- Let SDG_DATA_ENGINEER use the integration and secret to create the repo.
USE ROLE SECURITYADMIN;
GRANT USAGE ON INTEGRATION SDG_GIT_API TO ROLE SDG_DATA_ENGINEER;
GRANT USAGE ON SECRET SDG_SYS_CONFIG.SECRETS.SDG_GIT_SECRET TO ROLE SDG_DATA_ENGINEER;

USE ROLE SDG_DATA_ENGINEER;
USE WAREHOUSE SDG_TRANSFORM_WH;

CREATE GIT REPOSITORY IF NOT EXISTS SDG_SYS_CONFIG.DBT.SDG_DEMO_REPO
    API_INTEGRATION = SDG_GIT_API
    GIT_CREDENTIALS = SDG_SYS_CONFIG.SECRETS.SDG_GIT_SECRET
    ORIGIN          = 'https://github.com/dmacklin1/SDG_SNOWFLAKE_DBT_DEMO.git';

ALTER GIT REPOSITORY SDG_SYS_CONFIG.DBT.SDG_DEMO_REPO FETCH;

-- The dbt project as a first-class, versioned Snowflake object.
CREATE OR REPLACE DBT PROJECT SDG_SYS_CONFIG.DBT.SDG_DEMO
    FROM '@SDG_SYS_CONFIG.DBT.SDG_DEMO_REPO/branches/main/dbt/'
    DBT_VERSION = '1.9.4'
    COMMENT     = 'SDG demo pipeline';

EXECUTE DBT PROJECT SDG_SYS_CONFIG.DBT.SDG_DEMO ARGS = 'build';

SHOW VERSIONS IN DBT PROJECT SDG_SYS_CONFIG.DBT.SDG_DEMO;

-- And scheduled, which is the natural close.
CREATE OR REPLACE TASK SDG_SYS_CONFIG.DBT.RUN_SDG_DEMO_DAILY
    WAREHOUSE = SDG_TRANSFORM_WH
    SCHEDULE  = 'USING CRON 0 6 * * * America/New_York'
AS
    EXECUTE DBT PROJECT SDG_SYS_CONFIG.DBT.SDG_DEMO ARGS = 'build';

ALTER TASK SDG_SYS_CONFIG.DBT.RUN_SDG_DEMO_DAILY RESUME;

-- ============================================================================
-- 13. WHAT CHANGES IN PRODUCTION
-- ============================================================================
-- Talking points, not runnable code. The gap between this script and a real
-- deployment is roughly:
--
--   ENVIRONMENTS   DEV / TST / PRD prefixes on every database, warehouse, and
--                  role. Same script, driven by a config block at the top.
--   SERVICE ACCTS  TYPE = SERVICE users with RSA key-pair auth for CI/CD.
--                  Never a password in a script, never a password in git.
--   AUTH POLICIES  Section 5 policies actually applied to users or SSO.
--   CI/CD          GitHub Actions running dbt against TST on PR, PRD on merge,
--                  with a prod guard macro blocking manual runs.
--   NETWORK        Network policies restricting service accounts to known IPs.
--   ENV PARITY     Zero-copy clone from PRD to refresh DEV and TST cheaply.
