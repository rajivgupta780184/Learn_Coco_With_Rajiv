# Snowflake Performance Optimizer — Documentation

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
6. [Performance Dimensions](#performance-dimensions)
   - [1. Query Execution](#1-query-execution)
   - [2. Warehouse Configuration](#2-warehouse-configuration)
   - [3. Data Organization](#3-data-organization)
   - [4. Caching Layers](#4-caching-layers)
   - [5. Query Acceleration Service](#5-query-acceleration-service)
   - [6. Query Lifecycle](#6-query-lifecycle)
7. [Data Collection — SQL Query Reference](#data-collection--sql-query-reference)
   - [Query 1: Slow Query Analysis](#query-1-slow-query-analysis)
   - [Query 2: Spillage Detection](#query-2-spillage-detection)
   - [Query 3: Partition Pruning Efficiency](#query-3-partition-pruning-efficiency)
   - [Query 4: Queue Wait Time Analysis](#query-4-queue-wait-time-analysis)
   - [Query 5: Warehouse Credit Consumption](#query-5-warehouse-credit-consumption)
   - [Query 6: User Activity Analysis](#query-6-user-activity-analysis)
   - [Query 7: Large Table Clustering Assessment](#query-7-large-table-clustering-assessment)
   - [Query 8: Warehouse Utilization Patterns](#query-8-warehouse-utilization-patterns)
   - [Query 9: QAS Eligibility (Per Query)](#query-9-qas-eligibility-per-query)
   - [Query 10: QAS Eligibility (Per Warehouse)](#query-10-qas-eligibility-per-warehouse)
   - [Query 11: Cache Hit Rate Analysis](#query-11-cache-hit-rate-analysis)
   - [Query 12: Compilation vs Execution Time](#query-12-compilation-vs-execution-time)
   - [Query 13: Failed and Error Query Analysis](#query-13-failed-and-error-query-analysis)
   - [Query 14: Warehouse Configuration Audit](#query-14-warehouse-configuration-audit)
   - [Query 15: Concurrency and Peak Load Analysis](#query-15-concurrency-and-peak-load-analysis)
8. [Automatic Retry Logic](#automatic-retry-logic)
9. [Optimization Checklists](#optimization-checklists)
10. [Performance Red Flags](#performance-red-flags)
11. [Finding Severity and Priority Matrix](#finding-severity-and-priority-matrix)
12. [Recommended Actions](#recommended-actions)
13. [Report Generation](#report-generation)
    - [Report 1: Performance Assessment](#report-1-performance-assessment)
    - [Report 2: Performance Recommendations](#report-2-performance-recommendations)
    - [Report 3: Compliance Evaluation](#report-3-compliance-evaluation)
    - [Report Dependencies and Flow](#report-dependencies-and-flow)
    - [HTML Report Requirements](#html-report-requirements)
14. [Execution Checklist](#execution-checklist)
15. [Data Sources](#data-sources)
16. [Post-Run Monitoring](#post-run-monitoring)
17. [Troubleshooting](#troubleshooting)
18. [Frequently Asked Questions](#frequently-asked-questions)

---

## Overview

The **Snowflake Performance Optimizer** is a Cortex Code skill that performs a comprehensive, read-only performance audit of a Snowflake account. It executes 15 analysis queries across `SNOWFLAKE.ACCOUNT_USAGE` views, covering query execution, warehouse configuration, data organization, caching, query acceleration, query lifecycle health, and concurrency.

The skill produces three HTML reports — an Assessment, a Recommendation plan, and a Compliance Evaluation — all saved to `snowflake-performance-optimizer/reports/`.

All analysis is **read-only**. No DDL, DML, or configuration changes are executed. All metrics are derived from actual query results — no sample or dummy data is used.

### Key Capabilities

- Analyzes 15 query categories across 6 performance dimensions.
- Identifies slow queries (>60s), spillage patterns, poor partition pruning, queue contention, and error patterns.
- Evaluates warehouse configuration (sizing, auto-suspend, scaling policy, QAS eligibility).
- Measures cache hit rates per warehouse and recommends auto-suspend tuning.
- Detects compilation bottlenecks (SQL complexity vs. compute).
- Produces three sequentially-dependent HTML reports: Assessment, Recommendations, and Compliance Evaluation.
- Includes automatic retry logic with self-diagnosis for failed queries.

### What This Skill Does NOT Do

- It does **not** execute any DDL, DML, or configuration changes.
- It does **not** alter warehouse settings, clustering keys, or account parameters.
- It is strictly an assessment and documentation tool.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                  Snowflake Performance Optimizer                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  DATA COLLECTION (15 Queries)                                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ Q1: Slow │ │ Q2: Spill│ │ Q3: Prune│ │ Q4: Queue│ │ Q5:Credit│ │
│  │ Queries  │ │ Detection│ │ Efficieny│ │ Wait Time│ │ Consumpt │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ │
│  ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ │
│  │ Q6: User │ │ Q7: Clust│ │ Q8: WH   │ │Q9/10:QAS │ │Q11:Cache │ │
│  │ Activity │ │ Tables   │ │ Patterns │ │Eligiblity│ │ Hit Rate │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ │
│  ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐              │
│  │Q12:Compil│ │Q13:Errors│ │Q14:WH Cfg│ │Q15:Concur│              │
│  │ vs Exec  │ │ Analysis │ │ Audit    │ │ Peak Load│              │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘              │
│       │             │            │             │                     │
│       └─────────────┴────────────┴─────────────┘                    │
│                          │                                          │
│              ┌───────────┴───────────┐                              │
│              │   Automatic Retry     │                              │
│              │   Logic (on failure)  │                              │
│              └───────────┬───────────┘                              │
│                          │                                          │
│  PHASE 1                 ▼                                          │
│            ┌──────────────────────────┐                              │
│            │  Assessment HTML Report  │                              │
│            │  (findings only)         │                              │
│            └────────────┬─────────────┘                              │
│                         │                                           │
│  PHASE 2                ▼                                           │
│            ┌────────────────────────────┐                            │
│            │ Recommendation HTML Report │                            │
│            │ (prioritized fixes + SQL)  │                            │
│            └────────────┬───────────────┘                            │
│                         │                                           │
│  PHASE 3                ▼                                           │
│            ┌──────────────────────────────┐                          │
│            │ Compliance Evaluation Report │                          │
│            │ (score + gap analysis)       │                          │
│            └──────────────────────────────┘                          │
│                                                                     │
│  All reports → snowflake-performance-optimizer/reports/              │
└─────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Input:** Read-only SQL queries against `SNOWFLAKE.ACCOUNT_USAGE` views with a default 7-day lookback window.
2. **Processing:** Query results are analyzed against defined thresholds and severity rules. Failed queries enter the automatic retry loop.
3. **Output:** Three self-contained HTML reports saved to `snowflake-performance-optimizer/reports/`.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| **Snowflake Role** | `ACCOUNTADMIN` (required for `SNOWFLAKE.ACCOUNT_USAGE` views) |
| **Warehouse** | Any active warehouse (X-SMALL is sufficient for the analysis queries) |
| **Execution Time** | ~5-10 minutes for full analysis |
| **Data Latency** | `ACCOUNT_USAGE` views have up to 45-minute delay |
| **Default Lookback** | 7 days for all queries |
| **Browser** | Any modern browser (Chrome, Firefox, Edge) to render HTML reports |

### Workspace Setup

The skill expects the following directory structure:

```
snowflake-performance-optimizer/
├── SKILL.md                          # Skill definition (do not modify manually)
├── documentation/
│   └── snowflake-performance-optimizer-doc.md  # This file
└── reports/                          # Generated HTML reports land here
    ├── Report-Performance-Assessment-<DD-MM-YYYY>.html
    ├── Report-Performance-Recommendation-<DD-MM-YYYY>.html
    └── Report-Performance-Compliance-<DD-MM-YYYY>.html
```

---

## Quick Start

1. Open Snowsight and navigate to the workspace containing this skill.
2. Ensure you are using the **ACCOUNTADMIN** role (or equivalent with read access to `SNOWFLAKE.ACCOUNT_USAGE`).
3. Invoke the skill by asking Cortex Code:
   > "Run the Snowflake Performance Optimizer"
4. The optimizer executes all 15 queries, applies retry logic for any failures, and generates three HTML reports sequentially.
5. Review the generated reports in `snowflake-performance-optimizer/reports/`.

---

## Trigger Keywords

The skill activates when user input matches any of these topics:

- Performance optimization / performance audit
- Slow queries / query tuning
- Warehouse sizing / warehouse performance
- Clustering strategies / partition pruning
- Query profiling / execution plans
- Performance troubleshooting
- Spillage / memory issues
- Queue time / concurrency
- Cache hit rate
- Query acceleration
- Compilation time

---

## Performance Dimensions

The skill evaluates **six** performance dimensions across every analysis:

### 1. Query Execution

| Metric | Description |
|--------|-------------|
| Query compilation time | Time spent in the cloud services layer creating the execution plan |
| Execution time breakdown | Total elapsed time minus compilation, queuing, and other overhead |
| Bytes scanned vs pruned | Data actually read vs data skipped by partition pruning |
| Spillage to local/remote storage | Memory overflow to SSD (local) or S3/blob (remote) |
| Queue time and concurrency | Time spent waiting for warehouse resources |

### 2. Warehouse Configuration

| Metric | Description |
|--------|-------------|
| Warehouse size selection | Whether the size matches the workload complexity |
| Multi-cluster scaling policies | STANDARD (latency-focused) vs ECONOMY (cost-focused) |
| Auto-suspend and auto-resume | Idle timeout and automatic startup settings |
| Statement timeout and queue timeout | Maximum wait times before cancellation |
| Resource monitors | Credit consumption governance |
| Workload isolation | Separation of ETL, BI, and ad-hoc workloads |

### 3. Data Organization

| Metric | Description |
|--------|-------------|
| Clustering keys | Whether large, frequently filtered tables have appropriate clustering |
| Micro-partition pruning | Efficiency of partition elimination during query execution |
| Search optimization service | Usage and ROI of the search optimization service |
| Materialized views | Pre-computed result sets for repeated aggregations |

### 4. Caching Layers

| Layer | Retention | Description |
|-------|-----------|-------------|
| Result cache | 24 hours | Exact query result reuse (no compute cost) |
| Local disk cache (warehouse) | While warehouse is running | SSD-based table data cache |
| Metadata cache | Persistent | Column stats, row counts, min/max values |

### 5. Query Acceleration Service

| Metric | Description |
|--------|-------------|
| QAS eligibility | Which queries/warehouses would benefit from QAS |
| Scale factor tuning | Optimal scale factor setting (start at 8) |
| Cost vs performance tradeoff | QAS credit consumption vs execution time reduction |

### 6. Query Lifecycle

| Metric | Description |
|--------|-------------|
| Compilation time vs execution time | Queries bottlenecked by SQL complexity, not compute |
| Failed/error query patterns | Recurring errors that waste credits and break pipelines |
| Concurrency and locking | Peak-hour contention and resource competition |

---

## Data Collection — SQL Query Reference

All queries target `SNOWFLAKE.ACCOUNT_USAGE` views with a default **7-day lookback** window.

### Query 1: Slow Query Analysis

**Purpose:** Identify queries exceeding 60 seconds and capture key performance metrics.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`

**Thresholds:** `total_elapsed_time > 60000` (60 seconds in milliseconds)

```sql
SELECT 
    query_id,
    SUBSTR(query_text, 1, 200) AS query_text_preview,
    user_name,
    warehouse_name,
    COALESCE(total_elapsed_time, 0) / 1000 AS elapsed_seconds,
    COALESCE(bytes_scanned, 0) / (1024*1024*1024) AS gb_scanned,
    COALESCE(partitions_scanned, 0) AS partitions_scanned,
    COALESCE(partitions_total, 0) AS partitions_total,
    ROUND(COALESCE(partitions_scanned, 0) / NULLIF(partitions_total, 0) * 100, 2) AS partition_scan_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND total_elapsed_time > 60000
ORDER BY total_elapsed_time DESC
LIMIT 50;
```

**Output Columns:**

| Column | Type | Description |
|--------|------|-------------|
| `query_id` | VARCHAR | Unique query identifier |
| `query_text_preview` | VARCHAR | First 200 characters of the SQL |
| `user_name` | VARCHAR | User who executed the query |
| `warehouse_name` | VARCHAR | Warehouse used for execution |
| `elapsed_seconds` | NUMBER | Total elapsed time in seconds |
| `gb_scanned` | NUMBER | Gigabytes of data scanned |
| `partitions_scanned` | NUMBER | Number of micro-partitions scanned |
| `partitions_total` | NUMBER | Total micro-partitions in the table(s) |
| `partition_scan_pct` | NUMBER | Percentage of partitions scanned |

**Key Insights:** COALESCE wrappers prevent NULL arithmetic errors. NULLIF on `partitions_total` prevents division-by-zero for queries without partition metadata.

---

### Query 2: Spillage Detection

**Purpose:** Find queries with local or remote storage spillage. Remote spillage is flagged as **critical** — it indicates the warehouse is undersized.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`

```sql
SELECT 
    query_id,
    query_text,
    warehouse_name,
    bytes_spilled_to_local_storage / (1024*1024*1024) AS gb_spilled_local,
    bytes_spilled_to_remote_storage / (1024*1024*1024) AS gb_spilled_remote,
    total_elapsed_time / 1000 AS elapsed_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0)
ORDER BY bytes_spilled_to_remote_storage DESC
LIMIT 30;
```

**Severity Rules:**
- `gb_spilled_remote > 0` → **Critical** — warehouse must be upsized
- `gb_spilled_local > 0` only → **Warning** — monitor, may need upsizing for heavy workloads

---

### Query 3: Partition Pruning Efficiency

**Purpose:** Identify queries scanning >50% of partitions on tables with >100 partitions. Poor pruning indicates missing or misaligned clustering keys or missing WHERE filters.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`

```sql
SELECT 
    query_id,
    query_text,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 2) AS scan_percentage,
    bytes_scanned / (1024*1024*1024) AS gb_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND partitions_total > 100
    AND partitions_scanned / NULLIF(partitions_total, 0) > 0.5
ORDER BY partitions_scanned DESC
LIMIT 30;
```

**Severity Rules:**
- `scan_percentage > 80%` → **Critical** — near-full table scan
- `scan_percentage 50-80%` → **Moderate** — pruning is suboptimal

---

### Query 4: Queue Wait Time Analysis

**Purpose:** Detect warehouse congestion patterns and identify peak hours with high queue times.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`

```sql
SELECT 
    warehouse_name,
    DATE_TRUNC('hour', start_time) AS hour,
    COUNT(*) AS query_count,
    AVG(queued_overload_time) / 1000 AS avg_queue_seconds,
    MAX(queued_overload_time) / 1000 AS max_queue_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND queued_overload_time > 0
GROUP BY warehouse_name, DATE_TRUNC('hour', start_time)
HAVING AVG(queued_overload_time) > 1000
ORDER BY hour DESC, avg_queue_seconds DESC;
```

**Thresholds:** Only includes hours where average queue time exceeds 1 second (1000ms). High queue times indicate the warehouse needs more clusters or workload isolation.

---

### Query 5: Warehouse Credit Consumption

**Purpose:** Analyze credit consumption by warehouse and calculate average daily credits.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY`

```sql
SELECT 
    WAREHOUSE_NAME,
    SUM(CREDITS_USED) AS TOTAL_CREDITS,
    COUNT(DISTINCT DATE_TRUNC('day', START_TIME)) AS ACTIVE_DAYS,
    SUM(CREDITS_USED) / NULLIF(COUNT(DISTINCT DATE_TRUNC('day', START_TIME)), 0) AS AVG_DAILY_CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE START_TIME >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY WAREHOUSE_NAME
ORDER BY TOTAL_CREDITS DESC
LIMIT 20;
```

**Key Insight:** `AVG_DAILY_CREDITS` is calculated only across active days (not calendar days), providing a more accurate measure of per-day consumption when a warehouse is used intermittently.

---

### Query 6: User Activity Analysis

**Purpose:** Summarize query counts by user and identify users with high data scan volumes or remote spillage.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`

```sql
SELECT 
    USER_NAME,
    COUNT(*) AS QUERY_COUNT,
    AVG(TOTAL_ELAPSED_TIME) / 1000 AS AVG_ELAPSED_SEC,
    SUM(BYTES_SCANNED) / (1024*1024*1024) AS TOTAL_GB_SCANNED,
    SUM(CASE WHEN BYTES_SPILLED_TO_REMOTE_STORAGE > 0 THEN 1 ELSE 0 END) AS REMOTE_SPILL_COUNT
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY USER_NAME
ORDER BY QUERY_COUNT DESC
LIMIT 20;
```

**Use Cases:** Identify automated service accounts vs interactive users, flag users causing disproportionate remote spillage, track scan volume for cost attribution.

---

### Query 7: Large Table Clustering Assessment

**Purpose:** Find tables >1GB with >1M rows and review their clustering status. Prioritize tables >10GB for clustering review.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.TABLES`

```sql
SELECT 
    TABLE_CATALOG,
    TABLE_SCHEMA,
    TABLE_NAME,
    CLUSTERING_KEY,
    ROW_COUNT,
    BYTES / (1024*1024*1024) AS SIZE_GB
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
WHERE DELETED IS NULL
    AND ROW_COUNT > 1000000
    AND BYTES > 1073741824
ORDER BY BYTES DESC
LIMIT 30;
```

**Assessment Rules:**
- `SIZE_GB > 10` and `CLUSTERING_KEY IS NULL` → Strong candidate for clustering
- `SIZE_GB 1-10` and `CLUSTERING_KEY IS NULL` → Review query patterns before clustering
- `CLUSTERING_KEY IS NOT NULL` → Verify clustering key aligns with common filter columns

---

### Query 8: Warehouse Utilization Patterns

**Purpose:** Analyze hourly query volume and average execution time per warehouse to understand workload distribution.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`

```sql
SELECT 
    warehouse_name,
    DATE_TRUNC('hour', start_time) AS hour,
    COUNT(*) AS query_count,
    AVG(total_elapsed_time) / 1000 AS avg_elapsed_seconds,
    SUM(credits_used_cloud_services) AS cloud_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name, DATE_TRUNC('hour', start_time)
ORDER BY hour DESC, query_count DESC;
```

---

### Query 9: QAS Eligibility (Per Query)

**Purpose:** Identify individual queries that would benefit most from the Query Acceleration Service.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_ACCELERATION_ELIGIBLE`

```sql
SELECT 
    query_id,
    warehouse_name,
    eligible_query_acceleration_time / 1000 AS eligible_acceleration_sec,
    upper_limit_scale_factor
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ACCELERATION_ELIGIBLE
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY eligible_query_acceleration_time DESC
LIMIT 30;
```

**Key Columns:**
- `eligible_acceleration_sec` — How many seconds of execution time QAS could save
- `upper_limit_scale_factor` — The maximum useful scale factor for this query

**Decision Rules:**
- Queries with `eligible_acceleration_sec > 10` are strong candidates for QAS.
- If `upper_limit_scale_factor <= 8`, a scale factor of 8 is recommended as the starting point.
- If the query already runs under 5 seconds, QAS overhead may not be worthwhile.

---

### Query 10: QAS Eligibility (Per Warehouse)

**Purpose:** Aggregate QAS eligibility by warehouse to determine where enabling QAS would have the most impact.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_ACCELERATION_ELIGIBLE`

```sql
SELECT 
    warehouse_name,
    COUNT(query_id) AS num_eligible_queries,
    SUM(eligible_query_acceleration_time) / 1000 AS total_eligible_sec
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ACCELERATION_ELIGIBLE
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_eligible_sec DESC;
```

**Decision Rule:** Warehouses with `total_eligible_sec > 300` (5 minutes) are strong candidates for enabling QAS.

**Enabling QAS:**
```sql
ALTER WAREHOUSE <warehouse_name> SET ENABLE_QUERY_ACCELERATION = TRUE;
ALTER WAREHOUSE <warehouse_name> SET QUERY_ACCELERATION_MAX_SCALE_FACTOR = 8;
```

---

### Query 11: Cache Hit Rate Analysis

**Purpose:** Measure the percentage of data scanned from warehouse cache vs remote storage per warehouse. Low cache hit rates indicate frequent cold starts or mismatched auto-suspend settings.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`

```sql
SELECT 
    warehouse_name,
    COUNT(*) AS query_count,
    SUM(bytes_scanned) / (1024*1024*1024) AS total_gb_scanned,
    ROUND(SUM(bytes_scanned * percentage_scanned_from_cache) / NULLIF(SUM(bytes_scanned), 0) * 100, 2) AS cache_hit_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND bytes_scanned > 0
GROUP BY warehouse_name
ORDER BY cache_hit_pct ASC;
```

**Assessment Rules:**
- `cache_hit_pct < 10%` → Auto-suspend may be too aggressive for BI/interactive workloads; consider extending to 300-600 seconds
- `cache_hit_pct > 50%` → Cache is working well
- `cache_hit_pct = 0%` → Warehouse is likely suspending between every query

**Auto-Suspend Guidelines by Workload:**

| Workload Type | Recommended Auto-Suspend | Rationale |
|--------------|--------------------------|-----------|
| Tasks / ETL | 60 seconds (immediate) | Batch jobs; cache not beneficial |
| DevOps / Data Science | ~300 seconds (5 min) | Ad-hoc queries; cache moderately useful |
| BI / SELECT workloads | 600+ seconds (10+ min) | Repeated queries; cache is critical |

---

### Query 12: Compilation vs Execution Time

**Purpose:** Identify queries where compilation time exceeds execution time, indicating SQL complexity bottlenecks. **Warehouse upsizing will NOT help** — compilation runs in the cloud services layer, not the warehouse.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`

```sql
SELECT 
    query_id,
    SUBSTR(query_text, 1, 200) AS query_text_preview,
    user_name,
    warehouse_name,
    compilation_time / 1000 AS compile_sec,
    execution_time / 1000 AS exec_sec,
    total_elapsed_time / 1000 AS total_sec,
    ROUND(compilation_time / NULLIF(total_elapsed_time, 0) * 100, 2) AS compile_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND compilation_time > execution_time
    AND total_elapsed_time > 5000
ORDER BY compilation_time DESC
LIMIT 30;
```

**Thresholds:** Only includes queries where total elapsed time > 5 seconds AND compilation time exceeds execution time.

**Common Root Causes:**
- Too many tables/columns referenced in a single query
- Complex joins with many predicates
- Deep UDF nesting or recursive CTEs
- Wide tables with hundreds of columns in SELECT

**Fixes:** Break complex queries into CTEs or temporary tables; reduce the number of columns selected; simplify join conditions.

---

### Query 13: Failed and Error Query Analysis

**Purpose:** Track query failures and errors to identify broken pipelines, permission issues, or recurring bad SQL patterns.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`

```sql
SELECT 
    error_code,
    error_message,
    COUNT(*) AS error_count,
    COUNT(DISTINCT user_name) AS affected_users,
    MIN(start_time) AS first_occurrence,
    MAX(start_time) AS last_occurrence
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND execution_status = 'FAIL'
GROUP BY error_code, error_message
ORDER BY error_count DESC
LIMIT 20;
```

**Use Cases:**
- Detect recurring errors that waste warehouse credits
- Identify permission issues affecting multiple users
- Track broken scheduled tasks or pipelines
- Prioritize error remediation by frequency and affected user count

---

### Query 14: Warehouse Configuration Audit

**Purpose:** Review all warehouse settings to identify misconfigurations that waste credits or cause performance issues.

**Data Source:** `SHOW WAREHOUSES` command

```sql
SHOW WAREHOUSES;
```

**Post-Query Assessment Rules:**

| Condition | Flag | Risk |
|-----------|------|------|
| Auto-suspend > 600s on non-BI warehouses | Credit waste | Idle warehouse consuming credits |
| Auto-resume = FALSE | Manual intervention required | Queries fail if warehouse is suspended |
| STANDARD scaling policy on cost-focused workloads | Overspending on scaling | ECONOMY is cheaper for non-latency-sensitive work |
| X-SMALL with detected spillage | Undersized | Queries spilling to storage |
| X-LARGE+ with <10 queries/day | Oversized | Paying for unused compute capacity |

---

### Query 15: Concurrency and Peak Load Analysis

**Purpose:** Identify hours with the highest concurrent query load to detect contention periods and inform multi-cluster or workload isolation decisions.

**Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`

```sql
SELECT 
    warehouse_name,
    DATE_TRUNC('hour', start_time) AS hour,
    COUNT(*) AS total_queries,
    COUNT(DISTINCT user_name) AS distinct_users,
    AVG(total_elapsed_time) / 1000 AS avg_elapsed_sec,
    MAX(total_elapsed_time) / 1000 AS max_elapsed_sec,
    SUM(CASE WHEN queued_overload_time > 0 THEN 1 ELSE 0 END) AS queued_queries
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND warehouse_name IS NOT NULL
GROUP BY warehouse_name, DATE_TRUNC('hour', start_time)
HAVING COUNT(*) > 10
ORDER BY total_queries DESC
LIMIT 30;
```

**Thresholds:** Only includes hours with more than 10 queries to filter out low-activity noise.

**Decision Rules:**
- `queued_queries / total_queries > 20%` → Significant contention; consider multi-cluster scaling
- `distinct_users > 5` with queuing → Multiple users competing; consider workload isolation

---

## Automatic Retry Logic

If any query fails during analysis, the skill applies corrective fixes before retrying:

| Error Type | Corrective Action |
|------------|-------------------|
| **Timeout** | Reduce date range to 3 days: `DATEADD(day, -3, CURRENT_TIMESTAMP())`, add LIMIT clause |
| **Permission denied** | Switch to ACCOUNTADMIN role or grant monitor privileges |
| **Column not found** | Verify column names in INFORMATION_SCHEMA |
| **Division by zero** | Use `NULLIF()` for divisor columns |
| **No data returned** | Relax filter thresholds or expand date range |

**Retry Flow:**
```
Query Fails ──► Diagnose Error Type ──► Apply Fix ──► Retry Query
                                                          │
                                           ┌──────────────┤
                                           ▼              ▼
                                        Success     Still Failing
                                           │              │
                                    Continue Flow   Log as SKIPPED
                                                   in report
```

If a query is ultimately skipped, it is flagged in the Assessment Report with the error details, enabling manual follow-up.

---

## Optimization Checklists

### Query Optimization

- [ ] Use EXPLAIN PLAN to analyze query execution
- [ ] Add WHERE filters to reduce partition scanning
- [ ] Avoid SELECT * — specify needed columns
- [ ] Use LIMIT during development/testing
- [ ] Optimize JOINs (filter before joining)
- [ ] Replace correlated subqueries with JOINs

### Clustering Strategy

- [ ] Identify tables > 1TB with frequent range queries
- [ ] Choose clustering keys based on filter columns
- [ ] Monitor clustering depth with `SYSTEM$CLUSTERING_INFORMATION`
- [ ] Avoid over-clustering (increases maintenance costs)

### Warehouse Sizing

- [ ] Start with X-SMALL, scale up if spillage occurs
- [ ] Use larger warehouses for complex queries, not more concurrency
- [ ] Enable multi-cluster for concurrency scaling
- [ ] Match warehouse size to workload type

### Caching Optimization

- [ ] Structure queries consistently to hit result cache
- [ ] Keep warehouses running for frequently accessed data
- [ ] Use materialized views for repeated aggregations

### Query Acceleration Service

- [ ] Run QAS eligibility analysis to find candidate queries
- [ ] Enable QAS on warehouses with high eligible acceleration time
- [ ] Set appropriate scale factor (start with 8, tune based on results)
- [ ] Monitor QAS credit consumption vs performance gain

### Warehouse Configuration Audit

- [ ] Review auto-suspend settings per workload type (60s for ETL, 300s+ for BI)
- [ ] Verify auto-resume is enabled on all warehouses
- [ ] Check scaling policy (STANDARD for latency, ECONOMY for cost)
- [ ] Audit MAX_CONCURRENCY_LEVEL settings
- [ ] Set STATEMENT_QUEUED_TIMEOUT_IN_SECONDS to avoid infinite queueing

### Query Health Monitoring

- [ ] Track recurring query failures and error codes
- [ ] Identify queries with compilation time > execution time
- [ ] Monitor cache hit rates per warehouse
- [ ] Review concurrency peaks and plan workload isolation

---

## Performance Red Flags

| Issue | Indicator | Severity | Solution |
|-------|-----------|----------|----------|
| Remote spillage | `bytes_spilled_to_remote_storage > 0` | Critical | Increase warehouse size |
| Full table scans | `partition_scan_pct > 80%` | Critical | Add clustering keys or WHERE filters |
| No network policy | Queue times consistently > 5s | High | Add clusters or separate workloads |
| Queue delays | `queued_overload_time > 5s` | High | Add clusters or separate workloads |
| High compilation time | `compilation_time > execution_time` | High | Simplify SQL, reduce joins/columns, avoid deep UDF nesting |
| Query failures | `execution_status = 'FAIL'` recurring | High | Fix broken SQL, check permissions, repair pipelines |
| Low cache hit rate | `percentage_scanned_from_cache < 10%` | Medium | Extend auto-suspend for BI warehouses to 300-600s |
| QAS eligible but disabled | `eligible_query_acceleration_time > 0` | Medium | Enable QAS: `ALTER WAREHOUSE SET ENABLE_QUERY_ACCELERATION = TRUE` |
| High concurrency + queuing | `queued_queries > 20%` of total in peak hour | High | Enable multi-cluster scaling or isolate workloads |
| No result cache | Result cache not being hit | Medium | Standardize query patterns for cache reuse |

---

## Finding Severity and Priority Matrix

Performance findings are mapped to priorities with recommended timelines:

| Finding | Severity | Effort | Priority | Timeline |
|---------|----------|--------|----------|----------|
| Remote spillage (warehouse undersized) | Critical | Low | P0 | Immediate |
| Full table scans (>80% partitions) | Critical | Medium | P0 | Immediate |
| Recurring query failures (broken pipelines) | High | Low | P1 | Within 24 hours |
| Queue wait times > 5s sustained | High | Medium | P1 | Within 24 hours |
| Compilation > execution time | High | Medium | P1 | Within 7 days |
| Oversized warehouses (X-LARGE+ with <10 queries/day) | High | Low | P1 | Within 7 days |
| Auto-suspend > 600s on ETL warehouses | Medium | Low | P2 | Within 14 days |
| Cache hit rate < 10% | Medium | Low | P2 | Within 14 days |
| Large tables (>10GB) without clustering keys | Medium | Medium | P2 | Within 30 days |
| QAS eligible but not enabled | Medium | Low | P2 | Within 30 days |
| Auto-resume = FALSE | Medium | Low | P2 | Within 7 days |
| STANDARD scaling on cost-focused workloads | Low | Low | P3 | Within 30 days |
| Direct user grants instead of roles (query-related) | Low | Medium | P3 | Within 90 days |
| Tables 1-10GB without clustering review | Low | Low | P3 | Within 90 days |

---

## Recommended Actions

| # | Action | Detail |
|---|--------|--------|
| 1 | **Profile First** | Use Query Profile in Snowsight to visualize bottlenecks |
| 2 | **Check Pruning** | Ensure WHERE clauses align with clustering keys |
| 3 | **Right-Size** | Match warehouse size to query complexity, not volume |
| 4 | **Isolate Workloads** | Separate ETL, BI, and ad-hoc into different warehouses |
| 5 | **Monitor Trends** | Set up alerts for queue time and spillage patterns |
| 6 | **Enable QAS** | For eligible queries, enable Query Acceleration Service before upsizing warehouse |
| 7 | **Tune Auto-Suspend** | Balance cache retention (BI: 300-600s) vs credit savings (ETL: 60s) |
| 8 | **Fix Failures First** | Recurring query errors waste credits and mask real performance issues |
| 9 | **Simplify High-Compile Queries** | Break complex SQL into CTEs or temp tables to reduce compilation overhead |
| 10 | **Review Concurrency** | Use MAX_CONCURRENCY_LEVEL and multi-cluster scaling to manage peak loads |

---

## Report Generation

The skill generates **three** HTML reports in strict sequential order. Each report builds on the previous one.

### Report 1: Performance Assessment

| Property | Value |
|----------|-------|
| **Filename** | `Report-Performance-Assessment-DD-MM-YYYY.html` |
| **Location** | `snowflake-performance-optimizer/reports/` |
| **Content** | Assessment results ONLY — no recommendations |

**Required Sections:**
- Executive Summary with key metrics
- Warehouse Performance Assessment (credit consumption, utilization)
- Query Performance Assessment (by type, by user)
- Cache Hit Rate Assessment (per warehouse)
- Compilation Time Assessment (high-compile queries)
- Query Acceleration Service Eligibility
- Data Storage Assessment (large tables, clustering status)
- Partition Pruning Assessment (inefficient queries)
- Spillage Assessment (memory issues)
- Failed Query Assessment (error patterns)
- Warehouse Configuration Audit (auto-suspend, scaling, sizing)
- Concurrency Assessment (peak load hours)
- Key Findings Summary

### Report 2: Performance Recommendations

| Property | Value |
|----------|-------|
| **Filename** | `Report-Performance-Recommendation-DD-MM-YYYY.html` |
| **Location** | `snowflake-performance-optimizer/reports/` |
| **Content** | Actionable recommendations derived from Assessment |

**Required Sections:**
- Recommendation Summary (count by priority)
- High Priority Recommendations (with SQL fixes)
- Medium Priority Recommendations
- Low Priority Recommendations
- Implementation Roadmap (weekly schedule)
- Estimated savings/impact metrics

### Report 3: Compliance Evaluation

| Property | Value |
|----------|-------|
| **Filename** | `Report-Performance-Compliance-DD-MM-YYYY.html` |
| **Location** | `snowflake-performance-optimizer/reports/` |
| **Content** | Compliance status against recommendations |

**Required Sections:**
- Overall Compliance Score (percentage)
- Compliance by Recommendation (table with status badges)
- Best Practices Checklist (pass/fail indicators)
- Cross-Reference Matrix (assessment → recommendation mapping)
- Required Actions for Full Compliance
- Report References

### Report Dependencies and Flow

```
Phase 1: Live Snowflake Data ──► Assessment Report
                                        │
Phase 2: Assessment Findings ──► Recommendation Report
                                        │
Phase 3: Assessment + Recommendations ──► Compliance Report
```

| Order | Report | Input | Output |
|-------|--------|-------|--------|
| 1st | Assessment | Live ACCOUNT_USAGE queries | Findings with severity ratings |
| 2nd | Recommendations | Assessment findings | Prioritized fix plan with SQL |
| 3rd | Compliance | Assessment + Recommendations | Compliance score and gap analysis |

### HTML Report Requirements

| Requirement | Description |
|-------------|-------------|
| Professional styling | Clean CSS with consistent design |
| Color-coded badges | Green (good), Yellow (warning), Red (critical) |
| Responsive tables | Hover effects and readable column widths |
| Section headers | Clear navigation between report sections |
| Footer metadata | Generation timestamp, account name, role used |
| Data accuracy | All metrics derived from actual query results |
| Freshness indicators | Row counts and data latency notes |
| Finding-to-recommendation mapping | Every finding links to a specific recommendation with SQL fix and estimated impact |

---

## Execution Checklist

The complete checklist for a full skill run:

- [ ] Executed all 15 analysis queries (Queries 1-15, with QAS split into per-query and per-warehouse)
- [ ] Applied retry logic for any failed queries
- [ ] Generated Assessment Report (findings only, no recommendations)
- [ ] Generated Recommendation Report (derived from assessment)
- [ ] Generated Compliance Report (references both previous reports)
- [ ] Validated all 3 reports are saved in `snowflake-performance-optimizer/reports/` folder

---

## Data Sources

All queries are read-only and target the following Snowflake system views:

| View / Command | Queries Used In | Purpose |
|----------------|----------------|---------|
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` | Q1, Q2, Q3, Q4, Q6, Q8, Q11, Q12, Q13, Q15 | Query execution metadata, timing, spillage, partitions, errors, concurrency |
| `SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY` | Q5 | Credit consumption by warehouse |
| `SNOWFLAKE.ACCOUNT_USAGE.TABLES` | Q7 | Table metadata, row counts, sizes, clustering keys |
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_ACCELERATION_ELIGIBLE` | Q9, Q10 | QAS eligibility per query and per warehouse |
| `SHOW WAREHOUSES` | Q14 | Warehouse configuration (size, auto-suspend, scaling policy, auto-resume) |

**Note:** `SNOWFLAKE.ACCOUNT_USAGE` views have a latency of up to 45 minutes. Results reflect data available at query time, not real-time state. Very recent queries may not yet appear.

---

## Post-Run Monitoring

After reviewing the reports and applying recommended changes, set up ongoing monitoring:

### Scheduled Performance Check

```sql
CREATE OR REPLACE TASK performance_monitoring_weekly
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 9 * * 1 UTC'
AS BEGIN END;
```

### Key Metrics to Track Weekly

| Metric | Target | Alert If |
|--------|--------|----------|
| Remote spillage count | 0 | Any query spills to remote storage |
| Average queue wait time | < 1 second | Sustained > 5 seconds during business hours |
| Cache hit rate (BI warehouses) | > 50% | Drops below 10% |
| Failed query count | Decreasing trend | Spike of > 20% week-over-week |
| QAS savings (if enabled) | Positive ROI | Credit cost > time savings value |
| Partition scan efficiency | < 50% avg scan pct | > 80% scan pct on large tables |

### Recommended Re-Run Cadence

| Scenario | Recommended Frequency |
|----------|-----------------------|
| Active development with frequent schema/workload changes | Weekly |
| Stable production environment | Monthly |
| After major warehouse resizing or clustering changes | On-demand (immediately after) |
| After onboarding new teams or workloads | On-demand |
| Pre-budget planning (cost optimization) | Quarterly |

---

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| Permission errors on ACCOUNT_USAGE views | Insufficient role privileges | Switch to `ACCOUNTADMIN` role |
| Query returns 0 rows | No matching activity in the last 7 days | Expand date range to 14 or 30 days via retry logic |
| `QUERY_ACCELERATION_ELIGIBLE` view not found | QAS not enabled or view not available in account | Log as SKIPPED; does not affect other queries |
| Division by zero in partition scan query | `partitions_total` is 0 | Already handled by `NULLIF(partitions_total, 0)` |
| `SHOW WAREHOUSES` returns no results | No warehouses exist or insufficient privileges | Verify role has USAGE on at least one warehouse |
| High compilation time queries not found | No queries exceed the 5-second + compile > exec threshold | Expected for simple workloads; report as "No issues" |
| Reports not appearing in expected folder | Path mismatch | Verify reports are in `snowflake-performance-optimizer/reports/` |
| HTML reports look broken in browser | Browser compatibility | Use a modern browser (Chrome, Firefox, Edge) |
| Elapsed time metrics seem off | `ACCOUNT_USAGE` latency (up to 45 minutes) | Recent queries may not yet appear; note latency in report |
| Cache hit rate shows 0% for all warehouses | All warehouses auto-suspend immediately; no cache retained | Flag in assessment; recommend extending auto-suspend for BI workloads |

---

## Frequently Asked Questions

### Q: Do I need ACCOUNTADMIN to run the optimizer?

**A:** Yes, ACCOUNTADMIN is required for full access to `SNOWFLAKE.ACCOUNT_USAGE` views. A custom role with `IMPORTED PRIVILEGES` on the `SNOWFLAKE` database may work for most queries, but `SHOW WAREHOUSES` and some views may require higher privileges.

### Q: Will the optimizer make any changes to my account?

**A:** No. The optimizer is strictly read-only. It executes `SELECT` queries and `SHOW` commands only. All recommended SQL (ALTER WAREHOUSE, clustering, etc.) is provided as documentation — it is never executed automatically.

### Q: How long does a full performance audit take?

**A:** Typically 5–10 minutes depending on account size, query history volume, and warehouse availability. The 15 analysis queries run sequentially, and HTML report generation adds a few seconds per report.

### Q: What happens if a query fails during the audit?

**A:** The automatic retry logic diagnoses the error (timeout, permission, column not found, division by zero, no data), applies a corrective fix, and retries. If recovery fails, the query is marked as SKIPPED in the report with the error details.

### Q: Can I run individual queries instead of the full audit?

**A:** Yes. Each of the 15 queries is self-contained and can be executed independently. You can ask Cortex Code to run a specific query category (e.g., "Run only the spillage detection query").

### Q: What is the default lookback window?

**A:** 7 days for all queries. If queries return no data, the retry logic may expand the window to 14 or 30 days. You can also request a custom lookback window when invoking the skill.

### Q: How does the optimizer handle the 45-minute ACCOUNT_USAGE latency?

**A:** The optimizer notes this latency in reports. Very recent queries (last 45 minutes) may not appear in results. For real-time diagnostics, use `INFORMATION_SCHEMA.QUERY_HISTORY()` table function directly.

### Q: What is the difference between local and remote spillage?

**A:** Local spillage writes to the warehouse's SSD cache — it's a warning that the query is close to the memory limit. Remote spillage writes to cloud storage (S3/Azure Blob/GCS) — it's critical and means the warehouse is definitively undersized for that query. Remote spillage has a much larger performance impact.

### Q: Should I upsize the warehouse or enable QAS first?

**A:** Check QAS eligibility first (Queries 9-10). If a query is QAS-eligible, enabling QAS is cheaper and faster to implement than upsizing. Upsize only for queries with remote spillage or where QAS is not applicable. QAS works best for queries with selective filters on large datasets.

### Q: How does the Compliance Evaluation score work?

**A:** The compliance score is a percentage reflecting how many of the recommended optimizations have been implemented. It cross-references Assessment findings with Recommendations to produce a gap analysis. A score of 100% means all recommendations have been addressed.

### Q: Where are the reports saved?

**A:** All HTML reports are saved to `snowflake-performance-optimizer/reports/` in the workspace. File names include the execution date (DD-MM-YYYY format) for version tracking.

### Q: How often should I run the optimizer?

**A:** Recommended cadence:
- **Weekly:** For accounts with active development and frequent workload changes
- **Monthly:** For stable production accounts
- **On-demand:** After major changes (warehouse resizing, new clustering, team onboarding)
- **Quarterly:** For cost optimization and budget planning
