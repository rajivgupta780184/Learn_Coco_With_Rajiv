---
name: coco-security-bestpractice-cli
description: "Cortex Code CLI security best practices validation, PAT audit, credential hygiene, RBAC compliance, MCP server security, sandbox configuration, managed settings, hook-based policy enforcement, and incident response readiness. Use when: CoCo CLI security audit, CLI hardening, CLI security checklist, CLI credential check, PAT expiration review, CLI compliance validation, or generating CLI security reports."
author: Rajiv Gupta
linkedin: https://www.linkedin.com/in/rajiv-gupta-618b0228/
---

# Cortex Code CLI — Security Best Practices Validator

Execute a three-phase security validation workflow sequentially. Each phase must fully
complete before proceeding to the next. All validation tests, remediation guidance,
checklists, and priority definitions are contained within this single skill file. Do not
reference or load any external skills during execution.

This skill validates 10 security domains — all 10 MUST be evaluated in every run:
1. Credential Security
2. Role & Access Control
3. Conversation History Security
4. MCP Server Security
5. Production Safety
6. Permission Model & Trust Levels
7. Sandbox Configuration
8. Managed Settings (Enterprise Policy)
9. Compromised Token Response Readiness
10. Hook Security & Policy Enforcement

All HTML reports MUST be saved to the `coco-security-bestpractice-cli/reports/` folder.

**IMPORTANT:** This entire workflow is assessment and documentation only. Do NOT execute
any DDL, DML, or configuration changes.

---

## PHASE 1 — SECURITY VALIDATION ASSESSMENT

Perform a comprehensive security validation of the Cortex Code CLI environment across all
ten security domains defined below. For each finding, capture the Test ID, Test Name,
Domain, Status (PASS / FAIL / WARN / INFO), Severity (Critical / High / Medium / Low),
Finding Detail, and Remediation.

Tests are classified into two types:
- **SQL-Validated** (6 tests): Server-side checks via ACCOUNT_USAGE queries
- **CLI Guidance** (7 tests): Client-side checks with documented verification commands

### Prerequisites

Before beginning assessment, verify role and privileges:
```sql
SELECT CURRENT_ROLE(), CURRENT_USER();
```

---

### Domain 1 — Credential Security

**1.1 — PAT Expiration Compliance (CRITICAL)**

Verify no programmatic access tokens exceed 90-day expiration.
Reference: "Use PATs with at most a 90 day expiration"

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

Assessment rules:
- `TOTAL_LIFETIME_DAYS > 90` → **FAIL** (CRITICAL) — Token exceeds 90-day maximum
- `TOTAL_LIFETIME_DAYS > 60 AND <= 90` → **WARN** (MEDIUM) — Approaching maximum lifetime
- `TOTAL_LIFETIME_DAYS <= 60` → **PASS**
- `DAYS_UNTIL_EXPIRY < 7` → **WARN** (LOW) — Token expiring soon, plan rotation

*Remediation (PAT Expiration):*

Step 1 — Revoke long-lived tokens:
```
Snowsight → User Menu → Programmatic Access Tokens → Revoke
```

Step 2 — Generate new PAT with expiration ≤ 90 days.

Step 3 — Store token in environment variable, never in configuration files:
```bash
export SNOWFLAKE_PAT="<token_value>"
```

Step 4 — Use descriptive names for token purpose tracking.

---

**1.2 — Credential Exposure in Git (HIGH)**

Verify .gitignore includes sensitive configuration paths.
Reference: "Never commit credentials to git"

Assessment: Local filesystem check — report as **INFO** in Workspace context with CLI verification commands.

```
Verify the following entries exist in your .gitignore:
  ~/.snowflake/connections.toml
  ~/.snowflake/cortex/permissions.json
  ~/.snowflake/cortex/conversations/
  ~/.snowflake/cortex/mcp.json
  .env
  *.pem
  *.key

Verification: grep -c "connections.toml" .gitignore
Expected: >= 1
```

*Remediation (Git Credential Exposure):*
```bash
echo "~/.snowflake/connections.toml" >> ~/.gitignore
echo "~/.snowflake/cortex/" >> ~/.gitignore
echo ".env" >> ~/.gitignore
echo "*.pem" >> ~/.gitignore
```

---

