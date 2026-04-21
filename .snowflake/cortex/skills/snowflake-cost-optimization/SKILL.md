---
name: snowflake-cost-optimization
description: Snowflake cost optimization strategies, warehouse sizing, query tuning, storage efficiency, and spend analysis. Use when: analyzing costs, reducing credits, optimizing warehouses, identifying expensive queries, storage cleanup, or budget management.
---

# Snowflake Cost Optimization Skill

Execute a three-phase cost optimization workflow sequentially. Each phase must fully
complete before proceeding to the next. All tasks must exclusively use the query
definitions, optimization checklists, credit rate tiers, and best practices defined
within this skill file. Do not reference, load, or execute skills from any other source.

This skill assesses four cost categories — all four MUST be evaluated in every run:
1. Compute (Warehouses)
2. Storage
3. Serverless Features
4. AI Services (Cortex)

Default cost rate: **$3/credit** for all USD estimates unless account-specific pricing
is available. Note this assumption clearly in all reports.

---

## PHASE 1 — COST OPTIMIZATION ASSESSMENT

Perform a comprehensive scan of the Snowflake account to identify and quantify all cost
optimization opportunities across all four cost categories.

### Category 1 — Compute (Warehouse) Costs

Warehouses drive credit consumption through virtual warehouse metering, auto-suspend/resume
behaviour, multi-cluster scaling, and query spillage to storage.

**Assessment query — Top Spending Warehouses (Last 30 Days):**
```sql
SELECT
    warehouse_name,
    SUM(credits_used) AS total_credits,
    SUM(credits_used) * 3 AS estimated_cost_usd -- adjust rate
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY total_credits DESC;
```

Execute the query above, then assess every warehouse against these checks:

| Check | Flag When |
|-------|-----------|
| AUTO_SUSPEND | Set above 60 seconds |
| AUTO_RESUME | Disabled |
| Right-sizing | XL+ warehouse without evidence of query spillage |
| Multi-cluster scaling | Policy mismatched to workload pattern |
| Query spillage | Queries spilling to remote storage (under-sizing indicator) |
| Workload separation | Mixed ETL + interactive queries on the same warehouse |
| Resource monitors | No resource monitor configured for spend governance |

**Optimization checklist (Compute):**
- [ ] Set AUTO_SUSPEND to 60 seconds (or less for sporadic workloads)
- [ ] Enable AUTO_RESUME
- [ ] Right-size warehouses (start small, scale up)
- [ ] Use separate warehouses for different workload types
- [ ] Avoid XL+ warehouses unless queries spill to storage

### Category 2 — Storage Costs

Storage costs come from active storage, Time Travel retention, Fail-Safe, and staged files.

Assess the following storage domains:
- Active storage consumption by database and schema
- Time Travel retention settings — flag any non-critical tables with retention > 1 day
- Fail-Safe storage consumption and associated costs
- Stage file storage (internal and external) — identify orphaned or stale staged files
- Unused tables, zero-row tables, clones, and transient/temporary table sprawl

**Optimization checklist (Storage):**
- [ ] Reduce TIME_TRAVEL retention for non-critical tables
- [ ] Drop unused tables, clones, and stages
- [ ] Clean up temporary and transient tables
- [ ] Monitor FAIL_SAFE storage consumption

### Category 3 — Serverless Feature Costs

Serverless costs come from Snowpipe, automatic clustering, materialized view maintenance,
search optimization, and replication.

Assess all serverless services for cost efficiency:
- **Snowpipe:** ingestion frequency, file sizing, and credit consumption patterns
- **Automatic Clustering:** tables with clustering enabled but low query benefit
- **Materialized View Maintenance:** stale or infrequently queried materialized views
- **Search Optimization:** tables with search optimization enabled but low usage
- **Replication:** replication group costs, frequency, and business justification

**Optimization checklist (Query & Serverless):**
- [ ] Identify and tune expensive queries (QUERY_HISTORY)
- [ ] Add clustering keys to large, frequently filtered tables
- [ ] Use result caching effectively
- [ ] Avoid SELECT * — select only needed columns
- [ ] Filter early in queries (predicate pushdown)

### Category 4 — AI Services Costs (Cortex)

AI Services span Cortex AI/SQL Functions, Cortex Analyst, Cortex Search, Cortex
Fine-Tuning, Document AI, Cortex Code CLI, and Embedding Functions.

**Billing model:** Token-based billing (credits per million tokens). Input + output
tokens are counted for generative functions. Additional warehouse compute costs apply
for query execution. Copilot is currently free (no charges).

**AI Services credit rate tiers (approximate):**

| Model Category | Models | Credits per 1M Tokens |
|---------------|--------|----------------------|
| Small | mistral-7b, gemma-7b | ~0.12 |
| Medium | llama3.1-8b, mistral-large | ~0.60 |
| Large | llama3.1-70b | ~1.21 |
| XLarge | llama3.1-405b | ~3.63 |
| Embedding | embed-text-768/1024 | ~0.10 |

**Note:** Document AI and Cortex Analyst have separate billing models. Always check
the latest Snowflake pricing documentation.

