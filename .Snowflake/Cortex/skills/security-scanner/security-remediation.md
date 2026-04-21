---
name: security-remediation
description: Snowflake security remediation guidance based on security-assessment findings. Provides detailed fix instructions for MFA gaps, password policies, network security, RBAC issues, data exfiltration prevention, and inactive user management. Use AFTER running security-assessment skill. Does NOT auto-apply fixes - provides step-by-step remediation guidance only.
---

# Security Remediation Skill - Fix Guidance for Assessment Findings

## Overview
This skill provides **detailed remediation guidance** for security findings identified by the `security-assessment` skill. It reads assessment findings and generates specific SQL commands and procedures to address each vulnerability.

**IMPORTANT**: This skill provides remediation GUIDANCE only. Review all commands before execution. Test in non-production environment first.

---

## Prerequisites

Before applying any remediation:
1. Run the `security-assessment` skill first to identify current gaps
2. Ensure you have appropriate privileges (ACCOUNTADMIN or SECURITYADMIN)
3. Document current state before making changes
4. Create a rollback plan for each change
5. Schedule maintenance window for impactful changes

```sql
-- Verify your current role and privileges
SELECT CURRENT_ROLE(), CURRENT_USER();

-- Document current security settings
SHOW PARAMETERS IN ACCOUNT;
SHOW USERS;
SHOW ROLES;
```

---

## 1. MFA Remediation

### 1.1 Fix: ACCOUNTADMIN Users Without MFA

**Finding Reference**: `ACCOUNTADMIN_NO_MFA`
**Severity**: CRITICAL
**Impact**: Highest privilege accounts vulnerable to credential theft

#### Remediation Steps:

**Step 1: Identify affected users**
```sql
-- List ACCOUNTADMIN users without MFA
SELECT u.NAME AS user_name, u.EMAIL, u.HAS_MFA, u.LAST_SUCCESS_LOGIN
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS g ON u.NAME = g.GRANTEE_NAME
WHERE g.ROLE = 'ACCOUNTADMIN' 
  AND g.DELETED_ON IS NULL
  AND u.DELETED_ON IS NULL
  AND (u.HAS_MFA = FALSE OR u.HAS_MFA IS NULL);
```

**Step 2: Create authentication policy requiring MFA**
```sql
-- Create MFA-required authentication policy for admins
CREATE OR REPLACE AUTHENTICATION POLICY admin_mfa_required
    MFA_ENROLLMENT = 'REQUIRED'
    MFA_AUTHENTICATION_METHODS = ('TOTP')
    CLIENT_TYPES = ('SNOWFLAKE_UI', 'SNOWSIGHT', 'DRIVERS', 'SNOWSQL')
    AUTHENTICATION_METHODS = ('PASSWORD', 'SAML')
    COMMENT = 'Requires MFA for all admin users';
```

**Step 3: Apply policy to ACCOUNTADMIN users**
```sql
-- Apply to specific users (replace USER_NAME with actual names)
ALTER USER <USER_NAME> SET AUTHENTICATION POLICY = admin_mfa_required;

-- Example for identified users:
-- ALTER USER GS_SERVICE_ACCOUNT_USER SET AUTHENTICATION POLICY = admin_mfa_required;
-- ALTER USER PRADYUT_MITRA SET AUTHENTICATION POLICY = admin_mfa_required;
```

**Step 4: Notify users and set enrollment deadline**
```sql
-- Optionally disable users until MFA enrolled (AGGRESSIVE)
-- ALTER USER <USER_NAME> SET DISABLED = TRUE;
-- Re-enable after MFA enrollment confirmed

-- Set temporary bypass for migration period (NOT RECOMMENDED for production)
-- ALTER USER <USER_NAME> SET BYPASS_MFA_UNTIL = DATEADD(day, 7, CURRENT_TIMESTAMP());
```

**Step 5: Verify remediation**
```sql
-- Confirm MFA policy applied
SHOW PARAMETERS LIKE '%AUTHENTICATION%' FOR USER <USER_NAME>;
```

---

### 1.2 Fix: All Users Without MFA

**Finding Reference**: `USERS_WITHOUT_MFA`
**Severity**: CRITICAL
**Impact**: User accounts vulnerable to credential-based attacks

#### Remediation Steps:

**Step 1: Create tiered authentication policies**
```sql
-- Policy for human users (requires MFA)
CREATE OR REPLACE AUTHENTICATION POLICY human_user_mfa_policy
    MFA_ENROLLMENT = 'REQUIRED'
    MFA_AUTHENTICATION_METHODS = ('TOTP')
    CLIENT_TYPES = ('SNOWFLAKE_UI', 'SNOWSIGHT')
    AUTHENTICATION_METHODS = ('PASSWORD', 'SAML')
    COMMENT = 'MFA required for human users via UI';

-- Policy for service accounts (key-pair preferred, no MFA needed)
CREATE OR REPLACE AUTHENTICATION POLICY service_account_policy
    MFA_ENROLLMENT = 'OPTIONAL'
    AUTHENTICATION_METHODS = ('KEYPAIR')
    COMMENT = 'Service accounts should use key-pair authentication';
```

**Step 2: Categorize and apply policies**
```sql
-- Apply human user policy to users with @company.com emails
-- Generate ALTER statements for each user:
SELECT 'ALTER USER ' || NAME || ' SET AUTHENTICATION POLICY = human_user_mfa_policy;' AS remediation_sql
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL
  AND HAS_PASSWORD = TRUE
  AND HAS_MFA = FALSE
  AND EMAIL LIKE '%@kipi.%'
  AND NAME NOT LIKE '%SVC%'
  AND NAME NOT LIKE '%SERVICE%'
  AND NAME NOT LIKE '%BOT%';

-- Apply service account policy to service accounts:
SELECT 'ALTER USER ' || NAME || ' SET AUTHENTICATION POLICY = service_account_policy;' AS remediation_sql
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL
  AND (NAME LIKE '%SVC%' OR NAME LIKE '%SERVICE%' OR NAME LIKE '%BOT%' OR EMAIL IS NULL);
```

**Step 3: Set account-level default (optional)**
```sql
-- Apply MFA policy at account level (affects all new users)
ALTER ACCOUNT SET AUTHENTICATION POLICY = human_user_mfa_policy;
```

---

## 2. Password Policy Remediation

### 2.1 Fix: No Password Policy Configured

**Finding Reference**: `NO_PASSWORD_POLICY`
**Severity**: HIGH
**Impact**: Weak passwords, no rotation enforcement, unlimited retry attempts

#### Remediation Steps:

**Step 1: Create enterprise password policy**
```sql
CREATE OR REPLACE PASSWORD POLICY enterprise_password_policy
    PASSWORD_MIN_LENGTH = 14
    PASSWORD_MAX_LENGTH = 256
    PASSWORD_MIN_UPPER_CASE_CHARS = 2
    PASSWORD_MIN_LOWER_CASE_CHARS = 2
    PASSWORD_MIN_NUMERIC_CHARS = 2
    PASSWORD_MIN_SPECIAL_CHARS = 2
    PASSWORD_MIN_AGE_DAYS = 1
    PASSWORD_MAX_AGE_DAYS = 90
    PASSWORD_MAX_RETRIES = 5
    PASSWORD_LOCKOUT_TIME_MINS = 30
    PASSWORD_HISTORY = 12
    COMMENT = 'Enterprise password policy - 90 day rotation, complexity requirements';
```

**Step 2: Apply at account level**
```sql
-- Apply to entire account
ALTER ACCOUNT SET PASSWORD POLICY = enterprise_password_policy;
```

**Step 3: Create stricter policy for privileged users (optional)**
```sql
CREATE OR REPLACE PASSWORD POLICY admin_password_policy
    PASSWORD_MIN_LENGTH = 16
    PASSWORD_MAX_LENGTH = 256
    PASSWORD_MIN_UPPER_CASE_CHARS = 2
    PASSWORD_MIN_LOWER_CASE_CHARS = 2
    PASSWORD_MIN_NUMERIC_CHARS = 2
    PASSWORD_MIN_SPECIAL_CHARS = 2
    PASSWORD_MIN_AGE_DAYS = 1
    PASSWORD_MAX_AGE_DAYS = 60
    PASSWORD_MAX_RETRIES = 3
    PASSWORD_LOCKOUT_TIME_MINS = 60
    PASSWORD_HISTORY = 24
    COMMENT = 'Stricter policy for admin users - 60 day rotation';

-- Apply to admin users
-- ALTER USER <ADMIN_USER> SET PASSWORD POLICY = admin_password_policy;
```