**1.3 — Configuration File Permissions (HIGH)**

Verify configuration files use mode 600 and directories use mode 700.
Reference: "Set file permissions to 600/700"

Assessment: Local filesystem check — report as **INFO** in Workspace context.

```
Verification commands:
  stat -c '%a' ~/.snowflake/connections.toml    # Should be 600
  stat -c '%a' ~/.snowflake/cortex              # Should be 700
  stat -c '%a' ~/.snowflake/cortex/conversations # Should be 700
```

*Remediation (File Permissions):*
```bash
chmod 600 ~/.snowflake/connections.toml
chmod 700 ~/.snowflake/cortex
chmod 700 ~/.snowflake/cortex/conversations
```

---

### Domain 2 — Role & Access Control

**2.1 — ACCOUNTADMIN Usage for Routine Operations (HIGH)**

Detect routine (non-admin) operations executed under ACCOUNTADMIN role.
Reference: "Never use ACCOUNTADMIN for routine work" / "Use least privilege roles"

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

Assessment rules:
- `QUERY_COUNT > 50` non-admin queries under ACCOUNTADMIN → **FAIL** (HIGH)
- `QUERY_COUNT 11-50` → **WARN** (MEDIUM)
- No results → **PASS**

*Remediation (ACCOUNTADMIN Routine Usage):*

Step 1 — Create dedicated roles for routine operations:
```sql
CREATE ROLE IF NOT EXISTS DEVELOPER;
CREATE ROLE IF NOT EXISTS ANALYST;
```

Step 2 — Assign appropriate privileges:
```sql
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DEVELOPER;
GRANT USAGE ON DATABASE MY_DB TO ROLE DEVELOPER;
```

Step 3 — Update Cortex Code CLI connection profiles:
```toml
[dev]
role = "DEVELOPER"

[prod_readonly]
role = "ANALYST"
```

Step 4 — Never use ACCOUNTADMIN for SELECT, INSERT, CREATE TABLE, or similar routine queries.

---

**2.2 — Least Privilege — AI Functions Under Admin Role (MEDIUM)**

Identify users executing Cortex AI functions under ACCOUNTADMIN.

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

Assessment rules:
- Any results → **WARN** (MEDIUM) — Cortex AI functions should use a non-admin role
- No results → **PASS**

*Remediation (AI Functions Under Admin):*
```sql
CREATE ROLE IF NOT EXISTS AI_DEVELOPER;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE AI_DEVELOPER;
GRANT ROLE AI_DEVELOPER TO USER <username>;
```

Update CLI connection:
```toml
[ai_dev]
role = "AI_DEVELOPER"
```

---

### Domain 3 — Conversation History Security

**3.1 — Session History Assessment (MEDIUM)**

Assess whether conversation history may contain sensitive data.
Reference: "Use cortex --private when starting Cortex Code to disable session saving for sensitive work"

Assessment: Report as **INFO** with CLI verification commands.

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

### Domain 4 — MCP Server Security

**4.1 — MCP Server Inventory (HIGH)**

Audit MCP server configurations for trust and credential hygiene.
Reference: "Only install trusted MCP servers" / "Never hardcode MCP credentials"

Assessment: Report as **INFO** with CLI verification commands.

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

### Domain 5 — Production Safety

**5.1 — Destructive Operations Audit (CRITICAL)**

Detect DDL operations (DROP, TRUNCATE, DELETE) that may indicate bypass mode usage.
Reference: "Enable planning mode for production and reserve bypass mode for trusted environments"

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

Assessment rules:
- `DROP_DATABASE` or `DROP_SCHEMA` operations found → **FAIL** (CRITICAL)
- `DROP_TABLE` or `TRUNCATE_TABLE` with `ROLE_NAME = 'ACCOUNTADMIN'` → **FAIL** (HIGH)
- `DELETE` operations under ACCOUNTADMIN → **WARN** (MEDIUM)
- No destructive operations → **PASS**

*Remediation (Production Safety):*

Step 1 — Always use planning mode for production work:
```
/plan
Drop and recreate the ANALYTICS schema
```

Step 2 — Reserve bypass mode for trusted development only:
```
/bypass      (enable — use with extreme caution)
/bypass-off  (disable — return to confirm mode)
```