Execute ALL six of the following assessment queries — none may be omitted even if a
service appears to have zero usage:

**4a — Cortex AI Services Credit Usage (Last 30 Days):**
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

**4b — Cortex AI SQL Functions Usage by Model:**
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

**4c — Cortex Analyst Usage (Text-to-SQL):**
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

**4d — Cortex Search Service Costs:**
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

**4e — All AI/ML Service Costs Summary:**
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

**4f — Cortex Code CLI / Copilot Usage:**
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

After executing all six queries, assess each Cortex sub-category:
- **Cortex AI/SQL Functions** (AI_COMPLETE, AI_CLASSIFY, AI_FILTER, AI_AGG, etc.):
    Flag usage of Large or XLarge models where smaller models may suffice, using the
    credit rate tiers above.
- **Cortex Analyst (Text-to-SQL):** Daily credit trend and usage anomalies.
- **Cortex Search:** Per-service credit and token consumption; flag over-provisioned services.
- **Cortex Fine-Tuning:** Custom model training cost and frequency justification.
- **Document AI:** Document processing volume and credit efficiency.
- **Cortex Code CLI:** Usage patterns (currently free — monitor for billing changes).
- **Embedding Functions** (EMBED_TEXT_768, EMBED_TEXT_1024): Token volume and credit usage.
- **Token-based billing awareness:** Flag cases where input+output token volumes are
  abnormally high without corresponding business output.

**Optimization checklist (AI Services):**
- [ ] Use smallest effective model (mistral-7b < llama3.1-8b < llama3.1-70b < llama3.1-405b)
- [ ] Use warehouse size no larger than MEDIUM for Cortex functions
- [ ] Leverage result caching for repeated AI calls
- [ ] Use AI_COUNT_TOKENS to estimate costs before large batch operations
- [ ] Consider TRY_COMPLETE to avoid costs on error cases
- [ ] Monitor token usage via CORTEX_AISQL_USAGE_HISTORY
- [ ] Restrict model access via CORTEX_MODELS_ALLOWLIST if needed

**Best practices for AI cost control:**
1. **Model Selection:** Start with smaller models and only upgrade if quality is insufficient.
2. **Prompt Engineering:** Shorter, precise prompts reduce token consumption.
3. **Batch Processing:** Group similar requests to leverage caching.
4. **Error Handling:** Use TRY_ variants (TRY_COMPLETE, TRY_CLASSIFY) to avoid charges on errors.
5. **Token Estimation:** Use AI_COUNT_TOKENS() before large batch operations.
6. **Access Control:** Set CORTEX_MODELS_ALLOWLIST to restrict expensive models.
7. **Monitoring:** Regularly review METERING_DAILY_HISTORY and CORTEX_AISQL_USAGE_HISTORY.

### Phase 1 — Finding Capture Format

For each finding across all four categories, capture:
- Optimization category and sub-category
- Estimated monthly cost impact in credits and USD ($3/credit baseline)
- Affected Snowflake objects (warehouse name, table, service, model, function, etc.)
- Severity classification: Critical / High / Medium / Low
- Relevant optimization checklist item that applies

### Phase 1 — Report Output

Generate a self-contained HTML report saved to the `cost-optimization/reports/` folder:
- **File path:** `cost-optimization/reports/Report-Cost-Optimization-Assessment-<DD-MM-YYYY>.html`
- **Must include:** Executive summary with total estimated monthly spend, findings
  breakdown by all four cost categories and severity, detailed findings table per
  category with affected objects and estimated savings, AI model credit rate reference
  table, optimization checklist completion status, a "Report Generation Summary" banner
  at the TOP with assessment timestamp and total elapsed time for Phase 1.

---

## PHASE 2 — COST OPTIMIZATION RECOMMENDATIONS

Using exclusively the Phase 1 assessment report as input, prepare a detailed, actionable
recommendation plan covering all four cost categories. Organize all recommendations in
strict priority order:

| Priority | SLA | Description |
|----------|-----|-------------|
| P0 — Critical | Within 24 hours | Immediate action required |
| P1 — High | Within 7 days | Urgent remediation |
| P2 — Medium | Within 30 days | Scheduled remediation |
| P3 — Low | Within 90 days | Best-practice improvements |

For each recommendation, provide:
- Direct reference to the Phase 1 finding it addresses (category, object, severity)
- Step-by-step remediation guidance with exact Snowflake SQL commands or configuration changes
- Estimated credit and cost savings upon implementation (credits/month and USD/month)
- Implementation complexity rating: Low / Medium / High
- Business impact and risk context (what breaks if done incorrectly)

Category-specific remediation guidance:

**Compute:** ALTER WAREHOUSE commands for AUTO_SUSPEND/AUTO_RESUME, right-sizing guidance,
workload separation strategy, resource monitor setup commands.

**Storage:** ALTER TABLE commands for Time Travel reduction, DROP commands for unused
objects (provided as guidance only), stage cleanup procedures.

**Serverless:** ALTER TABLE to disable unnecessary clustering, materialized view refresh
policy adjustments, search optimization removal commands, replication schedule optimization.

