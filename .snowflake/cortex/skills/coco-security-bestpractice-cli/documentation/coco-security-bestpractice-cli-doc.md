# Cortex Code CLI — Security Best Practices Validator Documentation

**Author:** Rajiv Gupta
**LinkedIn:** [https://www.linkedin.com/in/rajiv-gupta-618b0228/](https://www.linkedin.com/in/rajiv-gupta-618b0228/)
**Version:** 2.0
**Last Updated:** April 22, 2026
**Reference:** https://docs.snowflake.com/en/user-guide/cortex-code/security

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Three-Phase Workflow](#three-phase-workflow)
   - [Phase 1 — Security Validation Assessment](#phase-1--security-validation-assessment)
   - [Phase 2 — Security Recommendations](#phase-2--security-recommendations)
   - [Phase 3 — Compliance Dashboard](#phase-3--compliance-dashboard)
6. [Test Domains Reference](#test-domains-reference)
   - [Domain 1 — Credential Security](#domain-1--credential-security)
   - [Domain 2 — Role & Access Control](#domain-2--role--access-control)
   - [Domain 3 — Conversation History Security](#domain-3--conversation-history-security)
   - [Domain 4 — MCP Server Security](#domain-4--mcp-server-security)
   - [Domain 5 — Production Safety](#domain-5--production-safety)
   - [Domain 6 — Permission Model & Trust Levels](#domain-6--permission-model--trust-levels)
   - [Domain 7 — Sandbox Configuration](#domain-7--sandbox-configuration)
   - [Domain 8 — Managed Settings (Enterprise Policy)](#domain-8--managed-settings-enterprise-policy)
   - [Domain 9 — Compromised Token Response Readiness](#domain-9--compromised-token-response-readiness)
   - [Domain 10 — Hook Security & Policy Enforcement](#domain-10--hook-security--policy-enforcement)
7. [Official Security Checklist Mapping](#official-security-checklist-mapping)
8. [Finding Severity Definitions](#finding-severity-definitions)
9. [Priority Matrix](#priority-matrix)
10. [Cortex Code CLI Permission Model Reference](#cortex-code-cli-permission-model-reference)
11. [Cortex Code CLI Trust Levels Reference](#cortex-code-cli-trust-levels-reference)
12. [Sandbox Configuration Reference](#sandbox-configuration-reference)
13. [Managed Settings Reference](#managed-settings-reference)
14. [Hook Events Reference](#hook-events-reference)
15. [Report Specifications](#report-specifications)
16. [Execution Rules](#execution-rules)
17. [Error Handling & Self-Healing](#error-handling--self-healing)
18. [Data Sources](#data-sources)
19. [Post-Run Monitoring](#post-run-monitoring)
20. [Troubleshooting](#troubleshooting)
21. [Frequently Asked Questions](#frequently-asked-questions)

---

## Overview

The **Cortex Code CLI Security Best Practices Validator** is a Cortex Code skill that performs a comprehensive, three-phase security posture assessment of a Snowflake account against the official Cortex Code CLI security best practices. It validates 10 security domains through a combination of SQL-based queries (server-side checks) and documented guidance (client-side checks), produces prioritized remediation recommendations, and generates an interactive compliance dashboard.

### Key Capabilities

- Validates 10 security domains covering credentials, RBAC, conversation history, MCP servers, production safety, permissions, sandbox, managed settings, incident response, and hooks.
- Executes 6 SQL queries for server-side validation (PAT expiration, ACCOUNTADMIN usage, AI role separation, destructive operations, write operations, audit readiness).
- Provides 7 client-side guidance assessments for local filesystem checks (git ignore, file permissions, conversation history, MCP config, sandbox, managed settings, hooks).
- Maps all tests to the official 10-item Snowflake security checklist.
- Produces three sequentially-dependent HTML reports: Assessment, Recommendations, and Compliance Dashboard.
- Includes self-healing retry logic for failed queries.

### What This Skill Does NOT Do

- It does **not** execute any DDL, DML, or configuration changes.
- It does **not** modify account settings, tokens, roles, or local files.
- Client-side checks (file permissions, .gitignore, sandbox config) are reported as guidance — the skill cannot access the local filesystem from a Workspace context.
- It is strictly an assessment and documentation tool.

### Test Classification

| Type | Count | Test IDs | Description |
|------|-------|----------|-------------|
| **SQL-Validated** | 6 tests | 1.1, 2.1, 2.2, 5.1, 6.1, 9.1 | Server-side checks via ACCOUNT_USAGE queries |
| **CLI Guidance** | 7 tests | 1.2, 1.3, 3.1, 4.1, 7.1, 8.1, 10.1 | Client-side checks with documented verification commands |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│            Cortex Code CLI Security Best Practices Validator             │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  SQL-VALIDATED TESTS (Server-Side)                                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│  │ Test 1.1 │ │ Test 2.1 │ │ Test 2.2 │ │ Test 5.1 │ │ Test 6.1 │     │
│  │ PAT Exp  │ │ Admin Use│ │ AI Role  │ │ Destruct │ │ Write Ops│     │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘     │
│       │       ┌────┴─────┐      │             │             │           │
│       │       │ Test 9.1 │      │             │             │           │
│       │       │ Audit    │      │             │             │           │
│       │       └────┬─────┘      │             │             │           │
│       └────────────┴────────────┴─────────────┴─────────────┘           │
│                          │                                               │
│  CLI GUIDANCE TESTS (Client-Side)                                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│  │ Test 1.2 │ │ Test 1.3 │ │ Test 3.1 │ │ Test 4.1 │ │ Test 7.1 │     │
│  │ Git Cred │ │ File Perm│ │ History  │ │ MCP Srvr │ │ Sandbox  │     │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘     │
│  ┌────┴─────┐ ┌────┴─────┐      │             │             │           │
│  │ Test 8.1 │ │ Test 10.1│      │             │             │           │
│  │ Managed  │ │ Hooks    │      │             │             │           │
│  └────┬─────┘ └────┬─────┘      │             │             │           │
│       └─────────────┴────────────┘             │             │           │
│                          │                     │             │           │
│              ┌───────────┴─────────────────────┴─────────────┘           │
│              │       Self-Healing Retry Logic                            │
│              └───────────┬───────────────────────┘                       │
│                          │                                               │
│  PHASE 1                 ▼                                               │
│            ┌──────────────────────────────────┐                          │
│            │  Assessment HTML Report          │                          │
│            │  (PASS/FAIL/WARN/INFO per test)  │                          │
│            └─────────────┬────────────────────┘                          │
│                          │                                               │
│  PHASE 2                 ▼                                               │
│            ┌──────────────────────────────────┐                          │
│            │  Recommendation HTML Report      │                          │
│            │  (P0–P3 priorities + fixes)      │                          │
│            └─────────────┬────────────────────┘                          │
│                          │                                               │
│  PHASE 3                 ▼                                               │
│            ┌──────────────────────────────────┐                          │
│            │  Compliance Dashboard HTML       │                          │
│            │  (interactive, executive-ready)  │                          │
│            └──────────────────────────────────┘                          │
│                                                                          │
│  All reports → coco-security-bestpractice-cli/reports/                   │
└──────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Input:** Read-only SQL queries against `SNOWFLAKE.ACCOUNT_USAGE` views (30-day and 7-day lookbacks), plus documented CLI verification commands for local checks.
2. **Processing:** Query results are assessed against defined thresholds and tagged with status (PASS/FAIL/WARN/INFO) and severity. Failed queries enter the self-healing retry loop.
3. **Output:** Three self-contained HTML reports saved sequentially to `coco-security-bestpractice-cli/reports/`.

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| **Snowflake Role** | `ACCOUNTADMIN` (required for `SNOWFLAKE.ACCOUNT_USAGE` views) |
| **Warehouse** | Any active warehouse (X-SMALL sufficient) |
| **Data Latency** | `ACCOUNT_USAGE` views have up to 45-minute delay |
| **SQL Lookback** | 30 days for most tests; 7 days for incident response test (9.1) |
| **Execution Time** | ~5-10 minutes for full three-phase workflow |
| **Browser** | Any modern browser (Chrome, Firefox, Edge) to render HTML reports |

### Workspace Setup

```
coco-security-bestpractice-cli/
├── SKILL.md                          # Skill definition
├── documentation/
│   └── coco-security-bestpractice-cli-doc.md  # This file
└── reports/                          # Generated HTML reports land here
    ├── Report-CoCo-CLI-Security-Validation-<DD-MM-YYYY>.html
    ├── Report-CoCo-CLI-Security-Recommendation-<DD-MM-YYYY>.html
    └── Report-CoCo-CLI-Compliance-Dashboard-<DD-MM-YYYY>.html
```

---

## Quick Start

1. Open Snowsight Workspace containing this skill.
2. Ensure you are using the **ACCOUNTADMIN** role.
3. Invoke the skill by asking Cortex Code:
   > "Run the CoCo CLI security validation"
4. The validator executes all three phases sequentially:
   - Phase 1: Runs 13 tests across 10 security domains
   - Phase 2: Produces prioritized recommendations from Phase 1 findings
   - Phase 3: Generates an interactive compliance dashboard
5. Review the generated HTML reports in `coco-security-bestpractice-cli/reports/`.
6. Follow CLI Guidance sections to complete client-side checks locally on your machine.

---

## Three-Phase Workflow

The skill executes three phases **strictly sequentially** — no skipping, merging, or parallelizing.

### Phase 1 — Security Validation Assessment

Performs a comprehensive security validation across all 10 domains. For each test, captures:

| Field | Description |
|-------|-------------|
| `Test ID` | Unique identifier (e.g., 1.1, 2.1) |
| `Test Name` | Descriptive name |
| `Domain` | Security domain (1–10) |
| `Status` | PASS / FAIL / WARN / INFO |
| `Severity` | Critical / High / Medium / Low |
| `Finding Detail` | Description of the security gap or confirmation |
| `Remediation` | Step-by-step fix instructions |

**Output:** `Report-CoCo-CLI-Security-Validation-<DD-MM-YYYY>.html`

Report contents:
- Report Generation Summary banner (TOP) with timestamp and elapsed time
- Executive summary with PASS/FAIL/WARN/INFO counts
- Official 10-item checklist with status badges
- Detailed test results per domain
- SQL query results for server-side tests
- CLI guidance for client-side tests
- Overall compliance score

### Phase 2 — Security Recommendations

Takes Phase 1 findings and produces a prioritized remediation plan:

| Priority | SLA | Description |
|----------|-----|-------------|
| **P0 — Critical** | Within 24 hours | Immediate action required |
| **P1 — High** | Within 7 days | Urgent remediation |
| **P2 — Medium** | Within 30 days | Scheduled remediation |
| **P3 — Low** | Within 90 days | Best-practice improvements |

Each recommendation includes:
- Finding reference (Test ID, domain, severity)
- Step-by-step remediation instructions with exact commands (SQL or CLI)
- Estimated remediation effort (Low / Medium / High)
- Risk context (what breaks if done incorrectly)
- Verification steps to confirm remediation success

**Output:** `Report-CoCo-CLI-Security-Recommendation-<DD-MM-YYYY>.html`

Report contents:
- Reference to source Phase 1 validation report
- Prioritized recommendation table (P0–P3)
- Detailed fix instructions per finding
- Estimated remediation effort
- Official checklist cross-reference
- Report Generation Summary banner (TOP) with elapsed time

### Phase 3 — Compliance Dashboard

Generates an interactive, self-contained HTML dashboard from Phases 1 and 2 data.

**Output:** `Report-CoCo-CLI-Compliance-Dashboard-<DD-MM-YYYY>.html`

Dashboard panels:
- **Domain Breakdown:** Finding count, completion percentage, and status for each of the 10 security domains
- **Priority Tracking:** Remediation timeline adherence for P0–P3 against SLA windows (24hr / 7d / 30d / 90d)
- **Official Checklist Panel:** 10-item checklist with PASS/FAIL/WARN/INFO badges and linked test references
- **Test Classification Panel:** SQL-Validated tests (6) vs CLI Guidance tests (7) with individual status badges
- **Visual Indicators:** Progress bars and/or charts per priority bucket, per domain, and overall
- **Risk Flagging:** Overdue or at-risk items where SLA deadlines are breached or within 48 hours of expiry
- **Overall Compliance Score:** Single composite percentage — `(PASS count / total testable items) × 100`
- **Technical:** Fully interactive, self-contained HTML, no external dependencies, print-friendly, executive-ready

---

## Test Domains Reference

### Domain 1 — Credential Security

**Tests:** 1.1 (PAT Expiration), 1.2 (Git Credential Exposure), 1.3 (File Permissions)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **1.1** | SQL | CRITICAL | PATs with lifetime > 90 days |
| **1.2** | Guidance | HIGH | .gitignore coverage for sensitive config files |
| **1.3** | Guidance | HIGH | 600/700 permissions on config files/directories |

**Key Principle:** Credentials should be short-lived (≤ 90 days), stored in environment variables (never in config files), and protected by filesystem permissions (600 for files, 700 for directories).

**Files to Protect:**
- `~/.snowflake/connections.toml` — Connection profiles with account details
- `~/.snowflake/cortex/permissions.json` — Persistent permission decisions
- `~/.snowflake/cortex/conversations/` — Chat history that may contain sensitive data
- `~/.snowflake/cortex/mcp.json` — MCP server configuration

**Test 1.1 SQL Query:**
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
- `TOTAL_LIFETIME_DAYS > 90` → **FAIL** (CRITICAL)
- `TOTAL_LIFETIME_DAYS > 60 AND <= 90` → **WARN** (MEDIUM)
- `TOTAL_LIFETIME_DAYS <= 60` → **PASS**
- `DAYS_UNTIL_EXPIRY < 7` → **WARN** (LOW)

**Test 1.2 CLI Verification:**
```bash
grep -c "connections.toml" .gitignore   # Expected: >= 1
```

Required .gitignore entries: `~/.snowflake/connections.toml`, `~/.snowflake/cortex/`, `.env`, `*.pem`, `*.key`

**Test 1.3 CLI Verification:**
```bash
stat -c '%a' ~/.snowflake/connections.toml    # Should be 600
stat -c '%a' ~/.snowflake/cortex              # Should be 700
stat -c '%a' ~/.snowflake/cortex/conversations # Should be 700
```

### Domain 2 — Role & Access Control

**Tests:** 2.1 (ACCOUNTADMIN Routine Usage), 2.2 (AI Function Role Separation)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **2.1** | SQL | HIGH | Non-admin queries executed under ACCOUNTADMIN |
| **2.2** | SQL | MEDIUM | Cortex AI functions executed under ACCOUNTADMIN |

**Key Principle:** Never use ACCOUNTADMIN for routine work. Create dedicated roles per workload type. Use multiple CLI connection profiles with different roles.

**Recommended Role Structure:**
```
ACCOUNTADMIN (admin tasks only)
├── SYSADMIN
│   ├── DEVELOPER (routine development)
│   ├── ETL_ROLE (pipeline operations)
│   └── AI_DEVELOPER (Cortex AI functions)
├── SECURITYADMIN
└── USERADMIN
```

**Test 2.1 Assessment Rules:**
- `QUERY_COUNT > 50` non-admin queries under ACCOUNTADMIN → **FAIL** (HIGH)
- `QUERY_COUNT 11-50` → **WARN** (MEDIUM)
- No results → **PASS**

**Test 2.2 Assessment Rules:**
- Any Cortex AI function calls under ACCOUNTADMIN → **WARN** (MEDIUM)
- No results → **PASS**

### Domain 3 — Conversation History Security

**Test:** 3.1 (Session History Assessment)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **3.1** | Guidance | MEDIUM | Conversation history size and sensitive content risk |

**Key Principle:** Use `cortex --private` for sensitive work. Clear sessions with `/clear`. Restrict directory permissions to 700.

**Privacy Modes:**
| Mode | Command | Behavior |
|------|---------|----------|
| Normal | `cortex` | Conversations saved to `~/.snowflake/cortex/conversations/` |
| Private | `cortex --private` | No conversation history saved |

### Domain 4 — MCP Server Security

**Test:** 4.1 (MCP Server Inventory)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **4.1** | Guidance | HIGH | Trusted MCP servers, no hardcoded credentials |

**Key Principle:** Only install trusted MCP servers. Never hardcode credentials — use environment variable references (`${VAR}` syntax).

**MCP Commands:**
| Command | Description |
|---------|-------------|
| `cortex mcp list` | List installed servers |
| `cortex mcp add <server>` | Add a server |
| `cortex mcp remove <server>` | Remove a server |

**Correct credential pattern:**
```json
{
  "mcpServers": {
    "github": {
      "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" }
    }
  }
}
```

### Domain 5 — Production Safety

**Test:** 5.1 (Destructive Operations Audit)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **5.1** | SQL | CRITICAL | DROP, TRUNCATE, DELETE operations in last 30 days |

**Key Principle:** Use planning mode (`/plan`) for production work. Reserve bypass mode for trusted development environments only.

**Cortex Code CLI Modes:**

| Mode | Icon | Behavior | Use Case |
|------|------|----------|----------|
| **Confirm** | Blue ⏵⏵ | Prompts before actions | Default — recommended |
| **Plan** | Orange ⏸ | Creates plan for review | Production work |
| **Bypass** | Red >> | Auto-approves all actions | Trusted development only |

**Mode switching:** Press `Shift-Tab` to cycle, or type `/plan`, `/bypass`, `/bypass-off`.

**Test 5.1 Assessment Rules:**
- `DROP_DATABASE` or `DROP_SCHEMA` found → **FAIL** (CRITICAL)
- `DROP_TABLE` or `TRUNCATE_TABLE` with ACCOUNTADMIN → **FAIL** (HIGH)
- `DELETE` under ACCOUNTADMIN → **WARN** (MEDIUM)
- No destructive operations → **PASS**

**Bypass Safety Override:**
```bash
export COCO_DANGEROUS_MODE_REQUIRE_SQL_WRITE_PERMISSION=true
```

### Domain 6 — Permission Model & Trust Levels

**Test:** 6.1 (SQL Write Operations Audit)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **6.1** | SQL | INFO | Volume and types of write operations |

**Key Principle:** Periodically audit permissions. Reset persistent permissions by deleting `~/.snowflake/cortex/permissions.json`. Use `/new` to reset session permission cache.

**Test 6.1 Assessment Rules:**
- High volume of write operations → **INFO** — Document for awareness
- No results → **PASS**

### Domain 7 — Sandbox Configuration

**Test:** 7.1 (Sandbox Enablement)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **7.1** | Guidance | HIGH | Sandbox enabled and properly configured |

**Key Principle:** Enable sandbox for command isolation. Configure filesystem and network restrictions. Use managed settings to enforce sandbox in enterprise environments.

**CLI Verification:**
```
/sandbox status               # Check current status
/sandbox runtime on           # Enable for session
```

### Domain 8 — Managed Settings (Enterprise Policy)

**Test:** 8.1 (Enterprise Policy Assessment)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **8.1** | Guidance | MEDIUM | Managed settings file presence and configuration |

**Key Principle:** Deploy managed settings via MDM/configuration management. Enforce sandbox, restrict accounts, and set minimum version requirements.

**File Locations:**
| OS | Path |
|----|------|
| macOS | `/Library/Application Support/Cortex/managed-settings.json` |
| Linux | `/etc/cortex/managed-settings.json` |
| Windows | `%ProgramData%\Cortex\managed-settings.json` |

### Domain 9 — Compromised Token Response Readiness

**Test:** 9.1 (Query History Audit Capability)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **9.1** | SQL | HIGH | Ability to audit query history for incident response |

**Key Principle:** Ensure QUERY_HISTORY is accessible for forensic analysis. Have a documented incident response procedure for compromised tokens.

**Incident Response Steps:**
1. IMMEDIATELY revoke the compromised PAT in Snowsight
2. Generate a new token (≤ 90-day expiration)
3. Store new token in environment variable (NOT config file)
4. Audit query history for suspicious activity
5. Look for: unusual query types, unexpected IPs, off-hours activity, data exports

**Test 9.1 Assessment Rules:**
- Query returns data → **PASS** — QUERY_HISTORY accessible
- Permission error → **FAIL** (HIGH) — Cannot audit in case of compromise

### Domain 10 — Hook Security & Policy Enforcement

**Test:** 10.1 (Hook Configuration)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **10.1** | Guidance | MEDIUM | Hook-based policy enforcement setup |

**Key Principle:** Use hooks to automate security policy enforcement. Implement PreToolUse hooks to block dangerous operations.

---

## Official Security Checklist Mapping

This maps the 10-item official Snowflake security checklist to skill test domains:

| # | Official Checklist Item | Test Domain | Test ID(s) | Validation Type |
|---|------------------------|-------------|------------|-----------------|
| 1 | Use PATs with at most a 90-day expiration | Credentials | 1.1 | SQL |
| 2 | Set file permissions to 600/700 | Credentials | 1.3 | Guidance |
| 3 | Never commit credentials to git | Credentials | 1.2 | Guidance |
| 4 | Use least privilege roles | Role & Access | 2.1, 2.2 | SQL |
| 5 | Never use ACCOUNTADMIN for routine work | Role & Access | 2.1 | SQL |
| 6 | Enable planning mode for production | Production Safety | 5.1 | SQL |
| 7 | Only install trusted MCP servers | MCP Security | 4.1 | Guidance |
| 8 | Store credentials in environment variables | Credentials | 1.2, 1.3 | Guidance |
| 9 | Use hooks to enforce policies | Hook Security | 10.1 | Guidance |
| 10 | Periodically audit permissions | Permission Model | 6.1 | SQL |

---

## Finding Severity Definitions

| Severity | Definition | SLA | Example Findings |
|----------|------------|-----|------------------|
| **CRITICAL** | Immediate risk of unauthorized access or data loss | Within 24 hours | PAT > 90 days, DROP DATABASE detected |
| **HIGH** | Significant security gap exploitable by an attacker | Within 7 days | ACCOUNTADMIN routine usage, sandbox disabled, MCP hardcoded creds, cannot audit |
| **MEDIUM** | Security weakness requiring scheduled remediation | Within 30 days | AI functions under admin, unmanaged history, no managed settings, no hooks |
| **LOW** | Best-practice improvement | Within 90 days | PAT expiring within 7 days |
| **INFO** | Informational guidance; no immediate action required | N/A | Write operations audit, client-side guidance |

---

## Priority Matrix

| Finding | Domain | Severity | Effort | Priority | Timeline |
|---------|--------|----------|--------|----------|----------|
| PAT lifetime > 90 days | Credentials | CRITICAL | Low | P0 | Immediate |
| DROP DATABASE/SCHEMA detected | Production Safety | CRITICAL | Low | P0 | Immediate |
| ACCOUNTADMIN 50+ routine queries | Role & Access | HIGH | Medium | P1 | 7 days |
| Sandbox not enabled | Sandbox | HIGH | Low | P1 | 7 days |
| MCP hardcoded credentials | MCP Security | HIGH | Low | P1 | 7 days |
| Cannot audit query history | Incident Response | HIGH | Low | P1 | 7 days |
| Credentials not in .gitignore | Credentials | HIGH | Low | P1 | 7 days |
| File permissions not 600/700 | Credentials | HIGH | Low | P1 | 7 days |
| AI functions under ACCOUNTADMIN | Role & Access | MEDIUM | Medium | P2 | 30 days |
| Conversation history unmanaged | History Security | MEDIUM | Low | P2 | 30 days |
| No managed settings (enterprise) | Enterprise Policy | MEDIUM | Medium | P2 | 30 days |
| No hook-based enforcement | Hooks | MEDIUM | Medium | P2 | 30 days |
| PAT expiring within 7 days | Credentials | LOW | Low | P3 | Before expiry |

---

## Cortex Code CLI Permission Model Reference

### Permission Types

| Permission | Scope | Description |
|------------|-------|-------------|
| `EXECUTE_COMMAND` | Local | Run bash/shell commands |
| `FILE_READ` | Local | Read file contents |
| `FILE_WRITE` | Local | Create new files |
| `FILE_EDIT` | Local | Modify existing files |
| `WEB_ACCESS` | Network | Web search and fetch operations |

### Permission Persistence

| Scope | Storage | Reset Method |
|-------|---------|-------------|
| **Session** | In-memory only | `/new` command or end session |
| **Persistent** | `~/.snowflake/cortex/permissions.json` | Delete the file |
| **Managed** | System-level managed settings file | IT admin / MDM |

---

## Cortex Code CLI Trust Levels Reference

### Tool Trust Levels

| Level | Examples | Behavior in Confirm Mode |
|-------|----------|-------------------------|
| **SAFE** | ls, cat, echo, grep, pwd | Auto-approved |
| **LOW** | touch file.txt, mkdir | Usually auto-approved |
| **MEDIUM** | Edit files, moderate bash | Prompts for confirmation |
| **HIGH** | rm, curl, wget, sudo | Always prompts |
| **CRITICAL** | rm -rf, destructive operations | Extra confirmation required |

### SQL Trust Levels

| Level | Operations | Behavior |
|-------|-----------|----------|
| **READ_ONLY** | SELECT, SHOW, DESCRIBE, EXPLAIN | Auto-approved |
| **WRITE** | INSERT, UPDATE, DELETE, CREATE, ALTER, DROP | Prompts for confirmation |
| **USE_ROLE** | USE ROLE, USE WAREHOUSE, USE DATABASE | Prompts for confirmation |

---

## Sandbox Configuration Reference

### Sandbox Modes

| Mode | Description |
|------|-------------|
| `regular` | Standard isolation with configurable filesystem and network rules |
| `strict` | Maximum isolation; no network, restricted filesystem |

### Configuration File

Location: `~/.snowflake/cortex/settings.json`

```json
{
  "sandbox": {
    "enabled": true,
    "mode": "regular",
    "allowUnsandboxedCommands": true,
    "filesystem": {
      "denyRead": ["/private/secrets"],
      "denyWrite": ["/etc", "/var", "~/.ssh"]
    },
    "network": {
      "deniedDomains": ["*.internal.company.com"]
    }
  }
}
```

### Built-In Protected Paths (Always Denied for Write)

| Category | Paths |
|----------|-------|
| Shell configs | `~/.bashrc`, `~/.zshrc`, `~/.profile`, `~/.bash_profile` |
| Git hooks | `~/.git/hooks`, `.git/hooks` |
| SSH config | `~/.ssh/authorized_keys`, `~/.ssh/config` |
| Managed settings | OS-specific managed settings directory |

### Sandbox Commands

| Command | Description |
|---------|-------------|
| `/sandbox status` | Show current sandbox status |
| `/sandbox runtime on` | Enable sandbox for current session |
| `/sandbox runtime off` | Disable sandbox for current session |

---

## Managed Settings Reference

### File Locations

| OS | Path |
|----|------|
| **macOS** | `/Library/Application Support/Cortex/managed-settings.json` |
| **Linux** | `/etc/cortex/managed-settings.json` |
| **Windows** | `%ProgramData%\Cortex\managed-settings.json` |

### Configuration Schema

```json
{
  "version": "1.0",
  "permissions": {
    "dangerouslyAllowAll": false,
    "defaultMode": "allow",
    "onlyAllow": ["account(mycompany-prod)", "account(mycompany-staging)"]
  },
  "settings": {
    "forceSandboxEnabled": true,
    "forceSandboxMode": "regular",
    "forceNoHistoryMode": true
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

### Key Settings

| Setting | Purpose | Recommended Value |
|---------|---------|-------------------|
| `dangerouslyAllowAll` | Auto-approve all permissions | `false` |
| `forceSandboxEnabled` | Force sandbox on all users | `true` |
| `forceSandboxMode` | Lock sandbox mode | `"regular"` |
| `forceNoHistoryMode` | Disable conversation saving | `true` for compliance |
| `onlyAllow` | Restrict to specific accounts | List of account identifiers |
| `minimumVersion` | Enforce minimum CLI version | Latest stable version |

---

## Hook Events Reference

### Available Events

| Event | Timing | Can Block? | Use Case |
|-------|--------|-----------|----------|
| `PreToolUse` | Before tool execution | Yes | Validate commands, block dangerous ops |
| `PostToolUse` | After tool execution | No | Logging, auditing |
| `PermissionRequest` | When permission needed | Yes | Custom approval logic |
| `UserPromptSubmit` | When user submits prompt | Yes | Content filtering |
| `SessionStart` | Session begins | No | Setup, initialization |
| `SessionEnd` | Session ends | No | Cleanup, audit logging |

### Tool Matchers

| Pattern | Matches |
|---------|---------|
| `"Bash"` | Only Bash commands |
| `"Edit\|Write"` | Edit or Write operations |
| `"mcp__.*"` | All MCP tool calls |
| `"SQL*"` | All SQL tools |
| `"*"` | All tools |

### Hook Script Return Format

| Method | Allow | Block |
|--------|-------|-------|
| **Exit code** | `0` | `2` |
| **JSON** | `{"decision": "allow", "systemMessage": "Validated"}` | `{"decision": "block", "reason": "Blocked by policy"}` |

### Configuration Priority (Highest to Lowest)

| Priority | Path | Scope |
|----------|------|-------|
| 1 | `.cortex/settings.local.json` | Local project (git-ignored) |
| 2 | `.cortex/settings.json` | Project (shared) |
| 3 | `~/.claude/settings.json` | User |
| 4 | `~/.snowflake/cortex/hooks.json` | Global |

---

## Report Specifications

### Report File Inventory

| Phase | Filename Pattern | Description |
|-------|-----------------|-------------|
| Phase 1 | `Report-CoCo-CLI-Security-Validation-DD-MM-YYYY.html` | Assessment findings across all 10 domains |
| Phase 2 | `Report-CoCo-CLI-Security-Recommendation-DD-MM-YYYY.html` | Prioritized recommendations with fixes |
| Phase 3 | `Report-CoCo-CLI-Compliance-Dashboard-DD-MM-YYYY.html` | Interactive compliance tracking dashboard |

All reports saved to: `coco-security-bestpractice-cli/reports/`

### Phase 1 Report Sections

1. Report Generation Summary banner (TOP) — timestamp, elapsed time, role, account
2. Executive Summary — overall compliance score, PASS/FAIL/WARN/INFO counts
3. Official Checklist Status — 10-item checklist with color-coded badges
4. Detailed Test Results — per-domain findings with severity, detail, remediation
5. SQL-Validated Tests — query results for Tests 1.1, 2.1, 2.2, 5.1, 6.1, 9.1
6. CLI-Side Guidance — consolidated local checks for Tests 1.2, 1.3, 3.1, 4.1, 7.1, 8.1, 10.1
7. Compliance Score — `(PASS count / total testable items) × 100`

### Phase 2 Report Sections

1. Report Generation Summary banner (TOP) — elapsed time
2. Reference to source Phase 1 validation report
3. Prioritized recommendation table (P0–P3) across all domains
4. Detailed fix instructions per finding (SQL or CLI commands)
5. Estimated remediation effort per finding
6. Official checklist cross-reference
7. Self-Healing Summary (if any queries were corrected)

### Phase 3 Dashboard Panels

1. Domain Breakdown — finding count, completion %, status per domain
2. Priority Tracking — P0–P3 SLA adherence
3. Official Checklist Panel — 10 items with badges
4. Test Classification — SQL-Validated (6) vs CLI Guidance (7)
5. Visual Indicators — progress bars/charts
6. Risk Flagging — overdue/at-risk items
7. Overall Compliance Health Score

### Severity Badges

| Color | Status |
|-------|--------|
| Red | CRITICAL |
| Orange | HIGH |
| Yellow | MEDIUM |
| Blue | LOW |
| Green | PASS |
| Gray | INFO |

### HTML Requirements

- Self-contained, no external dependencies
- Professional styling with consistent design
- Color-coded severity badges
- Print-friendly layout
- Executive-ready presentation
- Responsive tables with hover effects

---

## Execution Rules

| # | Rule |
|---|------|
| 1 | Run all three phases strictly sequentially — do not skip, merge, or parallelize |
| 2 | Execute ALL 10 test domains during Phase 1 — none may be skipped |
| 3 | Capture and prominently display total elapsed time for Phase 1 and Phase 2 individually |
| 4 | Substitute `<DD-MM-YYYY>` with today's actual date in all filenames |
| 5 | All HTML reports must be professionally styled, print-friendly, and stakeholder-ready |
| 6 | No DDL, DML, or configuration changes — assessment and documentation only |
| 7 | Save all reports exclusively to `coco-security-bestpractice-cli/reports/` |
| 8 | Display "Report Generation Summary" banner at TOP of each phase report |
| 9 | Use color-coded severity badges: Red=CRITICAL, Orange=HIGH, Yellow=MEDIUM, Blue=LOW, Green=PASS, Gray=INFO |

---

## Error Handling & Self-Healing

The skill includes a built-in self-healing mechanism for query failures.

### How It Works

1. **Auto-Recovery:** If any SQL query or workflow step fails, the skill does not halt. It automatically diagnoses the root cause, applies the appropriate fix, and retries.

2. **Inline Logging:** For every failed-and-recovered step, the skill logs within the relevant phase report:
   - Step name / query identifier that failed
   - Exact error message received from Snowflake
   - Root cause diagnosis
   - Corrective fix applied
   - Retry outcome (Success / Failed after retry)

3. **Skill File Updates:** When a query failure is successfully resolved, the corrected query is written back to the SKILL.md file with an inline comment:
   ```sql
   -- [FIXED on <DD-MM-YYYY>]: <concise description of what was corrected and why>
   ```

4. **Graceful Degradation:** If a step fails and cannot be recovered after retry, it is marked as **SKIPPED** with a clear root cause explanation. The skill continues with remaining steps and flags the skipped item under a "Manual Review Required" section.

5. **Self-Healing Summary:** All self-healing actions are consolidated into a dedicated "Self-Healing Summary" section appended to the Phase 1 and Phase 2 reports.

### Failure Response Flow

```
Query Fails ──► Diagnose Root Cause ──► Apply Fix ──► Retry
                                                        │
                                         ┌──────────────┤
                                         ▼              ▼
                                      Success        Failed Again
                                         │              │
                                  Log & Continue    Mark SKIPPED
                                                        │
                                              Flag in "Manual Review
                                              Required" section
```

---

## Data Sources

All queries are read-only and target the following Snowflake system views:

| View / Command | Test ID | Purpose | Lookback |
|----------------|---------|---------|----------|
| `SNOWFLAKE.ACCOUNT_USAGE.PROGRAMMATIC_ACCESS_TOKENS` | 1.1 | PAT inventory and expiration audit | All active tokens |
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` | 2.1 | ACCOUNTADMIN routine usage detection | 30 days |
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` | 2.2 | AI function role separation | 30 days |
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` | 5.1 | Destructive operations audit | 30 days |
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` | 6.1 | SQL write operations audit | 30 days |
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` | 9.1 | Query history audit capability | 7 days |

**Note:** `ACCOUNT_USAGE` views have up to 45-minute latency. Client-side tests (1.2, 1.3, 3.1, 4.1, 7.1, 8.1, 10.1) require local CLI access to validate and cannot be verified remotely from a Workspace.

---

## Post-Run Monitoring

After reviewing reports and applying remediation, establish ongoing monitoring.

### Key Metrics to Track Monthly

| Metric | Target | Alert If |
|--------|--------|----------|
| PAT maximum lifetime | ≤ 90 days | Any token > 90 days |
| ACCOUNTADMIN routine query count | 0 | Any non-admin query under ACCOUNTADMIN |
| Destructive operations under admin | 0 | Any DROP/TRUNCATE under ACCOUNTADMIN |
| Active PATs nearing expiry | Planned rotation | Any PAT within 7 days of expiry |
| MCP server inventory | All trusted | Unknown server appears |

### Recommended Re-Run Cadence

| Scenario | Frequency |
|----------|-----------|
| Standard environments | Monthly |
| After team onboarding (new CLI users) | On-demand |
| After security incidents or PAT compromise | Immediately |
| Enterprise compliance reviews | Quarterly |
| After MCP server or hook configuration changes | On-demand |

---

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| Permission errors on ACCOUNT_USAGE | Insufficient role | Switch to ACCOUNTADMIN |
| PROGRAMMATIC_ACCESS_TOKENS view not found | View may not be available in older accounts | Skip Test 1.1; report as INFO |
| Query returns 0 rows for ACCOUNTADMIN usage | No admin queries in last 30 days | Report Test 2.1 as PASS |
| Cannot verify .gitignore from Workspace | Workspace cannot access local filesystem | Report as INFO with CLI guidance |
| Sandbox status unknown from Workspace | Sandbox is a local CLI feature | Report as INFO with CLI guidance |
| Managed settings cannot be verified remotely | OS-level file on user's machine | Report as INFO with guidance |
| Report not appearing | Path mismatch | Verify `coco-security-bestpractice-cli/reports/` exists |
| Self-healing loop | Query cannot be fixed automatically | Marked as SKIPPED; check "Manual Review Required" section |
| HTML report looks broken | Browser compatibility | Use modern browser (Chrome, Firefox, Edge) |

---

## Frequently Asked Questions

### Q: Do I need ACCOUNTADMIN to run this validator?

**A:** Yes, for the SQL-validated tests (1.1, 2.1, 2.2, 5.1, 6.1, 9.1). The client-side guidance tests are documentation-only and don't require any specific role.

### Q: Will this skill make any changes to my account?

**A:** No. All queries are read-only (SELECT, SHOW). All remediation steps are provided as documentation only — nothing is executed automatically.

### Q: Why are some tests marked as INFO instead of PASS/FAIL?

**A:** Tests that require local filesystem access (file permissions, .gitignore, sandbox config, MCP config, managed settings, hooks) cannot be validated from a Snowsight Workspace. They are reported as INFO with step-by-step CLI commands to run locally.

### Q: How is the compliance score calculated?

**A:** `(PASS count / total testable items) × 100`. The score is displayed in Phase 1 and tracked in the Phase 3 Compliance Dashboard.

### Q: How many reports are generated?

**A:** Three reports, generated sequentially:
1. **Assessment** — Phase 1 findings across all 10 domains
2. **Recommendations** — Phase 2 prioritized remediation plan (P0–P3)
3. **Compliance Dashboard** — Phase 3 interactive tracking with health score

### Q: How often should I run this validation?

**A:** Recommended cadence:
- **Monthly:** Standard for most environments
- **After onboarding:** When new team members set up Cortex Code CLI
- **After incidents:** Following any security event or PAT compromise
- **Quarterly:** For enterprise compliance reviews

### Q: What is the most critical finding?

**A:** PATs with lifetime > 90 days (Test 1.1) and DROP DATABASE/SCHEMA operations (Test 5.1) are both CRITICAL (P0). PATs should be rotated immediately; destructive operations indicate bypass mode may be in use without safeguards.

### Q: Can I use this skill from the Cortex Code CLI itself?

**A:** The SQL-validated tests work from both Workspace and CLI contexts. The client-side guidance tests provide commands you can run directly in your terminal to complete the validation.

### Q: What is the difference between sandbox and managed settings?

**A:** Sandbox isolates command execution within the CLI session (per-user control via `~/.snowflake/cortex/settings.json`). Managed settings are system-level policies deployed by IT administrators (via OS-specific paths) that enforce sandbox, restrict accounts, and set minimum version requirements across all users on a machine.

### Q: How do I reset all persistent permissions?

**A:** Delete `~/.snowflake/cortex/permissions.json`. Use `/new` in the CLI to reset session-level permissions without deleting the file.

### Q: What should I do if a PAT is compromised?

**A:** Immediately: (1) Revoke the PAT in Snowsight, (2) Generate a new token ≤ 90 days, (3) Audit `QUERY_HISTORY` for suspicious activity, (4) Look for unusual query types, unexpected IPs, off-hours activity, and data export operations.

### Q: What happens if a query fails during the assessment?

**A:** The self-healing mechanism auto-diagnoses, fixes, and retries. If recovery fails, the query is marked as SKIPPED with error details and flagged under "Manual Review Required." The assessment continues with remaining tests.

### Q: Where are the reports saved?

**A:** All HTML reports are saved to `coco-security-bestpractice-cli/reports/` in the workspace. File names include the execution date (DD-MM-YYYY format) for version tracking.
