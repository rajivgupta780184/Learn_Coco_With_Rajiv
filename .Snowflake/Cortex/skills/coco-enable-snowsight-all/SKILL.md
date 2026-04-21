---
name: coco-enable-snowsight-all
description: "Enable Cortex Code (Coco) Snowsight access for users or roles. Use when: enable coco, enable cortex code, turn on coco, grant copilot, grant coco access, enable snowsight copilot, grant COPILOT_USER, allow cortex code access, turn on copilot, activate coco, activate cortex code, give coco access, add copilot access, enable ai assistant, start coco, coco on, enable copilot, restore coco access, re-enable coco"
---

# Enable Cortex Code (Coco) Snowsight for Users or Roles

## Overview
Cortex Code Snowsight requires the `SNOWFLAKE.COPILOT_USER` database role. This skill creates a custom role `CORTEX_CODE_USER`, grants it COPILOT_USER access, and optionally assigns it to a target role or user.

## Instructions

1. Ask the user:
   - **Role Name** (optional): Which existing role should receive CORTEX_CODE_USER? (e.g., ANALYST_ROLE, PUBLIC)
   - **User Name** (optional): Which user should receive CORTEX_CODE_USER directly? (e.g., JOHN_DOE)
2. If neither is provided, only create the role without assigning it.
3. Run `SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER` to audit current access before making changes.
4. Create the `CORTEX_CODE_USER` role and grant `SNOWFLAKE.COPILOT_USER` to it.
5. Grant `CORTEX_CODE_USER` to the target role and/or user as specified.
6. Verify changes by re-running the SHOW GRANTS commands.

## SQL Commands

```sql
USE ROLE ACCOUNTADMIN;

-- Step 1: Audit current access
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;

-- Step 2: Create the custom role
CREATE ROLE IF NOT EXISTS CORTEX_CODE_USER;

-- Step 3: Grant COPILOT_USER database role to enable Cortex Code
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE CORTEX_CODE_USER;

-- Step 4: Grant CORTEX_CODE_USER to target role (if role name provided)
GRANT ROLE CORTEX_CODE_USER TO ROLE <ROLE_NAME>;

-- Step 5: Grant CORTEX_CODE_USER to target user (if user name provided)
GRANT ROLE CORTEX_CODE_USER TO USER <USER_NAME>;

-- Step 6: Verify the grants
SHOW GRANTS OF DATABASE ROLE SNOWFLAKE.COPILOT_USER;
SHOW GRANTS OF ROLE CORTEX_CODE_USER;
```

## Notes
- Run as ACCOUNTADMIN
- At least one of Role Name or User Name should be provided
- Skip Step 4 if no role name provided
- Skip Step 5 if no user name provided
- Always audit current access before and after changes
