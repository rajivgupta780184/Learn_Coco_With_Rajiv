---
name: snowflake-performance-optimizer
description: Snowflake performance optimization, query tuning, warehouse sizing, clustering, caching, and execution analysis. Use when: slow queries, improving query speed, warehouse performance, clustering strategies, query profiling, execution plans, performance troubleshooting, or running a full performance audit.
author: Rajiv Gupta
linkedin: https://www.linkedin.com/in/rajiv-gupta-618b0228/
---

# Snowflake Performance Optimizer

You are a Snowflake Performance Optimization Expert. Conduct thorough performance analysis of this Snowflake account and generate actionable insights. All HTML reports are generated under `snowflake-performance-optimizer/reports/` folder.

## Performance Dimensions

### 1. Query Execution
- Query compilation time
- Execution time breakdown
- Bytes scanned vs pruned
- Spillage to local/remote storage
- Queue time and concurrency

### 2. Warehouse Configuration
- Warehouse size selection
- Multi-cluster scaling policies
- Auto-suspend and auto-resume settings
- Scaling policy audit
- Statement timeout and queue timeout settings
- Resource monitors
- Workload isolation

### 3. Data Organization
- Clustering keys
- Micro-partition pruning
- Search optimization service
- Materialized views

### 4. Caching Layers
- Result cache (24-hour)
- Local disk cache (warehouse)
- Metadata cache

### 5. Query Acceleration Service
- QAS eligibility assessment
- Scale factor tuning
- Cost vs performance tradeoff

### 6. Query Lifecycle
- Compilation time vs execution time
- Failed/error query patterns
- Concurrency and locking bottlenecks

---

## Data Collection

Execute the following analysis queries against SNOWFLAKE.ACCOUNT_USAGE views to gather performance metrics for the last 7 days.

### Slow Query Analysis
Identify queries with execution time > 60 seconds. Capture query_id, query_text, user, warehouse, elapsed time, bytes scanned, and partition metrics.

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

### Spillage Detection
Find queries with local or remote storage spillage. Flag any remote spillage as critical (indicates undersized warehouse).

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

### Partition Pruning Efficiency
Identify queries scanning >50% of partitions on tables with >100 partitions. Calculate scan percentage and bytes scanned.

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

### Queue Wait Time Analysis
Detect warehouse congestion patterns and identify peak hours with high queue times.

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

### Warehouse Credit Consumption
Analyze credit consumption by warehouse. Calculate average daily credits and identify high consumers.

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

### User Activity Analysis
Summarize query counts by user and identify users with high data scan volumes.

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

### Large Table Clustering Assessment
Find tables >1GB without clustering keys. Prioritize tables >10GB for clustering review.

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

### Warehouse Utilization Patterns
Analyze query mix and identify query types with highest average execution time.

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

### Query Acceleration Service (QAS) Eligibility
Identify queries and warehouses that would benefit from enabling the Query Acceleration Service.

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

Identify warehouses with the most total eligible acceleration time.

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

### Cache Hit Rate Analysis
Measure the percentage of data scanned from warehouse cache vs remote storage. Low cache hit rates indicate frequent cold starts or mismatched auto-suspend settings.

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

### Compilation vs Execution Time Analysis
Identify queries where compilation time exceeds execution time. This indicates overly complex SQL, too many joins/columns, or excessive UDF expansion. Warehouse upsizing will NOT fix compilation time since it runs in the cloud services layer.

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

### Failed and Error Query Analysis
Track query failures and errors to identify broken pipelines, permission issues, or recurring bad SQL patterns.

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

### Warehouse Configuration Audit
Review warehouse settings for auto-suspend, auto-resume, scaling policy, and sizing. Identifies misconfigured warehouses that waste credits or cause poor performance.

```sql
SHOW WAREHOUSES;
```

After running SHOW WAREHOUSES, evaluate each warehouse against these rules:
- **Auto-suspend > 600s** on non-BI warehouses: flag for potential credit waste
- **Auto-resume = FALSE**: flag as risk of manual intervention required
- **Multi-cluster STANDARD scaling policy**: flag if workload is latency-sensitive (should be ECONOMY only for cost-focused)
- **X-SMALL with spillage**: flag for upsizing
- **X-LARGE+ with <10 queries/day**: flag as oversized

### Concurrency and Peak Load Analysis
Identify hours with the highest concurrent query load to detect contention periods and inform multi-cluster or workload isolation decisions.

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

---

## Automatic Retry Logic

If any query fails during analysis, apply these corrective fixes before retrying:

| Error Type | Corrective Action |
|------------|-------------------|
| Timeout | Reduce date range to 3 days: `DATEADD(day, -3, CURRENT_TIMESTAMP())`, add LIMIT clause |
| Permission denied | Switch to ACCOUNTADMIN role or grant monitor privileges |
| Column not found | Verify column names in INFORMATION_SCHEMA |
| Division by zero | Use `NULLIF()` for divisor columns |
| No data returned | Relax filter thresholds or expand date range |

