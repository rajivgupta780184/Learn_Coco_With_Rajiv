---
name: coco-security-bestpractice-cli
description: Validates Cortex Code CLI security best practices. Use when asked to audit, check, validate, or scan Cortex Code CLI security posture, CoCo CLI hardening, CLI security checklist, or CLI security compliance.
author: Rajiv Gupta
linkedin: https://www.linkedin.com/in/rajiv-gupta-618b0228/
---

# Cortex Code CLI — Security Best Practices Validator

## Purpose

This skill validates a Snowflake account and its Cortex Code CLI environment against the official security best practices documented at https://docs.snowflake.com/en/user-guide/cortex-code/security. It performs **read-only** assessment across 10 security domains, produces a prioritized finding report, and generates remediation guidance.

**No DDL, DML, or configuration changes are executed.** This is strictly an assessment and documentation skill.

## When to Use

- User asks to audit, validate, or check Cortex Code CLI security posture
- User asks about CoCo CLI hardening or security checklist compliance
- User wants to verify security best practices for Cortex Code CLI
- User asks about CLI security compliance or readiness

## Prerequisites

- Role: ACCOUNTADMIN (or role with access to SNOWFLAKE.ACCOUNT_USAGE views)
- Warehouse: Any active warehouse

## Execution Rules

1. Execute ALL 10 test domains sequentially — none may be skipped
2. For each test, capture: Test ID, Test Name, Domain, Status (PASS / FAIL / WARN / INFO), Severity, Finding Detail, Remediation
3. All SQL queries are READ-ONLY (SELECT, SHOW, DESCRIBE only)
4. Generate a single self-contained HTML report saved to `coco-security-bestpractice-cli/reports/`
5. Report filename: `Report-CoCo-CLI-Security-Validation-<DD-MM-YYYY>.html`
6. Display a "Report Generation Summary" banner at the top with timestamp and elapsed time
7. Include an overall compliance score (percentage of PASS results)

---

## Test Domain 1: Credential Security

### Test 1.1 — PAT Expiration Compliance

**Objective:** Verify no programmatic access tokens exceed 90-day expiration.

**Reference:** "Use PATs with at most a 90 day expiration"

```sql
SELECT
    USER_NAME,
    NAME AS TOKEN_NAME,
    CREATED_ON,
    EXPIRES_AT,
    DATEDIFF('day', CURRENT_TIMESTAMP(), EXPIRES_AT) AS DAYS_UNTIL_EXPIRY,
    DATEDIFF('day', CREATED_ON, EXPIRES_AT) AS TOTAL_LIFETIME_DAYS
FROM SNOWFLAKE.ACCOUNT_USAGE.PROGRAMMATIC_ACCESS_TOKENS
WHERE DELETED_ON IS NULL
    AND EXPIRES_AT IS NOT NULL
ORDER BY TOTAL_LIFETIME_DAYS DESC;
```

**Assessment Rules:**
- `TOTAL_LIFETIME_DAYS > 90` → **FAIL** (CRITICAL) — Token exceeds 90-day maximum
- `TOTAL_LIFETIME_DAYS > 60 AND <= 90` → **WARN** (MEDIUM) — Token approaching maximum lifetime
- `TOTAL_LIFETIME_DAYS <= 60` → **PASS**
- Tokens with `DAYS_UNTIL_EXPIRY < 7` → **WARN** (LOW) — Token expiring soon, plan rotation

**Remediation:**
```
1. Revoke long-lived tokens in Snowsight → User Menu → Programmatic Access Tokens
2. Generate new PAT with expiration ≤ 90 days
3. Use descriptive names for token purpose tracking
4. Store token in environment variable, never in configuration files:
   export SNOWFLAKE_PAT="<token_value>"
```

### Test 1.2 — Credential Exposure in Git

**Objective:** Verify .gitignore includes sensitive configuration paths.

**Reference:** "Never commit credentials to git"

**Assessment:** This is a local filesystem check. When running in Snowsight Workspace context, report as **INFO** with the following guidance:

