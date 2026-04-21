# Enable Cortex Code for Custom Role

## Overview
This skill creates a custom role CORTEX_CODE_USER and grants it the `SNOWFLAKE.COPILOT_USER` database role to enable Cortex Code access.

## Prompts
Before executing, ask the user:
1. **Role Name** (optional): Which existing role should receive CORTEX_CODE_USER? (e.g., ANALYST_ROLE, PUBLIC)
2. **User Name** (optional): Which user should receive CORTEX_CODE_USER directly? (e.g., JOHN_DOE)

If neither is provided, only create the role without assigning it.

## SQL Commands

```sql
USE ROLE ACCOUNTADMIN;

-- Step 1: Create the custom role
CREATE ROLE IF NOT EXISTS CORTEX_CODE_USER;

-- Step 2: Grant COPILOT_USER database role to enable Cortex Code
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE CORTEX_CODE_USER;

-- Step 3: Grant CORTEX_CODE_USER to target role (if role name provided)
GRANT ROLE CORTEX_CODE_USER TO ROLE <ROLE_NAME>;

-- Step 4: Grant CORTEX_CODE_USER to target user (if user name provided)
GRANT ROLE CORTEX_CODE_USER TO USER <USER_NAME>;

-- Step 5: Verify the grant
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;
SHOW GRANTS OF ROLE CORTEX_CODE_USER;
```

## Notes
- Run as ACCOUNTADMIN
- At least one of Role Name or User Name should be provided
- Skip Step 3 if no role name provided
- Skip Step 4 if no user name provided
- Verify grants after execution
