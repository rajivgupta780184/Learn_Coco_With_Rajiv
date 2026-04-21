---
name: coco-cost-analyzer
description: "Generate a self-contained HTML dashboard for Snowflake Cortex Code (CoCo) usage across Snowsight and CLI, covering Tokens, Token Credits, per-model granular breakdown, and credit-cost trends. Triggers: CoCo cost, Cortex Code usage, CoCo analytics, CoCo dashboard, CoCo report, token usage, token credits, CLI usage, Snowsight usage, CoCo spending, Cortex Code cost analysis, scan account, scan my account, analyze coco, coco scan."
author: Rajiv Gupta
linkedin: https://www.linkedin.com/in/rajiv-gupta-618b0228/
---

# CoCo Usage Analytics — Cortex Code Skill Prompt

**Version:** 6.0.0

> **MANDATORY EXECUTION CONTRACT**: When this skill is invoked, the agent MUST follow every numbered step below in exact order. Skipping, reordering, or summarizing steps is a VIOLATION. The agent MUST use the pre-flight checklist (Section 9) to self-verify before delivering the report.

Generate a self-contained HTML dashboard for Snowflake Cortex Code (CoCo) usage across Snowsight and CLI, covering: Tokens, Token Credits, per-model granular breakdown, and credit-cost trends. Uses ONLY real data from Snowflake ACCOUNT_USAGE views — no dummy or sample data.

**Output filename:** `coco-cost-analyzer/reports/COCO-COST-ANALYTICS-DD-MM-YYYY.html` where DD-MM-YYYY is the current date. The file MUST be saved under the `coco-cost-analyzer/reports/` folder ONLY.

---

## EXECUTION ORDER (MANDATORY — DO NOT SKIP OR REORDER)

```
STEP 1 → Run Snowsight SQL query (Section 2)
STEP 2 → Run CLI SQL query (Section 2)
STEP 3 → Run User lookup query (Section 2)
STEP 4 → Embed query results as JS arrays (Section 6)
STEP 5 → Generate HTML file matching EXACT layout (Section 3)
STEP 6 → Verify against pre-flight checklist (Section 9)
STEP 7 → Save file to correct path (Section 7)
```

**CRITICAL: Steps 1-3 MUST be executed as actual SQL queries against Snowflake. Do NOT fabricate, estimate, or assume any data values.**

---

## 1. Source Data

Both views share an identical schema. Use ONLY these columns — no others exist.

