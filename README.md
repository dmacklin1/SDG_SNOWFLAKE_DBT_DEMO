# SDG Snowflake + dbt + Cortex Demo

End-to-end: account setup -> RBAC -> medallion databases -> dbt pipeline ->
semantic view -> Cortex agent. Built to run on a fresh Snowflake trial account
in about 30 minutes.

## Order of operations

1. **`SDG_DEMO_SETUP.sql`** sections 1-6 — paste into a Snowsight worksheet, run top to bottom.
2. **`dbt/`** — load into a Snowflake Workspace, run `dbt build` in the terminal.
3. **`SDG_DEMO_SETUP.sql`** sections 8-11 — back to the worksheet for validation,
   semantic view, agent, and the demo queries.

Sections 12-14 are presenter-only (Git integration, production notes, cleanup).

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

Two source systems that only meet in Silver — that switch from
source-organised to subject-organised is the reason the Silver layer exists.

## Trial account constraints

- **No dbt packages.** `dbt deps` needs external network access, unavailable on
  trials. Every test in this project is a dbt built-in. Do not add a `packages.yml`.
- **Cross-region inference must be on.** Section 1 sets it. Without it the agent
  fails with a region error.
- **Cortex Code CLI is unavailable on trials.** Use Cortex Code in Snowsight.
- **~10 credits/day** of Cortex AI functions without a payment method on file.

## Two things that are deliberate, not oversights

**Section 5 creates authentication policies but does not apply them.** Applying
an MFA-required policy to the only user on a fresh trial can lock you out with
no recovery path. The objects exist so the pattern is visible; the `ALTER USER`
lines stay commented.

**The semantic view defines two completion-rate metrics.**
`overall_completion_rate_pct` is volume-weighted;
`avg_doctor_completion_rate_pct` is an unweighted mean of per-doctor rates.
They answer the same English question with different numbers. Deciding which one
is the default — and writing that decision into the comments the model reads —
is most of the accuracy work in a semantic layer.

## Demoing incremental

`slv_appointments` is incremental, watermarked on `appointment_date`. Append rows
to `seeds/raw_appointments.csv` with dates after 2024-01-31, run `dbt build`, and
only the new rows process.

The watermark is a stable business column, not `_loaded_at`. `_loaded_at` is
`CURRENT_TIMESTAMP()` set in the Bronze view, so it refreshes on every upstream
rebuild — using it as a watermark would silently reprocess the full table on
every run while still looking correct in the row counts.

## Expected build

2 seeds, 7 models, 20 tests, all passing. Roughly 60-90 seconds on an X-Small.