**Guidance for CLI users:**
```
Verify the following entries exist in your .gitignore:
  ~/.snowflake/connections.toml
  ~/.snowflake/cortex/permissions.json
  ~/.snowflake/cortex/conversations/
  ~/.snowflake/cortex/mcp.json
  .env
  *.pem
  *.key

Run: grep -c "connections.toml" .gitignore
Expected: >= 1
```

**Remediation:**
```
echo "~/.snowflake/connections.toml" >> ~/.gitignore
echo "~/.snowflake/cortex/" >> ~/.gitignore
echo ".env" >> ~/.gitignore
echo "*.pem" >> ~/.gitignore
```

### Test 1.3 — Configuration File Permissions

**Objective:** Verify configuration files use mode 600 and directories use mode 700.

**Reference:** "Set file permissions to 600/700"

**Assessment:** Local filesystem check — report as **INFO** in Workspace context.

**Guidance for CLI users:**
```
Run these commands to verify:
  stat -c '%a' ~/.snowflake/connections.toml    # Should be 600
  stat -c '%a' ~/.snowflake/cortex              # Should be 700
  stat -c '%a' ~/.snowflake/cortex/conversations # Should be 700

Fix:
  chmod 600 ~/.snowflake/connections.toml
  chmod 700 ~/.snowflake/cortex
  chmod 700 ~/.snowflake/cortex/conversations
```

---

## Test Domain 2: Role & Access Control

### Test 2.1 — ACCOUNTADMIN Usage for Routine Operations

**Objective:** Detect routine (non-admin) operations executed under ACCOUNTADMIN role.

**Reference:** "Never use ACCOUNTADMIN for routine work" / "Use least privilege roles"

```sql
SELECT
    USER_NAME,
    ROLE_NAME,
    COUNT(*) AS QUERY_COUNT,
    COUNT(DISTINCT DATE_TRUNC('day', START_TIME)) AS ACTIVE_DAYS,
    MIN(START_TIME) AS FIRST_QUERY,
    MAX(START_TIME) AS LAST_QUERY
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(day, -30, CURRENT_TIMESTAMP())
    AND ROLE_NAME = 'ACCOUNTADMIN'
    AND QUERY_TYPE NOT IN ('GRANT', 'REVOKE', 'ALTER_ACCOUNT', 'CREATE_ROLE', 'DROP_ROLE', 'ALTER_USER', 'CREATE_USER', 'DROP_USER')
GROUP BY USER_NAME, ROLE_NAME
HAVING COUNT(*) > 10
ORDER BY QUERY_COUNT DESC;
```

**Assessment Rules:**
- Users with `QUERY_COUNT > 50` non-admin queries under ACCOUNTADMIN → **FAIL** (HIGH)
- Users with `QUERY_COUNT 11-50` → **WARN** (MEDIUM)
- No results → **PASS**

**Remediation:**
```
1. Create dedicated roles for routine operations:
   CREATE ROLE IF NOT EXISTS DEVELOPER;
   CREATE ROLE IF NOT EXISTS ANALYST;

2. Assign appropriate privileges to the role:
   GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DEVELOPER;
   GRANT USAGE ON DATABASE MY_DB TO ROLE DEVELOPER;

3. Update Cortex Code CLI connection profiles:
   [dev]
   role = "DEVELOPER"

   [prod_readonly]
   role = "ANALYST"

4. Never use ACCOUNTADMIN for SELECT, INSERT, CREATE TABLE, or similar routine queries.
```

### Test 2.2 — Least Privilege Validation

**Objective:** Identify users with ACCOUNTADMIN who also execute Cortex AI functions (indicating routine AI work under admin role).