**Step 4: Verify policy application**
```sql
SHOW PASSWORD POLICIES;
SHOW PARAMETERS LIKE '%PASSWORD%' IN ACCOUNT;
```

---

### 2.2 Fix: Stale Passwords (90+ Days Old)

**Finding Reference**: `STALE_PASSWORD`
**Severity**: HIGH
**Impact**: Long-lived credentials increase risk of compromise

#### Remediation Steps:

**Step 1: Generate password reset commands**
```sql
-- Generate ALTER USER statements for password reset
SELECT 
    'ALTER USER ' || NAME || ' SET MUST_CHANGE_PASSWORD = TRUE;' AS remediation_sql,
    NAME AS user_name,
    EMAIL,
    DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) AS days_since_rotation
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND HAS_PASSWORD = TRUE
  AND PASSWORD_LAST_SET_TIME < DATEADD(day, -90, CURRENT_TIMESTAMP())
ORDER BY days_since_rotation DESC;
```

**Step 2: Force password change for critical accounts first**
```sql
-- Example: Force password change for oldest passwords
-- ALTER USER SNOWFLAKE SET MUST_CHANGE_PASSWORD = TRUE;
-- ALTER USER KIPIADMIN SET MUST_CHANGE_PASSWORD = TRUE;
-- ALTER USER RAKESH SET MUST_CHANGE_PASSWORD = TRUE;
```

**Step 3: Send notification before enforcement**
```sql
-- Create list for email notification
SELECT NAME, EMAIL, 
       DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) AS days_old
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND HAS_PASSWORD = TRUE
  AND PASSWORD_LAST_SET_TIME < DATEADD(day, -90, CURRENT_TIMESTAMP())
  AND EMAIL IS NOT NULL;
-- Export this list and send password reset reminder emails
```

**Step 4: Disable accounts with extremely old passwords (optional)**
```sql
-- For accounts > 365 days without password change, consider disabling
SELECT 'ALTER USER ' || NAME || ' SET DISABLED = TRUE;' AS disable_sql,
       NAME, 
       DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) AS days_old
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND HAS_PASSWORD = TRUE
  AND PASSWORD_LAST_SET_TIME < DATEADD(day, -365, CURRENT_TIMESTAMP());
```

---

## 3. Session Policy Remediation

### 3.1 Fix: No Session Policy Configured

**Finding Reference**: `NO_SESSION_POLICY`
**Severity**: HIGH
**Impact**: Sessions may remain active indefinitely, increasing exposure window

#### Remediation Steps:

**Step 1: Create session policy with appropriate timeouts**
```sql
-- Standard session policy
CREATE OR REPLACE SESSION POLICY standard_session_policy
    SESSION_IDLE_TIMEOUT_MINS = 60
    SESSION_UI_IDLE_TIMEOUT_MINS = 30
    COMMENT = 'Standard session timeout - 60 min idle, 30 min UI idle';

-- Stricter policy for privileged users
CREATE OR REPLACE SESSION POLICY admin_session_policy
    SESSION_IDLE_TIMEOUT_MINS = 30
    SESSION_UI_IDLE_TIMEOUT_MINS = 15
    COMMENT = 'Admin session timeout - 30 min idle, 15 min UI idle';

-- Relaxed policy for ETL/service accounts (longer running jobs)
CREATE OR REPLACE SESSION POLICY service_session_policy
    SESSION_IDLE_TIMEOUT_MINS = 240
    SESSION_UI_IDLE_TIMEOUT_MINS = 60
    COMMENT = 'Service account sessions - 4 hour idle for long jobs';
```

**Step 2: Apply policies**
```sql
-- Apply standard policy at account level
ALTER ACCOUNT SET SESSION POLICY = standard_session_policy;

-- Apply stricter policy to admin users
-- ALTER USER <ADMIN_USER> SET SESSION POLICY = admin_session_policy;

-- Apply relaxed policy to service accounts
-- ALTER USER <SERVICE_ACCOUNT> SET SESSION POLICY = service_session_policy;
```

**Step 3: Verify active sessions and policy**
```sql
SHOW SESSION POLICIES;
SHOW PARAMETERS LIKE '%SESSION%' IN ACCOUNT;
```

---

## 4. Brute Force / Failed Login Remediation

