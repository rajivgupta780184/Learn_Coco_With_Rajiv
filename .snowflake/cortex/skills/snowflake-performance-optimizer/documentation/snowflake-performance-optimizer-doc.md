# Snowflake Performance Optimizer — Skill Documentation

**Skill Name:** `snowflake-performance-optimizer`
**File:** `SKILL.md`
**Last Updated:** April 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Purpose and Use Cases](#purpose-and-use-cases)
3. [Prerequisites](#prerequisites)
4. [Trigger Keywords](#trigger-keywords)
5. [Performance Dimensions](#performance-dimensions)
6. [Data Collection — SQL Query Reference](#data-collection--sql-query-reference)
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
7. [Automatic Retry Logic](#automatic-retry-logic)
8. [Optimization Checklists](#optimization-checklists)
9. [Performance Red Flags](#performance-red-flags)
10. [Recommended Actions](#recommended-actions)
11. [Report Generation](#report-generation)
    - [Report 1: Performance Assessment](#report-1-performance-assessment)
    - [Report 2: Performance Recommendations](#report-2-performance-recommendations)
    - [Report 3: Compliance Evaluation](#report-3-compliance-evaluation)
    - [Report Dependencies and Flow](#report-dependencies-and-flow)
    - [HTML Report Requirements](#html-report-requirements)
12. [Execution Checklist](#execution-checklist)
13. [Troubleshooting](#troubleshooting)

---

## Overview

The **Snowflake Performance Optimizer** is a Cortex Code skill that performs a comprehensive performance audit of a Snowflake account. It executes 14 analysis query categories against `SNOWFLAKE.ACCOUNT_USAGE` views, covering query execution, warehouse configuration, data organization, caching, query acceleration, query lifecycle health, and concurrency.

The skill produces three HTML reports — an Assessment, a Recommendation plan, and a Compliance Evaluation — all saved to `snowflake-performance-optimizer/reports/`.

All analysis is **read-only**. No DDL, DML, or configuration changes are executed. All metrics are derived from actual query results — no sample or dummy data is used.

---

## Purpose and Use Cases

| Use Case | Description |
|----------|-------------|
| **Full Performance Audit** | Run all 14 query categories to get a complete account health snapshot |
| **Slow Query Investigation** | Identify queries exceeding 60 seconds and diagnose root causes |
| **Warehouse Right-Sizing** | Detect spillage patterns that indicate undersized warehouses |
| **Clustering Review** | Find large tables (>1GB) that may benefit from clustering keys |
| **Cache Optimization** | Measure cache hit rates and tune auto-suspend settings per workload |
| **QAS Assessment** | Identify queries eligible for Query Acceleration Service before upsizing |
| **Concurrency Planning** | Detect peak-hour contention and plan multi-cluster or workload isolation |
| **Error Pattern Detection** | Track recurring query failures to fix broken pipelines early |
| **Compilation Bottlenecks** | Find queries where SQL complexity (not compute) is the bottleneck |
| **Executive Reporting** | Generate stakeholder-ready HTML reports with compliance scores |

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| **Snowflake Role** | `ACCOUNTADMIN` (required for `SNOWFLAKE.ACCOUNT_USAGE` views) |
| **Warehouse** | Any active warehouse (X-SMALL is sufficient) |
| **Execution Time** | ~5-10 minutes for full analysis |
| **Data Latency** | `ACCOUNT_USAGE` views have up to 45-minute delay |
| **Default Lookback** | 7 days for all queries |
| **Browser** | Any modern browser to render generated HTML reports |

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

**Key Insight:** `AVG_DAILY_CREDITS` is calculated only across active days (not calendar days), providing a more accurate measure of per-day consumption when a warehouse is used.

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

| Issue | Indicator | Solution |
|-------|-----------|----------|
| Remote spillage | `bytes_spilled_to_remote_storage > 0` | Increase warehouse size |
| Full table scans | `partition_scan_pct > 80%` | Add clustering keys or WHERE filters |
| Queue delays | `queued_overload_time > 5s` | Add clusters or separate workloads |
| No result cache | Result cache not being hit | Standardize query patterns for cache reuse |
| High compilation time | `compilation_time > execution_time` | Simplify SQL, reduce joins/columns, avoid deep UDF nesting |
| Query failures | `execution_status = 'FAIL'` recurring | Fix broken SQL, check permissions, repair pipelines |
| Low cache hit rate | `percentage_scanned_from_cache < 10%` | Extend auto-suspend for BI warehouses to 300-600s |
| QAS eligible but disabled | `eligible_query_acceleration_time > 0` | Enable QAS: `ALTER WAREHOUSE SET ENABLE_QUERY_ACCELERATION = TRUE` |
| High concurrency + queuing | `queued_queries > 20%` of total in peak hour | Enable multi-cluster scaling or isolate workloads |

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

- [ ] Executed all 14 analysis query categories (Queries 1-15, with QAS split into per-query and per-warehouse)
- [ ] Applied retry logic for any failed queries
- [ ] Generated Assessment Report (findings only, no recommendations)
- [ ] Generated Recommendation Report (derived from assessment)
- [ ] Generated Compliance Report (references both previous reports)
- [ ] Validated all 3 reports are saved in `snowflake-performance-optimizer/reports/` folder

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