| View |
|------|
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` |
| `SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_CLI_USAGE_HISTORY` |

| Column | Type | Description |
|---|---|---|
| USER_ID | NUMBER(38,0) | Internal numeric user identifier |
| USER_TAGS | ARRAY | Tags associated with the user |
| REQUEST_ID | VARCHAR | Unique request identifier |
| PARENT_REQUEST_ID | VARCHAR | Parent request ID (chained requests) |
| USAGE_TIME | TIMESTAMP_TZ(9) | Timestamp when usage was recorded |
| TOKEN_CREDITS | NUMBER(38,9) | Total token credits consumed |
| TOKENS | NUMBER(38,0) | Total token count |
| TOKENS_GRANULAR | OBJECT | Per-model token breakdown (see below) |
| CREDITS_GRANULAR | OBJECT | Per-model credit breakdown (see below) |

### TOKENS_GRANULAR / CREDITS_GRANULAR structure
Each key is a model name. Each value object has four fields: `input`, `output`, `cache_read_input`, `cache_write_input`.
```json
{
  "claude-opus-4-6": {
    "input": 1, "output": 194,
    "cache_read_input": 27721, "cache_write_input": 705
  }
}
```

---

## 2. SQL Queries (MUST BE EXECUTED — NOT SKIPPED)

**STEP 1 — Snowsight query:**
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

**STEP 2 — CLI query:** Same query but replace `CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` with `CORTEX_CODE_CLI_USAGE_HISTORY`.

**STEP 3 — User lookup:** Resolve USER_ID to usernames.
```sql
SELECT USER_ID, NAME FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE USER_ID IN (<comma-separated list of all distinct USER_IDs from Steps 1 and 2>);
```

### Column Mapping (SQL -> JS)
| SQL Column | JS Property | SQL Column | JS Property |
|---|---|---|---|
| USAGE_DATE | date | INPUT_CREDITS | inputCredits |
| USER_ID | userId | OUTPUT_CREDITS | outputCredits |
| MODEL_NAME | model | CACHE_READ_CREDITS | cacheReadCredits |
| TOTAL_TOKENS | totalTokens | CACHE_WRITE_CREDITS | cacheWriteCredits |
| TOTAL_TOKEN_CREDITS | totalTokenCredits | CACHE_READ_TOKENS | cacheReadTokens |
| INPUT_TOKENS | inputTokens | CACHE_WRITE_TOKENS | cacheWriteTokens |
| OUTPUT_TOKENS | outputTokens | | |

---

## 3. Dashboard Layout (EXACT — DO NOT DEVIATE)

Single self-contained HTML file. **TWO primary tabs: CLI and Snowsight.** Switching tabs swaps data source but keeps selected date range. Each tab shows its own KPIs, charts, and table using ONLY that tab's data.

```
+======================================================================+
|  CoCo Usage Analytics                                                |
+======================================================================+
|  [ CLI ]  [ Snowsight ]           [7D] [15D] [30D] [45D] [60D] [90D] [Custom]
+----------------------------------------------------------------------+
|  KPI Cards (8 cards in a row):                                       |
|  Total Tokens | Token Credits | Input Tokens | Output Tokens |       |
|  Cache Read | Cache Write | Total Credits | Top Model                |
+----------------------------------------------------------------------+
|  Chart 1 — Token Usage Over Time (line chart, total tokens by day)   |
+----------------------------------------------------------------------+
|  Chart 2 — Token Type Breakdown (stacked bar: input, output,         |
|            cache_read, cache_write tokens by day)                     |
+----------------------------------------------------------------------+
|  Chart 3 — Token Credits Over Time (filled area chart by day)        |
+----------------------------------------------------------------------+
|  Chart 4 — Credit Breakdown by Token Type (stacked bar:              |
|            inputCredits, outputCredits, cacheReadCredits,             |
|            cacheWriteCredits by day)                                  |
+----------------------------------------------------------------------+
|  Chart 5 — Model Usage Comparison (grouped bar: one series per       |
|            model, tokens by day)                                      |
+----------------------------------------------------------------------+
|  Chart 6 — Per-User Token Consumption (horizontal bar: total tokens  |
|            per user, sorted descending. Use resolved usernames.)      |
+----------------------------------------------------------------------+
|  Usage Detail Table                                                   |
|  Date | User | Model | Total Tokens | Input | Output |               |
|  Cache Read | Cache Write | Token Credits | Total Credits             |
+----------------------------------------------------------------------+
```

### MANDATORY DASHBOARD REQUIREMENTS:
- [ ] Exactly **2 tabs**: CLI and Snowsight (not combined, not merged)
- [ ] Tabs switch data source; date range persists across tab switches
- [ ] Exactly **8 KPI cards** visible at all times
- [ ] Exactly **6 charts** using Chart.js (types specified above)
- [ ] Exactly **1 detail table** with all columns listed above
- [ ] **Date range picker** with 7 buttons: 7D, 15D, 30D (default), 45D, 60D, 90D, Custom
- [ ] Custom range reveals From/To date inputs + Apply button
- [ ] ALL charts, KPIs, and table re-filter when date range changes
- [ ] Per-User chart (Chart 6) MUST show resolved usernames, NOT numeric USER_IDs
- [ ] User lookup map embedded as: `const USERS = {<userId>: '<username>', ...};`

---

## 4. Date Range Picker

Presets: 7D, 15D, **30D** (default), 45D, 60D, 90D, Custom.

When Custom is selected: reveal two `<input type="date">` fields (From / To) and an Apply button. On Apply, re-filter ALL charts, KPIs, and detail table.

Active button colour MUST match tab accent: CLI = amber (#F5A623), Snowsight = green (#48D7A4).

```javascript
function filterByRange(rows, days, fromDate, toDate) {
  const now = new Date(); now.setHours(23,59,59);
  const from = fromDate ? new Date(fromDate) : new Date(+now - days*86400000);
  const to = toDate ? new Date(toDate) : now;
  return rows.filter(r => { const d = new Date(r.date); return d >= from && d <= to; });
}
```

---

## 5. Visual Design (MANDATORY — USE THESE EXACT VALUES)

| Item | Value |
|---|---|
| Charts | Chart.js 4.4.1 via `https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js` |
| Fonts | Space Mono (code/labels), DM Sans (body/headings) via Google Fonts |
| Background | 40x40px CSS grid at 3% opacity |
| Output | Single self-contained HTML, no build step, no external data files |

```css
:root {
  --sf-blue:#29B5E8; --cli:#F5A623; --sg:#48D7A4;
  --bg:#080E14; --surface:#0F1923; --surface2:#162231;
  --border:rgba(41,181,232,0.12); --text:#E8F4FD; --muted:#5A7A95; --danger:#FF5757;
}
```

```javascript
const MODEL_COLORS = ['#F5A623','#29B5E8','#48D7A4','#E84292','#9B59B6','#E74C3C'];
const TOKEN_TYPE_COLORS = {
  input:'#29B5E8', output:'#48D7A4',
  cache_read_input:'#F5A623', cache_write_input:'#E84292'
};
```

---

## 6. Data Embedding Rules (CRITICAL)

- **NO dummy or sample data.** The dashboard MUST use ONLY real data queried from Steps 1-3.
- Query results from Step 1 → embed as `const sgData = [...]`
- Query results from Step 2 → embed as `const cliData = [...]`
- Query results from Step 3 → embed as `const USERS = {userId: 'username', ...}`
- If a source (CLI or Snowsight) returns zero rows, embed as empty array `[]` and show "No data available" placeholder on that tab.
- NULL or missing numeric values MUST default to `0` in the JS arrays.

---

## 7. Output Rules

The generated HTML file MUST be saved to: `coco-cost-analyzer/reports/COCO-COST-ANALYTICS-DD-MM-YYYY.html` (DD-MM-YYYY = current date).

| Scenario | Behaviour |
|---|---|
| Only CLI data | "No data available" placeholder on Snowsight tab |
| Only Snowsight data | "No data available" placeholder on CLI tab |
| Neither source has data | Show "No CoCo usage data found" full-page message |
| User specifies date range | Pre-set as active default |
| Always | Fully self-contained — no external data files, no sample/dummy data |

---

## 8. Interaction Rules

- Tab switch: swap `sgData`/`cliData`, re-render all KPIs + charts + table, keep date range
- Date range change: re-filter active tab's data, re-render all KPIs + charts + table
- All Chart.js instances MUST be destroyed before re-creating (prevent canvas reuse errors)
- Detail table sorted by date descending by default
- KPI "Total Credits" = sum of (inputCredits + outputCredits + cacheReadCredits + cacheWriteCredits)
- KPI "Top Model" = model with highest totalTokens in filtered data

---

## 9. PRE-FLIGHT CHECKLIST (MANDATORY — VERIFY BEFORE SAVING)

Before saving the HTML file, the agent MUST mentally verify each item. If ANY item fails, FIX IT before saving.

```
DATA INTEGRITY:
  [ ] Snowsight SQL query was EXECUTED (not skipped)
  [ ] CLI SQL query was EXECUTED (not skipped)
  [ ] User lookup query was EXECUTED (not skipped)
  [ ] All query results are embedded as JS arrays with real data
  [ ] No dummy/sample/hardcoded data exists
  [ ] USERS map contains resolved usernames for all USER_IDs