### 4.1 Fix: Potential Brute Force Attacks

**Finding Reference**: `BRUTE_FORCE_ATTEMPT`
**Severity**: HIGH
**Impact**: Credential stuffing or targeted attacks in progress

#### Remediation Steps:

**Step 1: Block suspicious IPs with network policy**
```sql
-- Create blocklist network policy for suspicious IPs
CREATE OR REPLACE NETWORK POLICY block_suspicious_ips
    ALLOWED_IP_LIST = ('0.0.0.0/0')  -- Allow all except blocked
    BLOCKED_IP_LIST = (
        '44.229.241.60',    -- 67 failed attempts
        '54.188.54.135',    -- 44 failed attempts
        '155.226.153.254',  -- Bot attempts
        '155.226.153.255',  -- Bot attempts
        '155.226.153.253'   -- Bot attempts
    )
    COMMENT = 'Block IPs with suspicious failed login patterns';

-- Apply at account level
ALTER ACCOUNT SET NETWORK_POLICY = block_suspicious_ips;
```

**Step 2: Reset passwords for targeted accounts**
```sql
-- Force password reset for accounts targeted by brute force
ALTER USER MANISH SET MUST_CHANGE_PASSWORD = TRUE;
ALTER USER EXPERIAN_USER SET MUST_CHANGE_PASSWORD = TRUE;
ALTER USER PRATYASHA_SAMAL SET MUST_CHANGE_PASSWORD = TRUE;
ALTER USER RITESH SET MUST_CHANGE_PASSWORD = TRUE;
ALTER USER KAIRA3_BOT SET MUST_CHANGE_PASSWORD = TRUE;
```

**Step 3: Enable account lockout via password policy**
```sql
-- Ensure password policy has lockout enabled
ALTER PASSWORD POLICY enterprise_password_policy SET
    PASSWORD_MAX_RETRIES = 5
    PASSWORD_LOCKOUT_TIME_MINS = 30;
```

**Step 4: Create monitoring alert**
```sql
-- Create alert for future brute force detection
CREATE OR REPLACE ALERT brute_force_detection_alert
    WAREHOUSE = WH_DOC_AI
    SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Every hour
    IF (EXISTS (
        SELECT 1
        FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
        WHERE IS_SUCCESS = 'NO'
          AND EVENT_TIMESTAMP >= DATEADD(hour, -1, CURRENT_TIMESTAMP())
        GROUP BY USER_NAME, CLIENT_IP
        HAVING COUNT(*) >= 10
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'security_email_integration',
            'security@company.com',
            'ALERT: Potential Brute Force Attack Detected',
            'Multiple failed login attempts detected in the last hour. Review LOGIN_HISTORY immediately.'
        );
```

**Step 5: Review and investigate**
```sql
-- Get detailed info on suspicious IPs
SELECT USER_NAME, CLIENT_IP, ERROR_CODE, ERROR_MESSAGE, 
       COUNT(*) AS attempts,
       MIN(EVENT_TIMESTAMP) AS first_attempt,
       MAX(EVENT_TIMESTAMP) AS last_attempt
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'NO'
  AND EVENT_TIMESTAMP >= DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND CLIENT_IP IN ('44.229.241.60', '54.188.54.135')
GROUP BY USER_NAME, CLIENT_IP, ERROR_CODE, ERROR_MESSAGE
ORDER BY attempts DESC;
```

---

## 5. Inactive User Remediation

### 5.1 Fix: Inactive Users (90+ Days)

**Finding Reference**: `INACTIVE_USER`
**Severity**: MEDIUM
**Impact**: Orphaned accounts increase attack surface

#### Remediation Steps:

**Step 1: Generate disable commands for inactive users**
```sql
-- Generate ALTER USER statements to disable inactive accounts
SELECT 
    'ALTER USER ' || NAME || ' SET DISABLED = TRUE;' AS remediation_sql,
    NAME AS user_name,
    EMAIL,
    DEFAULT_ROLE,
    LAST_SUCCESS_LOGIN,
    DATEDIFF('day', LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) AS days_inactive
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND LAST_SUCCESS_LOGIN < DATEADD(day, -90, CURRENT_TIMESTAMP())
ORDER BY days_inactive DESC;
```

