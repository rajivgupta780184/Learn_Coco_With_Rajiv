# Security Policy Skill - Documentation

**Skill Name:** `security-policy`
**Version:** 1.0
**Location:** `.snowflake/cortex/skills/security-policy/SKILL.md`
**Author:** Workspace Administrator
**Last Updated:** April 21, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Purpose](#purpose)
3. [Skill Trigger Mechanism](#skill-trigger-mechanism)
4. [Policy Domains](#policy-domains)
   - [Data Export Restrictions](#1-data-export-restrictions)
   - [Allowed Actions](#2-allowed-actions)
   - [Role and Access Controls](#3-role-and-access-controls)
   - [Sensitive Data Handling](#4-sensitive-data-handling)
   - [Query Safety](#5-query-safety)
   - [Prohibited Operations](#6-prohibited-operations)
5. [Trigger Keywords Reference](#trigger-keywords-reference)
6. [Compliance and Auditing](#compliance-and-auditing)
7. [Limitations](#limitations)
8. [Recommendations for Platform-Level Enforcement](#recommendations-for-platform-level-enforcement)

---

## Overview

The `security-policy` skill is a Cortex Code client-side skill that acts as a security guardrail within Snowflake Snowsight Workspaces. It defines a set of rules and restrictions that Cortex Code (the AI coding assistant) should follow when assisting users, with the goal of preventing data leakage, privilege escalation, destructive operations, and exposure of sensitive information.

## Purpose

This skill addresses the following organizational security concerns:

| Concern | Protection |
|---|---|
| **Data Exfiltration** | Blocks export of query results to any file format or external location |
| **Privilege Escalation** | Prevents unauthorized role switching or grant modifications |
| **Destructive Operations** | Requires explicit confirmation before DROP, DELETE, or TRUNCATE |
| **PII Exposure** | Prevents display or storage of unmasked personally identifiable information |
| **Credential Leakage** | Blocks sharing of passwords, API keys, tokens, and secrets |
| **Security Bypass** | Prevents use of dynamic SQL or temporary objects to circumvent access controls |

## Skill Trigger Mechanism

### How It Works

The skill is registered as a client-side skill at the path:

```
.snowflake/cortex/skills/security-policy/SKILL.md
```

Cortex Code discovers skills in the `.snowflake/cortex/skills/` directory. When a user's query matches keywords in the skill's `description` field (defined in the YAML frontmatter), the skill is invoked and its instructions are loaded into the assistant's context.

### Frontmatter Configuration

```yaml
---
name: security-policy
description: "Check before any SQL query, data export, file creation, file write,
  CSV, JSON, Parquet, Excel, XML export, COPY INTO, download, role change, USE ROLE,
  privilege escalation, DROP, DELETE, TRUNCATE, CREATE OR REPLACE, grant, revoke,
  PII access, sensitive data, unmasked data, masking policy, password, API key, secret,
  credential, dynamic SQL, temporary object, data exfiltration, bypass security,
  circumvent access, connection token, query results to file, save data, write data,
  export data, extract data, dump data, backup data"
---
```

The description is intentionally broad to maximize the likelihood of matching across a wide range of security-relevant user requests.

---

## Policy Domains

### 1. Data Export Restrictions

**Severity: CRITICAL**

All data export operations are strictly prohibited. This is the highest-priority rule in the policy.

**Blocked Actions:**

| Action | Example |
|---|---|
| File export | Writing query results to CSV, JSON, Parquet, Excel, XML, TXT |
| Workspace file creation with data | Using the `write` tool to save query output |
| Stage export | `COPY INTO @stage` commands |
| Download links | Generating any downloadable file containing data |
| Circumvention attempts | Any creative workaround to export data |

**Response Protocol:** If a user requests data export, the assistant must politely decline and cite organizational policy.

### 2. Allowed Actions

The following actions are explicitly permitted under this policy:

- **Display results in chat** - Query results may be shown inline in the conversation interface (with reasonable row limits)
- **Write SQL code files** - `.sql` files containing query logic (not data) may be created
- **Create documentation** - Markdown, notebooks, and code files that do not contain exported data

### 3. Role and Access Controls

**Principle:** Operate within the user's current role permissions at all times.

| Rule | Detail |
|---|---|
| No privilege escalation | Never switch to higher-privileged roles |
| No unauthorized USE ROLE | Only execute `USE ROLE` when explicitly requested by the user |
| Respect masking policies | Honor all column-level and row-level access controls |
| No grant modifications | Do not alter grants, roles, or access control configurations |

### 4. Sensitive Data Handling

**Principle:** Protect all personally identifiable information (PII) and credentials.

**Protected Data Types:**
- Social Security Numbers (SSN)
- Full credit card numbers
- Passwords and passphrases
- API keys and tokens
- Connection credentials

**Rules:**
- Never display, log, or store unmasked PII
- Do not reverse-engineer or bypass masking policies
- Do not use alternative queries to expose masked data
- Proactively warn users if their request could expose sensitive data

### 5. Query Safety

**Principle:** Prevent accidental or unauthorized destructive changes to data and objects.

| Operation | Requirement |
|---|---|
| `DROP` | Explicit user confirmation required |
| `TRUNCATE` | Explicit user confirmation required |
| `DELETE` | Explicit user confirmation required |
| `CREATE OR REPLACE` on production objects | Explicit user confirmation required |
| Large unbounded queries | Must include `LIMIT` clauses |

### 6. Prohibited Operations

The following operations are unconditionally blocked:

- **Data exfiltration** to external services or URLs
- **Dynamic SQL execution** that could bypass security controls
- **Temporary object creation** designed to circumvent access restrictions
- **Credential sharing** including connection tokens, passwords, or API keys

---

## Trigger Keywords Reference

The following keywords are configured in the skill description to maximize matching:

| Category | Keywords |
|---|---|
| **Data Export** | data export, file creation, file write, CSV, JSON, Parquet, Excel, XML export, COPY INTO, download, query results to file, save data, write data, export data, extract data, dump data, backup data |
| **Role & Access** | role change, USE ROLE, privilege escalation, grant, revoke |
| **Destructive DDL** | DROP, DELETE, TRUNCATE, CREATE OR REPLACE |
| **Sensitive Data** | PII access, sensitive data, unmasked data, masking policy, password, API key, secret, credential, connection token |
| **Security Bypass** | dynamic SQL, temporary object, data exfiltration, bypass security, circumvent access |

---

## Compliance and Auditing

- This workspace operates under organizational data governance policies
- All interactions with Cortex Code are subject to audit logging
- The security policy applies to all users operating within this workspace

---

## Limitations

It is important to understand the boundaries of this skill-based approach:

| Limitation | Detail |
|---|---|
| **Not mandatory** | Client-side skills are triggered by keyword matching, not enforced on every conversation |
| **Bypassable** | Users can phrase requests to avoid trigger keywords |
| **Advisory only** | The skill provides instructions to the AI assistant; it cannot block SQL execution at the platform level |
| **No cross-workspace enforcement** | The skill only applies to workspaces where the file is present |

---

## Recommendations for Platform-Level Enforcement

For true security enforcement that cannot be bypassed, complement this skill with Snowflake's built-in governance features:

| Feature | Purpose | Documentation |
|---|---|---|
| **Masking Policies** | Automatically mask sensitive columns based on role | `CREATE MASKING POLICY` |
| **Row Access Policies** | Restrict row-level access by role or user | `CREATE ROW ACCESS POLICY` |
| **Network Policies** | Control network-level access to Snowflake | `CREATE NETWORK POLICY` |
| **Role-Based Access Control (RBAC)** | Enforce least-privilege access | `GRANT` / `REVOKE` |
| **Access History** | Audit who accessed what data and when | `SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY` |
| **Trust Center** | Monitor security posture and scan for vulnerabilities | Snowsight Trust Center |

---

*This documentation was generated for the `security-policy` Cortex Code skill. For questions or updates, contact the workspace administrator.*