Step 3 — Mode reference:
```
Shift-Tab to cycle modes:
  Blue ⏵⏵  = Confirm (default, recommended)
  Orange ⏸ = Plan (review before action)
  Red >>   = Bypass (all auto-approved — dangerous)
```

Step 4 — For SQL write safety in bypass mode:
```bash
export COCO_DANGEROUS_MODE_REQUIRE_SQL_WRITE_PERMISSION=true
```

---

### Domain 6 — Permission Model & Trust Levels

**6.1 — SQL Write Operations Audit (INFO)**

Audit write operations to ensure proper permission governance.
Reference: Permission types — EXECUTE_COMMAND, FILE_READ, FILE_WRITE, FILE_EDIT, WEB_ACCESS.
SQL categories — READ_ONLY (auto-approved), WRITE (prompts), USE_ROLE (prompts).

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

Assessment rules:
- High volume of write operations → **INFO** — Document for awareness
- No results → **PASS**

*Guidance (Permission Model):*

Trust model risk levels:
| Level | Examples | Behavior |
|-------|----------|----------|
| SAFE | ls, cat, echo, grep | Auto-approved |
| LOW | touch file.txt | Usually auto-approved |
| MEDIUM | Edit files, moderate bash | Prompts in Confirm mode |
| HIGH | rm, curl, wget, sudo | Always prompts |
| CRITICAL | rm -rf, destructive ops | Extra confirmation |

SQL trust levels:
| Level | Operations | Behavior |
|-------|-----------|----------|
| READ_ONLY | SELECT, SHOW, DESCRIBE | Auto-approved |
| WRITE | INSERT, UPDATE, DELETE, CREATE | Prompts |
| USE_ROLE | USE ROLE, USE WAREHOUSE | Prompts |

Recommendation:
- Review `~/.snowflake/cortex/permissions.json` periodically
- Delete the file to reset all persistent permissions
- Use `/new` to reset session permission cache

---

### Domain 7 — Sandbox Configuration

**7.1 — Sandbox Enablement (HIGH)**

Validate sandbox configuration best practices.
Reference: "Cortex Code CLI supports sandboxing to isolate command execution"

Assessment: Report as **INFO** with CLI verification commands.

```
1. Check sandbox status during a session:
   /sandbox status

2. Enable sandbox:
   /sandbox runtime on

3. Enable via settings file (~/.snowflake/cortex/settings.json):
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
   - Shell configs: ~/.bashrc, ~/.zshrc, ~/.profile
   - Git hooks: ~/.git/hooks, .git/hooks
   - SSH config: ~/.ssh/authorized_keys, ~/.ssh/config
   - Managed settings: /Library/Application Support/Cortex/ (macOS),
     /etc/cortex/ (Linux)

6. Enterprise enforcement via managed settings:
   {
     "settings": {
       "forceSandboxEnabled": true,
       "forceSandboxMode": "regular"
     }
   }
```

---

### Domain 8 — Managed Settings (Enterprise Policy)

**8.1 — Enterprise Policy Assessment (MEDIUM)**

Validate managed settings best practices for enterprise deployment.
Reference: "In managed environments, your organization may deploy a system-level managed settings file that enforces policy"

Assessment: Report as **INFO** with guidance for enterprise administrators.

Managed settings file locations:
| OS | Path |
|----|------|
| macOS | `/Library/Application Support/Cortex/managed-settings.json` |
| Linux | `/etc/cortex/managed-settings.json` |
| Windows | `%ProgramData%\Cortex\managed-settings.json` |

Recommended corporate baseline:
```json
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
```

Restrict to specific Snowflake accounts:
```json
{
  "permissions": {
    "onlyAllow": [
      "account(mycompany-prod)",
      "account(mycompany-staging)"
    ]
  }
}
```

Force conversation history disabled for compliance:
```json
{
  "settings": {
    "forceNoHistoryMode": true
  }
}
```

Deploy via enterprise configuration management (MDM, SCCM, Puppet, Chef, Ansible).

---

### Domain 9 — Compromised Token Response Readiness

**9.1 — Query History Audit Capability (HIGH)**

Verify the account can audit suspicious activity in case of a compromised PAT.
Reference: "If your personal access token is compromised... Review the query history"

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