```sql
SELECT
    q.USER_NAME,
    q.ROLE_NAME,
    COUNT(*) AS AI_QUERY_COUNT
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY q
WHERE q.START_TIME >= DATEADD(day, -30, CURRENT_TIMESTAMP())
    AND q.ROLE_NAME = 'ACCOUNTADMIN'
    AND (q.QUERY_TEXT ILIKE '%COMPLETE(%' OR q.QUERY_TEXT ILIKE '%AI_CLASSIFY%'
         OR q.QUERY_TEXT ILIKE '%AI_EXTRACT%' OR q.QUERY_TEXT ILIKE '%AI_SUMMARIZE%'
         OR q.QUERY_TEXT ILIKE '%AI_TRANSLATE%' OR q.QUERY_TEXT ILIKE '%CORTEX%')
GROUP BY q.USER_NAME, q.ROLE_NAME
ORDER BY AI_QUERY_COUNT DESC;
```

**Assessment Rules:**
- Any results → **WARN** (MEDIUM) — Cortex AI functions should use a non-admin role
- No results → **PASS**

**Remediation:**
```
Create a dedicated role for AI work:
  CREATE ROLE IF NOT EXISTS AI_DEVELOPER;
  GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE AI_DEVELOPER;
  GRANT ROLE AI_DEVELOPER TO USER <username>;

Update CLI connection:
  [ai_dev]
  role = "AI_DEVELOPER"
```

---

## Test Domain 3: Conversation History Security

### Test 3.1 — Session History Assessment

**Objective:** Assess whether users are generating excessive session history that could contain sensitive data.

**Reference:** "Use cortex --private when starting Cortex Code to disable session saving for sensitive work"

**Assessment:** Report as **INFO** with guidance.

**Guidance for CLI users:**
```
1. Check conversation history size:
   du -sh ~/.snowflake/cortex/conversations/

2. Review for sensitive content:
   ls -la ~/.snowflake/cortex/conversations/

3. For sensitive work, always start with:
   cortex --private

4. Clear current session before exiting:
   /clear

5. Restrict directory permissions:
   chmod 700 ~/.snowflake/cortex/conversations
```

---

## Test Domain 4: MCP Server Security

### Test 4.1 — MCP Server Inventory Assessment

**Objective:** Document guidance for auditing MCP server configurations.

**Reference:** "Only install trusted MCP servers" / "Never hardcode MCP credentials"

**Assessment:** Report as **INFO** with guidance.

**Guidance for CLI users:**
```
1. List all installed MCP servers:
   cortex mcp list

2. Remove any untrusted or unknown servers:
   cortex mcp remove <server_name>

3. Verify no hardcoded credentials in MCP config:
   cat ~/.snowflake/cortex/mcp.json | grep -v '\${'

   Any line containing tokens, passwords, or API keys NOT wrapped in ${VAR}
   syntax is a FAIL.

4. Correct MCP credential pattern (environment variables):
   {
     "mcpServers": {
       "github": {
         "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
       }
     }
   }

5. Set credentials in shell profile:
   export GITHUB_TOKEN="your_token_here"
```

---

## Test Domain 5: Production Safety

### Test 5.1 — Destructive Operations Without Planning Mode

**Objective:** Detect DDL operations (DROP, TRUNCATE, DELETE) that may indicate bypass or non-plan mode usage.

**Reference:** "Enable planning mode for production and reserve bypass mode for trusted environments"

```sql
SELECT
    USER_NAME,
    QUERY_TYPE,
    SUBSTR(QUERY_TEXT, 1, 200) AS QUERY_PREVIEW,
    START_TIME,
    ROLE_NAME,
    EXECUTION_STATUS
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(day, -30, CURRENT_TIMESTAMP())
    AND QUERY_TYPE IN ('DROP', 'TRUNCATE_TABLE', 'DELETE', 'DROP_TABLE', 'DROP_DATABASE', 'DROP_SCHEMA')
ORDER BY START_TIME DESC
LIMIT 50;
```

**Assessment Rules:**
- `DROP_DATABASE` or `DROP_SCHEMA` operations found → **FAIL** (CRITICAL)
- `DROP_TABLE` or `TRUNCATE_TABLE` with `ROLE_NAME = 'ACCOUNTADMIN'` → **FAIL** (HIGH)
- `DELETE` operations under ACCOUNTADMIN → **WARN** (MEDIUM)
- No destructive operations → **PASS**

