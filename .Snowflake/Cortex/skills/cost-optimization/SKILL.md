---
name: snowflake-cost-optimization
description: Snowflake cost optimization strategies, warehouse sizing, query tuning, storage efficiency, and spend analysis. Use when: analyzing costs, reducing credits, optimizing warehouses, identifying expensive queries, storage cleanup, or budget management.
---

# Snowflake Cost Optimization Skill

## Overview
This skill provides guidance for analyzing and optimizing Snowflake costs across compute, storage, and serverless features.

## Cost Categories

### 1. Compute Costs (Warehouses)
- Virtual warehouse credit consumption
- Auto-suspend and auto-resume settings
- Multi-cluster warehouse scaling
- Query spillage to storage

### 2. Storage Costs
- Active storage
- Time Travel retention
- Fail-safe storage
- Stage file storage

### 3. Serverless Costs
- Snowpipe
- Automatic clustering
- Materialized view maintenance
- Search optimization
- Replication

### 4. AI Services Costs (Cortex)
- **Cortex AI/SQL Functions**: LLM functions (AI_COMPLETE, AI_CLASSIFY, AI_FILTER, AI_AGG, etc.)
- **Cortex Analyst**: Natural language to SQL conversion
- **Cortex Search**: Vector search and retrieval services
- **Cortex Fine-Tuning**: Custom model training
- **Document AI**: Document processing and extraction
- **Cortex Code CLI**: AI-powered coding assistance via CLI
- **Embedding Functions**: EMBED_TEXT_768, EMBED_TEXT_1024

**Billing Model:**
- Token-based billing (credits per million tokens)
- Input + Output tokens counted for generative functions
- Additional warehouse compute costs for query execution
- Copilot is currently free (no charges)

---

## Optimization Checklist

### Warehouse Optimization
- [ ] Set AUTO_SUSPEND to 60 seconds (or less for sporadic workloads)
- [ ] Enable AUTO_RESUME
- [ ] Right-size warehouses (start small, scale up)
- [ ] Use separate warehouses for different workload types
- [ ] Avoid XL+ warehouses unless queries spill to storage

### Query Optimization
- [ ] Identify and tune expensive queries (QUERY_HISTORY)
- [ ] Add clustering keys to large, frequently filtered tables
- [ ] Use result caching effectively
- [ ] Avoid SELECT * - select only needed columns
- [ ] Filter early in queries (predicate pushdown)

### Storage Optimization
- [ ] Reduce TIME_TRAVEL retention for non-critical tables
- [ ] Drop unused tables, clones, and stages
- [ ] Clean up temporary and transient tables
- [ ] Monitor FAIL_SAFE storage consumption

### AI Services Optimization
- [ ] Use smallest effective model (mistral-7b < llama3.1-8b < llama3.1-70b < llama3.1-405b)
- [ ] Use warehouse size no larger than MEDIUM for Cortex functions
- [ ] Leverage result caching for repeated AI calls
- [ ] Use AI_COUNT_TOKENS to estimate costs before large batch operations
- [ ] Consider TRY_COMPLETE to avoid costs on error cases
- [ ] Monitor token usage via CORTEX_AISQL_USAGE_HISTORY
- [ ] Restrict model access via CORTEX_MODELS_ALLOWLIST if needed

---

## Key Analysis Queries

### Top Spending Warehouses (Last 30 Days)
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

### Cortex AI Services Credit Usage (Last 30 Days)
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

### Cortex AI SQL Functions Usage by Model
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

### Cortex Analyst Usage (Text-to-SQL)
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

### Cortex Search Service Costs
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

### All AI/ML Service Costs Summary
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

### Cortex Code CLI / Copilot Usage
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

---

## AI Services Credit Rates (Approximate)

| Model Category | Models | Credits per 1M Tokens |
|---------------|--------|----------------------|
| Small | mistral-7b, gemma-7b | ~0.12 |
| Medium | llama3.1-8b, mistral-large | ~0.60 |
| Large | llama3.1-70b | ~1.21 |
| XLarge | llama3.1-405b | ~3.63 |
| Embedding | embed-text-768/1024 | ~0.10 |

**Note:** Copilot (including Cortex Code CLI) is currently free. Document AI and Cortex Analyst have separate billing models. Always check the latest Snowflake pricing documentation.

---

## Best Practices for AI Cost Control

1. **Model Selection**: Start with smaller models (mistral-7b, llama3.1-8b) and only upgrade if quality is insufficient
2. **Prompt Engineering**: Shorter, precise prompts reduce token consumption
3. **Batch Processing**: Group similar requests to leverage caching
4. **Error Handling**: Use TRY_ variants (TRY_COMPLETE, TRY_CLASSIFY) to avoid charges on errors
5. **Token Estimation**: Use AI_COUNT_TOKENS() before large batch operations
6. **Access Control**: Set CORTEX_MODELS_ALLOWLIST to restrict expensive models
7. **Monitoring**: Regularly review METERING_DAILY_HISTORY and CORTEX_AISQL_USAGE_HISTORY