Assessment rules:
- Query returns data → **PASS** — QUERY_HISTORY is accessible for incident response
- Query fails with permission error → **FAIL** (HIGH) — Cannot audit in case of compromise

*Remediation (Compromised Token Response):*

If a PAT is compromised:

Step 1 — IMMEDIATELY revoke the PAT in Snowsight.

Step 2 — Generate a new token with ≤ 90-day expiration.

Step 3 — Store new token in environment variable (NOT in config file).

Step 4 — Audit suspicious activity:
```sql
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE USER_NAME = '<compromised_username>'
ORDER BY START_TIME DESC;
```

Step 5 — Look for:
- Unusual query types (DROP, GRANT, CREATE USER)
- Queries from unexpected IPs
- Queries outside normal working hours
- Data export operations (COPY INTO, GET)

---

### Domain 10 — Hook Security & Policy Enforcement

**10.1 — Hook-Based Policy Enforcement (MEDIUM)**

Validate hook-based security policy enforcement.
Reference: "Use hooks to enforce policies by automating custom security checks"

Assessment: Report as **INFO** with CLI verification commands.

Hook configuration locations (highest to lowest priority):
| Priority | Path |
|----------|------|
| 1 (Local) | `.cortex/settings.local.json` |
| 2 (Project) | `.cortex/settings.json` |
| 3 (User) | `~/.claude/settings.json` |
| 4 (Global) | `~/.snowflake/cortex/hooks.json` |

Available hook events:
| Event | Can Block? | Use Case |
|-------|-----------|----------|
| PreToolUse | Yes | Validate commands, block dangerous operations |
| PostToolUse | No | Logging, auditing |
| PermissionRequest | Yes | Custom approval logic |
| UserPromptSubmit | Yes | Content filtering |
| SessionStart | No | Setup, initialization |
| SessionEnd | No | Cleanup, audit logging |

Tool matchers:
| Pattern | Matches |
|---------|---------|
| `"Bash"` | Only Bash commands |
| `"Edit\|Write"` | Edit or Write operations |
| `"mcp__.*"` | All MCP tools |
| `"SQL*"` | All SQL tools |
| `"*"` | All tools |

Example — Pre-execution hook to validate bash commands:
```json
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
```

Hook script return format:
- Exit code 0: Allow
- Exit code 2: Block
- JSON: `{"decision": "block", "reason": "Operation not allowed by policy"}`
- JSON: `{"decision": "allow", "systemMessage": "Validated by security hook"}`

---

### Phase 1 — Report Output

Generate a self-contained HTML report saved to `coco-security-bestpractice-cli/reports/`:
- **File name:** `Report-CoCo-CLI-Security-Validation-<DD-MM-YYYY>.html`
- **Must include:** Report Generation Summary banner at the TOP with timestamp and elapsed
  time, executive summary with PASS/FAIL/WARN/INFO counts, official checklist status (10
  items with badges), detailed test results per domain, SQL query results for server-side
  tests, CLI guidance for client-side tests, overall compliance score.

---

## PHASE 2 — SECURITY RECOMMENDATIONS

Using all findings from Phase 1, generate a prioritized remediation plan organized by
priority level.

### Priority Levels

| Priority | SLA | Description |
|----------|-----|-------------|
| P0 — Critical | Within 24 hours | Immediate action required |
| P1 — High | Within 7 days | Urgent remediation |
| P2 — Medium | Within 30 days | Scheduled remediation |
| P3 — Low | Within 90 days | Best-practice improvements |

### Recommendation Structure

Each recommendation must include:
- Finding reference (Test ID, domain, severity)
- Step-by-step remediation instructions with exact commands (SQL or CLI)
- Estimated remediation effort (Low / Medium / High)
- Risk context (what breaks if done incorrectly)
- Verification steps to confirm remediation success

### Priority Mapping

