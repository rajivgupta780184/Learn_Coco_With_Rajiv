---
name: coco-disable-snowsight-all
description: "Disable Cortex Code (Coco) Snowsight access for all non-admin users. Use when: disable coco, disable cortex code, revoke copilot, remove copilot access, disable snowsight copilot, revoke COPILOT_USER, block cortex code access, turn off coco for all users."
---

# Disable Cortex Code(coco) Snowsight for Non-Admin and public roles

## Overview
Cortex Code Snowsight requires the `SNOWFLAKE.COPILOT_USER` database role. This guide revokes access from custom roles & PUBLIC system role while preserving access for Snowflake system roles.

## Instructions

1. Run `SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER` to audit current access
2. Identify all non-system roles (exclude: ACCOUNTADMIN, SECURITYADMIN, SYSADMIN, USERADMIN, ORGADMIN, SNOWFLAKE)
3. Revoke `SNOWFLAKE.COPILOT_USER` from each identified role and PUBLIC
4. Verify changes by re-running the SHOW GRANTS command

## SQL Commands

```sql
USE ROLE ACCOUNTADMIN;

-- Step 1: Check which roles currently have COPILOT_USER granted
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;

-- Step 2: Revoke COPILOT_USER from custom roles and PUBLIC system role only (excludes ACCOUNTADMIN, SECURITYADMIN, SYSADMIN, USERADMIN, ORGADMIN, SNOWFLAKE roles)
-- Excluded roles: ACCOUNTADMIN, SECURITYADMIN, SYSADMIN, USERADMIN, ORGADMIN, SNOWFLAKE
REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE <CUSTOM_ROLE_1>;
REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE <CUSTOM_ROLE_2>;

-- Step 3: Verify changes
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;
```

## Dynamic Script to Revoke from All Custom Roles

```sql
-- Generate REVOKE statements for all non-system roles with COPILOT_USER access
SELECT 'REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE ' || grantee_name || ';' AS revoke_statement
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE grantee_name NOT IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN', 'SNOWFLAKE')
  AND granted_to = 'ROLE';
```

## Notes
- Always run `SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER` first to audit current access
- Excluded from revocation: ACCOUNTADMIN, SECURITYADMIN, SYSADMIN, USERADMIN, ORGADMIN, SNOWFLAKE
- Run as ACCOUNTADMIN
