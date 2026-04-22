# Cortex Code CLI — Security Best Practices Validator Documentation

**Author:** Rajiv Gupta
**LinkedIn:** [https://www.linkedin.com/in/rajiv-gupta-618b0228/](https://www.linkedin.com/in/rajiv-gupta-618b0228/)
**Version:** 1.0
**Last Updated:** April 22, 2026
**Reference:** https://docs.snowflake.com/en/user-guide/cortex-code/security

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Test Domains Reference](#test-domains-reference)
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
6. [Official Security Checklist Mapping](#official-security-checklist-mapping)
7. [Finding Severity Definitions](#finding-severity-definitions)
8. [Priority Matrix](#priority-matrix)
9. [Cortex Code CLI Permission Model Reference](#cortex-code-cli-permission-model-reference)
10. [Cortex Code CLI Trust Levels Reference](#cortex-code-cli-trust-levels-reference)
11. [Sandbox Configuration Reference](#sandbox-configuration-reference)
12. [Managed Settings Reference](#managed-settings-reference)
13. [Hook Events Reference](#hook-events-reference)
14. [Report Specifications](#report-specifications)
15. [Data Sources](#data-sources)
16. [Troubleshooting](#troubleshooting)
17. [Frequently Asked Questions](#frequently-asked-questions)

---

## Overview

The **Cortex Code CLI Security Best Practices Validator** is a Cortex Code skill that assesses a Snowflake account's compliance with the official Cortex Code CLI security best practices. It validates 10 security domains through a combination of SQL-based queries (for server-side checks) and documented guidance (for client-side checks).

### Key Capabilities

- Validates 10 security domains covering credentials, RBAC, conversation history, MCP servers, production safety, permissions, sandbox, managed settings, incident response, and hooks.
- Executes 6 SQL queries for server-side validation (PAT expiration, ACCOUNTADMIN usage, AI role separation, destructive operations, write operations, audit readiness).
- Provides 7 client-side guidance assessments for local filesystem checks (git ignore, file permissions, conversation history, MCP config, sandbox, managed settings, hooks).
- Maps all tests to the official 10-item Snowflake security checklist.
- Produces a single self-contained HTML report with compliance score.

### What This Skill Does NOT Do

- It does **not** execute any DDL, DML, or configuration changes.
- It does **not** modify account settings, tokens, roles, or local files.
- Client-side checks (file permissions, .gitignore, sandbox config) are reported as guidance — the skill cannot access the local filesystem from a Workspace context.

### Test Classification

| Type | Count | Description |
|------|-------|-------------|
| **SQL-Validated** | 6 tests | Server-side checks via ACCOUNT_USAGE queries (Tests 1.1, 2.1, 2.2, 5.1, 6.1, 9.1) |
| **CLI Guidance** | 7 tests | Client-side checks with documented verification steps (Tests 1.2, 1.3, 3.1, 4.1, 7.1, 8.1, 10.1) |

---

## Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│             Cortex Code CLI Security Best Practices Validator          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  SQL-VALIDATED TESTS (Server-Side)                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │ Test 1.1 │ │ Test 2.1 │ │ Test 2.2 │ │ Test 5.1 │ │ Test 6.1 │   │
│  │ PAT Exp  │ │ Admin Use│ │ AI Role  │ │ Destruct │ │ Write Ops│   │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘   │
│       │             │            │             │             │         │
│  ┌────┴─────┐       │            │             │             │         │
│  │ Test 9.1 │       │            │             │             │         │
│  │ Audit    │       │            │             │             │         │
│  │ Readiness│       │            │             │             │         │
│  └────┬─────┘       │            │             │             │         │
│       └─────────────┴────────────┴─────────────┴─────────────┘        │
│                          │                                             │
│  CLI GUIDANCE TESTS (Client-Side)                                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │ Test 1.2 │ │ Test 1.3 │ │ Test 3.1 │ │ Test 4.1 │ │ Test 7.1 │   │
│  │ Git Cred │ │ File Perm│ │ History  │ │ MCP Srvr │ │ Sandbox  │   │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘   │
│       │             │            │             │             │         │
│  ┌────┴─────┐ ┌────┴─────┐      │             │             │         │
│  │ Test 8.1 │ │ Test 10.1│      │             │             │         │
│  │ Managed  │ │ Hooks    │      │             │             │         │
│  │ Settings │ │ Policy   │      │             │             │         │
│  └────┬─────┘ └────┬─────┘      │             │             │         │
│       └─────────────┴────────────┴─────────────┘             │         │
│                          │                                    │         │
│                          ▼                                    │         │
│            ┌──────────────────────────────────┐               │         │
│            │  Combined Assessment Results     │◄──────────────┘         │
│            └─────────────┬────────────────────┘                         │
│                          │                                              │
│                          ▼                                              │
│            ┌──────────────────────────────────┐                         │
│            │  HTML Report                     │                         │
│            │  · Compliance Score              │                         │
│            │  · Official Checklist Status     │                         │
│            │  · Detailed Test Results         │                         │
│            │  · Remediation Priority Matrix   │                         │
│            └──────────────────────────────────┘                         │
│                                                                         │
│  Report → coco-security-bestpractice-cli/reports/                      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| **Snowflake Role** | `ACCOUNTADMIN` (required for `SNOWFLAKE.ACCOUNT_USAGE` views) |
| **Warehouse** | Any active warehouse (X-SMALL sufficient) |
| **Data Latency** | `ACCOUNT_USAGE` views have up to 45-minute delay |
| **Lookback Window** | 30 days for SQL-validated tests; 7 days for incident response test |

### Workspace Setup

```
coco-security-bestpractice-cli/
├── SKILL.md                          # Skill definition
├── documentation/
│   └── coco-security-bestpractice-cli-doc.md  # This file
└── reports/
    └── Report-CoCo-CLI-Security-Validation-<DD-MM-YYYY>.html
```

---

## Quick Start

1. Open Snowsight Workspace containing this skill.
2. Use **ACCOUNTADMIN** role.
3. Invoke the skill:
   > "Run the CoCo CLI security validation"
4. Review the generated HTML report in `coco-security-bestpractice-cli/reports/`.
5. Follow CLI Guidance sections to complete client-side checks locally.

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

### Domain 2 — Role & Access Control

**Tests:** 2.1 (ACCOUNTADMIN Routine Usage), 2.2 (AI Function Role Separation)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **2.1** | SQL | HIGH | Non-admin queries executed under ACCOUNTADMIN |
| **2.2** | SQL | MEDIUM | Cortex AI functions executed under ACCOUNTADMIN |

**Key Principle:** Never use ACCOUNTADMIN for routine work. Create dedicated roles per workload type (developer, analyst, AI developer). Use multiple CLI connection profiles with different roles.

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

### Domain 3 — Conversation History Security

**Test:** 3.1 (Session History Assessment)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **3.1** | Guidance | MEDIUM | Conversation history size and sensitive content risk |

**Key Principle:** Use `cortex --private` for sensitive work. Clear sessions with `/clear`. Restrict directory permissions to 700.

**Privacy Modes:**
- `cortex` — Normal mode; conversations saved to `~/.snowflake/cortex/conversations/`
- `cortex --private` — Private mode; no conversation history saved

### Domain 4 — MCP Server Security

**Test:** 4.1 (MCP Server Inventory)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **4.1** | Guidance | HIGH | Trusted MCP servers, no hardcoded credentials |

**Key Principle:** Only install trusted MCP servers. Never hardcode credentials in MCP config — use environment variable references (`${VAR}` syntax).

**MCP Commands:**
- `cortex mcp list` — List installed servers
- `cortex mcp add <server>` — Add a server
- `cortex mcp remove <server>` — Remove a server

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

### Domain 6 — Permission Model & Trust Levels

**Test:** 6.1 (SQL Write Operations Audit)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **6.1** | SQL | INFO | Volume and types of write operations |

**Key Principle:** Periodically audit permissions. Reset persistent permissions by deleting `~/.snowflake/cortex/permissions.json`. Use `/new` to reset session permission cache.

### Domain 7 — Sandbox Configuration

**Test:** 7.1 (Sandbox Enablement)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **7.1** | Guidance | HIGH | Sandbox enabled and properly configured |

**Key Principle:** Enable sandbox for command isolation. Configure filesystem and network restrictions. Use managed settings to enforce sandbox in enterprise environments.

### Domain 8 — Managed Settings (Enterprise Policy)

**Test:** 8.1 (Enterprise Policy Assessment)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **8.1** | Guidance | MEDIUM | Managed settings file presence and configuration |

**Key Principle:** Deploy managed settings via MDM/configuration management. Enforce sandbox, restrict accounts, and set minimum version requirements.

### Domain 9 — Compromised Token Response Readiness

**Test:** 9.1 (Query History Audit Capability)

| Test | Type | Severity | What It Checks |
|------|------|----------|----------------|
| **9.1** | SQL | HIGH | Ability to audit query history for incident response |

**Key Principle:** Ensure QUERY_HISTORY is accessible for forensic analysis. Have a documented incident response procedure for compromised tokens.

**Incident Response Steps:**
1. Revoke the compromised PAT immediately
2. Generate a new token (≤ 90-day expiration)
3. Audit query history for suspicious activity
4. Look for: unusual query types, unexpected IPs, off-hours activity, data exports

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

| Severity | Definition | SLA |
|----------|------------|-----|
| **CRITICAL** | Immediate risk of unauthorized access or data loss | Within 24 hours |
| **HIGH** | Significant security gap exploitable by an attacker | Within 7 days |
| **MEDIUM** | Security weakness requiring scheduled remediation | Within 30 days |
| **LOW** | Best-practice improvement | Within 90 days |
| **INFO** | Informational guidance; no immediate action required | N/A |

---

## Priority Matrix

| Finding | Domain | Severity | Effort | Timeline |
|---------|--------|----------|--------|----------|
| PAT lifetime > 90 days | Credentials | CRITICAL | Low | Immediate |
| DROP DATABASE/SCHEMA operations detected | Production Safety | CRITICAL | Low | Immediate |
| ACCOUNTADMIN used for 50+ routine queries | Role & Access | HIGH | Medium | 7 days |
| Sandbox not enabled | Sandbox | HIGH | Low | 7 days |
| MCP servers with hardcoded credentials | MCP Security | HIGH | Low | 7 days |
| Cannot audit query history | Incident Response | HIGH | Low | 7 days |
| Credentials not in .gitignore | Credentials | HIGH | Low | 7 days |
| Config file permissions not 600/700 | Credentials | HIGH | Low | 7 days |
| Cortex AI functions under ACCOUNTADMIN | Role & Access | MEDIUM | Medium | 30 days |
| Conversation history unmanaged | History Security | MEDIUM | Low | 30 days |
| No managed settings (enterprise) | Enterprise Policy | MEDIUM | Medium | 30 days |
| No hook-based policy enforcement | Hooks | MEDIUM | Medium | 30 days |
| PAT expiring within 7 days | Credentials | LOW | Low | Before expiry |

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

```json
// Block an operation
{"decision": "block", "reason": "Operation blocked by corporate policy"}

// Allow with message
{"decision": "allow", "systemMessage": "Validated by security hook"}
```

Exit codes: `0` = allow, `2` = block.

### Configuration Priority (Highest to Lowest)

1. `.cortex/settings.local.json` (local project)
2. `.cortex/settings.json` (project)
3. `~/.claude/settings.json` (user)
4. `~/.snowflake/cortex/hooks.json` (global)

---

## Report Specifications

| Property | Value |
|----------|-------|
| **Filename** | `Report-CoCo-CLI-Security-Validation-<DD-MM-YYYY>.html` |
| **Location** | `coco-security-bestpractice-cli/reports/` |
| **Format** | Self-contained HTML, no external dependencies |

### Report Sections

1. **Report Generation Summary** — Timestamp, elapsed time, role, account
2. **Executive Summary** — Overall compliance score, PASS/FAIL/WARN/INFO counts
3. **Official Checklist Status** — 10-item checklist with color-coded badges
4. **Detailed Test Results** — Per-domain findings with severity, detail, and remediation
5. **SQL-Validated Tests** — Query results for Tests 1.1, 2.1, 2.2, 5.1, 6.1, 9.1
6. **CLI-Side Guidance** — Consolidated local checks for Tests 1.2, 1.3, 3.1, 4.1, 7.1, 8.1, 10.1
7. **Remediation Priority Matrix** — Findings sorted CRITICAL → HIGH → MEDIUM → LOW
8. **Compliance Score** — `(PASS count / total testable items) × 100`

### Severity Badges

| Color | Severity |
|-------|----------|
| Red | CRITICAL |
| Orange | HIGH |
| Yellow | MEDIUM |
| Blue | LOW |
| Green | PASS |
| Gray | INFO |

---

## Data Sources

| View / Command | Test ID | Purpose |
|----------------|---------|---------|
| `SNOWFLAKE.ACCOUNT_USAGE.PROGRAMMATIC_ACCESS_TOKENS` | 1.1 | PAT inventory and expiration audit |
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` | 2.1, 2.2, 5.1, 6.1, 9.1 | Query activity by role, type, and user |

**Note:** `ACCOUNT_USAGE` views have up to 45-minute latency. Client-side tests (1.2, 1.3, 3.1, 4.1, 7.1, 8.1, 10.1) require local CLI access to validate.

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

---

## Frequently Asked Questions

### Q: Do I need ACCOUNTADMIN to run this validator?

**A:** Yes, for the SQL-validated tests (1.1, 2.1, 2.2, 5.1, 6.1, 9.1). The client-side guidance tests are documentation-only and don't require any specific role.

### Q: Will this skill make any changes to my account?

**A:** No. All queries are read-only (SELECT, SHOW). All remediation steps are provided as documentation only.

### Q: Why are some tests marked as INFO instead of PASS/FAIL?

**A:** Tests that require local filesystem access (file permissions, .gitignore, sandbox config, MCP config, managed settings, hooks) cannot be validated from a Snowsight Workspace. They are reported as INFO with step-by-step CLI commands to run locally.

### Q: How is the compliance score calculated?

**A:** `(PASS count / total SQL-testable items) × 100`. INFO items (client-side guidance) are excluded from the score but included in the report for completeness.

### Q: How often should I run this validation?

**A:** Recommended cadence:
- **Monthly:** Standard for most environments
- **After onboarding:** When new team members set up Cortex Code CLI
- **After incidents:** Following any security event or PAT compromise
- **Quarterly:** For enterprise compliance reviews

### Q: What is the most critical finding?

**A:** PATs with lifetime > 90 days (Test 1.1) and DROP DATABASE/SCHEMA operations (Test 5.1) are both CRITICAL. PATs should be rotated immediately; destructive operations indicate bypass mode may be in use without safeguards.

### Q: Can I use this skill from the Cortex Code CLI itself?

**A:** The SQL-validated tests work from both Workspace and CLI contexts. The client-side guidance tests provide commands you can run directly in your terminal to complete the validation.

### Q: What is the difference between sandbox and managed settings?

**A:** Sandbox isolates command execution within the CLI session (per-user control). Managed settings are system-level policies deployed by IT administrators that enforce sandbox, restrict accounts, and set minimum version requirements across all users on a machine.

### Q: How do I reset all persistent permissions?

**A:** Delete `~/.snowflake/cortex/permissions.json`. Use `/new` in the CLI to reset session-level permissions without deleting the file.

### Q: What should I do if a PAT is compromised?

**A:** Immediately: (1) Revoke the PAT in Snowsight, (2) Generate a new token ≤ 90 days, (3) Audit `QUERY_HISTORY` for suspicious activity, (4) Look for unusual query types, unexpected IPs, off-hours activity, and data export operations.