**Remediation:**
```
1. Always use planning mode for production work:
   /plan
   Drop and recreate the ANALYTICS schema

2. Reserve bypass mode for trusted development only:
   /bypass      (enable — use with extreme caution)
   /bypass-off  (disable — return to confirm mode)

3. Press Shift-Tab to cycle modes:
   Blue ⏵⏵  = Confirm (default, recommended)
   Orange ⏸ = Plan (review before action)
   Red >>   = Bypass (all auto-approved — dangerous)

4. For SQL write safety in bypass mode, set:
   export COCO_DANGEROUS_MODE_REQUIRE_SQL_WRITE_PERMISSION=true
```

---

## Test Domain 6: Permission Model & Trust Levels

### Test 6.1 — SQL Write Operations Audit

**Objective:** Audit write operations to ensure proper permission governance.

**Reference:** Permission types: EXECUTE_COMMAND, FILE_READ, FILE_WRITE, FILE_EDIT, WEB_ACCESS. SQL categories: READ_ONLY (auto-approved), WRITE (prompts), USE_ROLE (prompts).

```sql
SELECT
    USER_NAME,
    QUERY_TYPE,
    COUNT(*) AS OPERATION_COUNT,
    COUNT(DISTINCT DATE_TRUNC('day', START_TIME)) AS ACTIVE_DAYS
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(day, -30, CURRENT_TIMESTAMP())
    AND QUERY_TYPE IN ('INSERT', 'UPDATE', 'DELETE', 'MERGE', 'CREATE_TABLE', 'CREATE_TABLE_AS_SELECT',
                        'ALTER_TABLE_MODIFY_COLUMN', 'ALTER_TABLE_ADD_COLUMN', 'DROP_TABLE')
GROUP BY USER_NAME, QUERY_TYPE
ORDER BY OPERATION_COUNT DESC
LIMIT 30;
```

**Assessment Rules:**
- High volume of write operations → **INFO** — Document for awareness; verify these had proper permission prompts
- No results → **PASS**

**Guidance:**
```
Permission types in Cortex Code CLI:
  EXECUTE_COMMAND  — Run bash/shell commands
  FILE_READ        — Read file contents
  FILE_WRITE       — Create/modify files
  FILE_EDIT        — Edit existing files
  WEB_ACCESS       — Web search/fetch

Trust model risk levels:
  SAFE     — ls, cat, echo, grep        → Auto-approved
  LOW      — touch file.txt              → Usually auto-approved
  MEDIUM   — Edit files, moderate bash   → Prompts in Confirm mode
  HIGH     — rm, curl, wget, sudo        → Always prompts
  CRITICAL — rm -rf, destructive ops     → Extra confirmation

SQL trust levels:
  READ_ONLY — SELECT, SHOW, DESCRIBE     → Auto-approved
  WRITE     — INSERT, UPDATE, DELETE, CREATE → Prompts
  USE_ROLE  — USE ROLE, USE WAREHOUSE    → Prompts

Recommendation:
  - Review ~/.snowflake/cortex/permissions.json periodically
  - Delete the file to reset all persistent permissions
  - Use /new to reset session permission cache
```

---

## Test Domain 7: Sandbox Configuration

### Test 7.1 — Sandbox Enablement Assessment

**Objective:** Document sandbox configuration best practices and verification steps.

**Reference:** "Cortex Code CLI supports sandboxing to isolate command execution"

**Assessment:** Report as **INFO** with guidance.

