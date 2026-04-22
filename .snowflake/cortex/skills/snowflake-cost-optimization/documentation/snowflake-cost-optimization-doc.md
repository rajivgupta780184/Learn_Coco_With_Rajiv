# Snowflake Cost Optimization — Documentation

**Author:** Rajiv Gupta
**LinkedIn:** [https://www.linkedin.com/in/rajiv-gupta-618b0228/](https://www.linkedin.com/in/rajiv-gupta-618b0228/)
**Version:** 1.0
**Last Updated:** April 22, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Trigger Keywords](#trigger-keywords)
6. [Cost Categories](#cost-categories)
7. [Three-Phase Workflow](#three-phase-workflow)
8. [Phase 1 — Cost Optimization Assessment](#phase-1--cost-optimization-assessment)
   - [Category 1: Compute (Warehouse) Costs](#category-1-compute-warehouse-costs)
   - [Category 2: Storage Costs](#category-2-storage-costs)
   - [Category 3: Serverless Feature Costs](#category-3-serverless-feature-costs)
   - [Category 4: AI Services Costs (Cortex)](#category-4-ai-services-costs-cortex)
   - [Finding Capture Format](#finding-capture-format)
   - [Phase 1 Report Output](#phase-1-report-output)
9. [Phase 2 — Cost Optimization Recommendations](#phase-2--cost-optimization-recommendations)
   - [Priority Classification](#priority-classification)
   - [Recommendation Structure](#recommendation-structure)
   - [Category-Specific Remediation](#category-specific-remediation)
   - [Phase 2 Report Output](#phase-2-report-output)
10. [Phase 3 — Compliance Dashboard](#phase-3--compliance-dashboard)
    - [Dashboard Panels](#dashboard-panels)
    - [Visual Indicators and Scoring](#visual-indicators-and-scoring)
    - [Phase 3 Report Output](#phase-3-report-output)
11. [SQL Query Reference](#sql-query-reference)
12. [AI Model Credit Rate Tiers](#ai-model-credit-rate-tiers)
13. [Optimization Checklists](#optimization-checklists)
14. [AI Cost Control Best Practices](#ai-cost-control-best-practices)
15. [Finding Severity and Priority Matrix](#finding-severity-and-priority-matrix)
16. [Execution Rules](#execution-rules)
17. [Error Handling and Self-Healing](#error-handling-and-self-healing)
18. [Report File Inventory](#report-file-inventory)
19. [Data Sources](#data-sources)
20. [Post-Run Monitoring](#post-run-monitoring)
21. [Troubleshooting](#troubleshooting)
22. [Frequently Asked Questions](#frequently-asked-questions)

---

## Overview

The **Snowflake Cost Optimization** skill performs a comprehensive, three-phase cost analysis of a Snowflake account. It assesses spending across four cost categories — Compute, Storage, Serverless, and AI Services — and produces three professional HTML reports: an assessment, a recommendation plan, and a compliance dashboard.

All analysis is **read-only**. No DDL, DML, or configuration changes are executed at any point. The skill uses a default rate of **$3 per credit** for all USD estimates unless account-specific pricing is provided.

### Key Capabilities

- Scans 4 cost categories: Compute, Storage, Serverless, and AI Services (Cortex).
- Executes 7 SQL queries during Phase 1 (1 compute + 6 Cortex/AI).
- Evaluates warehouse configuration (AUTO_SUSPEND, AUTO_RESUME, sizing, scaling policy, resource monitors).
- Assesses storage efficiency (Time Travel, Fail-Safe, staged files, unused tables).
- Audits serverless feature ROI (Snowpipe, clustering, materialized views, search optimization, replication).
- Analyzes Cortex AI token consumption by model tier with downgrade savings estimates.
- Produces three sequentially-dependent HTML reports: Assessment, Recommendations, Compliance Dashboard.
- Includes self-healing retry logic for failed queries.

### What This Skill Does NOT Do

- It does **not** execute any DDL, DML, or configuration changes.
- It does **not** alter warehouse settings, drop objects, or modify account parameters.
- It is strictly an assessment and documentation tool.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Snowflake Cost Optimization                       │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  PHASE 1: COST ASSESSMENT (4 Categories, 7 Queries)                 │
│                                                                      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐         │
│  │  Category 1    │  │  Category 2    │  │  Category 3    │         │
│  │  COMPUTE       │  │  STORAGE       │  │  SERVERLESS    │         │
│  │  ┌──────────┐  │  │  · Active      │  │  · Snowpipe    │         │
│  │  │ Query 1a │  │  │  · Time Travel │  │  · Clustering  │         │
│  │  │ Top WH   │  │  │  · Fail-Safe   │  │  · Mat. Views  │         │
│  │  │ Spend    │  │  │  · Stages      │  │  · Search Opt  │         │
│  │  └──────────┘  │  │  · Unused Obj  │  │  · Replication │         │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘         │
│          │                   │                    │                   │
│  ┌───────┴───────────────────┴────────────────────┴──────────┐      │
│  │                   Category 4: AI SERVICES                  │      │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐  │      │
│  │  │Q4a: AI │ │Q4b: SQL│ │Q4c:    │ │Q4d:    │ │Q4e: All│  │      │
│  │  │Credits │ │Func by │ │Analyst │ │Search  │ │AI/ML   │  │      │
│  │  │Usage   │ │Model   │ │Usage   │ │Costs   │ │Summary │  │      │
│  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘  │      │
│  │  ┌────────┐                                                │      │
│  │  │Q4f:    │                                                │      │
│  │  │Copilot │                                                │      │
│  │  └────────┘                                                │      │
│  └───────────────────────────┬────────────────────────────────┘      │
│                              │                                       │
│              ┌───────────────┴───────────────┐                       │
│              │     Self-Healing Retry Logic   │                       │
│              └───────────────┬───────────────┘                       │
│                              │                                       │
│  PHASE 1                    ▼                                       │
│            ┌──────────────────────────────┐                          │
│            │  Assessment HTML Report      │                          │
│            │  (findings + cost estimates) │                          │
│            └─────────────┬────────────────┘                          │
│                          │                                           │
│  PHASE 2                 ▼                                           │
│            ┌──────────────────────────────┐                          │
│            │  Recommendation HTML Report  │                          │
│            │  (P0–P3 fixes + SQL + $$$)   │                          │
│            └─────────────┬────────────────┘                          │
│                          │                                           │
│  PHASE 3                 ▼                                           │
│            ┌──────────────────────────────┐                          │
│            │  Compliance Dashboard HTML   │                          │
│            │  (interactive, executive)    │                          │
│            └──────────────────────────────┘                          │
│                                                                      │
│  All reports → snowflake-cost-optimization/reports/                  │
└──────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Input:** Read-only SQL queries against `SNOWFLAKE.ACCOUNT_USAGE` views with a 30-day lookback window, plus `SHOW WAREHOUSES` for configuration audit.
2. **Processing:** Query results are assessed against defined thresholds, flagged by severity, and quantified in credits and USD. Failed queries enter the self-healing retry loop.
3. **Output:** Three self-contained HTML reports saved to `snowflake-cost-optimization/reports/`.

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
| **Browser** | Any modern browser (Chrome, Firefox, Edge) to render HTML reports |

### Workspace Setup

The skill expects the following directory structure:

```
snowflake-cost-optimization/
├── SKILL.md                          # Skill definition (do not modify manually)
├── documentation/
│   └── snowflake-cost-optimization-doc.md  # This file
└── reports/                          # Generated HTML reports land here
    ├── Report-Cost-Optimization-Assessment-<DD-MM-YYYY>.html
    ├── Report-Cost-Optimization-Recommendation-<DD-MM-YYYY>.html
    └── Report-Cost-Optimization-Compliance-Dashboard-<DD-MM-YYYY>.html
```

---

## Quick Start

1. Open Snowsight and navigate to the workspace containing this skill.
2. Ensure you are using the **ACCOUNTADMIN** role (or equivalent with read access to `SNOWFLAKE.ACCOUNT_USAGE`).
3. Invoke the skill by asking Cortex Code:
   > "Run the Snowflake Cost Optimization"
4. The optimizer executes all three phases sequentially:
   - Phase 1: Runs 7 queries across 4 cost categories
   - Phase 2: Produces prioritized recommendations from Phase 1 findings
   - Phase 3: Generates an interactive compliance dashboard
5. Review the generated HTML reports in `snowflake-cost-optimization/reports/`.

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

Warehouses drive credit consumption through virtual warehouse metering, auto-suspend/resume behavior, multi-cluster scaling, and query spillage to storage.

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

| Check | Flag Condition | Risk | Severity |
|-------|---------------|------|----------|
| AUTO_SUSPEND | Set above 60 seconds | Credit waste during idle periods | High |
| AUTO_RESUME | Disabled | Requires manual intervention to start | Medium |
| Right-sizing | XL+ without query spillage evidence | Over-provisioned compute | High |
| Multi-cluster scaling | Policy mismatched to workload pattern | Under/over-scaling | Medium |
| Query spillage | Queries spilling to remote storage | Under-sized warehouse | Critical |
| Workload separation | Mixed ETL + interactive on same warehouse | Contention and cost inefficiency | Medium |
| Resource monitors | None configured | No spend governance | High |

### Category 2: Storage Costs

Storage costs come from active storage, Time Travel retention, Fail-Safe, and staged files.

**Assessment Areas:**

| Storage Domain | What to Check | Severity When Flagged |
|---------------|---------------|----------------------|
| Active storage | Consumption by database and schema | Info |
| Time Travel | Retention > 1 day on non-critical tables | Medium |
| Fail-Safe | Associated storage costs | Low |
| Stage files | Orphaned or stale files on internal/external stages | Medium |
| Unused objects | Zero-row tables, unused clones, transient/temporary table sprawl | High |

### Category 3: Serverless Feature Costs

Serverless costs come from Snowpipe, automatic clustering, materialized view maintenance, search optimization, and replication.

**Assessment Areas:**

| Service | What to Check | Severity When Flagged |
|---------|---------------|----------------------|
| **Snowpipe** | Ingestion frequency, file sizing, credit consumption patterns | Medium |
| **Automatic Clustering** | Tables with clustering enabled but low query benefit | High |
| **Materialized View Maintenance** | Stale or infrequently queried materialized views | Medium |
| **Search Optimization** | Tables with search optimization enabled but low usage | Medium |
| **Replication** | Replication group costs, frequency, business justification | High |

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

| Sub-Category | Assessment Focus | Severity When Flagged |
|-------------|-----------------|----------------------|
| **Cortex AI/SQL Functions** | Flag usage of Large/XLarge models where smaller models suffice | High |
| **Cortex Analyst** | Daily credit trends, usage anomalies | Medium |
| **Cortex Search** | Per-service credit consumption; flag over-provisioned services | Medium |
| **Cortex Fine-Tuning** | Training cost and frequency justification | High |
| **Document AI** | Processing volume and credit efficiency | Medium |
| **Cortex Code CLI** | Usage patterns (currently free — monitor for billing changes) | Low |
| **Embeddings** | Token volume and credit usage for EMBED_TEXT_768/1024 | Medium |
| **Token Volume** | Flag abnormally high input+output volumes without corresponding business output | High |

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

**Compute Remediation Examples:**

```sql
-- Set auto-suspend to 60 seconds
ALTER WAREHOUSE <warehouse_name> SET AUTO_SUSPEND = 60;

-- Enable auto-resume
ALTER WAREHOUSE <warehouse_name> SET AUTO_RESUME = TRUE;

-- Right-size a warehouse
ALTER WAREHOUSE <warehouse_name> SET WAREHOUSE_SIZE = 'MEDIUM';

-- Create a resource monitor
CREATE RESOURCE MONITOR <monitor_name>
    WITH CREDIT_QUOTA = 1000
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;
```

**Storage Remediation Examples:**

```sql
-- Reduce Time Travel retention
ALTER TABLE <db>.<schema>.<table> SET DATA_RETENTION_TIME_IN_DAYS = 1;

-- Drop unused table (guidance only — verify before executing)
-- DROP TABLE <db>.<schema>.<table>;

-- Remove staged files
-- REMOVE @<stage_name>/<path>;
```

**AI / Cortex Remediation Examples:**

```sql
-- Restrict expensive models
ALTER ACCOUNT SET CORTEX_MODELS_ALLOWLIST = 'mistral-7b,llama3.1-8b,mistral-large';

-- Pre-estimate token cost before batch
SELECT AI_COUNT_TOKENS('mistral-7b', <prompt_column>) FROM <table> LIMIT 100;

-- Use TRY_COMPLETE to avoid charges on errors
SELECT TRY_COMPLETE('mistral-7b', <prompt>) FROM <table>;
```

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

| Query ID | Target View | Purpose | Category |
|----------|-------------|---------|----------|
| **1a** | `WAREHOUSE_METERING_HISTORY` | Top spending warehouses (30 days) | Compute |
| **4a** | `METERING_DAILY_HISTORY` | Cortex AI services credit usage | AI Services |
| **4b** | `CORTEX_AISQL_USAGE_HISTORY` | AI SQL functions usage by model | AI Services |
| **4c** | `METERING_DAILY_HISTORY` | Cortex Analyst daily usage | AI Services |
| **4d** | `CORTEX_SEARCH_DAILY_USAGE_HISTORY` | Cortex Search service costs | AI Services |
| **4e** | `METERING_DAILY_HISTORY` | All AI/ML service costs summary | AI Services |
| **4f** | `METERING_DAILY_HISTORY` | Cortex Code CLI / Copilot usage | AI Services |

All queries target the `SNOWFLAKE.ACCOUNT_USAGE` schema and use a 30-day lookback window.

**Note:** Categories 2 (Storage) and 3 (Serverless) are assessed through configuration review, `SHOW` commands, and metadata analysis rather than dedicated numbered queries.

---

## AI Model Credit Rate Tiers

These approximate rates are used for cost estimation and model downgrade recommendations:

| Category | Models | Credits per 1M Tokens | Monthly Cost at 10M Tokens |
|----------|--------|----------------------|---------------------------|
| **Small** | mistral-7b, gemma-7b | ~0.12 | ~$3.60 |
| **Medium** | llama3.1-8b, mistral-large | ~0.60 | ~$18.00 |
| **Large** | llama3.1-70b | ~1.21 | ~$36.30 |
| **XLarge** | llama3.1-405b | ~3.63 | ~$108.90 |
| **Embedding** | embed-text-768, embed-text-1024 | ~0.10 | ~$3.00 |

**Model Downgrade Savings Examples:**

| Current Model | Downgrade To | Savings per 1M Tokens | % Reduction |
|--------------|-------------|----------------------|-------------|
| llama3.1-405b (XLarge) | llama3.1-70b (Large) | ~2.42 credits | 67% |
| llama3.1-405b (XLarge) | llama3.1-8b (Medium) | ~3.03 credits | 83% |
| llama3.1-70b (Large) | llama3.1-8b (Medium) | ~0.61 credits | 50% |
| llama3.1-70b (Large) | mistral-7b (Small) | ~1.09 credits | 90% |
| mistral-large (Medium) | mistral-7b (Small) | ~0.48 credits | 80% |

**Notes:**
- Document AI and Cortex Analyst have separate billing models
- Always check the latest Snowflake pricing documentation for current rates
- These rates are used for relative comparison and savings estimation
- Monthly cost column assumes $3/credit rate

---

## Optimization Checklists

### Compute Checklist

- [ ] Set AUTO_SUSPEND to 60 seconds (or less for sporadic workloads)
- [ ] Enable AUTO_RESUME on all warehouses
- [ ] Right-size warehouses (start small, scale up only when spillage occurs)
- [ ] Use separate warehouses for different workload types (ETL, BI, ad-hoc)
- [ ] Avoid XL+ warehouses unless queries spill to storage
- [ ] Configure resource monitors for spend governance

### Storage Checklist

- [ ] Reduce TIME_TRAVEL retention for non-critical tables (1 day vs default)
- [ ] Drop unused tables, clones, and stages
- [ ] Clean up temporary and transient tables
- [ ] Monitor FAIL_SAFE storage consumption
- [ ] Remove orphaned staged files

### Serverless Checklist

- [ ] Identify and tune expensive queries (QUERY_HISTORY)
- [ ] Add clustering keys only to large, frequently filtered tables
- [ ] Use result caching effectively
- [ ] Avoid SELECT * — select only needed columns
- [ ] Filter early in queries (predicate pushdown)
- [ ] Evaluate ROI of materialized views and search optimization

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

### Model Selection Decision Tree

```
Task Requires AI Function
        │
        ▼
Is quality acceptable with mistral-7b (Small)?
        │
   ┌────┴────┐
   YES       NO
   │         │
   Use       Try llama3.1-8b (Medium)
   Small     │
             ▼
        Is quality acceptable?
             │
        ┌────┴────┐
        YES       NO
        │         │
        Use       Try llama3.1-70b (Large)
        Medium    │
                  ▼
             Is quality acceptable?
                  │
             ┌────┴────┐
             YES       NO
             │         │
             Use       Use llama3.1-405b (XLarge)
             Large     (last resort — 30x cost of Small)
```

---

## Finding Severity and Priority Matrix

Cost findings are mapped to priorities with recommended timelines and estimated effort:

| Finding | Category | Severity | Effort | Priority | Timeline |
|---------|----------|----------|--------|----------|----------|
| Query spillage to remote storage | Compute | Critical | Low | P0 | Immediate |
| No resource monitor on high-spend warehouse | Compute | High | Low | P0 | Within 24 hours |
| AUTO_SUSPEND > 600s on ETL warehouse | Compute | High | Low | P1 | Within 7 days |
| XL+ warehouse without spillage evidence | Compute | High | Low | P1 | Within 7 days |
| Unused tables consuming storage credits | Storage | High | Medium | P1 | Within 7 days |
| AUTO_RESUME disabled | Compute | Medium | Low | P1 | Within 7 days |
| Clustering enabled with low query benefit | Serverless | High | Medium | P1 | Within 7 days |
| Replication without business justification | Serverless | High | High | P2 | Within 30 days |
| Time Travel retention > 1 day on non-critical tables | Storage | Medium | Low | P2 | Within 30 days |
| Large/XLarge model where Small suffices | AI Services | High | Low | P2 | Within 30 days |
| Orphaned staged files | Storage | Medium | Medium | P2 | Within 30 days |
| Stale materialized views | Serverless | Medium | Medium | P2 | Within 30 days |
| Search optimization with low usage | Serverless | Medium | Low | P2 | Within 30 days |
| Over-provisioned Cortex Search service | AI Services | Medium | Medium | P2 | Within 30 days |
| Mixed ETL + interactive on same warehouse | Compute | Medium | High | P3 | Within 90 days |
| High token volume without business output | AI Services | High | Medium | P3 | Within 90 days |
| Fail-Safe storage optimization | Storage | Low | Low | P3 | Within 90 days |
| Transient/temporary table sprawl | Storage | Low | Medium | P3 | Within 90 days |

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

The skill includes a built-in self-healing mechanism for query failures.

### How It Works

1. **Auto-Recovery:** If any SQL query or workflow step fails, the skill does not halt. It automatically diagnoses the root cause, applies the appropriate fix, and retries.

2. **Inline Logging:** For every failed-and-recovered step, the scanner logs within the relevant phase report:
   - Step name / query identifier that failed
   - Exact error message received from Snowflake
   - Root cause diagnosis
   - Corrective fix applied
   - Retry outcome (Success / Failed after retry)

3. **Skill File Updates:** When a query failure is successfully resolved, the corrected query is written back to the SKILL.md file with an inline comment:
   ```sql
   -- [FIXED on <DD-MM-YYYY>]: <concise description of what was corrected and why>
   ```

4. **Graceful Degradation:** If a step fails and cannot be recovered after retry, it is marked as **SKIPPED** with a clear root cause explanation. The skill continues with remaining steps and flags the skipped item under a "Manual Review Required" section.

5. **Self-Healing Summary:** All self-healing actions are consolidated into a dedicated "Self-Healing Summary" section appended to the Phase 1 and Phase 2 reports.

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

---

## Report File Inventory

| Phase | Filename Pattern | Description |
|-------|-----------------|-------------|
| Phase 1 | `Report-Cost-Optimization-Assessment-DD-MM-YYYY.html` | Assessment findings across all 4 categories |
| Phase 2 | `Report-Cost-Optimization-Recommendation-DD-MM-YYYY.html` | Prioritized recommendations with SQL fixes |
| Phase 3 | `Report-Cost-Optimization-Compliance-Dashboard-DD-MM-YYYY.html` | Interactive compliance tracking dashboard |

All reports are saved to: `snowflake-cost-optimization/reports/`

---

## Data Sources

All queries are read-only and target the following Snowflake system views:

| View / Command | Query ID | Purpose |
|----------------|----------|---------|
| `SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY` | 1a | Warehouse credit consumption over 30 days |
| `SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY` | 4a, 4c, 4e, 4f | AI services credit usage, Analyst usage, all AI/ML summary, Copilot usage |
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY` | 4b | Cortex AI SQL function usage by model and function |
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY` | 4d | Cortex Search service token and credit consumption |
| `SNOWFLAKE.ACCOUNT_USAGE.TABLES` | Storage | Table metadata, row counts, sizes, Time Travel settings |
| `SNOWFLAKE.ACCOUNT_USAGE.STAGES` | Storage | Stage inventory for orphaned file detection |
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` | Serverless | Query patterns for clustering/MV/search optimization ROI |
| `SHOW WAREHOUSES` | Compute | Warehouse configuration (size, auto-suspend, scaling, auto-resume) |

**Note:** `SNOWFLAKE.ACCOUNT_USAGE` views have a latency of up to 45 minutes and retain up to 365 days of data. The skill defaults to a 30-day lookback window.

---

## Post-Run Monitoring

After reviewing reports and applying recommended changes, set up ongoing cost monitoring.

### Key Metrics to Track Monthly

| Metric | Target | Alert If |
|--------|--------|----------|
| Total monthly credit consumption | Decreasing trend | Increases > 15% month-over-month |
| Top warehouse spend | Within budget allocation | Any single warehouse exceeds 40% of total spend |
| Storage growth rate | Aligned with data growth | Growth > 20% without corresponding business justification |
| AI Services credits | Within allocated budget | Spike > 50% week-over-week |
| Unused table count | Zero | New unused tables appear |
| Resource monitor triggers | No suspensions | Any warehouse hits 100% quota |

### Recommended Re-Run Cadence

| Scenario | Frequency |
|----------|-----------|
| Active development with frequent schema/workload changes | Weekly |
| Stable production environment | Monthly |
| After major warehouse or clustering changes | On-demand (immediately after) |
| Pre-budget or quarterly business review | Quarterly |
| After onboarding new AI/ML workloads | On-demand |
| After Snowflake pricing changes | On-demand |

### Cost Trend Tracking Query

Use this query to track total credit consumption trends over time:

```sql
SELECT
    DATE_TRUNC('week', start_time) AS week,
    SUM(credits_used) AS total_credits,
    ROUND(SUM(credits_used) * 3, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(month, -3, CURRENT_TIMESTAMP())
GROUP BY DATE_TRUNC('week', start_time)
ORDER BY week DESC;
```

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
| Storage assessment incomplete | Missing IMPORTED PRIVILEGES on SNOWFLAKE database | Grant IMPORTED PRIVILEGES to the role being used |

---

## Frequently Asked Questions

### Q: Do I need ACCOUNTADMIN to run the cost optimizer?

**A:** Yes, ACCOUNTADMIN is recommended for full access to `SNOWFLAKE.ACCOUNT_USAGE` views. A custom role with `IMPORTED PRIVILEGES` on the `SNOWFLAKE` database may work for most queries, but some views (particularly `CORTEX_AISQL_USAGE_HISTORY` and `CORTEX_SEARCH_DAILY_USAGE_HISTORY`) may require higher privileges.

### Q: Will the optimizer make any changes to my account?

**A:** No. The optimizer is strictly read-only. It executes `SELECT` queries and `SHOW` commands only. All remediation SQL (ALTER WAREHOUSE, DROP TABLE, etc.) is provided as documentation — it is never executed automatically.

### Q: Why is the default cost rate $3/credit?

**A:** $3/credit is a commonly used baseline for Snowflake On-Demand pricing. Your actual rate may differ based on your contract (Capacity or On-Demand), region, and cloud provider. You can override this rate when invoking the skill for more accurate USD estimates.

### Q: How long does a full cost optimization audit take?

**A:** Typically 5–15 minutes depending on account size, number of warehouses, and AI service usage volume. Phase 1 (assessment) takes the longest due to the 7 SQL queries. Phase 2 and 3 are primarily report generation.

### Q: Can I run individual cost categories instead of all four?

**A:** The skill is designed to run all four categories in every execution. However, you can ask Cortex Code to focus on a specific category (e.g., "Analyze only my AI Services costs") — the individual queries are self-contained.

### Q: What happens if a query fails during the audit?

**A:** The self-healing mechanism auto-diagnoses, fixes, and retries. If recovery fails, the query is marked as SKIPPED with error details and flagged under "Manual Review Required." The audit continues with remaining queries.

### Q: How does the compliance dashboard track progress?

**A:** The Phase 3 dashboard cross-references Phase 1 findings with Phase 2 recommendations. It calculates a Cost Recovery Score (savings realized vs. total potential) and an Overall Health Score (percentage of recommendations implemented). It also tracks SLA adherence for each priority level (P0: 24hr, P1: 7d, P2: 30d, P3: 90d).

### Q: Why are there 6 AI queries but only 1 compute query?

**A:** Compute assessment relies heavily on the top-spending warehouses query plus `SHOW WAREHOUSES` for configuration audit. Storage and serverless use metadata views and configuration analysis. AI Services requires 6 separate queries because each Cortex sub-service (AI Functions, Analyst, Search, Fine-Tuning, Document AI, Copilot) has distinct billing views and usage patterns.

### Q: How accurate are the model downgrade savings estimates?

**A:** The credit rate tiers are approximate and based on published Snowflake pricing. Actual savings depend on your specific token volumes, model usage patterns, and contract pricing. The estimates provide directional guidance for identifying the highest-impact optimization opportunities.

### Q: Where are the reports saved?

**A:** All HTML reports are saved to `snowflake-cost-optimization/reports/` in the workspace. File names include the execution date (DD-MM-YYYY format) for version tracking.

### Q: How often should I run the cost optimizer?

**A:** Recommended cadence:
- **Monthly:** Standard for most accounts
- **Weekly:** For accounts with rapidly changing workloads or active AI development
- **Quarterly:** For budget planning and executive reviews
- **On-demand:** After major changes (new warehouses, new AI workloads, pricing changes)

### Q: Can I use the reports for executive presentations?

**A:** Yes. All three reports are designed to be executive-ready with professional styling, color-coded badges, and print-friendly layouts. The Phase 3 Compliance Dashboard is specifically designed for stakeholder presentation with interactive visualizations and a single composite health score.
