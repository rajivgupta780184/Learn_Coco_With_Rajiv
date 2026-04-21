---
name: enable-coco
description: "Enable Cortex Code (Coco) Snowsight access for the PUBLIC role. Use when: enable coco, enable cortex code, turn on coco, grant copilot, grant coco access, enable snowsight copilot, grant COPILOT_USER, allow cortex code access, turn on copilot, activate coco, activate cortex code, give coco access, add copilot access, enable ai assistant, start coco, coco on, enable copilot, restore coco access, re-enable coco"
author: Rajiv Gupta
linkedin: https://www.linkedin.com/in/rajiv-gupta-618b0228/
---

# Enable Cortex Code (Coco) Snowsight for PUBLIC Role

## Instructions

1. Use ACCOUNTADMIN role.
2. Grant `SNOWFLAKE.COPILOT_USER` database role to the PUBLIC role.
3. Verify that the PUBLIC role now has the `SNOWFLAKE.COPILOT_USER` database role by running `SHOW GRANTS TO ROLE PUBLIC` and confirming the grant appears.

## SQL Commands

```sql
USE ROLE ACCOUNTADMIN;

-- Step 1: Grant COPILOT_USER to PUBLIC
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE PUBLIC;

-- Step 2: Verify PUBLIC role has the grant
SHOW GRANTS TO ROLE PUBLIC;
```
