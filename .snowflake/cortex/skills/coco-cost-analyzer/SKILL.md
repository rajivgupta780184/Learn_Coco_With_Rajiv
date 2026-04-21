---
name: coco-cost-analyzer
description: Generate a self-contained HTML dashboard for Snowflake Cortex Code (CoCo) usage across Snowsight and CLI, covering Tokens, Token Credits, per-model granular breakdown, and credit-cost trends. Triggers: CoCo cost, Cortex Code usage, CoCo analytics, CoCo dashboard, CoCo report, token usage, token credits, CLI usage, Snowsight usage, CoCo spending, Cortex Code cost analysis.
---

# CoCo Usage Analytics — Cortex Code Skill Prompt

**Version:** 5.1.0

Generate a self-contained HTML dashboard for Snowflake Cortex Code (CoCo) usage across Snowsight and CLI, covering: Tokens, Token Credits, per-model granular breakdown, and credit-cost trends. Uses ONLY real data from Snowflake ACCOUNT_USAGE views — no dummy or sample data.

**Output filename:** `coco_cost_analyzer/reports/COCO-COST-ANALYTICS-DD-MM-YYYY.html` where DD-MM-YYYY is the current date (e.g. `coco_cost_analyzer/reports/COCO-COST-ANALYTICS-24-03-2026.html`). The file MUST be saved under the `coco_cost_analyzer/reports/` folder only.

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

## 2. SQL Queries

Run these to get data for the dashboard. The dashboard must embed the **results** as JS arrays.

### Snowsight Usage
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

### CLI Usage
Same query but replace `CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY` with `CORTEX_CODE_CLI_USAGE_HISTORY`.

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

## 3. Dashboard Layout

Single self-contained HTML file. TWO primary tabs: **CLI** and **Snowsight**. Switching tabs swaps data source but keeps selected date range.

```
+======================================================================+
|  CoCo Usage Analytics                                                |
+======================================================================+
|  [7D] [15D] [30D] [45D] [60D] [90D] [Custom]                        |
+----------------------------------------------------------------------+
|  [ CLI ]  [ Snowsight ]                                              |
+----------------------------------------------------------------------+
|  KPI Cards: Total Tokens | Token Credits | Input Tokens |            |
|  Output Tokens | Cache Read | Cache Write | Total Credits | Top Model|
+----------------------------------------------------------------------+
|  Section 1 — Token Usage Over Time                                   |
|  Line chart (total tokens by day) + Stacked bar (input, output,      |
|  cache_read, cache_write tokens by day)                              |
+----------------------------------------------------------------------+
|  Section 2 — Token Credits Over Time                                 |
|  Filled area chart: total token credits by day                       |
+----------------------------------------------------------------------+
|  Section 3 — Credit Breakdown by Token Type                          |
|  Stacked bar: inputCredits, outputCredits, cacheReadCredits,         |
|  cacheWriteCredits by day                                            |
+----------------------------------------------------------------------+
|  Section 4 — Model Usage Comparison                                  |
|  Grouped bar chart: one series per model, tokens by day              |
+----------------------------------------------------------------------+
|  Section 5 — Per-User Token Consumption                              |
|  Horizontal bar: total tokens per USER_ID, sorted descending         |
+----------------------------------------------------------------------+
|  Section 6 — Usage Detail Table                                      |
|  Date | User | Model | Total Tokens | Input | Output |               |
|  Cache Read | Cache Write | Token Credits | Total Credits            |
+----------------------------------------------------------------------+
```

---

## 4. Date Range Picker

Presets: 7D, 15D, **30D** (default), 45D, 60D, 90D, Custom.

When Custom is selected: reveal two `<input type="date">` fields (From / To) and an Apply button. On Apply, re-filter ALL charts, KPIs, and detail table.

Active button colour matches tab accent: CLI = amber (#F5A623), Snowsight = green (#48D7A4).

```javascript
function filterByRange(rows, days, fromDate, toDate) {
  const now = new Date(); now.setHours(23,59,59);
  const from = fromDate ? new Date(fromDate) : new Date(+now - days*86400000);
  const to = toDate ? new Date(toDate) : now;
  return rows.filter(r => { const d = new Date(r.date); return d >= from && d <= to; });
}
```

---

## 5. Visual Design

| Item | Value |
|---|---|
| Charts | Chart.js 4.4.1 via cdnjs.cloudflare.com |
| Fonts | Space Mono (code/labels), DM Sans (body/headings) via Google Fonts |
| Background | 40x40px CSS grid at 3% opacity |
| Output | Single self-contained HTML, no build step |

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

## 6. Data Rules

- **NO dummy or sample data.** The dashboard must use ONLY real data queried from the Snowflake views listed in Section 1.
- If a source (CLI or Snowsight) returns zero rows, show a "No data available" placeholder on that tab.
- The data is queried at generation time via the SQL in Section 8 and embedded as JS arrays in the HTML.

---

## 7. Output Rules

Return ONLY raw HTML. No markdown fences. No explanation. Fully self-contained, immediately renderable in any browser.

The generated HTML file MUST be saved to: `coco_cost_analyzer/reports/COCO-COST-ANALYTICS-DD-MM-YYYY.html` (DD-MM-YYYY = current date). Always write the file under the `coco_cost_analyzer/reports/` folder.

| Scenario | Behaviour |
|---|---|
| Only CLI data | "No data available" placeholder on Snowsight tab |
| Only Snowsight data | "No data available" placeholder on CLI tab |
| Neither source has data | Show "No CoCo usage data found" message |
| User specifies date range | Pre-set as active default |
| Always | Fully self-contained — no external data files, no sample/dummy data |

---

## 8. How to Run (SQL Only — No Setup Required)

Run this single SQL statement. It queries BOTH real usage views, aggregates the data as JSON, and passes it to Cortex to generate the HTML dashboard with your actual data embedded:

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
    'COCO-COST-ANALYTICS-' || TO_CHAR(CURRENT_DATE(), 'DD-MM-YYYY') || '.html' AS REPORT_FILENAME,
    SNOWFLAKE.CORTEX.COMPLETE(
    'claude-3-5-sonnet',
    [
        {
            'role': 'system',
            'content': 'You generate self-contained HTML dashboards. Use Chart.js 4.4.1 from cdnjs. Google Fonts: Space Mono + DM Sans. Dark theme: --bg:#080E14, --surface:#0F1923, --text:#E8F4FD, --cli:#F5A623, --sg:#48D7A4, --sf-blue:#29B5E8. Date picker (7D/15D/30D default/45D/60D/90D/Custom). 8 KPI cards. Charts: token trend line, token type stacked bar, credit area, credit breakdown bar, model grouped bar, per-user horizontal bar. Detail table. TWO tabs: CLI and Snowsight. NO sample/dummy data. If a source has no data show a No Data placeholder. Return ONLY raw HTML.'
        },
        {
            'role': 'user',
            'content': 'Generate CoCo Usage Analytics dashboard. Embed this REAL data as JS arrays. Snowsight data: ' || COALESCE(sg.DATA_JSON::VARCHAR, '[]') || ' CLI data: ' || COALESCE(cli.DATA_JSON::VARCHAR, '[]') || ' Return only HTML.'
        }
    ],
    {'max_tokens': 8192, 'temperature': 0.2}
) AS DASHBOARD_HTML
FROM sg_data sg, cli_data cli;
```

The result column `DASHBOARD_HTML` contains the complete HTML with your real usage data. The `REPORT_FILENAME` column provides the filename. Extract the HTML from the JSON response `messages` field and save with the generated filename.

---

**Last updated:** 2026-03-24 | **Version:** 5.1.0
