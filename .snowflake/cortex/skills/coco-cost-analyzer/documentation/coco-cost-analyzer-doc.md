# CoCo Cost Analyzer — Skill Documentation

**Skill Name:** `coco-cost-analyzer`
**Version:** 5.1.0
**Last Updated:** 2026-03-24

---

## Table of Contents

1. [Overview](#overview)
2. [Purpose and Use Cases](#purpose-and-use-cases)
3. [Prerequisites](#prerequisites)
4. [Trigger Keywords](#trigger-keywords)
5. [Data Sources](#data-sources)
6. [Schema Reference](#schema-reference)
7. [SQL Queries](#sql-queries)
8. [Dashboard Architecture](#dashboard-architecture)
9. [KPI Cards](#kpi-cards)
10. [Chart Sections](#chart-sections)
11. [Date Range Picker](#date-range-picker)
12. [Visual Design Specification](#visual-design-specification)
13. [Output Rules and Edge Cases](#output-rules-and-edge-cases)
14. [Self-Contained SQL Execution](#self-contained-sql-execution)
15. [Report Output](#report-output)
16. [Troubleshooting](#troubleshooting)

---

## Overview

The **CoCo Cost Analyzer** is a Cortex Code skill that generates a self-contained HTML dashboard for analyzing Snowflake Cortex Code (CoCo) usage. It covers both **Snowsight** (browser-based) and **CLI** (command-line) usage channels, providing granular visibility into token consumption, token credits, per-model breakdowns, and credit-cost trends.

The dashboard uses **only real data** queried from Snowflake's `ACCOUNT_USAGE` views — no dummy or sample data is ever used.

---

## Purpose and Use Cases

| Use Case | Description |
|----------|-------------|
| **Cost Monitoring** | Track how many credits Cortex Code is consuming across Snowsight and CLI |
| **Model Comparison** | Compare token usage and costs across different AI models (e.g., claude-opus-4-6, claude-3-5-sonnet) |
| **User Attribution** | Identify which users are the heaviest Cortex Code consumers |
| **Trend Analysis** | Visualize usage trends over 7, 15, 30, 45, 60, or 90-day windows |
| **Token Type Breakdown** | Understand the split between input, output, cache read, and cache write tokens |
| **Channel Comparison** | Compare Snowsight vs CLI usage patterns side by side |

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

- CoCo cost
- Cortex Code usage
- CoCo analytics
- CoCo dashboard
- CoCo report
- Token usage
- Token credits
- CLI usage
- Snowsight usage
- CoCo spending
- Cortex Code cost analysis

---

## Data Sources

The skill queries exactly **two** Snowflake ACCOUNT_USAGE views. Both views share an identical schema.

| View | Channel |
|------|---------|
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` | Snowsight (browser) |
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY` | CLI (command-line) |

---

## Schema Reference

### Column Definitions

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

### Snowsight Usage Query

This query flattens both `TOKENS_GRANULAR` and `CREDITS_GRANULAR` to produce one row per user, per day, per model, with all token and credit metrics.

```sql
SELECT
    DATE_TRUNC('DAY', h.USAGE_TIME)::DATE  AS USAGE_DATE,
    h.USER_ID,
    f.KEY                                  AS MODEL_NAME,
    h.TOKENS                               AS TOTAL_TOKENS,
    h.TOKEN_CREDITS                        AS TOTAL_TOKEN_CREDITS,
    f.VALUE:"input"::NUMBER                AS INPUT_TOKENS,
    f.VALUE:"output"::NUMBER               AS OUTPUT_TOKENS,
    f.VALUE:"cache_read_input"::NUMBER     AS CACHE_READ_TOKENS,
    f.VALUE:"cache_write_input"::NUMBER    AS CACHE_WRITE_TOKENS,
    c.VALUE:"input"::FLOAT                 AS INPUT_CREDITS,
    c.VALUE:"output"::FLOAT                AS OUTPUT_CREDITS,
    c.VALUE:"cache_read_input"::FLOAT      AS CACHE_READ_CREDITS,
    c.VALUE:"cache_write_input"::FLOAT     AS CACHE_WRITE_CREDITS
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY h,
     LATERAL FLATTEN(INPUT => h.TOKENS_GRANULAR) f,
     LATERAL FLATTEN(INPUT => h.CREDITS_GRANULAR) c
WHERE f.KEY = c.KEY
  AND h.USAGE_TIME >= DATEADD('DAY', -90, CURRENT_TIMESTAMP())
ORDER BY 1 DESC;
```

### CLI Usage Query

Identical to the Snowsight query, substituting the view name:

```sql
-- Same query structure as above, replacing:
--   CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
-- with:
--   CORTEX_CODE_CLI_USAGE_HISTORY
```

### Key Query Patterns

- **Double LATERAL FLATTEN**: Both `TOKENS_GRANULAR` and `CREDITS_GRANULAR` are flattened in the same query, joined on `f.KEY = c.KEY` to align model-level token and credit data.
- **90-Day Window**: The default lookback is 90 days from the current timestamp.
- **Date Truncation**: Usage timestamps are truncated to day-level for aggregation.

### SQL-to-JavaScript Column Mapping

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

---

## Dashboard Architecture

The generated dashboard is a **single self-contained HTML file** with no external dependencies (all CSS and JS are inline except CDN-hosted Chart.js and Google Fonts).

### Tab Structure

The dashboard has **two primary tabs**:

| Tab | Data Source | Accent Color |
|-----|-------------|--------------|
| **CLI** | `CORTEX_CODE_CLI_USAGE_HISTORY` | Amber (`#F5A623`) |
| **Snowsight** | `CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` | Green (`#48D7A4`) |

Switching tabs swaps the data source but preserves the currently selected date range.

### Layout Structure

```
+======================================================================+
|  CoCo Usage Analytics                                                |
+======================================================================+
|  [7D] [15D] [30D] [45D] [60D] [90D] [Custom]                        |
+----------------------------------------------------------------------+
|  [ CLI ]  [ Snowsight ]                                              |
+----------------------------------------------------------------------+
|  KPI Cards (8 cards)                                                 |
+----------------------------------------------------------------------+
|  Section 1 — Token Usage Over Time                                   |
+----------------------------------------------------------------------+
|  Section 2 — Token Credits Over Time                                 |
+----------------------------------------------------------------------+
|  Section 3 — Credit Breakdown by Token Type                          |
+----------------------------------------------------------------------+
|  Section 4 — Model Usage Comparison                                  |
+----------------------------------------------------------------------+
|  Section 5 — Per-User Token Consumption                              |
+----------------------------------------------------------------------+
|  Section 6 — Usage Detail Table                                      |
+----------------------------------------------------------------------+
```

---

## KPI Cards

The dashboard displays **8 KPI summary cards** at the top, updated dynamically based on the selected tab and date range:

| # | KPI | Description |
|---|-----|-------------|
| 1 | **Total Tokens** | Sum of all tokens consumed |
| 2 | **Token Credits** | Sum of all token credits |
| 3 | **Input Tokens** | Sum of input (prompt) tokens |
| 4 | **Output Tokens** | Sum of output (completion) tokens |
| 5 | **Cache Read** | Sum of cache read input tokens |
| 6 | **Cache Write** | Sum of cache write input tokens |
| 7 | **Total Credits** | Sum of all credit components (input + output + cache read + cache write credits) |
| 8 | **Top Model** | The model with the highest total token consumption |

---

## Chart Sections

### Section 1: Token Usage Over Time
- **Line chart**: Total tokens by day
- **Stacked bar chart**: Breakdown by token type (input, output, cache_read, cache_write) per day

### Section 2: Token Credits Over Time
- **Filled area chart**: Total token credits by day

### Section 3: Credit Breakdown by Token Type
- **Stacked bar chart**: Daily breakdown of `inputCredits`, `outputCredits`, `cacheReadCredits`, `cacheWriteCredits`

### Section 4: Model Usage Comparison
- **Grouped bar chart**: One series per model, showing token consumption by day

### Section 5: Per-User Token Consumption
- **Horizontal bar chart**: Total tokens per `USER_ID`, sorted descending

### Section 6: Usage Detail Table
- Interactive sortable table with columns:

| Column | Source |
|--------|--------|
| Date | `USAGE_DATE` |
| User | `USER_ID` |
| Model | `MODEL_NAME` |
| Total Tokens | `TOTAL_TOKENS` |
| Input | `INPUT_TOKENS` |
| Output | `OUTPUT_TOKENS` |
| Cache Read | `CACHE_READ_TOKENS` |
| Cache Write | `CACHE_WRITE_TOKENS` |
| Token Credits | `TOTAL_TOKEN_CREDITS` |
| Total Credits | Sum of all credit components |

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
1. Two date input fields appear (From / To)
2. An **Apply** button is shown
3. On Apply, all charts, KPIs, and the detail table are re-filtered to the custom range

### Active Button Styling

The active date range button color matches the current tab accent:
- **CLI tab**: Amber (`#F5A623`)
- **Snowsight tab**: Green (`#48D7A4`)

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
| Chart.js | 4.4.1 | `cdnjs.cloudflare.com` |
| Space Mono (font) | — | Google Fonts |
| DM Sans (font) | — | Google Fonts |

### Font Usage

| Context | Font |
|---------|------|
| Code and chart labels | Space Mono |
| Body text and headings | DM Sans |

### Color Palette

```css
:root {
  --sf-blue:  #29B5E8;    /* Snowflake brand blue */
  --cli:      #F5A623;    /* CLI tab accent (amber) */
  --sg:       #48D7A4;    /* Snowsight tab accent (green) */
  --bg:       #080E14;    /* Page background */
  --surface:  #0F1923;    /* Card/section background */
  --surface2: #162231;    /* Secondary surface */
  --border:   rgba(41, 181, 232, 0.12);  /* Border color */
  --text:     #E8F4FD;    /* Primary text */
  --muted:    #5A7A95;    /* Secondary/muted text */
  --danger:   #FF5757;    /* Error/alert color */
}
```

### Chart Color Schemes

**Model colors** (assigned in order to each distinct model):
```javascript
const MODEL_COLORS = [
  '#F5A623',  // Amber
  '#29B5E8',  // Blue
  '#48D7A4',  // Green
  '#E84292',  // Pink
  '#9B59B6',  // Purple
  '#E74C3C'   // Red
];
```

**Token type colors** (consistent across all charts):
```javascript
const TOKEN_TYPE_COLORS = {
  input:             '#29B5E8',  // Blue
  output:            '#48D7A4',  // Green
  cache_read_input:  '#F5A623',  // Amber
  cache_write_input: '#E84292'   // Pink
};
```

### Background

A subtle 40×40px CSS grid overlay at 3% opacity provides visual texture without distracting from data.

---

## Output Rules and Edge Cases

### General Rules

- The output is **always** a single, self-contained HTML file
- **No markdown fences**, no code explanation — raw HTML only
- All data is embedded as JavaScript arrays at generation time
- No external data files or API calls at render time

### Edge Case Handling

| Scenario | Behavior |
|----------|----------|
| Only CLI data available | Snowsight tab shows "No data available" placeholder |
| Only Snowsight data available | CLI tab shows "No data available" placeholder |
| Neither source has data | Full-page "No CoCo usage data found" message |
| User specifies a custom date range | Pre-set as the active default in the dashboard |
| All scenarios | Fully self-contained — no external data files, no sample/dummy data |

---

## Self-Contained SQL Execution

The skill also provides a single SQL statement that can generate the entire dashboard without the Cortex Code agent. This query:

1. Queries both Snowsight and CLI usage views
2. Aggregates data into JSON arrays using `ARRAY_AGG` and `OBJECT_CONSTRUCT`
3. Passes the real data to `SNOWFLAKE.CORTEX.COMPLETE` (using `claude-3-5-sonnet`) to generate HTML
4. Returns two columns: `REPORT_FILENAME` and `DASHBOARD_HTML`

```sql
WITH sg_data AS (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
        'date', USAGE_DATE::VARCHAR,
        'userId', USER_ID,
        'model', MODEL_NAME,
        'totalTokens', TOTAL_TOKENS,
        'totalTokenCredits', TOTAL_TOKEN_CREDITS,
        'inputTokens', INPUT_TOKENS,
        'outputTokens', OUTPUT_TOKENS,
        'cacheReadTokens', CACHE_READ_TOKENS,
        'cacheWriteTokens', CACHE_WRITE_TOKENS,
        'inputCredits', INPUT_CREDITS,
        'outputCredits', OUTPUT_CREDITS,
        'cacheReadCredits', CACHE_READ_CREDITS,
        'cacheWriteCredits', CACHE_WRITE_CREDITS
    )) AS DATA_JSON
    FROM (
        SELECT
            DATE_TRUNC('DAY', h.USAGE_TIME)::DATE AS USAGE_DATE,
            h.USER_ID,
            f.KEY AS MODEL_NAME,
            SUM(h.TOKENS) AS TOTAL_TOKENS,
            SUM(h.TOKEN_CREDITS) AS TOTAL_TOKEN_CREDITS,
            SUM(f.VALUE:"input"::NUMBER) AS INPUT_TOKENS,
            SUM(f.VALUE:"output"::NUMBER) AS OUTPUT_TOKENS,
            SUM(f.VALUE:"cache_read_input"::NUMBER) AS CACHE_READ_TOKENS,
            SUM(f.VALUE:"cache_write_input"::NUMBER) AS CACHE_WRITE_TOKENS,
            SUM(c.VALUE:"input"::FLOAT) AS INPUT_CREDITS,
            SUM(c.VALUE:"output"::FLOAT) AS OUTPUT_CREDITS,
            SUM(c.VALUE:"cache_read_input"::FLOAT) AS CACHE_READ_CREDITS,
            SUM(c.VALUE:"cache_write_input"::FLOAT) AS CACHE_WRITE_CREDITS
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY h,
             LATERAL FLATTEN(INPUT => h.TOKENS_GRANULAR) f,
             LATERAL FLATTEN(INPUT => h.CREDITS_GRANULAR) c
        WHERE f.KEY = c.KEY
          AND h.USAGE_TIME >= DATEADD('DAY', -90, CURRENT_TIMESTAMP())
        GROUP BY 1, 2, 3
    )
),
cli_data AS (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
        'date', USAGE_DATE::VARCHAR,
        'userId', USER_ID,
        'model', MODEL_NAME,
        'totalTokens', TOTAL_TOKENS,
        'totalTokenCredits', TOTAL_TOKEN_CREDITS,
        'inputTokens', INPUT_TOKENS,
        'outputTokens', OUTPUT_TOKENS,
        'cacheReadTokens', CACHE_READ_TOKENS,
        'cacheWriteTokens', CACHE_WRITE_TOKENS,
        'inputCredits', INPUT_CREDITS,
        'outputCredits', OUTPUT_CREDITS,
        'cacheReadCredits', CACHE_READ_CREDITS,
        'cacheWriteCredits', CACHE_WRITE_CREDITS
    )) AS DATA_JSON
    FROM (
        SELECT
            DATE_TRUNC('DAY', h.USAGE_TIME)::DATE AS USAGE_DATE,
            h.USER_ID,
            f.KEY AS MODEL_NAME,
            SUM(h.TOKENS) AS TOTAL_TOKENS,
            SUM(h.TOKEN_CREDITS) AS TOTAL_TOKEN_CREDITS,
            SUM(f.VALUE:"input"::NUMBER) AS INPUT_TOKENS,
            SUM(f.VALUE:"output"::NUMBER) AS OUTPUT_TOKENS,
            SUM(f.VALUE:"cache_read_input"::NUMBER) AS CACHE_READ_TOKENS,
            SUM(f.VALUE:"cache_write_input"::NUMBER) AS CACHE_WRITE_TOKENS,
            SUM(c.VALUE:"input"::FLOAT) AS INPUT_CREDITS,
            SUM(c.VALUE:"output"::FLOAT) AS OUTPUT_CREDITS,
            SUM(c.VALUE:"cache_read_input"::FLOAT) AS CACHE_READ_CREDITS,
            SUM(c.VALUE:"cache_write_input"::FLOAT) AS CACHE_WRITE_CREDITS
        FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY h,
             LATERAL FLATTEN(INPUT => h.TOKENS_GRANULAR) f,
             LATERAL FLATTEN(INPUT => h.CREDITS_GRANULAR) c
        WHERE f.KEY = c.KEY
          AND h.USAGE_TIME >= DATEADD('DAY', -90, CURRENT_TIMESTAMP())
        GROUP BY 1, 2, 3
    )
)
SELECT
    'COCO-COST-ANALYTICS-' || TO_CHAR(CURRENT_DATE(), 'DD-MM-YYYY') || '.html'
        AS REPORT_FILENAME,
    SNOWFLAKE.CORTEX.COMPLETE(
        'claude-3-5-sonnet',
        [
            {
                'role': 'system',
                'content': 'You generate self-contained HTML dashboards. Use Chart.js 4.4.1 from cdnjs. Google Fonts: Space Mono + DM Sans. Dark theme. Date picker (7D/15D/30D default/45D/60D/90D/Custom). 8 KPI cards. Charts: token trend line, token type stacked bar, credit area, credit breakdown bar, model grouped bar, per-user horizontal bar. Detail table. TWO tabs: CLI and Snowsight. NO sample/dummy data. Return ONLY raw HTML.'
            },
            {
                'role': 'user',
                'content': 'Generate CoCo Usage Analytics dashboard. Embed this REAL data as JS arrays. Snowsight data: '
                    || COALESCE(sg.DATA_JSON::VARCHAR, '[]')
                    || ' CLI data: '
                    || COALESCE(cli.DATA_JSON::VARCHAR, '[]')
                    || ' Return only HTML.'
            }
        ],
        {'max_tokens': 8192, 'temperature': 0.2}
    ) AS DASHBOARD_HTML
FROM sg_data sg, cli_data cli;
```

### How to Use the SQL Output

1. Run the SQL query above
2. The `REPORT_FILENAME` column provides the filename (e.g., `COCO-COST-ANALYTICS-21-04-2026.html`)
3. The `DASHBOARD_HTML` column contains the complete HTML — extract the content from the JSON response's `messages` field
4. Save the HTML with the generated filename

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
| File size | Typically 50-150 KB depending on data volume |

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