**Guidance for CLI users:**
```
1. Check sandbox status during a session:
   /sandbox status

2. Enable sandbox:
   /sandbox runtime on

3. Or enable via settings file (~/.snowflake/cortex/settings.json):
   {
     "sandbox": {
       "enabled": true,
       "mode": "regular",
       "allowUnsandboxedCommands": true
     }
   }

4. Recommended sandbox configuration for production:
   {
     "sandbox": {
       "enabled": true,
       "mode": "regular",
       "filesystem": {
         "denyRead": ["/private/secrets"],
         "denyWrite": ["/etc", "/var", "~/.ssh"]
       },
       "network": {
         "deniedDomains": ["*.internal.company.com"]
       }
     }
   }

5. Protected paths (always denied for write — built-in):
   - Shell configs: ~/.bashrc, ~/.zshrc, ~/.profile, etc.
   - Git hooks: ~/.git/hooks, .git/hooks
   - SSH config: ~/.ssh/authorized_keys, ~/.ssh/config
   - Managed settings: /Library/Application Support/Cortex/ (macOS),
     /etc/cortex/ (Linux)

6. For enterprise environments, enforce sandbox via managed settings:
   {
     "settings": {
       "forceSandboxEnabled": true,
       "forceSandboxMode": "regular"
     }
   }
```

---

## Test Domain 8: Managed Settings (Enterprise Policy)

### Test 8.1 — Enterprise Policy Assessment

**Objective:** Document managed settings best practices for enterprise deployment.

**Reference:** "In managed environments, your organization may deploy a system-level managed settings file that enforces policy"

**Assessment:** Report as **INFO** with guidance.

**Guidance for enterprise administrators:**
```
1. Managed settings file locations:
   macOS:   /Library/Application Support/Cortex/managed-settings.json
   Linux:   /etc/cortex/managed-settings.json
   Windows: %ProgramData%\Cortex\managed-settings.json

2. Recommended corporate baseline:
   {
     "version": "1.0",
     "permissions": {
       "dangerouslyAllowAll": false,
       "defaultMode": "allow"
     },
     "settings": {
       "forceSandboxEnabled": true,
       "forceSandboxMode": "regular"
     },
     "required": {
       "minimumVersion": "1.0.25"
     },
     "ui": {
       "showManagedBanner": true,
       "bannerText": "[Secure] Managed by Corporate IT",
       "hideDangerousOptions": true
     }
   }

3. Restrict to specific Snowflake accounts:
   {
     "permissions": {
       "onlyAllow": [
         "account(mycompany-prod)",
         "account(mycompany-staging)"
       ]
     }
   }

4. Force conversation history disabled for compliance:
   {
     "settings": {
       "forceNoHistoryMode": true
     }
   }

5. Deploy via enterprise configuration management (MDM, SCCM, Puppet, Chef, Ansible).
```

---

## Test Domain 9: Compromised Token Response Readiness

### Test 9.1 — Query History Audit Capability

**Objective:** Verify the account can audit suspicious activity in case of a compromised PAT.

**Reference:** "If your personal access token is compromised... Review the query history"

```sql
SELECT
    USER_NAME,
    COUNT(*) AS TOTAL_QUERIES,
    MIN(START_TIME) AS EARLIEST_QUERY,
    MAX(START_TIME) AS LATEST_QUERY,
    COUNT(DISTINCT QUERY_TYPE) AS DISTINCT_OPERATIONS,
    COUNT(CASE WHEN EXECUTION_STATUS = 'FAIL' THEN 1 END) AS FAILED_QUERIES
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY USER_NAME
ORDER BY TOTAL_QUERIES DESC
LIMIT 20;
```

**Assessment Rules:**
- Query returns data → **PASS** — QUERY_HISTORY is accessible for incident response
- Query fails with permission error → **FAIL** (HIGH) — Cannot audit in case of compromise

**Remediation:**
```
If a PAT is compromised:
  1. IMMEDIATELY revoke the PAT in Snowsight
  2. Generate a new token with ≤ 90-day expiration
  3. Store new token in environment variable (NOT in config file)
  4. Audit suspicious activity:

     SELECT *
     FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
     WHERE USER_NAME = '<compromised_username>'
     ORDER BY START_TIME DESC;

  5. Look for:
     - Unusual query types (DROP, GRANT, CREATE USER)
     - Queries from unexpected IPs
     - Queries outside normal working hours
     - Data export operations (COPY INTO, GET)
```

---

## Test Domain 10: Hook Security & Policy Enforcement

### Test 10.1 — Hook-Based Policy Enforcement Assessment

**Objective:** Document hook-based security policy enforcement best practices.

