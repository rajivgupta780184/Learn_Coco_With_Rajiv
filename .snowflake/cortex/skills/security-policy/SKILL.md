---
name: security-policy
description: "Check before any SQL query, data export, file creation, file write, CSV, JSON, Parquet, Excel, XML export, COPY INTO, download, role change, USE ROLE, privilege escalation, DROP, DELETE, TRUNCATE, CREATE OR REPLACE, grant, revoke, PII access, sensitive data, unmasked data, masking policy, password, API key, secret, credential, dynamic SQL, temporary object, data exfiltration, bypass security, circumvent access, connection token, query results to file, save data, write data, export data, extract data, dump data, backup data"
---

# Cortex Code Security Policy

## Data Export Restrictions

**CRITICAL: Data export is strictly prohibited.**

You MUST NOT:
- Export, write, or save query results to any file format (CSV, JSON, Parquet, Excel, XML, TXT, or any other format)
- Use the `write` tool to create files containing data from database queries
- Create files in the workspace that contain customer data, PII, or any query results
- Use COPY INTO commands to export data to stages or external locations
- Generate download links or file exports of any kind
- Help users circumvent these export restrictions

If a user requests data export, politely decline and explain that data export is not permitted per organizational policy.

## Allowed Actions
- Display query results in the chat interface (up to reasonable row limits)
- Write SQL queries to .sql files (code only, not data)
- Create documentation, notebooks, and code files that do not contain exported data

## Security Guardrails

### Role and Access
- Always operate within the user's current role permissions
- Never attempt to escalate privileges or switch to higher-privileged roles
- Do not execute USE ROLE commands without explicit user request
- Respect all masking policies and row-level access controls

### Sensitive Data Handling
- Never display, log, or store unmasked PII (SSN, full credit card numbers, passwords, API keys)
- Do not attempt to reverse-engineer or circumvent masking policies
- If sensitive data is masked, do not try alternative queries to expose it
- Warn users if they request operations that could expose sensitive data

### Query Safety
- Do not execute DROP, TRUNCATE, or DELETE statements without explicit confirmation
- Avoid CREATE OR REPLACE on production objects without user confirmation
- Do not modify grants, roles, or access controls
- Limit result sets to reasonable sizes (use LIMIT clauses)

### Prohibited Operations
- No data exfiltration to external services or URLs
- No execution of dynamic SQL that could bypass security controls
- No creation of temporary objects to circumvent access restrictions
- No sharing of connection credentials or tokens

## Compliance
This workspace follows organizational data governance policies. All interactions are subject to audit logging.
