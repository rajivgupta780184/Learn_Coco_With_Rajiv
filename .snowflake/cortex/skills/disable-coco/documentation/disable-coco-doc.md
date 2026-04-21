# Disable CoCo (Cortex Code) — Skill Documentation

**Skill Name:** `disable-coco`
**File:** `SKILL.md`
**Last Updated:** April 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Purpose and Use Cases](#purpose-and-use-cases)
3. [Prerequisites](#prerequisites)
4. [Trigger Keywords](#trigger-keywords)
5. [How Cortex Code Access Works](#how-cortex-code-access-works)
6. [Step-by-Step Workflow](#step-by-step-workflow)
7. [SQL Command Reference](#sql-command-reference)
8. [Dynamic Revocation Script](#dynamic-revocation-script)
9. [Protected Roles](#protected-roles)
10. [Verification](#verification)
11. [Rollback Procedure](#rollback-procedure)
12. [Troubleshooting](#troubleshooting)

---

## Overview

The **Disable CoCo** skill revokes Cortex Code (CoCo) Snowsight access from all non-admin users by removing the `SNOWFLAKE.COPILOT_USER` database role from custom roles and the `PUBLIC` system role. Admin and system roles are explicitly preserved to maintain administrative access.

This is a **targeted access control operation** — it does not disable Cortex Code at the account level, it restricts which roles can use it.

---

## Purpose and Use Cases

| Use Case | Description |
|----------|-------------|
| **Restrict AI Access** | Remove Cortex Code from all non-privileged users while keeping admin access |
| **Cost Control** | Prevent token/credit consumption from non-essential CoCo usage |
| **Compliance** | Enforce policy that only authorized roles may use AI-powered code assistance |
| **Onboarding Control** | Prevent new users (who inherit PUBLIC role) from automatically getting CoCo access |
| **Temporary Lockdown** | Quickly revoke broad CoCo access during an audit or review period |

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| **Snowflake Role** | `ACCOUNTADMIN` (required to manage database role grants on the SNOWFLAKE database) |
| **Warehouse** | Not required — all commands are metadata operations |
| **Impact** | Non-destructive — only revokes a database role grant; no data or objects are affected |
| **Reversibility** | Fully reversible by re-granting `SNOWFLAKE.COPILOT_USER` |

---

## Trigger Keywords

The skill activates when user input matches any of these phrases:

- Disable coco / disable cortex code
- Turn off coco / stop coco
- Remove coco / revoke coco
- Coco off / no coco
- Disable copilot / revoke copilot
- Remove copilot access
- Disable snowsight copilot
- Revoke COPILOT_USER
- Block cortex code access
- Turn off coco for all users
- Restrict coco / restrict cortex code
- Deny coco access
- Disable AI assistant
- Turn off copilot / stop copilot
- Remove cortex code / block copilot

---

## How Cortex Code Access Works

Cortex Code (CoCo) in Snowsight is governed by a single database role:

```
SNOWFLAKE.COPILOT_USER
```

**Access Model:**
- Any Snowflake role that has been **granted** `SNOWFLAKE.COPILOT_USER` can use Cortex Code in Snowsight
- By default, `SNOWFLAKE.COPILOT_USER` is granted to the `PUBLIC` role, meaning **all users** have CoCo access
- Revoking `SNOWFLAKE.COPILOT_USER` from a role immediately removes CoCo Snowsight access for all users whose active role inherits from that role

**Inheritance Chain:**
```
User ──► Active Role ──► (inherits from) ──► PUBLIC ──► SNOWFLAKE.COPILOT_USER
                                                              │
                                               Revoke here to block access
```

---

## Step-by-Step Workflow

### Step 1: Audit Current Access

Run the grants audit to see which roles currently have CoCo access:

```sql
USE ROLE ACCOUNTADMIN;
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;
```

This returns a list of all roles that have been granted `SNOWFLAKE.COPILOT_USER`, including the `granted_to` type (ROLE) and `grantee_name`.

### Step 2: Identify Custom Roles

From the audit results, identify all roles that are **not** in the protected list:

| Protected Roles (DO NOT revoke) |
|------|
| ACCOUNTADMIN |
| SECURITYADMIN |
| SYSADMIN |
| USERADMIN |
| ORGADMIN |
| SNOWFLAKE |

Any role not in this list is a candidate for revocation, including `PUBLIC`.

### Step 3: Revoke Access

Execute REVOKE statements for each identified custom role:

```sql
REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE <CUSTOM_ROLE>;
REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE PUBLIC;
```

### Step 4: Verify Changes

Re-run the audit to confirm only protected roles retain access:

```sql
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;
```

---

## SQL Command Reference

### Audit Current Grants

```sql
USE ROLE ACCOUNTADMIN;
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;
```

**Output Columns:**

| Column | Description |
|--------|-------------|
| `created_on` | When the grant was created |
| `role` | The database role being granted (`COPILOT_USER`) |
| `granted_to` | Grant type (always `ROLE`) |
| `grantee_name` | The role that received the grant |
| `granted_by` | Who created the grant |

### Revoke from a Specific Role

```sql
REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE <ROLE_NAME>;
```

### Revoke from PUBLIC (Removes Default Access)

```sql
REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE PUBLIC;
```

This is the most impactful single command — it removes CoCo access from every user who doesn't have it through another role grant.

---

## Dynamic Revocation Script

Instead of manually identifying each role, use this two-step approach to automatically generate and review REVOKE statements:

### Step 1: Run the Audit

```sql
USE ROLE ACCOUNTADMIN;
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;
```

### Step 2: Generate REVOKE Statements

```sql
SELECT 
    'REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE ' || grantee_name || ';' AS revoke_statement
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE grantee_name NOT IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN', 'SNOWFLAKE')
  AND granted_to = 'ROLE';
```

**How It Works:**
1. `RESULT_SCAN(LAST_QUERY_ID())` reads the results of the preceding `SHOW GRANTS` command
2. The `WHERE` clause excludes all 6 protected system/admin roles
3. The output is a set of ready-to-execute `REVOKE` statements
4. Review the output, then copy and execute the generated statements

**Example Output:**
```
REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE PUBLIC;
REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE DATA_ANALYST;
REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE DEVELOPER;
```

---

## Protected Roles

These roles are **never** revoked by this skill. They retain CoCo access to ensure administrators can always use Cortex Code:

| Role | Reason |
|------|--------|
| `ACCOUNTADMIN` | Top-level admin — must retain all capabilities |
| `SECURITYADMIN` | Security management — needs full platform visibility |
| `SYSADMIN` | System administration — manages objects and warehouses |
| `USERADMIN` | User management — manages users and roles |
| `ORGADMIN` | Organization management — cross-account admin |
| `SNOWFLAKE` | Internal Snowflake system role — must not be modified |

---

## Verification

After executing revocations, verify the final state:

```sql
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;
```

**Expected Result:** Only the 6 protected roles (or a subset) should appear in the output. No custom roles or `PUBLIC` should be listed.

**Quick Validation Query:**

```sql
SELECT grantee_name
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE grantee_name NOT IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN', 'SNOWFLAKE');
```

If this returns 0 rows, all non-admin access has been successfully revoked.

---

## Rollback Procedure

To restore CoCo access, re-grant `SNOWFLAKE.COPILOT_USER` to the desired roles:

### Restore Access for All Users (via PUBLIC)

```sql
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE PUBLIC;
```

### Restore Access for a Specific Role

```sql
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE <ROLE_NAME>;
```

### Restore Access for Multiple Specific Roles

```sql
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE DATA_ANALYST;
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE DEVELOPER;
```

---

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| `Insufficient privileges` on SHOW GRANTS | Not using ACCOUNTADMIN role | Run `USE ROLE ACCOUNTADMIN` first |
| REVOKE statement fails | Role doesn't have the grant | Safe to ignore — role already lacks access |
| `RESULT_SCAN` returns empty | `SHOW GRANTS` wasn't the last query executed | Re-run `SHOW GRANTS` immediately before the `RESULT_SCAN` query |
| Admin user lost CoCo access | Admin's active role is a custom role, not a system role | Switch to ACCOUNTADMIN role, or grant `COPILOT_USER` to the specific admin's custom role |
| CoCo still works for a user after revoke | User's active role inherits from another role that still has the grant | Run the audit again to find all remaining grants |
| Need to re-enable for specific team only | Selective access required | Grant `COPILOT_USER` only to that team's role instead of PUBLIC |
