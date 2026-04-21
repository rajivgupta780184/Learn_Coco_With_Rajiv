---
name: performance-optimization
description: Snowflake performance optimization, query tuning, warehouse sizing, clustering, caching, and execution analysis. Use when: slow queries, improving query speed, warehouse performance, clustering strategies, query profiling, execution plans, or performance troubleshooting.
---

# Snowflake Performance Optimization Skill

## Overview
This skill provides guidance for analyzing and optimizing Snowflake query and workload performance.

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

---

## Performance Analysis Queries

### Identify Slow Queries (Last 7 Days)
```sql
SELECT 
    query_id,
    query_text,
    user_name,
    warehouse_name,
    total_elapsed_time / 1000 AS elapsed_seconds,
    bytes_scanned / (1024*1024*1024) AS gb_scanned,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 2) AS partition_scan_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    AND total_elapsed_time > 60000 -- > 60 seconds
ORDER BY total_elapsed_time DESC
LIMIT 50;
```

### Queries with Spillage (Performance Issue)
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

### Poor Partition Pruning (Table Scan Issues)
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
    AND partitions_scanned / NULLIF(partitions_total, 0) > 0.5 -- scanning >50%
ORDER BY partitions_scanned DESC
LIMIT 30;
```

### Queue Wait Time Analysis
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

### Warehouse Utilization Patterns
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

---

## Performance Red Flags

| Issue | Indicator | Solution |
|-------|-----------|----------|
| Remote spillage | bytes_spilled_to_remote_storage > 0 | Increase warehouse size |
| Full table scans | partition_scan_pct > 80% | Add clustering or filters |
| Queue delays | queued_overload_time > 5s | Add clusters or separate workloads |
| Compilation time | compilation_time > execution_time | Simplify query or check metadata |
| No result cache | Use result cache = false | Standardize query patterns |

---

## Recommended Actions

1. **Profile First**: Use Query Profile in Snowsight to visualize bottlenecks
2. **Check Pruning**: Ensure WHERE clauses align with clustering keys
3. **Right-Size**: Match warehouse size to query complexity, not volume
4. **Isolate Workloads**: Separate ETL, BI, and ad-hoc into different warehouses
5. **Monitor Trends**: Set up alerts for queue time and spillage patterns

---

## Automatic Query Retry Logic

When executing performance analysis queries, implement automatic retry with corrective fixes:

### Retry Strategy
```sql
-- Pattern: Wrap queries with error handling
-- If query fails due to permissions, suggest ACCOUNTADMIN role
-- If query times out, reduce date range or add LIMIT
-- If column doesn't exist, check ACCOUNT_USAGE view schema
```

### Common Error Corrections

| Error Type | Original Issue | Corrective Fix |
|------------|----------------|----------------|
| Timeout | Large date range | Reduce to 3 days: `DATEADD(day, -3, CURRENT_TIMESTAMP())` |
| Permission denied | Insufficient role | Switch to ACCOUNTADMIN or grant monitor privileges |
| Column not found | Schema change | Verify column names in INFORMATION_SCHEMA |
| Division by zero | NULL partitions | Use `NULLIF(partitions_total, 0)` |
| No data returned | Filter too restrictive | Relax thresholds or expand date range |

### Auto-Corrected Queries

#### Safe Slow Query Analysis (with fallback)
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

#### User Performance Summary
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

#### Credit Consumption Analysis
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

#### Large Table Clustering Assessment
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

---

## Sample Assessment Output (Reference Only)

> **NOTE:** The section below is a SAMPLE REFERENCE showing the expected format of assessment findings. 
> This is NOT live data. Actual findings are generated dynamically when you run the assessment 
> and are stored in the HTML reports under the `Reports/` folder.

### Example: Key Performance Metrics Format

**Top Credit Consumers:** *(example format)*
- WAREHOUSE_NAME_1: XX.XX credits/week
- WAREHOUSE_NAME_2: XX.XX credits/week
- WAREHOUSE_NAME_3: XX.XX credits/week

**High Volume Users:** *(example format)*
- USER_1: XXX,XXX queries
- USER_2: XXX,XXX queries

**Tables Requiring Clustering Review:** *(example format)*
- DATABASE.SCHEMA.TABLE_NAME: XXX GB (no clustering)

**Spillage Concerns:** *(example format)*
- Local/Remote spillage status summary

> **To get actual current findings:** Run the prompt from `Prompt/Prompt.md` or execute the 
> analysis queries above against your account. Results will be saved to dated HTML reports.

---

## Generated Reports

All HTML reports are generated and stored in the `performance-optimization/Reports/` folder:

| Report | File Name | Purpose |
|--------|-----------|---------|
| Assessment | `Report-Performance-Assessment-DD-MM-YYYY.html` | Performance assessment results (no recommendations) |
| Recommendation | `Report-Performance-Recommendation-DD-MM-YYYY.html` | Recommendations based on assessment findings |
| Compliance | `Report-Performance-Compliance-DD-MM-YYYY.html` | Compliance evaluation against recommendations |

### Report Generation Location
```
.snowflake/cortex/skills/performance-optimization/
├── Skills/
│   └── performance-optimization.md
├── Reports/
│   ├── Report-Performance-Assessment-20-02-2026.html
│   ├── Report-Performance-Recommendation-20-02-2026.html
│   └── Report-Performance-Compliance-20-02-2026.html
└── Prompt/
```

### Report Dependencies
1. **Assessment Report** - Generated first from live Snowflake data
2. **Recommendation Report** - Derived from assessment findings
3. **Compliance Report** - References both assessment and recommendations

---

## Latest Assessment Findings (February 20, 2026)

### Key Metrics
- **Total Queries (7 days):** 1,038,618
- **Total Credits Used:** 197.22
- **Total Data Scanned:** 13,587 GB
- **Storage Used:** 3,046 GB across 518 databases
- **Active Warehouses:** 43
- **Active Users:** 30+

### Critical Issues Identified
1. **Remote Spillage:** STORAGE_MONITOR_WH spilling 18GB+ to remote storage
2. **Unclustered Large Tables:** 6 tables >10GB without clustering (max 128GB)
3. **Always-On Warehouses:** MANIKANTA_S_WH, RITHISH__ALAVALAPATI_WH running 24/7 with low utilization

### Top Credit Consumers (7-Day Period)
| Warehouse | Credits | Status |
|-----------|---------|--------|
| SAURABH_DEOKAR_WH | 32.46 | High Consumer |
| SYSTEM$STREAMLIT_NOTEBOOK_WH | 25.85 | High Consumer |
| VIVEK_S_WH | 22.91 | High Consumer |
| COMPUTE_WH | 18.38 | Always On |

### Spillage Summary
- **50 queries** with spillage detected
- **Worst offender:** STORAGE_MONITOR_WH (18.25GB remote spillage per query)
- **Recommendation:** Resize to MEDIUM or LARGE

### Partition Pruning Issues
- **34 queries** scanning >50% of partitions
- **Most impacted:** ACCOUNT_USAGE.QUERY_HISTORY queries without date filters
- **Recommendation:** Always include date range filters

### Generated Reports
| Report | File |
|--------|------|
| Assessment | Report-Performance-Assessment-20-02-2026.html |
| Recommendations | Report-Performance-Recommendation-20-02-2026.html |
| Compliance | Report-Performance-Compliance-20-02-2026.html |
