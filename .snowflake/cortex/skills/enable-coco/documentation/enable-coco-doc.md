# Enable CoCo (Cortex Code) — Skill Documentation

**Skill Name:** `enable-coco`
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
8. [Verification](#verification)
9. [Selective Access (Alternative to PUBLIC)](#selective-access-alternative-to-public)
10. [Relationship to disable-coco Skill](#relationship-to-disable-coco-skill)
11. [Troubleshooting](#troubleshooting)

---

## Overview

The **Enable CoCo** skill grants Cortex Code (CoCo) Snowsight access to **all users** by granting the `SNOWFLAKE.COPILOT_USER` database role to the `PUBLIC` system role. Since every Snowflake user automatically inherits `PUBLIC`, this single grant enables CoCo for the entire account.

This is a **single-command metadata operation** — no data, objects, or configurations are modified beyond the role grant.

---

## Purpose and Use Cases

| Use Case | Description |
|----------|-------------|
| **Restore Default Access** | Re-enable CoCo after it was previously revoked via the `disable-coco` skill |
| **Account Onboarding** | Ensure all users in a new or existing account have access to Cortex Code |
| **Post-Audit Re-Enable** | Restore CoCo access after a security review or temporary lockdown |
| **Broad AI Enablement** | Enable AI-assisted coding for the entire organization in one step |

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| **Snowflake Role** | `ACCOUNTADMIN` (required to grant database roles on the SNOWFLAKE database) |
| **Warehouse** | Not required — this is a metadata-only operation |
| **Impact** | Grants CoCo access to **every user** in the account via PUBLIC role inheritance |
| **Reversibility** | Fully reversible using the `disable-coco` skill |
| **Idempotent** | Safe to run multiple times — re-granting an existing grant has no side effects |

---

## Trigger Keywords

The skill activates when user input matches any of these phrases:

- Enable coco / enable cortex code
- Turn on coco / coco on
- Grant copilot / grant coco access
- Enable snowsight copilot
- Grant COPILOT_USER
- Allow cortex code access
- Turn on copilot / activate coco
- Activate cortex code
- Give coco access / add copilot access
- Enable AI assistant
- Start coco / enable copilot
- Restore coco access / re-enable coco

---

## How Cortex Code Access Works

Cortex Code in Snowsight is controlled by a single database role:

```
SNOWFLAKE.COPILOT_USER
```

**Access Model:**

```
SNOWFLAKE.COPILOT_USER
        │
        ▼ (granted to)
     PUBLIC role
        │
        ▼ (inherited by)
   Every user in the account
        │
        ▼
   CoCo Snowsight enabled
```

- The `PUBLIC` role is a built-in Snowflake role that is automatically granted to every user
- Granting `SNOWFLAKE.COPILOT_USER` to `PUBLIC` gives CoCo access to all users regardless of their active role
- Users do not need to switch roles — `PUBLIC` is always in their role hierarchy

---

## Step-by-Step Workflow

### Step 1: Switch to ACCOUNTADMIN

```sql
USE ROLE ACCOUNTADMIN;
```

Only `ACCOUNTADMIN` has the privilege to manage grants on the `SNOWFLAKE` database.

### Step 2: Grant COPILOT_USER to PUBLIC

```sql
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE PUBLIC;
```

This single command enables CoCo for all users in the account.

### Step 3: Verify the Grant

```sql
SHOW GRANTS TO ROLE PUBLIC;
```

Confirm that `SNOWFLAKE.COPILOT_USER` appears in the output.

---

## SQL Command Reference

### Grant CoCo Access to All Users

```sql
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE PUBLIC;
```

| Parameter | Value |
|-----------|-------|
| Database Role | `SNOWFLAKE.COPILOT_USER` |
| Target Role | `PUBLIC` |
| Effect | All users gain CoCo Snowsight access |
| Required Privilege | `ACCOUNTADMIN` |

### Verify the Grant Exists

```sql
SHOW GRANTS TO ROLE PUBLIC;
```

**Expected Output (relevant row):**

| granted_on | name | granted_to | grantee_name |
|------------|------|------------|-------------|
| DATABASE ROLE | SNOWFLAKE.COPILOT_USER | ROLE | PUBLIC |

---

## Verification

After running the grant, verify with either of these approaches:

### Approach 1: Check PUBLIC Role Grants

```sql
SHOW GRANTS TO ROLE PUBLIC;
```

Look for a row where `name` is `SNOWFLAKE.COPILOT_USER`.

### Approach 2: Check COPILOT_USER Grantees

```sql
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;
```

Look for a row where `grantee_name` is `PUBLIC`. This also shows all other roles that have CoCo access.

---

## Selective Access (Alternative to PUBLIC)

If you want to enable CoCo for **specific roles only** instead of all users, grant `COPILOT_USER` to individual roles instead of `PUBLIC`:

### Grant to a Specific Role

```sql
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE DATA_ANALYST;
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE DEVELOPER;
```

### Selective Access Model

```
SNOWFLAKE.COPILOT_USER
        │
        ├──► DATA_ANALYST  (CoCo enabled)
        ├──► DEVELOPER     (CoCo enabled)
        └──✗ PUBLIC        (NOT granted — other users blocked)
```

This approach is useful when you want CoCo available only to specific teams while keeping it disabled for the broader organization.

---

## Relationship to disable-coco Skill

These two skills are complementary:

| Action | Skill | SQL |
|--------|-------|-----|
| **Enable** for all users | `enable-coco` | `GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE PUBLIC` |
| **Disable** for non-admin users | `disable-coco` | `REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE PUBLIC` + custom roles |

**Typical Workflow:**
1. CoCo is enabled by default (PUBLIC has COPILOT_USER)
2. Admin runs `disable-coco` to restrict access during audit
3. After review, admin runs `enable-coco` to restore access

---

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| `Insufficient privileges` on GRANT | Not using ACCOUNTADMIN role | Run `USE ROLE ACCOUNTADMIN` first |
| Grant succeeds but user can't see CoCo | User's session hasn't refreshed | User should log out and back into Snowsight |
| `SHOW GRANTS TO ROLE PUBLIC` doesn't show COPILOT_USER | Grant failed silently or wrong role used | Re-run with ACCOUNTADMIN and verify no errors |
| Want to enable for one team only, not everyone | PUBLIC is too broad | Grant to specific roles instead of PUBLIC (see Selective Access section) |
| COPILOT_USER already granted to PUBLIC | Grant was already in place | No action needed — command is idempotent and safe to re-run |
| CoCo works for admins but not regular users | COPILOT_USER only granted to admin roles, not PUBLIC | Run the GRANT to PUBLIC as described in this skill |