**Step 2: Revoke admin roles from inactive users FIRST**
```sql
-- Critical: Remove ACCOUNTADMIN from inactive users before disabling
-- REVOKE ROLE ACCOUNTADMIN FROM USER JP;
-- REVOKE ROLE ACCOUNTADMIN FROM USER SUMIT;

-- Generate revoke statements for inactive admin users:
SELECT 'REVOKE ROLE ' || g.ROLE || ' FROM USER ' || g.GRANTEE_NAME || ';' AS revoke_sql,
       g.GRANTEE_NAME, g.ROLE, u.LAST_SUCCESS_LOGIN
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS g
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON g.GRANTEE_NAME = u.NAME
WHERE g.DELETED_ON IS NULL
  AND u.DELETED_ON IS NULL
  AND g.ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'ORGADMIN')
  AND u.LAST_SUCCESS_LOGIN < DATEADD(day, -90, CURRENT_TIMESTAMP());
```

**Step 3: Disable accounts in batches**
```sql
-- Disable users inactive > 180 days first (highest risk)
-- Then 90-180 days after verification

-- Example batch 1: > 180 days inactive
-- ALTER USER JP SET DISABLED = TRUE;
-- ALTER USER PRATIK_HAWLE SET DISABLED = TRUE;
-- ALTER USER SADIYA_KHAN SET DISABLED = TRUE;
```

**Step 4: Document disabled accounts**
```sql
-- Create tracking table for disabled accounts
CREATE TABLE IF NOT EXISTS SECURITY_AUDIT.DISABLED_USERS (
    USER_NAME VARCHAR,
    EMAIL VARCHAR,
    DISABLED_DATE TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    DISABLED_BY VARCHAR DEFAULT CURRENT_USER(),
    REASON VARCHAR,
    DAYS_INACTIVE NUMBER,
    PREVIOUS_ROLES ARRAY
);

-- Log disabled users
INSERT INTO SECURITY_AUDIT.DISABLED_USERS (USER_NAME, EMAIL, REASON, DAYS_INACTIVE)
SELECT NAME, EMAIL, 'Inactive > 90 days', DATEDIFF('day', LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP())
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DISABLED = TRUE;
```

**Step 5: Set up automated cleanup task (future prevention)**
```sql
-- Task to automatically disable users inactive > 90 days
CREATE OR REPLACE TASK auto_disable_inactive_users
    WAREHOUSE = WH_DOC_AI
    SCHEDULE = 'USING CRON 0 2 * * 0 UTC'  -- Weekly on Sunday 2 AM
AS
BEGIN
    -- This is a template - implement with stored procedure
    -- CALL disable_inactive_users_procedure();
END;
```

---

## 6. RBAC Remediation

### 6.1 Fix: Users with Multiple Admin Roles

**Finding Reference**: `MULTI_ADMIN_ROLES`
**Severity**: HIGH
**Impact**: Violation of separation of duties, excessive privileges

#### Remediation Steps:

**Step 1: Document current state**
```sql
-- Export current admin role assignments
SELECT GRANTEE_NAME, ROLE, GRANTED_BY, CREATED_ON
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE DELETED_ON IS NULL
  AND ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN')
ORDER BY GRANTEE_NAME, ROLE;
```

**Step 2: Define role separation strategy**
```sql
-- Recommended separation:
-- ACCOUNTADMIN: Only 2-3 users (break-glass scenarios only)
-- SECURITYADMIN: Security team members
-- SYSADMIN: Platform administrators
-- USERADMIN: User management team
-- ORGADMIN: Organization administrators (usually same as ACCOUNTADMIN)

-- Users should NOT have both ACCOUNTADMIN + SECURITYADMIN + SYSADMIN
```

**Step 3: Generate revoke statements**
```sql
-- For users with 3+ admin roles, revoke excess roles
-- DEMO user has 4 admin roles - reduce to appropriate level

-- Example: If DEMO is a test account, remove all admin roles:
-- REVOKE ROLE ORGADMIN FROM USER DEMO;
-- REVOKE ROLE SYSADMIN FROM USER DEMO;
-- REVOKE ROLE SECURITYADMIN FROM USER DEMO;

-- For VINUKONDABALARAM (3 roles), determine primary function:
-- If platform admin: keep SYSADMIN, revoke ACCOUNTADMIN, ORGADMIN
-- REVOKE ROLE ACCOUNTADMIN FROM USER VINUKONDABALARAM;
-- REVOKE ROLE ORGADMIN FROM USER VINUKONDABALARAM;
```