| Finding | Domain | Severity | Priority |
|---------|--------|----------|----------|
| PAT lifetime > 90 days | Credentials | CRITICAL | P0 |
| DROP DATABASE/SCHEMA detected | Production Safety | CRITICAL | P0 |
| ACCOUNTADMIN 50+ routine queries | Role & Access | HIGH | P1 |
| Sandbox not enabled | Sandbox | HIGH | P1 |
| MCP hardcoded credentials | MCP Security | HIGH | P1 |
| Cannot audit query history | Incident Response | HIGH | P1 |
| Credentials not in .gitignore | Credentials | HIGH | P1 |
| File permissions not 600/700 | Credentials | HIGH | P1 |
| AI functions under ACCOUNTADMIN | Role & Access | MEDIUM | P2 |
| Conversation history unmanaged | History Security | MEDIUM | P2 |
| No managed settings (enterprise) | Enterprise Policy | MEDIUM | P2 |
| No hook-based enforcement | Hooks | MEDIUM | P2 |
| PAT expiring within 7 days | Credentials | LOW | P3 |

### Official Checklist Cross-Reference

| # | Checklist Item | Test ID(s) |
|---|----------------|------------|
| 1 | Use PATs with at most a 90-day expiration | 1.1 |
| 2 | Set file permissions to 600/700 | 1.3 |
| 3 | Never commit credentials to git | 1.2 |
| 4 | Use least privilege roles | 2.1, 2.2 |
| 5 | Never use ACCOUNTADMIN for routine work | 2.1 |
| 6 | Enable planning mode for production | 5.1 |
| 7 | Only install trusted MCP servers | 4.1 |
| 8 | Store credentials in environment variables | 1.2, 1.3 |
| 9 | Use hooks to enforce policies | 10.1 |
| 10 | Periodically audit permissions | 6.1 |

### Phase 2 — Report Output

Generate a self-contained HTML report saved to `coco-security-bestpractice-cli/reports/`:
- **File name:** `Report-CoCo-CLI-Security-Recommendation-<DD-MM-YYYY>.html`
- **Must include:** Reference to the source Phase 1 validation report, prioritized
  recommendation table (P0–P3), detailed fix instructions per finding, estimated
  remediation effort, official checklist cross-reference, "Report Generation Summary"
  banner at the TOP with total elapsed time for Phase 2.

---

## PHASE 3 — COMPLIANCE DASHBOARD

Using the validation and recommendation data from Phases 1 and 2, build an interactive
compliance dashboard:

- **File name:** `Report-CoCo-CLI-Compliance-Dashboard-<DD-MM-YYYY>.html`
- **Save to:** `coco-security-bestpractice-cli/reports/`

### Dashboard Requirements

- **Domain Breakdown:** Display finding count, completion percentage, and status for each
  of the 10 security domains.
- **Priority Tracking:** Remediation timeline adherence for each priority level (P0–P3)
  against defined SLA windows (24hr / 7d / 30d / 90d).
- **Official Checklist Panel:** 10-item checklist with PASS/FAIL/WARN/INFO badges and
  linked test references.
- **Test Classification Panel:** SQL-Validated tests (6) vs CLI Guidance tests (7) with
  individual status badges.
- **Visual Indicators:** Progress bars and/or charts per priority bucket, per domain,
  and for overall remediation completion.
- **Risk Flagging:** Highlight overdue or at-risk items where SLA deadlines have been
  breached or are within 48 hours of expiry.
- **Overall Compliance Score:** Single composite percentage reflecting overall validation
  status. Formula: (PASS count / total testable items) × 100.
- **Technical Requirements:** Fully interactive, self-contained HTML with no external
  dependencies, refresh-ready, suitable for executive presentation.

---

## Execution Rules

1. Run all three phases strictly sequentially — do not skip, merge, or parallelize.
2. Execute ALL 10 test domains during Phase 1 — none may be skipped.
3. Capture and prominently display total elapsed time for Phase 1 and Phase 2 individually.
4. Substitute `<DD-MM-YYYY>` with today's actual date when naming all output files.
5. All HTML reports must be professionally styled, print-friendly, and stakeholder-ready.
6. Under no circumstances execute any DDL, DML, or configuration changes — assessment and documentation only.
7. Save all generated HTML reports exclusively to the `coco-security-bestpractice-cli/reports/` folder.
8. For each phase report, display a "Report Generation Summary" banner at the TOP.
9. Color-coded severity badges: Red = CRITICAL, Orange = HIGH, Yellow = MEDIUM, Blue = LOW, Green = PASS, Gray = INFO.

---

## Error Handling & Self-Healing

1. If any SQL query or workflow step fails, do NOT halt. Automatically diagnose the root
   cause, apply the appropriate fix, and retry before continuing.

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