**AI / Cortex:** Model downgrade recommendations using the credit rate tiers defined in
Phase 1, prompt engineering guidance to reduce token consumption, TRY_COMPLETE and
TRY_CLASSIFY adoption for error handling, AI_COUNT_TOKENS() usage for pre-batch cost
estimation, CORTEX_MODELS_ALLOWLIST configuration to restrict expensive models, warehouse
size reduction to MEDIUM or below for Cortex function execution, result caching strategy
for repeated AI calls.

**IMPORTANT:** Do NOT apply, execute, or simulate any fixes. This phase is strictly
documentation and guidance only. No DDL, DML, or configuration changes are permitted.

### Phase 2 — Report Output

Generate a self-contained HTML report saved to the `cost-optimization/reports/` folder:
- **File path:** `cost-optimization/reports/Report-Cost-Optimization-Recommendation-<DD-MM-YYYY>.html`
- **Must include:** Reference to the source Phase 1 assessment report filename,
  prioritized recommendation table (P0 through P3) across all four cost categories,
  detailed fix instructions per finding, estimated remediation effort, total potential
  cost savings summary by category and overall, AI model substitution savings table,
  a "Report Generation Summary" banner at the TOP with total elapsed time for Phase 2.

---

## PHASE 3 — COST OPTIMIZATION COMPLIANCE DASHBOARD

Using the assessment and recommendation data from Phases 1 and 2, build an interactive
compliance dashboard that tracks remediation progress and cost recovery across all four
cost categories.

### Dashboard Requirements

- **File path:** `cost-optimization/reports/Report-Cost-Optimization-Compliance-Dashboard-<DD-MM-YYYY>.html`

- **Category Breakdown:** Display finding count, completion percentage, and estimated
  savings by each category:
  (1) Compute / Warehouse Management
  (2) Storage (Active, Time Travel, Fail-Safe, Stages)
  (3) Serverless (Snowpipe, Clustering, MV, Search, Replication)
  (4) AI Services / Cortex (by sub-service and model tier)

- **Priority Tracking:** Show remediation timeline adherence and completion status for
  each priority level (P0–P3) against the SLA windows (24hr / 7d / 30d / 90d).

- **AI Cost Recovery Panel:** Dedicated panel showing Cortex model tier distribution
  (Small / Medium / Large / XLarge), token consumption trends, and potential savings
  from model downgrades.

- **Visual Indicators:** Progress bars and/or charts per priority bucket, per category,
  and for overall remediation completion.

- **Risk Flagging:** Highlight overdue or at-risk items where SLA deadlines have been
  breached or are within 48 hours of expiry.

- **Cost Recovery Score:** Estimated cost savings realized vs. total potential savings
  identified, expressed as a percentage and USD value.

- **Overall Health Score:** Single composite compliance health score as a percentage
  reflecting overall remediation progress across all categories.

- **Technical Requirements:** Fully interactive, self-contained HTML with no external
  dependencies, refresh-ready for ongoing progress tracking, suitable for executive
  presentation.

---

## Execution Rules

1. Run all three phases strictly sequentially — do not skip, merge, or parallelize.
2. Execute ALL six Cortex-related queries during Phase 1 — none may be omitted even if a service appears to have zero usage.
3. Capture and prominently display the total elapsed time for Phase 1 and Phase 2 individually within their respective reports.
4. Substitute `<DD-MM-YYYY>` with today's actual date when naming all output files.
5. Use $3/credit as the default cost rate for all USD estimates unless account-specific pricing is available; note the assumption clearly in all reports.
6. All HTML reports must be professionally styled, print-friendly, and suitable for executive and stakeholder review.
7. Under no circumstances execute any DDL, DML, or account configuration changes — this entire workflow is assessment and documentation only.
8. Save all generated HTML reports exclusively to the `cost-optimization/reports/` folder — no other output location is permitted.
9. For each phase report, display a "Report Generation Summary" banner at the TOP with performance and cost metadata as a quick-reference header card.

---

## Error Handling & Self-Healing

1. If any SQL query or workflow step fails, do NOT halt. Automatically diagnose the root
   cause, apply the appropriate fix, and retry that specific step before continuing.

2. For every failed and subsequently recovered step, log inline within the relevant
   phase report:
   - Step name / query identifier that failed
   - Exact error message received from Snowflake
   - Root cause diagnosis
   - Corrective fix applied
   - Retry outcome (Success / Failed after retry)

3. Upon successfully resolving any SQL query failure, update the corresponding query
   definition in this skill file with the corrected version. Prepend the corrected
   query with an inline comment:
   `-- [FIXED on <DD-MM-YYYY>]: <concise description of what was corrected and why>`

4. If a step fails and cannot be recovered after retry, mark it as SKIPPED with a clear
   root cause explanation, continue with remaining steps, and flag the skipped item in
   the final report under a "Manual Review Required" section.

5. Consolidate all self-healing actions into a "Self-Healing Summary" section appended
   to the Phase 1 and Phase 2 reports respectively, listing every corrected query/step,
   the fix applied, and the final resolution status.