**Step 4: Create functional roles instead**
```sql
-- Create functional roles for specific tasks
CREATE ROLE IF NOT EXISTS PLATFORM_ADMIN_ROLE;
CREATE ROLE IF NOT EXISTS SECURITY_ADMIN_ROLE;
CREATE ROLE IF NOT EXISTS DATA_ADMIN_ROLE;

-- Grant appropriate privileges to functional roles
GRANT ROLE SYSADMIN TO ROLE PLATFORM_ADMIN_ROLE;
GRANT ROLE SECURITYADMIN TO ROLE SECURITY_ADMIN_ROLE;

-- Assign users to functional roles
-- GRANT ROLE PLATFORM_ADMIN_ROLE TO USER <username>;
```

**Step 5: Implement break-glass procedure for ACCOUNTADMIN**
```sql
-- Limit ACCOUNTADMIN to emergency use only
-- Document when ACCOUNTADMIN is used

CREATE TABLE IF NOT EXISTS SECURITY_AUDIT.ACCOUNTADMIN_USAGE_LOG (
    USER_NAME VARCHAR,
    SESSION_ID VARCHAR,
    QUERY_ID VARCHAR,
    QUERY_TEXT VARCHAR,
    START_TIME TIMESTAMP_LTZ,
    JUSTIFICATION VARCHAR
);
```

---

## 7. Network Security Remediation

### 7.1 Fix: No Restrictive Network Policy

**Finding Reference**: `ALLOW_ALL_POLICY`, `PUBLIC_IP_ACCESS`
**Severity**: HIGH
**Impact**: Account accessible from any IP address

#### Remediation Steps:

**Step 1: Inventory current access patterns**
```sql
-- Identify legitimate IP ranges from login history
SELECT CLIENT_IP, 
       COUNT(*) AS login_count,
       COUNT(DISTINCT USER_NAME) AS unique_users,
       MIN(EVENT_TIMESTAMP) AS first_seen,
       MAX(EVENT_TIMESTAMP) AS last_seen
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'YES'
  AND EVENT_TIMESTAMP >= DATEADD(day, -90, CURRENT_TIMESTAMP())
GROUP BY CLIENT_IP
ORDER BY login_count DESC;
```

**Step 2: Create restrictive network policy**
```sql
-- Replace ALLOW_ALL_POLICY with restrictive policy
CREATE OR REPLACE NETWORK POLICY corporate_network_policy
    ALLOWED_IP_LIST = (
        -- Add your corporate IP ranges here
        '10.0.0.0/8',          -- Internal private range
        '172.16.0.0/12',       -- Internal private range
        '192.168.0.0/16',      -- Internal private range
        -- Add specific public IPs for remote access
        -- 'x.x.x.x/32',       -- Office IP 1
        -- 'y.y.y.y/32'        -- VPN exit IP
    )
    BLOCKED_IP_LIST = ()
    COMMENT = 'Restrictive corporate network policy';
```

**Step 3: Test before applying at account level**
```sql
-- Apply to test user first
ALTER USER <TEST_USER> SET NETWORK_POLICY = corporate_network_policy;
-- Have test user verify they can still access

-- If successful, apply at account level
-- ALTER ACCOUNT SET NETWORK_POLICY = corporate_network_policy;
```

**Step 4: Remove overly permissive policies**
```sql
-- Drop ALLOW_ALL_POLICY after migration
-- DROP NETWORK POLICY IF EXISTS ALLOW_ALL_POLICY;
```

### 7.2 Fix: Private Link Not Implemented

**Finding Reference**: `NO_PRIVATE_LINK`
**Severity**: HIGH
**Impact**: All traffic traverses public internet

#### Remediation Steps:

**Step 1: Get Private Link configuration**
```sql
-- Get Snowflake endpoint information for Private Link setup
SELECT SYSTEM$GET_PRIVATELINK_CONFIG();
```

**Step 2: AWS PrivateLink setup (if using AWS)**
```
1. Create VPC endpoint in your AWS account pointing to Snowflake's PrivateLink service
2. Configure DNS to resolve Snowflake URLs to private endpoint
3. Update network policy to only allow private IP ranges
4. Test connectivity from private network
5. Block public access via network policy
```

