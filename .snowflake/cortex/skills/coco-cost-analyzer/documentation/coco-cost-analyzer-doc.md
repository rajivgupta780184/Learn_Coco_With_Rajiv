# CoCo Cost Analyzer — Skill Documentation

**Skill Name:** `coco-cost-analyzer`
**Version:** 6.0.0
**Author:** Rajiv Gupta
**LinkedIn:** https://www.linkedin.com/in/rajiv-gupta-618b0228/
**Last Updated:** 2026-04-21

---

## Table of Contents

1. [Overview](#overview)
2. [Purpose and Use Cases](#purpose-and-use-cases)
3. [Prerequisites](#prerequisites)
4. [Trigger Keywords](#trigger-keywords)
5. [Mandatory Execution Contract](#mandatory-execution-contract)
6. [Execution Order](#execution-order)
7. [Data Sources](#data-sources)
8. [Schema Reference](#schema-reference)
9. [SQL Queries](#sql-queries)
10. [SQL-to-JavaScript Column Mapping](#sql-to-javascript-column-mapping)
11. [Dashboard Architecture](#dashboard-architecture)
12. [Tab Structure](#tab-structure)
13. [KPI Cards](#kpi-cards)
14. [Chart Sections](#chart-sections)
15. [Date Range Picker](#date-range-picker)
16. [Visual Design Specification](#visual-design-specification)
17. [Data Embedding Rules](#data-embedding-rules)
18. [Interaction Rules](#interaction-rules)
19. [Output Rules and Edge Cases](#output-rules-and-edge-cases)
20. [Pre-Flight Checklist](#pre-flight-checklist)
21. [Report Output](#report-output)
22. [Troubleshooting](#troubleshooting)
23. [Changelog](#changelog)

---

## Overview

The **CoCo Cost Analyzer** is a Cortex Code client-side skill that generates a self-contained, interactive HTML dashboard for analyzing Snowflake Cortex Code (CoCo) usage. It provides separate views for **Snowsight** (browser-based) and **CLI** (command-line) usage channels via a tabbed interface, with granular visibility into token consumption, token credits, per-model breakdowns, and credit-cost trends.

The dashboard uses **only real data** queried from Snowflake's `ACCOUNT_USAGE` views — no dummy or sample data is ever used.

---

## Purpose and Use Cases

| Use Case | Description |
|----------|-------------|
| **Cost Monitoring** | Track how many credits Cortex Code is consuming across Snowsight and CLI |
| **Model Comparison** | Compare token usage and costs across different AI models (e.g., claude-opus-4-6, claude-sonnet-4-6) |
| **User Attribution** | Identify which users are the heaviest Cortex Code consumers (resolved usernames, not IDs) |
| **Trend Analysis** | Visualize usage trends over 7, 15, 30, 45, 60, or 90-day windows with custom range support |
| **Token Type Breakdown** | Understand the split between input, output, cache read, and cache write tokens and their credits |
| **Channel Comparison** | Compare Snowsight vs CLI usage patterns via dedicated tabs |
| **Account Scanning** | Full account-wide scan of all CoCo usage for audit and governance |

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| **Snowflake Role** | `ACCOUNTADMIN` (required to access `SNOWFLAKE.ACCOUNT_USAGE` views) |
| **Warehouse** | Any active warehouse (X-SMALL is sufficient) |
| **Data Latency** | `ACCOUNT_USAGE` views have up to 45-minute data latency |
| **Data Retention** | Views retain up to 365 days of history; skill queries last 90 days |
| **Browser** | Any modern browser to render the generated HTML dashboard |

---

## Trigger Keywords

The skill activates when user input matches any of the following keywords or phrases:

| Category | Keywords |
|----------|----------|
| **Direct** | CoCo cost, Cortex Code usage, CoCo analytics, CoCo dashboard, CoCo report |
| **Metrics** | Token usage, token credits, CLI usage, Snowsight usage |
| **Analysis** | CoCo spending, Cortex Code cost analysis, analyze coco |
| **Actions** | Scan account, scan my account, coco scan |

---

## Mandatory Execution Contract

> **CRITICAL:** When this skill is invoked, the agent MUST follow every numbered step in exact order. Skipping, reordering, or summarizing steps is a **VIOLATION**. The agent MUST use the pre-flight checklist (Section 20) to self-verify before delivering the report.

This contract ensures:
- All data comes from actual SQL query execution (never fabricated)
- The dashboard layout matches the exact specification (never simplified)
- All 22 checklist items pass before the file is saved

---

## Execution Order

The agent MUST execute these steps in this exact order:

```
STEP 1 → Run Snowsight SQL query (Section 9)
STEP 2 → Run CLI SQL query (Section 9)
STEP 3 → Run User lookup query (Section 9)
STEP 4 → Embed query results as JS arrays (Section 17)
STEP 5 → Generate HTML file matching EXACT layout (Section 11)
STEP 6 → Verify against pre-flight checklist (Section 20)
STEP 7 → Save file to correct path (Section 21)
```

**Steps 1-3 MUST be executed as actual SQL queries against Snowflake. Do NOT fabricate, estimate, or assume any data values.**

Steps 1 and 2 may be executed in parallel for efficiency, but Step 3 depends on the results of Steps 1-2 (to collect all distinct USER_IDs).

---

## Data Sources

The skill queries exactly **two** Snowflake ACCOUNT_USAGE views. Both views share an identical schema.

| View | Channel |
|------|---------|
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` | Snowsight (browser) |
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY` | CLI (command-line) |

A third view is used for user resolution:

| View | Purpose |
|------|---------|
| `SNOWFLAKE.ACCOUNT_USAGE.USERS` | Resolve numeric USER_ID to human-readable usernames |

---

## Schema Reference

### Column Definitions (Usage Views)

| Column | Type | Description |
|--------|------|-------------|
| `USER_ID` | `NUMBER(38,0)` | Internal numeric user identifier |
| `USER_TAGS` | `ARRAY` | Tags associated with the user |
| `REQUEST_ID` | `VARCHAR` | Unique request identifier |
| `PARENT_REQUEST_ID` | `VARCHAR` | Parent request ID for chained requests |
| `USAGE_TIME` | `TIMESTAMP_TZ(9)` | Timestamp when usage was recorded |
| `TOKEN_CREDITS` | `NUMBER(38,9)` | Total token credits consumed for the request |
| `TOKENS` | `NUMBER(38,0)` | Total token count for the request |
| `TOKENS_GRANULAR` | `OBJECT` | Per-model token breakdown (semi-structured) |
| `CREDITS_GRANULAR` | `OBJECT` | Per-model credit breakdown (semi-structured) |

### TOKENS_GRANULAR and CREDITS_GRANULAR Structure

These are semi-structured `OBJECT` columns. Each key is an AI model name. Each value object contains four numeric fields:

| Field | Description |
|-------|-------------|
| `input` | Tokens/credits for input (prompt) |
| `output` | Tokens/credits for output (completion) |
| `cache_read_input` | Tokens/credits for reading from prompt cache |
| `cache_write_input` | Tokens/credits for writing to prompt cache |

**Example TOKENS_GRANULAR value:**
```json
{
  "claude-opus-4-6": {
    "input": 1,
    "output": 194,
    "cache_read_input": 27721,
    "cache_write_input": 705
  }
}
```

These objects are flattened using `LATERAL FLATTEN` to extract per-model rows for analysis.

---

## SQL Queries

### Step 1 — Snowsight Usage Query

This query flattens both `TOKENS_GRANULAR` and `CREDITS_GRANULAR` to produce one aggregated row per user, per day, per model, with all token and credit metrics.

```sql
SELECT
    DATE_TRUNC('DAY', h.USAGE_TIME)::DATE  AS USAGE_DATE,
    h.USER_ID,
    f.KEY                                  AS MODEL_NAME,
    SUM(h.TOKENS)                          AS TOTAL_TOKENS,
    SUM(h.TOKEN_CREDITS)                   AS TOTAL_TOKEN_CREDITS,
    SUM(f.VALUE:"input"::NUMBER)           AS INPUT_TOKENS,
    SUM(f.VALUE:"output"::NUMBER)          AS OUTPUT_TOKENS,
    SUM(f.VALUE:"cache_read_input"::NUMBER) AS CACHE_READ_TOKENS,
    SUM(f.VALUE:"cache_write_input"::NUMBER) AS CACHE_WRITE_TOKENS,
    SUM(c.VALUE:"input"::FLOAT)            AS INPUT_CREDITS,
    SUM(c.VALUE:"output"::FLOAT)           AS OUTPUT_CREDITS,
    SUM(c.VALUE:"cache_read_input"::FLOAT) AS CACHE_READ_CREDITS,
    SUM(c.VALUE:"cache_write_input"::FLOAT) AS CACHE_WRITE_CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY h,
     LATERAL FLATTEN(INPUT => h.TOKENS_GRANULAR) f,
     LATERAL FLATTEN(INPUT => h.CREDITS_GRANULAR) c
WHERE f.KEY = c.KEY
  AND h.USAGE_TIME >= DATEADD('DAY', -90, CURRENT_TIMESTAMP())
GROUP BY 1, 2, 3
ORDER BY 1 DESC;
```

### Step 2 — CLI Usage Query

Identical to the Snowsight query, substituting the view name:

```sql
-- Same query structure, replacing:
--   CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
-- with:
--   CORTEX_CODE_CLI_USAGE_HISTORY
```

### Step 3 — User Lookup Query

Resolves all distinct USER_IDs from Steps 1 and 2 to human-readable usernames:

```sql
SELECT USER_ID, NAME FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE USER_ID IN (<comma-separated list of all distinct USER_IDs from Steps 1 and 2>);
```

### Key Query Patterns

| Pattern | Detail |
|---------|--------|
| **Double LATERAL FLATTEN** | Both `TOKENS_GRANULAR` and `CREDITS_GRANULAR` are flattened in the same query, joined on `f.KEY = c.KEY` to align model-level token and credit data |
| **90-Day Window** | The default lookback is 90 days from current timestamp |
| **Date Truncation** | Usage timestamps are truncated to day-level for aggregation |
| **GROUP BY** | Results are aggregated by date, user, and model |

---

## SQL-to-JavaScript Column Mapping

When query results are embedded into the HTML dashboard as JavaScript arrays, the following column-to-property mapping is used:

| SQL Column | JS Property | SQL Column | JS Property |
|------------|-------------|------------|-------------|
| `USAGE_DATE` | `date` | `INPUT_CREDITS` | `inputCredits` |
| `USER_ID` | `userId` | `OUTPUT_CREDITS` | `outputCredits` |
| `MODEL_NAME` | `model` | `CACHE_READ_CREDITS` | `cacheReadCredits` |
| `TOTAL_TOKENS` | `totalTokens` | `CACHE_WRITE_CREDITS` | `cacheWriteCredits` |
| `TOTAL_TOKEN_CREDITS` | `totalTokenCredits` | `CACHE_READ_TOKENS` | `cacheReadTokens` |
| `INPUT_TOKENS` | `inputTokens` | `CACHE_WRITE_TOKENS` | `cacheWriteTokens` |
| `OUTPUT_TOKENS` | `outputTokens` | | |

**Data variable names:**
- Step 1 results → `const sgData = [...]`
- Step 2 results → `const cliData = [...]`
- Step 3 results → `const USERS = {<userId>: '<username>', ...}`

---

## Dashboard Architecture

The generated dashboard is a **single self-contained HTML file** with no external dependencies except CDN-hosted Chart.js and Google Fonts.

### Layout (Exact — Do Not Deviate)

```
+======================================================================+
|  CoCo Usage Analytics                                                |
+======================================================================+
|  [ CLI ]  [ Snowsight ]         [7D][15D][30D][45D][60D][90D][Custom]|
+----------------------------------------------------------------------+
|  KPI Cards (8 cards in a row):                                       |
|  Total Tokens | Token Credits | Input Tokens | Output Tokens |       |
|  Cache Read | Cache Write | Total Credits | Top Model                |
+----------------------------------------------------------------------+
|  Chart 1 — Token Usage Over Time (line chart)                        |
+----------------------------------------------------------------------+
|  Chart 2 — Token Type Breakdown (stacked bar)                        |
+----------------------------------------------------------------------+
|  Chart 3 — Token Credits Over Time (filled area)                     |
+----------------------------------------------------------------------+
|  Chart 4 — Credit Breakdown by Token Type (stacked bar)              |
+----------------------------------------------------------------------+
|  Chart 5 — Model Usage Comparison (grouped bar)                      |
+----------------------------------------------------------------------+
|  Chart 6 — Per-User Token Consumption (horizontal bar)               |
+----------------------------------------------------------------------+
|  Usage Detail Table (10 columns)                                     |
+----------------------------------------------------------------------+
```

### Mandatory Dashboard Requirements Checklist

- Exactly **2 tabs**: CLI and Snowsight (not combined, not merged)
- Tabs switch data source; date range persists across tab switches
- Exactly **8 KPI cards** visible at all times
- Exactly **6 charts** using Chart.js (types specified above)
- Exactly **1 detail table** with all 10 columns
- **Date range picker** with 7 buttons: 7D, 15D, 30D (default), 45D, 60D, 90D, Custom
- Custom range reveals From/To date inputs + Apply button
- ALL charts, KPIs, and table re-filter when date range changes
- Per-User chart (Chart 6) MUST show resolved usernames, NOT numeric USER_IDs
- User lookup map embedded as: `const USERS = {<userId>: '<username>', ...}`

---

## Tab Structure

The dashboard has **two primary tabs** that are the core navigation:

| Tab | Data Source | Accent Color | Active Class |
|-----|-------------|--------------|--------------|
| **CLI** | `cliData` array | Amber (`#F5A623`) | `.active-cli` |
| **Snowsight** | `sgData` array | Green (`#48D7A4`) | `.active-sg` |

### Tab Behavior

| Action | Result |
|--------|--------|
| Click "CLI" | Loads `cliData`, re-renders all KPIs/charts/table, date range preserved |
| Click "Snowsight" | Loads `sgData`, re-renders all KPIs/charts/table, date range preserved |
| Default on load | Snowsight tab active, 30D date range |

---

## KPI Cards

The dashboard displays **8 KPI summary cards** at the top, updated dynamically based on the selected tab and date range:

| # | KPI | Calculation | Color |
|---|-----|-------------|-------|
| 1 | **Total Tokens** | Sum of `totalTokens` | Tab accent |
| 2 | **Token Credits** | Sum of `totalTokenCredits` (6 decimal places) | `#29B5E8` |
| 3 | **Input Tokens** | Sum of `inputTokens` | `#29B5E8` |
| 4 | **Output Tokens** | Sum of `outputTokens` | `#48D7A4` |
| 5 | **Cache Read** | Sum of `cacheReadTokens` | `#F5A623` |
| 6 | **Cache Write** | Sum of `cacheWriteTokens` | `#E84292` |
| 7 | **Total Credits** | Sum of (`inputCredits` + `outputCredits` + `cacheReadCredits` + `cacheWriteCredits`) (6 decimal places) | Tab accent |
| 8 | **Top Model** | Model with highest `totalTokens` in filtered data | `#9B59B6` |

---

## Chart Sections

All charts use **Chart.js 4.4.1** and are destroyed + recreated on every data change to prevent canvas reuse errors.

### Chart 1: Token Usage Over Time
- **Type:** Line chart with area fill
- **Data:** Total tokens by day
- **Color:** Tab accent color with 20% opacity fill
- **Features:** Smooth tension (0.3), visible point markers

### Chart 2: Token Type Breakdown
- **Type:** Stacked bar chart
- **Series:** Input (blue), Output (green), Cache Read (amber), Cache Write (pink)
- **Data:** Per token type by day

### Chart 3: Token Credits Over Time
- **Type:** Line chart with area fill
- **Data:** Total token credits by day
- **Color:** `#29B5E8` with 15% opacity fill

### Chart 4: Credit Breakdown by Token Type
- **Type:** Stacked bar chart
- **Series:** Input Credits, Output Credits, Cache Read Credits, Cache Write Credits
- **Colors:** Same token type color scheme as Chart 2

### Chart 5: Model Usage Comparison
- **Type:** Grouped bar chart
- **Series:** One bar per model, using `MODEL_COLORS`
- **Data:** Total tokens per model per day

### Chart 6: Per-User Token Consumption
- **Type:** Horizontal bar chart (`indexAxis: 'y'`)
- **Data:** Total tokens per user, sorted descending
- **Labels:** Resolved usernames from `USERS` map (NOT numeric IDs)
- **Color:** Tab accent

---

## Date Range Picker

### Preset Ranges

| Button | Period | Default? |
|--------|--------|----------|
| 7D | Last 7 days | No |
| 15D | Last 15 days | No |
| **30D** | **Last 30 days** | **Yes** |
| 45D | Last 45 days | No |
| 60D | Last 60 days | No |
| 90D | Last 90 days | No |
| Custom | User-defined range | No |

### Custom Range Behavior

When **Custom** is selected:
1. Two `<input type="date">` fields appear (From / To)
2. An **Apply** button is shown
3. On Apply, all charts, KPIs, and the detail table are re-filtered to the custom range

### Active Button Styling

The active date range button color **MUST** match the current tab accent:
- **CLI tab active:** Background `#F5A623`, text `#000`
- **Snowsight tab active:** Background `#48D7A4`, text `#000`

### Filter Logic

```javascript
function filterByRange(rows, days, fromDate, toDate) {
  const now = new Date(); now.setHours(23, 59, 59);
  const from = fromDate ? new Date(fromDate) : new Date(+now - days * 86400000);
  const to = toDate ? new Date(toDate) : now;
  return rows.filter(r => {
    const d = new Date(r.date);
    return d >= from && d <= to;
  });
}
```

---

## Visual Design Specification

### External Dependencies

| Dependency | Version | Source |
|------------|---------|--------|
| Chart.js | 4.4.1 | `https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js` |
| Space Mono (font) | Latest | Google Fonts |
| DM Sans (font) | Latest | Google Fonts |

### Font Usage

| Context | Font |
|---------|------|
| Code, chart labels, KPI values, table data, date buttons | Space Mono |
| Body text, headings, tab labels | DM Sans |

### Color Palette (Exact Values — Mandatory)

```css
:root {
  --sf-blue:  #29B5E8;
  --cli:      #F5A623;
  --sg:       #48D7A4;
  --bg:       #080E14;
  --surface:  #0F1923;
  --surface2: #162231;
  --border:   rgba(41, 181, 232, 0.12);
  --text:     #E8F4FD;
  --muted:    #5A7A95;
  --danger:   #FF5757;
}
```

### Chart Color Schemes

**Model colors** (assigned in order to each distinct model):
```javascript
const MODEL_COLORS = ['#F5A623','#29B5E8','#48D7A4','#E84292','#9B59B6','#E74C3C'];
```

**Token type colors** (consistent across all token-type charts):
```javascript
const TOKEN_TYPE_COLORS = {
  input:             '#29B5E8',
  output:            '#48D7A4',
  cache_read_input:  '#F5A623',
  cache_write_input: '#E84292'
};
```

### Background

A subtle 40x40px CSS grid overlay at 3% opacity provides visual texture:
```css
body {
  background-image:
    linear-gradient(rgba(41,181,232,0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(41,181,232,0.03) 1px, transparent 1px);
  background-size: 40px 40px;
}
```

---

## Data Embedding Rules

These rules are **CRITICAL** and must never be violated:

| Rule | Detail |
|------|--------|
| **No dummy data** | The dashboard MUST use ONLY real data queried from Steps 1-3 |
| **Snowsight data** | Query results from Step 1 → embed as `const sgData = [...]` |
| **CLI data** | Query results from Step 2 → embed as `const cliData = [...]` |
| **User map** | Query results from Step 3 → embed as `const USERS = {userId: 'username', ...}` |
| **Empty results** | If a source returns zero rows, embed as empty array `[]` and show "No data available" placeholder on that tab |
| **NULL handling** | NULL or missing numeric values MUST default to `0` in the JS arrays |

---

## Interaction Rules

| Interaction | Behavior |
|-------------|----------|
| **Tab switch** | Swap `sgData`/`cliData`, re-render all KPIs + charts + table, keep date range |
| **Date range change** | Re-filter active tab's data, re-render all KPIs + charts + table |
| **Chart recreation** | All Chart.js instances MUST be destroyed before re-creating (prevent canvas reuse errors) |
| **Table sort** | Detail table sorted by date descending by default |
| **Total Credits KPI** | `= inputCredits + outputCredits + cacheReadCredits + cacheWriteCredits` |
| **Top Model KPI** | Model with highest `totalTokens` in filtered data |
| **Default state** | Snowsight tab active, 30D range selected |

---

## Output Rules and Edge Cases

### General Rules

- The output is **always** a single, self-contained HTML file
- All data is embedded as JavaScript arrays at generation time
- No external data files or API calls at render time

### Edge Case Handling

| Scenario | Behavior |
|----------|----------|
| Only CLI data available | Snowsight tab shows "No data available" placeholder |
| Only Snowsight data available | CLI tab shows "No data available" placeholder |
| Neither source has data | Full-page "No CoCo usage data found" message |
| User specifies custom date range | Pre-set as the active default in the dashboard |
| All scenarios | Fully self-contained — no external data files, no sample/dummy data |

---

## Pre-Flight Checklist

Before saving the HTML file, the agent MUST verify **every item** below. If ANY item fails, it must be fixed before saving.

### Data Integrity (6 items)
- [ ] Snowsight SQL query was EXECUTED (not skipped)
- [ ] CLI SQL query was EXECUTED (not skipped)
- [ ] User lookup query was EXECUTED (not skipped)
- [ ] All query results are embedded as JS arrays with real data
- [ ] No dummy/sample/hardcoded data exists
- [ ] USERS map contains resolved usernames for all USER_IDs

### Layout (11 items)
- [ ] TWO separate tabs exist: "CLI" and "Snowsight"
- [ ] Tabs visually switch (active state styling with correct accent)
- [ ] Tab switch swaps data source (sgData vs cliData)
- [ ] Date range persists across tab switches
- [ ] 8 KPI cards are rendered
- [ ] 6 Chart.js charts are rendered (line, stacked bar, area, stacked bar, grouped bar, horizontal bar)
- [ ] 1 detail table with all 10 columns
- [ ] Date range picker has 7 buttons (7D, 15D, 30D, 45D, 60D, 90D, Custom)
- [ ] 30D is the default active range
- [ ] Custom range shows From/To inputs + Apply button
- [ ] Active range button color matches tab accent (CLI=#F5A623, Snowsight=#48D7A4)

### Styling (6 items)
- [ ] Chart.js 4.4.1 loaded from cdnjs
- [ ] Google Fonts loaded: DM Sans + Space Mono
- [ ] CSS variables match Section 16 exactly
- [ ] Dark theme background: #080E14
- [ ] 40x40px grid background pattern at 3% opacity
- [ ] MODEL_COLORS and TOKEN_TYPE_COLORS match Section 16

### File Output (3 items)
- [ ] Filename format: COCO-COST-ANALYTICS-DD-MM-YYYY.html
- [ ] Saved under: coco-cost-analyzer/reports/
- [ ] File is self-contained HTML (no external data dependencies)

**Total: 26 verification items**

---

## Report Output

### File Location

All generated reports are saved to:

```
coco-cost-analyzer/reports/COCO-COST-ANALYTICS-DD-MM-YYYY.html
```

Where `DD-MM-YYYY` is the date of generation (e.g., `COCO-COST-ANALYTICS-21-04-2026.html`).

### Report Characteristics

| Property | Value |
|----------|-------|
| Format | Self-contained HTML |
| External dependencies at render time | Chart.js (CDN), Google Fonts (CDN) |
| Data embedding | JavaScript arrays inline in the HTML |
| Interactivity | Tab switching, date range filtering, chart hover tooltips |
| File size | Typically 15-50 KB depending on data volume |
| Default view | Snowsight tab, 30-day range |

---

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| "No data available" on both tabs | No Cortex Code usage in the last 90 days, or ACCOUNT_USAGE latency | Wait 45 minutes after usage and retry |
| Permission error on views | Insufficient role privileges | Switch to `ACCOUNTADMIN` role |
| Charts not rendering | Chart.js CDN blocked by network policy | Ensure `cdnjs.cloudflare.com` is accessible |
| Empty TOKENS_GRANULAR | Very old usage records before granular tracking was enabled | Reduce date range to more recent data |
| SQL timeout | Large data volume over 90 days | Reduce the `DATEADD` range to 30 days |
| Fonts not loading | Google Fonts CDN blocked | Dashboard will fall back to system sans-serif |
| USER_IDs showing instead of names | User lookup query (Step 3) was skipped or returned no results | Ensure Step 3 is executed with all USER_IDs from Steps 1-2 |
| Tab accent colors wrong | CSS variables not matching spec | Verify `:root` CSS variables match Section 16 |
| Canvas reuse error | Charts not destroyed before recreation | Ensure all Chart.js instances call `.destroy()` before `new Chart()` |

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| **6.0.0** | 2026-04-21 | Added mandatory execution contract, 7-step execution order, 26-item pre-flight checklist, mandatory user resolution (Step 3), explicit interaction rules, stricter enforcement language throughout |
| 5.1.0 | 2026-03-24 | Added self-contained SQL execution section, expanded chart documentation |
| 5.0.0 | 2026-03-15 | Initial public version with 2-tab layout, 8 KPIs, 6 charts |

---

*This documentation describes the `coco-cost-analyzer` Cortex Code skill (v6.0.0). For questions or updates, contact the workspace administrator.*
