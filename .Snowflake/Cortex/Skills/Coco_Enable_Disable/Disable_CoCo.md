# Disable Cortex Code for Non-Admin Roles

## Overview
Cortex Code requires the `SNOWFLAKE.COPILOT_USER` database role. This guide revokes access from custom roles while preserving access for Snowflake system roles.

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