**Step 3: Azure Private Link setup (if using Azure)**
```
1. Create Private Endpoint in your Azure subscription
2. Configure Private DNS zone for Snowflake
3. Update network policy
4. Test and validate
```

**Step 4: Verify Private Link connectivity**
```sql
-- After setup, verify connections come from private IPs
SELECT CLIENT_IP, COUNT(*) AS connections
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'YES'
  AND EVENT_TIMESTAMP >= DATEADD(day, -1, CURRENT_TIMESTAMP())
GROUP BY CLIENT_IP;
-- Should show private IP ranges only
```

---

## 8. Data Exfiltration Prevention Remediation

### 8.1 Fix: Data Exfiltration Prevention Not Enabled

**Finding Reference**: `EXFIL_PREVENTION_DISABLED`
**Severity**: CRITICAL
**Impact**: Data can be exported to unauthorized external locations

#### Remediation Steps:

**Step 1: Enable data exfiltration prevention parameters**
```sql
-- CRITICAL: Enable these account parameters
ALTER ACCOUNT SET PREVENT_UNLOAD_TO_INLINE_URL = TRUE;
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = TRUE;
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION = TRUE;

-- Optional: Prevent unload to internal stages (more restrictive)
-- ALTER ACCOUNT SET PREVENT_UNLOAD_TO_INTERNAL_STAGES = TRUE;
```

**Step 2: Verify parameters are set**
```sql
SHOW PARAMETERS LIKE 'PREVENT%' IN ACCOUNT;
SHOW PARAMETERS LIKE 'REQUIRE_STORAGE%' IN ACCOUNT;
```

**Step 3: Audit existing external stages**
```sql
-- List all external stages for review
SELECT STAGE_CATALOG, STAGE_SCHEMA, STAGE_NAME, STAGE_URL, STAGE_OWNER, CREATED
FROM SNOWFLAKE.ACCOUNT_USAGE.STAGES
WHERE DELETED IS NULL 
  AND STAGE_TYPE = 'External Named'
ORDER BY CREATED DESC;
```

**Step 4: Create approved storage integrations**
```sql
-- Create controlled storage integration for approved S3 bucket
CREATE OR REPLACE STORAGE INTEGRATION approved_s3_integration
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::ACCOUNT:role/snowflake-role'
    STORAGE_ALLOWED_LOCATIONS = ('s3://approved-bucket-only/')
    COMMENT = 'Approved storage integration - controlled access';

-- Grant usage to specific roles only
GRANT USAGE ON INTEGRATION approved_s3_integration TO ROLE DATA_EXPORT_ROLE;
```

**Step 5: Remove or secure unauthorized stages**
```sql
-- Generate DROP statements for unauthorized stages
SELECT 'DROP STAGE IF EXISTS ' || STAGE_CATALOG || '.' || STAGE_SCHEMA || '.' || STAGE_NAME || ';' AS drop_sql,
       STAGE_NAME, STAGE_URL, STAGE_OWNER
FROM SNOWFLAKE.ACCOUNT_USAGE.STAGES
WHERE DELETED IS NULL 
  AND STAGE_TYPE = 'External Named'
  AND STAGE_URL NOT LIKE '%approved-bucket%';
```

---

## 9. Service Account Remediation

### 9.1 Fix: Service Accounts Using Password Authentication

**Finding Reference**: `SERVICE_ACCOUNT_PASSWORD`
**Severity**: HIGH
**Impact**: Service accounts should use key-pair, not passwords

#### Remediation Steps:

**Step 1: Generate RSA key pair**
```bash
# Generate 2048-bit RSA key pair (run locally, not in Snowflake)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Extract public key content (remove headers)
grep -v "BEGIN\|END" rsa_key.pub | tr -d '\n'
```

**Step 2: Set RSA public key for service accounts**
```sql
-- Set RSA public key for service account
ALTER USER <SERVICE_ACCOUNT> SET RSA_PUBLIC_KEY = 'MIIBIj...';
-- Paste the public key content from step 1

-- Example for identified service accounts:
-- ALTER USER CORTEX_API SET RSA_PUBLIC_KEY = 'MIIBIj...';
-- ALTER USER CARIBOU_USER SET RSA_PUBLIC_KEY = 'MIIBIj...';
-- ALTER USER FIVETRAN_USER_DEMO_DH SET RSA_PUBLIC_KEY = 'MIIBIj...';
```