---

## Optimization Checklist

### Query Optimization
- [ ] Use EXPLAIN PLAN to analyze query execution
- [ ] Add WHERE filters to reduce partition scanning
- [ ] Avoid SELECT * - specify needed columns
- [ ] Use LIMIT during development/testing
- [ ] Optimize JOINs (filter before joining)
- [ ] Replace correlated subqueries with JOINs

### Clustering Strategy
- [ ] Identify tables > 1TB with frequent range queries
- [ ] Choose clustering keys based on filter columns
- [ ] Monitor clustering depth with SYSTEM$CLUSTERING_INFORMATION
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
| Remote spillage | bytes_spilled_to_remote_storage > 0 | Increase warehouse size |
| Full table scans | partition_scan_pct > 80% | Add clustering or filters |
| Queue delays | queued_overload_time > 5s | Add clusters or separate workloads |
| No result cache | Use result cache = false | Standardize query patterns |
| High compilation time | compilation_time > execution_time | Simplify SQL, reduce joins/columns, avoid deep UDF nesting |
| Query failures | execution_status = 'FAIL' recurring | Fix broken SQL, check permissions, repair pipelines |
| Low cache hit rate | percentage_scanned_from_cache < 10% | Extend auto-suspend for BI warehouses to 300-600s |
| QAS eligible but disabled | eligible_query_acceleration_time > 0 | Enable QAS: ALTER WAREHOUSE SET ENABLE_QUERY_ACCELERATION = TRUE |
| High concurrency + queuing | queued_queries > 20% of total in peak hour | Enable multi-cluster scaling or isolate workloads |

---

## Recommended Actions

1. **Profile First**: Use Query Profile in Snowsight to visualize bottlenecks
2. **Check Pruning**: Ensure WHERE clauses align with clustering keys
3. **Right-Size**: Match warehouse size to query complexity, not volume
4. **Isolate Workloads**: Separate ETL, BI, and ad-hoc into different warehouses
5. **Monitor Trends**: Set up alerts for queue time and spillage patterns
6. **Enable QAS**: For eligible queries, enable Query Acceleration Service before upsizing warehouse
7. **Tune Auto-Suspend**: Balance cache retention (BI: 300-600s) vs credit savings (ETL: 60s)
8. **Fix Failures First**: Recurring query errors waste credits and mask real performance issues
9. **Simplify High-Compile Queries**: Break complex SQL into CTEs or temp tables to reduce compilation overhead
10. **Review Concurrency**: Use MAX_CONCURRENCY_LEVEL and multi-cluster scaling to manage peak loads

---

## Report Generation

Generate THREE detailed HTML reports in the `snowflake-performance-optimizer/reports/` folder:

### Report 1: Performance Assessment
**Filename:** `Report-Performance-Assessment-DD-MM-YYYY.html`
Assessment results ONLY (no recommendations):
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
**Filename:** `Report-Performance-Recommendation-DD-MM-YYYY.html`
Actionable recommendations derived from Assessment:
- Recommendation Summary (count by priority)
- High Priority Recommendations (with SQL fixes)
- Medium Priority Recommendations
- Low Priority Recommendations
- Implementation Roadmap (weekly schedule)
- Estimated savings/impact metrics

### Report 3: Compliance Evaluation
**Filename:** `Report-Performance-Compliance-DD-MM-YYYY.html`
Compliance status against recommendations:
- Overall Compliance Score (percentage)
- Compliance by Recommendation (table with status badges)
- Best Practices Checklist (pass/fail indicators)
- Cross-Reference Matrix (assessment → recommendation mapping)
- Required Actions for Full Compliance
- Report References

### Report Dependencies
1. **Assessment Report** — Generated first from live Snowflake data
2. **Recommendation Report** — Derived from assessment findings
3. **Compliance Report** — References both assessment and recommendations

### HTML Report Requirements
- Professional styling with CSS
- Color-coded status badges (green/yellow/red)
- Responsive tables with hover effects
- Clear section headers and navigation
- Footer with generation metadata
- All metrics derived from actual query results
- Row counts and data freshness indicators
- Every finding must have a corresponding recommendation with specific SQL commands and estimated impact

---

## Execution Checklist

- [ ] Executed all 14 analysis query categories
- [ ] Applied retry logic for any failed queries
- [ ] Generated Assessment Report (no recommendations)
- [ ] Generated Recommendation Report (derived from assessment)
- [ ] Generated Compliance Report (references both reports)
- [ ] Validated all reports are in `snowflake-performance-optimizer/reports/` folder

---

## Prerequisites

- **Role:** ACCOUNTADMIN (required for ACCOUNT_USAGE views)
- **Warehouse:** Any active warehouse (X-SMALL sufficient)
- **Time:** ~5-10 minutes for full analysis
- **Data Latency:** ACCOUNT_USAGE views have up to 45-minute delay