**Reference:** "Use hooks to enforce policies by automating custom security checks"

**Assessment:** Report as **INFO** with guidance.

**Guidance for CLI users:**
```
1. Hook configuration locations (highest to lowest priority):
   Local:   .cortex/settings.local.json
   Project: .cortex/settings.json
   User:    ~/.claude/settings.json
   Global:  ~/.snowflake/cortex/hooks.json

2. Example: Pre-execution hook to validate bash commands:
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             {
               "type": "command",
               "command": "bash .cortex/hooks/validate-bash.sh",
               "timeout": 60
             }
           ]
         }
       ]
     }
   }

3. Hook script return format:
   - Exit code 0: Do not block
   - Exit code 2: Block the operation
   - Or return JSON:
     {"decision": "block", "reason": "Operation not allowed by policy"}
     {"decision": "allow", "systemMessage": "Validated by policy"}

4. Available hook events:
   PreToolUse       — Before tool execution (can block)
   PostToolUse      — After tool execution
   PermissionRequest — When permission is needed (can block)
   UserPromptSubmit — When user submits prompt
   SessionStart     — When session starts
   SessionEnd       — When session ends

5. Tool matchers for targeted hooks:
   "Bash"           — Only Bash commands
   "Edit|Write"     — Edit or Write operations
   "mcp__.*"        — All MCP tools
   "SQL*"           — All SQL tools
   "*"              — All tools

6. Example: Block dangerous SQL patterns:
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "SQL*",
           "hooks": [
             {
               "type": "command",
               "command": "bash .cortex/hooks/validate-sql.sh"
             }
           ]
         }
       ]
     }
   }
```

---

## Official Security Checklist (Source of Truth)

This is the official checklist from the Snowflake documentation. Each test domain maps to one or more checklist items:

| # | Checklist Item | Test Domain | Test ID(s) |
|---|----------------|-------------|------------|
| 1 | Use PATs with at most a 90-day expiration | Credentials | 1.1 |
| 2 | Set file permissions to 600/700 | Credentials | 1.3 |
| 3 | Never commit credentials to git | Credentials | 1.2 |
| 4 | Use least privilege roles | Role & Access | 2.1, 2.2 |
| 5 | Never use ACCOUNTADMIN for routine work | Role & Access | 2.1 |
| 6 | Enable planning mode for production; reserve bypass for trusted environments | Production Safety | 5.1 |
| 7 | Only install trusted MCP servers | MCP Security | 4.1 |
| 8 | Store credentials in environment variables | Credentials | 1.2, 1.3 |
| 9 | Use hooks to enforce policies | Hook Security | 10.1 |
| 10 | Periodically audit permissions | Permission Model | 6.1 |

---

## Report Specifications

### Filename
`Report-CoCo-CLI-Security-Validation-<DD-MM-YYYY>.html`

### Location
`coco-security-bestpractice-cli/reports/`

### Report Sections

1. **Report Generation Summary** (TOP) — Timestamp, elapsed time, role, account
2. **Executive Summary** — Overall compliance score, PASS/FAIL/WARN/INFO counts
3. **Official Checklist Status** — 10-item checklist with status badges
4. **Detailed Test Results** — Per-domain findings with severity, detail, and remediation
5. **SQL-Validated Tests** — Results of Queries 1.1, 2.1, 2.2, 5.1, 6.1, 9.1
6. **CLI-Side Guidance** — Consolidated local checks for Tests 1.2, 1.3, 3.1, 4.1, 7.1, 8.1, 10.1
7. **Remediation Priority Matrix** — Findings sorted by severity (CRITICAL → HIGH → MEDIUM → LOW)
8. **Compliance Score Calculation** — Formula: (PASS count / total testable items) × 100

### HTML Requirements
- Self-contained, no external dependencies
- Professional styling with color-coded severity badges (Red=CRITICAL, Orange=HIGH, Yellow=MEDIUM, Blue=LOW, Green=PASS, Gray=INFO)
- Print-friendly
- Executive-ready presentation