LAYOUT:
  [ ] TWO separate tabs exist: "CLI" and "Snowsight"
  [ ] Tabs visually switch (active state styling)
  [ ] Tab switch swaps data source (sgData vs cliData)
  [ ] Date range persists across tab switches
  [ ] 8 KPI cards are rendered
  [ ] 6 Chart.js charts are rendered (line, stacked bar, area, stacked bar, grouped bar, horizontal bar)
  [ ] 1 detail table with all 10 columns
  [ ] Date range picker has 7 buttons (7D, 15D, 30D, 45D, 60D, 90D, Custom)
  [ ] 30D is the default active range
  [ ] Custom range shows From/To inputs + Apply button
  [ ] Active range button color matches tab accent (CLI=#F5A623, Snowsight=#48D7A4)

STYLING:
  [ ] Chart.js 4.4.1 loaded from cdnjs
  [ ] Google Fonts loaded: DM Sans + Space Mono
  [ ] CSS variables match Section 5 exactly
  [ ] Dark theme background: #080E14
  [ ] 40x40px grid background pattern at 3% opacity
  [ ] MODEL_COLORS and TOKEN_TYPE_COLORS match Section 5

FILE OUTPUT:
  [ ] Filename format: COCO-COST-ANALYTICS-DD-MM-YYYY.html
  [ ] Saved under: coco-cost-analyzer/reports/
  [ ] File is self-contained HTML (no external data dependencies)
```

---

**Last updated:** 2026-04-21 | **Version:** 6.0.0