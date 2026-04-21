# Snowflake Cost Optimization Skill — Documentation

**Skill Name:** `snowflake-cost-optimization`
**File:** `SKILL.md`
**Last Updated:** April 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Purpose and Use Cases](#purpose-and-use-cases)
3. [Prerequisites](#prerequisites)
4. [Trigger Keywords](#trigger-keywords)
5. [Cost Categories](#cost-categories)
6. [Three-Phase Workflow](#three-phase-workflow)
7. [Phase 1 — Cost Optimization Assessment](#phase-1--cost-optimization-assessment)
   - [Category 1: Compute (Warehouse) Costs](#category-1-compute-warehouse-costs)
   - [Category 2: Storage Costs](#category-2-storage-costs)
   - [Category 3: Serverless Feature Costs](#category-3-serverless-feature-costs)
   - [Category 4: AI Services Costs (Cortex)](#category-4-ai-services-costs-cortex)
   - [Finding Capture Format](#finding-capture-format)
   - [Phase 1 Report Output](#phase-1-report-output)
8. [Phase 2 — Cost Optimization Recommendations](#phase-2--cost-optimization-recommendations)
   - [Priority Classification](#priority-classification)
   - [Recommendation Structure](#recommendation-structure)
   - [Category-Specific Remediation](#category-specific-remediation)
   - [Phase 2 Report Output](#phase-2-report-output)
9. [Phase 3 — Compliance Dashboard](#phase-3--compliance-dashboard)
   - [Dashboard Panels](#dashboard-panels)
   - [Visual Indicators and Scoring](#visual-indicators-and-scoring)
   - [Phase 3 Report Output](#phase-3-report-output)
10. [SQL Query Reference](#sql-query-reference)
11. [AI Model Credit Rate Tiers](#ai-model-credit-rate-tiers)
12. [Optimization Checklists](#optimization-checklists)
13. [AI Cost Control Best Practices](#ai-cost-control-best-practices)
14. [Execution Rules](#execution-rules)
15. [Error Handling and Self-Healing](#error-handling-and-self-healing)
16. [Report File Inventory](#report-file-inventory)
17. [Troubleshooting](#troubleshooting)

---

## Overview

The **Snowflake Cost Optimization** skill performs a comprehensive, three-phase cost analysis of a Snowflake account. It assesses spending across four cost categories — Compute, Storage, Serverless, and AI Services — and produces three professional HTML reports: an assessment, a recommendation plan, and a compliance dashboard.

All analysis is **read-only**. No DDL, DML, or configuration changes are executed at any point. The skill uses a default rate of **$3 per credit** for all USD estimates unless account-specific pricing is provided.

---

## Purpose and Use Cases

| Use Case | Description |
|----------|-------------|
| **Monthly Cost Review** | Run a full scan to identify and quantify all cost optimization opportunities |
| **Warehouse Right-Sizing** | Detect oversized or misconfigured warehouses consuming unnecessary credits |
| **Storage Cleanup** | Find unused tables, excessive Time Travel retention, orphaned stages |
| **Serverless Audit** | Evaluate ROI of automatic clustering, materialized views, search optimization |
| **AI/Cortex Spend Analysis** | Track token consumption, model costs, and identify model downgrade opportunities |
| **Executive Reporting** | Generate stakeholder-ready compliance dashboards with health scores |
| **Budget Governance** | Establish baseline spend metrics and track remediation savings over time |

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| **Snowflake Role** | `ACCOUNTADMIN` (required for `SNOWFLAKE.ACCOUNT_USAGE` views) |
| **Warehouse** | Any active warehouse (X-SMALL sufficient for all queries) |
| **Data Latency** | `ACCOUNT_USAGE` views have up to 45-minute delay |
| **Data Retention** | Views retain up to 365 days; skill queries default to last 30 days |
| **Cost Rate** | $3/credit default; override with account-specific pricing if known |
| **Execution Time** | ~5-15 minutes for full three-phase workflow |

---

## Trigger Keywords

The skill activates when user input matches any of these topics:

- Snowflake cost optimization
- Cost analysis / cost review
- Credit consumption / credit usage
- Warehouse sizing / warehouse costs
- Expensive queries
- Storage cleanup / storage costs
- Serverless costs
- Cortex costs / AI costs / AI spending
- Budget management
- Reduce credits / reduce spending

---

## Cost Categories

The skill **always** evaluates all four categories in every run — none may be skipped:

| # | Category | Key Cost Drivers |
|---|----------|-----------------|
| 1 | **Compute** | Warehouse credits, auto-suspend/resume, multi-cluster scaling, query spillage |
| 2 | **Storage** | Active storage, Time Travel, Fail-Safe, staged files, unused tables |
| 3 | **Serverless** | Snowpipe, automatic clustering, materialized view maintenance, search optimization, replication |
| 4 | **AI Services** | Cortex AI/SQL functions, Cortex Analyst, Cortex Search, Fine-Tuning, Document AI, Cortex Code, embeddings |

---

## Three-Phase Workflow

The skill executes three phases **strictly sequentially** — no skipping, merging, or parallelizing:

```
Phase 1: Assessment ──► Phase 2: Recommendations ──► Phase 3: Compliance Dashboard
```

| Phase | Purpose | Input | Output |
|-------|---------|-------|--------|
| **Phase 1** | Scan and quantify all cost opportunities | Live Snowflake ACCOUNT_USAGE data | Assessment HTML report |
| **Phase 2** | Produce prioritized, actionable fix plan | Phase 1 report findings | Recommendation HTML report |
| **Phase 3** | Build compliance tracking dashboard | Phase 1 + Phase 2 data | Interactive compliance HTML dashboard |

---

## Phase 1 — Cost Optimization Assessment

### Category 1: Compute (Warehouse) Costs

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY`

**Assessment Query — Top Spending Warehouses (Last 30 Days):**

```sql
SELECT
    warehouse_name,
    SUM(credits_used) AS total_credits,
    SUM(credits_used) * 3 AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;
```

**Warehouse Health Checks:**

After running the query, each warehouse is assessed against these criteria:

| Check | Flag Condition | Risk |
|-------|---------------|------|
| AUTO_SUSPEND | Set above 60 seconds | Credit waste during idle periods |
| AUTO_RESUME | Disabled | Requires manual intervention to start |
| Right-sizing | XL+ without query spillage evidence | Over-provisioned compute |
| Multi-cluster scaling | Policy mismatched to workload pattern | Under/over-scaling |
| Query spillage | Queries spilling to remote storage | Under-sized warehouse |
| Workload separation | Mixed ETL + interactive on same warehouse | Contention and cost inefficiency |
| Resource monitors | None configured | No spend governance |

### Category 2: Storage Costs

**Assessment Areas:**

| Storage Domain | What to Check |
|---------------|---------------|
| Active storage | Consumption by database and schema |
| Time Travel | Retention > 1 day on non-critical tables |
| Fail-Safe | Associated storage costs |
| Stage files | Orphaned or stale files on internal/external stages |
| Unused objects | Zero-row tables, unused clones, transient/temporary table sprawl |

### Category 3: Serverless Feature Costs

**Assessment Areas:**

| Service | What to Check |
|---------|---------------|
| **Snowpipe** | Ingestion frequency, file sizing, credit consumption patterns |
| **Automatic Clustering** | Tables with clustering enabled but low query benefit |
| **Materialized View Maintenance** | Stale or infrequently queried materialized views |
| **Search Optimization** | Tables with search optimization enabled but low usage |
| **Replication** | Replication group costs, frequency, business justification |

### Category 4: AI Services Costs (Cortex)

This category requires execution of **all six** assessment queries — none may be omitted even if a service appears to have zero usage.

**Billing Model:** Token-based billing (credits per million tokens). Input + output tokens are counted for generative functions. Additional warehouse compute costs apply for query execution. Copilot is currently free.

#### Query 4a — Cortex AI Services Credit Usage

```sql
SELECT
    service_type,
    SUM(credits_used) AS total_credits,
    COUNT(*) AS day_count
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type IN ('AI_SERVICES', 'CORTEX_ANALYST', 'CORTEX_SEARCH')
  AND usage_date >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY service_type
ORDER BY total_credits DESC;
```

#### Query 4b — Cortex AI SQL Functions Usage by Model

```sql
SELECT
    model_name,
    function_name,
    SUM(tokens) AS total_tokens,
    SUM(token_credits) AS total_credits,
    COUNT(*) AS request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY
WHERE usage_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY model_name, function_name
ORDER BY total_credits DESC;
```

#### Query 4c — Cortex Analyst Usage (Text-to-SQL)

```sql
SELECT
    usage_date,
    SUM(credits_used) AS daily_credits,
    COUNT(*) AS day_count
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'CORTEX_ANALYST'
  AND usage_date >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY usage_date
ORDER BY usage_date DESC;
```

#### Query 4d — Cortex Search Service Costs

```sql
SELECT
    service_name,
    model_name,
    SUM(credits) AS total_credits,
    SUM(tokens) AS total_tokens,
    COUNT(*) AS day_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
WHERE usage_date >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY service_name, model_name
ORDER BY total_credits DESC;
```

#### Query 4e — All AI/ML Service Costs Summary

```sql
SELECT
    service_type,
    SUM(credits_used) AS total_credits,
    ROUND(SUM(credits_used) * 3, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type IN (
    'AI_SERVICES',
    'CORTEX_ANALYST',
    'CORTEX_SEARCH',
    'CORTEX_FINE_TUNING',
    'DOCUMENT_AI',
    'SNOWFLAKE_COPILOT'
)
AND usage_date >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY service_type
ORDER BY total_credits DESC;
```

#### Query 4f — Cortex Code CLI / Copilot Usage

```sql
SELECT
    usage_date,
    service_type,
    SUM(credits_used) AS daily_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type IN ('SNOWFLAKE_COPILOT', 'AI_SERVICES')
  AND usage_date >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY usage_date, service_type
ORDER BY usage_date DESC;
```

#### Post-Query Assessment Checklist

After executing all six queries, each Cortex sub-category is assessed:

| Sub-Category | Assessment Focus |
|-------------|-----------------|
| **Cortex AI/SQL Functions** | Flag usage of Large/XLarge models where smaller models suffice |
| **Cortex Analyst** | Daily credit trends, usage anomalies |
| **Cortex Search** | Per-service credit consumption; flag over-provisioned services |
| **Cortex Fine-Tuning** | Training cost and frequency justification |
| **Document AI** | Processing volume and credit efficiency |
| **Cortex Code CLI** | Usage patterns (currently free — monitor for billing changes) |
| **Embeddings** | Token volume and credit usage for EMBED_TEXT_768/1024 |
| **Token Volume** | Flag abnormally high input+output volumes without corresponding business output |

### Finding Capture Format

Every finding across all four categories is captured with:

| Field | Description |
|-------|-------------|
| **Category** | Cost category and sub-category |
| **Estimated Impact** | Monthly cost in credits and USD ($3/credit baseline) |
| **Affected Objects** | Warehouse name, table, service, model, function, etc. |
| **Severity** | Critical / High / Medium / Low |
| **Checklist Item** | Which optimization checklist item applies |

### Phase 1 Report Output

| Property | Value |
|----------|-------|
| **Filename** | `Report-Cost-Optimization-Assessment-DD-MM-YYYY.html` |
| **Location** | `snowflake-cost-optimization/reports/` |
| **Format** | Self-contained HTML |

**Required Report Sections:**
- Report Generation Summary banner (TOP) with timestamp and elapsed time
- Executive summary with total estimated monthly spend
- Findings breakdown by all four cost categories and severity
- Detailed findings table per category with affected objects and estimated savings
- AI model credit rate reference table
- Optimization checklist completion status

---

## Phase 2 — Cost Optimization Recommendations

### Priority Classification

| Priority | SLA | Description |
|----------|-----|-------------|
| **P0 — Critical** | Within 24 hours | Immediate action required |
| **P1 — High** | Within 7 days | Urgent remediation |
| **P2 — Medium** | Within 30 days | Scheduled remediation |
| **P3 — Low** | Within 90 days | Best-practice improvements |

### Recommendation Structure

Each recommendation includes:

| Field | Description |
|-------|-------------|
| **Finding Reference** | Direct link to Phase 1 finding (category, object, severity) |
| **Remediation Steps** | Step-by-step guidance with exact SQL commands or config changes |
| **Estimated Savings** | Credits/month and USD/month upon implementation |
| **Complexity** | Low / Medium / High |
| **Risk Context** | Business impact and what breaks if done incorrectly |

### Category-Specific Remediation

| Category | Remediation Approach |
|----------|---------------------|
| **Compute** | `ALTER WAREHOUSE` commands for AUTO_SUSPEND/AUTO_RESUME, right-sizing, workload separation strategy, resource monitor setup |
| **Storage** | `ALTER TABLE` for Time Travel reduction, `DROP` guidance for unused objects, stage cleanup procedures |
| **Serverless** | `ALTER TABLE` to disable unnecessary clustering, MV refresh policy adjustments, search optimization removal, replication schedule optimization |
| **AI / Cortex** | Model downgrade recommendations using credit rate tiers, prompt engineering guidance, TRY_COMPLETE/TRY_CLASSIFY adoption, AI_COUNT_TOKENS() for pre-batch estimation, CORTEX_MODELS_ALLOWLIST configuration, warehouse size reduction to MEDIUM or below, result caching strategy |

**IMPORTANT:** Phase 2 is strictly documentation and guidance. No DDL, DML, or configuration changes are executed.

### Phase 2 Report Output

| Property | Value |
|----------|-------|
| **Filename** | `Report-Cost-Optimization-Recommendation-DD-MM-YYYY.html` |
| **Location** | `snowflake-cost-optimization/reports/` |
| **Format** | Self-contained HTML |

**Required Report Sections:**
- Report Generation Summary banner (TOP) with elapsed time
- Reference to source Phase 1 assessment report filename
- Prioritized recommendation table (P0 through P3) across all four categories
- Detailed fix instructions per finding
- Estimated remediation effort
- Total potential cost savings summary by category and overall
- AI model substitution savings table

---

## Phase 3 — Compliance Dashboard

### Dashboard Panels

| Panel | Content |
|-------|---------|
| **Category Breakdown** | Finding count, completion percentage, and estimated savings for each of the 4 categories |
| **Priority Tracking** | Remediation timeline adherence and completion status for P0–P3 against SLA windows |
| **AI Cost Recovery** | Cortex model tier distribution, token consumption trends, model downgrade savings potential |
| **Risk Flagging** | Overdue or at-risk items where SLA deadlines are breached or within 48 hours of expiry |

**Category Detail Breakdown:**

| # | Category | Sub-Areas |
|---|----------|-----------|
| 1 | Compute / Warehouse Management | Warehouse sizing, suspend/resume, scaling, spillage |
| 2 | Storage | Active, Time Travel, Fail-Safe, Stages |
| 3 | Serverless | Snowpipe, Clustering, MV, Search, Replication |
| 4 | AI Services / Cortex | By sub-service and model tier |

### Visual Indicators and Scoring

| Indicator | Description |
|-----------|-------------|
| **Progress Bars** | Per priority bucket, per category, and overall remediation |
| **Cost Recovery Score** | Savings realized vs. total potential savings (percentage + USD) |
| **Overall Health Score** | Single composite compliance percentage reflecting total remediation progress |
| **Risk Highlights** | Color-coded flags for overdue (red) and at-risk (amber) items |

### Phase 3 Report Output

| Property | Value |
|----------|-------|
| **Filename** | `Report-Cost-Optimization-Compliance-Dashboard-DD-MM-YYYY.html` |
| **Location** | `snowflake-cost-optimization/reports/` |
| **Format** | Self-contained, interactive HTML |

**Technical Requirements:**
- Fully interactive with no external dependencies
- Refresh-ready for ongoing progress tracking
- Suitable for executive presentation
- Print-friendly styling

---

## SQL Query Reference

Complete inventory of all SQL queries executed during Phase 1:

| Query ID | Target View | Purpose |
|----------|-------------|---------|
| **1a** | `WAREHOUSE_METERING_HISTORY` | Top spending warehouses (30 days) |
| **4a** | `METERING_DAILY_HISTORY` | Cortex AI services credit usage |
| **4b** | `CORTEX_AISQL_USAGE_HISTORY` | AI SQL functions usage by model |
| **4c** | `METERING_DAILY_HISTORY` | Cortex Analyst daily usage |
| **4d** | `CORTEX_SEARCH_DAILY_USAGE_HISTORY` | Cortex Search service costs |
| **4e** | `METERING_DAILY_HISTORY` | All AI/ML service costs summary |
| **4f** | `METERING_DAILY_HISTORY` | Cortex Code CLI / Copilot usage |

All queries target `SNOWFLAKE.ACCOUNT_USAGE` schema and use a 30-day lookback window.

---

## AI Model Credit Rate Tiers

These approximate rates are used for cost estimation and model downgrade recommendations:

| Category | Models | Credits per 1M Tokens |
|----------|--------|----------------------|
| **Small** | mistral-7b, gemma-7b | ~0.12 |
| **Medium** | llama3.1-8b, mistral-large | ~0.60 |
| **Large** | llama3.1-70b | ~1.21 |
| **XLarge** | llama3.1-405b | ~3.63 |
| **Embedding** | embed-text-768, embed-text-1024 | ~0.10 |

**Notes:**
- Document AI and Cortex Analyst have separate billing models
- Always check the latest Snowflake pricing documentation for current rates
- These rates are used for relative comparison and savings estimation

---

## Optimization Checklists

### Compute Checklist

- [ ] Set AUTO_SUSPEND to 60 seconds (or less for sporadic workloads)
- [ ] Enable AUTO_RESUME
- [ ] Right-size warehouses (start small, scale up)
- [ ] Use separate warehouses for different workload types
- [ ] Avoid XL+ warehouses unless queries spill to storage

### Storage Checklist

- [ ] Reduce TIME_TRAVEL retention for non-critical tables
- [ ] Drop unused tables, clones, and stages
- [ ] Clean up temporary and transient tables
- [ ] Monitor FAIL_SAFE storage consumption

### Serverless Checklist

- [ ] Identify and tune expensive queries (QUERY_HISTORY)
- [ ] Add clustering keys to large, frequently filtered tables
- [ ] Use result caching effectively
- [ ] Avoid SELECT * — select only needed columns
- [ ] Filter early in queries (predicate pushdown)

### AI Services Checklist

- [ ] Use smallest effective model (mistral-7b < llama3.1-8b < llama3.1-70b < llama3.1-405b)
- [ ] Use warehouse size no larger than MEDIUM for Cortex functions
- [ ] Leverage result caching for repeated AI calls
- [ ] Use AI_COUNT_TOKENS to estimate costs before large batch operations
- [ ] Consider TRY_COMPLETE to avoid costs on error cases
- [ ] Monitor token usage via CORTEX_AISQL_USAGE_HISTORY
- [ ] Restrict model access via CORTEX_MODELS_ALLOWLIST if needed

---

## AI Cost Control Best Practices

| # | Practice | Detail |
|---|----------|--------|
| 1 | **Model Selection** | Start with smaller models and only upgrade if quality is insufficient |
| 2 | **Prompt Engineering** | Shorter, precise prompts reduce token consumption |
| 3 | **Batch Processing** | Group similar requests to leverage caching |
| 4 | **Error Handling** | Use TRY_ variants (TRY_COMPLETE, TRY_CLASSIFY) to avoid charges on errors |
| 5 | **Token Estimation** | Use AI_COUNT_TOKENS() before large batch operations |
| 6 | **Access Control** | Set CORTEX_MODELS_ALLOWLIST to restrict expensive models |
| 7 | **Monitoring** | Regularly review METERING_DAILY_HISTORY and CORTEX_AISQL_USAGE_HISTORY |

---

## Execution Rules

| # | Rule |
|---|------|
| 1 | Run all three phases strictly sequentially — no skipping, merging, or parallelizing |
| 2 | Execute ALL six Cortex queries during Phase 1 — none may be omitted |
| 3 | Capture and display total elapsed time for Phase 1 and Phase 2 individually |
| 4 | Substitute `DD-MM-YYYY` with today's actual date in all filenames |
| 5 | Use $3/credit as default cost rate; note assumption clearly in all reports |
| 6 | All HTML reports must be professionally styled, print-friendly, executive-ready |
| 7 | No DDL, DML, or configuration changes — assessment and documentation only |
| 8 | Save all reports exclusively to `snowflake-cost-optimization/reports/` |
| 9 | Display "Report Generation Summary" banner at TOP of Phase 1 and Phase 2 reports |

---

## Error Handling and Self-Healing

The skill includes a built-in self-healing mechanism for query failures:

### Failure Response Flow

```
Query Fails ──► Diagnose Root Cause ──► Apply Fix ──► Retry
                                                        │
                                         ┌──────────────┤
                                         ▼              ▼
                                      Success        Failed Again
                                         │              │
                                  Log & Continue    Mark SKIPPED
                                                        │
                                              Flag in "Manual Review
                                              Required" section
```

### What Gets Logged for Each Failure

| Field | Description |
|-------|-------------|
| Step name / query ID | Which query or step failed |
| Error message | Exact Snowflake error |
| Root cause diagnosis | Why it failed |
| Corrective fix | What was changed |
| Retry outcome | Success or Failed after retry |

### Self-Healing Actions

- On successful recovery: the corrected query version is updated in the skill file with an inline comment:
  ```sql
  -- [FIXED on DD-MM-YYYY]: <description of what was corrected and why>
  ```
- All self-healing actions are consolidated into a "Self-Healing Summary" section appended to Phase 1 and Phase 2 reports

---

## Report File Inventory

| Phase | Filename Pattern | Description |
|-------|-----------------|-------------|
| Phase 1 | `Report-Cost-Optimization-Assessment-DD-MM-YYYY.html` | Assessment findings across all 4 categories |
| Phase 2 | `Report-Cost-Optimization-Recommendation-DD-MM-YYYY.html` | Prioritized recommendations with SQL fixes |
| Phase 3 | `Report-Cost-Optimization-Compliance-Dashboard-DD-MM-YYYY.html` | Interactive compliance tracking dashboard |

All reports are saved to: `snowflake-cost-optimization/reports/`

---

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| Permission errors on ACCOUNT_USAGE views | Insufficient role | Switch to `ACCOUNTADMIN` |
| Query returns 0 rows for a Cortex service | Service not used in last 30 days | Expected — skill still records the result as "no usage" |
| Phase 2 references missing findings | Phase 1 was not run or was incomplete | Ensure Phase 1 completes fully before Phase 2 |
| Self-healing loop | Query cannot be fixed automatically | Marked as SKIPPED; check "Manual Review Required" section |
| Reports not appearing in expected folder | Path mismatch | Verify reports are in `snowflake-cost-optimization/reports/` |
| USD estimates seem incorrect | Default $3/credit may not match account pricing | Provide account-specific credit rate to override |
| CORTEX_SEARCH_DAILY_USAGE_HISTORY not found | Cortex Search not enabled or view not yet available | Logged as SKIPPED; no impact on other categories |
| CORTEX_AISQL_USAGE_HISTORY empty | No Cortex AI SQL function calls in last 30 days | Expected — skill records "no usage" |
| Report HTML looks broken | Browser compatibility | Use a modern browser (Chrome, Firefox, Edge) |
| Elapsed time not shown | Phase ran too fast to measure | Displayed as "<1 second" |