**Step 3: Disable password authentication for service accounts**
```sql
-- After key-pair is configured and tested, disable password
ALTER USER <SERVICE_ACCOUNT> SET PASSWORD = NULL;
-- Or set a random password that won't be used
```

**Step 4: Update application configurations**
```
Update all applications using these service accounts to use key-pair authentication:
1. Store private key securely (vault, secrets manager)
2. Configure connection to use private_key_file parameter
3. Test connectivity before disabling password
```

---

## 10. Remediation Verification Checklist

After applying remediations, verify each fix:

```sql
-- 1. MFA Verification
SELECT NAME, HAS_MFA 
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS 
WHERE HAS_PASSWORD = TRUE AND DELETED_ON IS NULL;

-- 2. Password Policy Verification
SHOW PASSWORD POLICIES;
SHOW PARAMETERS LIKE '%PASSWORD%' IN ACCOUNT;

-- 3. Session Policy Verification
SHOW SESSION POLICIES;
SHOW PARAMETERS LIKE '%SESSION%' IN ACCOUNT;

-- 4. Network Policy Verification
SHOW NETWORK POLICIES;
SHOW PARAMETERS LIKE '%NETWORK%' IN ACCOUNT;

-- 5. Data Exfiltration Prevention Verification
SHOW PARAMETERS LIKE 'PREVENT%' IN ACCOUNT;
SHOW PARAMETERS LIKE 'REQUIRE_STORAGE%' IN ACCOUNT;

-- 6. Inactive User Verification
SELECT COUNT(*) AS remaining_inactive
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS 
WHERE DELETED_ON IS NULL 
  AND DISABLED = FALSE
  AND LAST_SUCCESS_LOGIN < DATEADD(day, -90, CURRENT_TIMESTAMP());

-- 7. Admin Role Verification
SELECT GRANTEE_NAME, COUNT(*) AS admin_role_count
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN')
  AND DELETED_ON IS NULL
GROUP BY GRANTEE_NAME
HAVING COUNT(*) > 1;
```

---

## Remediation Priority Matrix

| Finding | Severity | Effort | Priority | Timeline |
|---------|----------|--------|----------|----------|
| ACCOUNTADMIN without MFA | CRITICAL | Low | P0 | Immediate |
| No Password Policy | HIGH | Low | P1 | 24 hours |
| Brute Force IPs | HIGH | Low | P1 | 24 hours |
| Data Exfil Prevention | CRITICAL | Low | P1 | 24 hours |
| Stale Passwords | HIGH | Medium | P2 | 1 week |
| Inactive Users | MEDIUM | Medium | P2 | 1 week |
| Session Policy | HIGH | Low | P2 | 1 week |
| RBAC Separation | HIGH | High | P3 | 2 weeks |
| Private Link | HIGH | High | P3 | 1 month |
| Network Policy | HIGH | Medium | P3 | 2 weeks |

---

## Rollback Procedures

If any remediation causes issues:

```sql
-- Rollback authentication policy
ALTER USER <USER> UNSET AUTHENTICATION POLICY;

-- Rollback password policy
ALTER ACCOUNT UNSET PASSWORD POLICY;

-- Rollback session policy  
ALTER ACCOUNT UNSET SESSION POLICY;

-- Rollback network policy
ALTER ACCOUNT UNSET NETWORK_POLICY;

-- Re-enable disabled user
ALTER USER <USER> SET DISABLED = FALSE;

-- Rollback data exfiltration parameters
ALTER ACCOUNT SET PREVENT_UNLOAD_TO_INLINE_URL = FALSE;
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = FALSE;
```

---

## Post-Remediation Monitoring

Set up ongoing monitoring after applying fixes:

```sql
-- Create monitoring task for security compliance
CREATE OR REPLACE TASK security_compliance_check
    WAREHOUSE = WH_DOC_AI
    SCHEDULE = 'USING CRON 0 8 * * 1 UTC'  -- Weekly Monday 8 AM
AS
BEGIN
    -- Run security assessment queries
    -- Store results in audit table
    -- Alert on new findings
END;
```

---

## Documentation Requirements

After each remediation:
1. Document what was changed
2. Document who approved the change
3. Document rollback procedure
4. Update security runbook
5. Schedule follow-up verification
