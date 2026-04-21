```
You are a Snowflake Performance Optimization Expert. Your task is to conduct a thorough performance analysis of this Snowflake account and generate actionable insights.

### PHASE 1: DATA COLLECTION

Execute the following analysis queries against SNOWFLAKE.ACCOUNT_USAGE views to gather performance metrics for the last 7 days:

1. **Slow Query Analysis**
   - Identify queries with execution time > 60 seconds
   - Capture query_id, query_text, user, warehouse, elapsed time, bytes scanned, partition metrics

2. **Spillage Detection**
   - Find queries with local or remote storage spillage
   - Flag any remote spillage as critical (indicates undersized warehouse)

3. **Partition Pruning Efficiency**
   - Identify queries scanning >50% of partitions on tables with >100 partitions
   - Calculate scan percentage and bytes scanned

4. **Queue Wait Time Analysis**
   - Detect warehouse congestion patterns
   - Identify peak hours with high queue times

5. **Warehouse Utilization**
   - Analyze credit consumption by warehouse
   - Calculate average daily credits and identify high consumers

6. **User Activity Analysis**
   - Summarize query counts by user
   - Identify users with high data scan volumes

7. **Large Table Assessment**
   - Find tables >1GB without clustering keys
   - Prioritize tables >10GB for clustering review

8. **Query Type Distribution**
   - Analyze query mix (SELECT, INSERT, CALL, etc.)
   - Identify query types with highest average execution time

### PHASE 2: AUTOMATIC RETRY LOGIC

If any query fails, apply these corrective fixes:

| Error Type | Corrective Action |
|------------|-------------------|
| Timeout | Reduce date range to 3 days, add LIMIT clause |
| Permission denied | Suggest switching to ACCOUNTADMIN role |
| Column not found | Verify column names in INFORMATION_SCHEMA |
| Division by zero | Use NULLIF() for divisor columns |
| No data returned | Relax filter thresholds or expand date range |

### PHASE 3: REPORT GENERATION

Generate THREE detailed HTML reports in the `performance-optimization/Reports/` folder:

#### Report 1: Performance Assessment
**Filename:** `Report-Performance-Assessment-DD-MM-YYYY.html`
**Content:** Assessment results ONLY (no recommendations)
- Executive Summary with key metrics
- Warehouse Performance Assessment (credit consumption, utilization)
- Query Performance Assessment (by type, by user)
- Data Storage Assessment (large tables, clustering status)
- Partition Pruning Assessment (inefficient queries)
- Spillage Assessment (memory issues)
- Key Findings Summary

#### Report 2: Performance Recommendations
**Filename:** `Report-Performance-Recommendation-DD-MM-YYYY.html`
**Content:** Actionable recommendations derived from Assessment
- Recommendation Summary (count by priority)
- High Priority Recommendations (with SQL fixes)
- Medium Priority Recommendations
- Low Priority Recommendations
- Implementation Roadmap (weekly schedule)
- Estimated savings/impact metrics

#### Report 3: Compliance Evaluation
**Filename:** `Report-Performance-Compliance-DD-MM-YYYY.html`
**Content:** Compliance status against recommendations
- Overall Compliance Score (percentage)
- Compliance by Recommendation (table with status badges)
- Best Practices Checklist (pass/fail indicators)
- Cross-Reference Matrix (assessment → recommendation mapping)
- Required Actions for Full Compliance
- Report References

### PHASE 4: SKILL FILE UPDATE

Update the `performance-optimization.md` skill file with:
- Latest assessment findings (date-stamped)
- Any new queries that were developed
- Corrected SQL patterns discovered during retry logic

### OUTPUT REQUIREMENTS

1. **HTML Reports** must include:
   - Professional styling with CSS
   - Color-coded status badges (green/yellow/red)
   - Responsive tables with hover effects
   - Clear section headers and navigation
   - Footer with generation metadata

2. **Data Accuracy**
   - All metrics must be derived from actual query results
   - Include row counts and data freshness indicators
   - Flag any truncated or incomplete data

3. **Actionable Insights**
   - Every finding must have a corresponding recommendation
   - Include specific SQL commands for fixes
   - Provide estimated impact (percentage improvement)

### EXECUTION CHECKLIST

- [ ] Executed all 8 analysis query categories
- [ ] Applied retry logic for any failed queries
- [ ] Generated Assessment Report (no recommendations)
- [ ] Generated Recommendation Report (derived from assessment)
- [ ] Generated Compliance Report (references both reports)
- [ ] Updated skill file with latest findings
- [ ] Validated all reports are in Reports/ folder
```

---

## Usage Instructions

1. **Copy the prompt above** and paste it into Cortex Code
2. **Ensure ACCOUNTADMIN role** is active for full ACCOUNT_USAGE access
3. **Wait for all queries to complete** before report generation
4. **Review generated reports** in the `Reports/` folder

---

## Expected Outputs

| Output | Location | Description |
|--------|----------|-------------|
| Assessment Report | `Reports/Report-Performance-Assessment-DD-MM-YYYY.html` | Raw performance data and findings |
| Recommendation Report | `Reports/Report-Performance-Recommendation-DD-MM-YYYY.html` | Prioritized optimization recommendations |
| Compliance Report | `Reports/Report-Performance-Compliance-DD-MM-YYYY.html` | Compliance evaluation with action items |
| Updated Skill File | `Skills/performance-optimization.md` | Latest findings appended |

---

## Prerequisites

- **Role:** ACCOUNTADMIN (required for ACCOUNT_USAGE views)
- **Warehouse:** Any active warehouse (X-SMALL sufficient)
- **Time:** ~5-10 minutes for full analysis
- **Data Latency:** ACCOUNT_USAGE views have up to 45-minute delay

---

## Sample Quick Start

For immediate execution, use this condensed prompt:

```
Scan this Snowflake account for performance optimization opportunities. 
Execute all queries from the performance-optimization skill file, apply 
automatic retry logic for any failures, and generate the following 
HTML reports in the performance-optimization/Reports/ folder:

1. Report-Performance-Assessment-[TODAY].html - Assessment only
2. Report-Performance-Recommendation-[TODAY].html - Based on assessment
3. Report-Performance-Compliance-[TODAY].html - Compliance evaluation

Update the skill file with findings.
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-20 | Initial agent creation |
