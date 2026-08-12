# SDG Snowflake + dbt + Cortex Demo

End-to-end: account setup -> RBAC -> medallion databases -> dbt pipeline ->
semantic view -> Cortex agent. Built to run on a fresh Snowflake trial account
in about 30 minutes.

## Order of operations

1. **`SDG_DEMO_SETUP.sql`** sections 1-6 — paste into a Snowsight worksheet, run top to bottom.
2. **`dbt/`** — load into a Snowflake Workspace, run `dbt build` in the terminal.
3. **`SDG_DEMO_SETUP.sql`** sections 8-11 — back to the worksheet for validation,
   semantic view, agent, and the demo queries.


## Architecture

```
raw_appointments.csv ─┐
                      ├─> BRZ ─> SLV.BASE ─┬─> SLV.DOCTORS ─────┐
raw_doctors.csv ──────┘                    └─> SLV.APPOINTMENTS ─┴─> GLD.ANALYTICS
                                                                        │
                                                        SDG_DOCTOR_PERFORMANCE (semantic view)
                                                                        │
                                                        SDG_APPOINTMENT_ANALYST (agent)
```

| Database | Schemas | Organised by |
|---|---|---|
| `SDG_BRZ` | `SOURCE_A`, `SOURCE_B` | source system |
| `SDG_SLV` | `BASE`, `DOCTORS`, `APPOINTMENTS` | subject area |
| `SDG_GLD` | `ANALYTICS` | consumption |
| `SDG_SYS_CONFIG` | `DBT`, `SECURITY` | platform |

## Trial account constraints

- **No dbt packages.** `dbt deps` needs external network access, unavailable on
  trials. Every test in this project is a dbt built-in. Do not add a `packages.yml`.
- **No Agent Functionality**
