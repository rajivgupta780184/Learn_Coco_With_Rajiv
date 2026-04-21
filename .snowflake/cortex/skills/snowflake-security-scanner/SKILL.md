---
name: snowflake-security-scanner
description: "Snowflake security posture assessment, vulnerability scanning, remediation guidance, compliance tracking, Trust Center integration, CIS Benchmark validation, and Threat Intelligence. Use when: security audit, vulnerability scan, compliance review, risk evaluation, MFA gaps, password policy, network security, RBAC issues, data exfiltration prevention, inactive user management, Trust Center findings, CIS benchmarks, data masking, row-access policies, or generating security reports."
---

# Snowflake Security Scanner

Execute a three-phase security workflow sequentially. Each phase must fully complete
before proceeding to the next. All assessment queries, remediation guidance, checklists,
and priority definitions are contained within this single skill file. Do not reference
or load any external skills during execution.

All HTML reports MUST be saved to the `snowflake-security-scanner/reports/` folder.

**IMPORTANT:** This entire workflow is assessment and documentation only. Do NOT execute
any DDL, DML, or configuration changes.

---

## PHASE 1 — SECURITY ASSESSMENT

Perform a comprehensive security scan of the Snowflake account across all twelve security
domains defined below. For each finding, capture the finding ID, severity (Critical /
High / Medium / Low), affected resource, and description.

### Prerequisites

Before beginning assessment, verify role and privileges:
```sql
SELECT CURRENT_ROLE(), CURRENT_USER();
```

---

### Domain 1 — Critical User Security Vulnerabilities

**1.1 — Users without MFA (CRITICAL)**
```sql
-- [FIXED on 18-02-2026]: Changed USER_NAME to NAME (correct column in USERS table)
SELECT 
    'USERS_WITHOUT_MFA' AS finding_id,
    'CRITICAL' AS severity,
    NAME AS user_name,
    EMAIL,
    DEFAULT_ROLE,
    LAST_SUCCESS_LOGIN,
    DATEDIFF('day', LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) AS days_since_login,
    'User has password authentication without MFA protection' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND HAS_PASSWORD = TRUE 
  AND HAS_MFA = FALSE
ORDER BY LAST_SUCCESS_LOGIN DESC;
```

*Remediation guidance (USERS_WITHOUT_MFA):*

Step 1 — Create tiered authentication policies:
```sql
CREATE OR REPLACE AUTHENTICATION POLICY human_user_mfa_policy
    MFA_ENROLLMENT = 'REQUIRED'
    MFA_AUTHENTICATION_METHODS = ('TOTP')
    CLIENT_TYPES = ('SNOWFLAKE_UI', 'SNOWSIGHT')
    AUTHENTICATION_METHODS = ('PASSWORD', 'SAML')
    COMMENT = 'MFA required for human users via UI';

CREATE OR REPLACE AUTHENTICATION POLICY service_account_policy
    MFA_ENROLLMENT = 'OPTIONAL'
    AUTHENTICATION_METHODS = ('KEYPAIR')
    COMMENT = 'Service accounts should use key-pair authentication';
```

Step 2 — Generate ALTER statements for each affected user:
```sql
SELECT 'ALTER USER ' || NAME || ' SET AUTHENTICATION POLICY = human_user_mfa_policy;' AS remediation_sql
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL
  AND HAS_PASSWORD = TRUE
  AND HAS_MFA = FALSE
  AND NAME NOT LIKE '%SVC%'
  AND NAME NOT LIKE '%SERVICE%'
  AND NAME NOT LIKE '%BOT%';
```

Step 3 — Optionally set account-level default:
```sql
ALTER ACCOUNT SET AUTHENTICATION POLICY = human_user_mfa_policy;
```

---

**1.2 — ACCOUNTADMIN users without MFA (CRITICAL)**
```sql
-- [FIXED on 18-02-2026]: Changed u.USER_NAME to u.NAME (correct column in USERS table)
SELECT 
    'ACCOUNTADMIN_NO_MFA' AS finding_id,
    'CRITICAL' AS severity,
    u.NAME AS user_name,
    u.EMAIL,
    u.HAS_MFA,
    u.LAST_SUCCESS_LOGIN,
    'Privileged ACCOUNTADMIN user lacks MFA protection' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS g ON u.NAME = g.GRANTEE_NAME
WHERE g.ROLE = 'ACCOUNTADMIN' 
  AND g.DELETED_ON IS NULL
  AND u.DELETED_ON IS NULL
  AND (u.HAS_MFA = FALSE OR u.HAS_MFA IS NULL);
```

*Remediation guidance (ACCOUNTADMIN_NO_MFA):*

Step 1 — Create admin-specific MFA policy:
```sql
CREATE OR REPLACE AUTHENTICATION POLICY admin_mfa_required
    MFA_ENROLLMENT = 'REQUIRED'
    MFA_AUTHENTICATION_METHODS = ('TOTP')
    CLIENT_TYPES = ('SNOWFLAKE_UI', 'SNOWSIGHT', 'DRIVERS', 'SNOWSQL')
    AUTHENTICATION_METHODS = ('PASSWORD', 'SAML')
    COMMENT = 'Requires MFA for all admin users';
```

Step 2 — Apply to each ACCOUNTADMIN user:
```sql
ALTER USER <USER_NAME> SET AUTHENTICATION POLICY = admin_mfa_required;
```

Step 3 — Verify:
```sql
SHOW PARAMETERS LIKE '%AUTHENTICATION%' FOR USER <USER_NAME>;
```

---

**1.3 — Users with weak default roles (MEDIUM)**
```sql
SELECT 
    'WEAK_DEFAULT_ROLE' AS finding_id,
    'MEDIUM' AS severity,
    USER_NAME,
    DEFAULT_ROLE,
    CREATED_ON,
    'User has PUBLIC or no default role set' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND (DEFAULT_ROLE IS NULL OR DEFAULT_ROLE = 'PUBLIC')
ORDER BY CREATED_ON DESC;
```

---

### Domain 2 — Inactive & Stale Account Assessment

**2.1 — Inactive users, 90+ days (MEDIUM)**
```sql
-- [FIXED on 18-02-2026]: Changed USER_NAME to NAME (correct column in USERS table)
SELECT 
    'INACTIVE_USER' AS finding_id,
    'MEDIUM' AS severity,
    NAME AS user_name,
    EMAIL,
    DEFAULT_ROLE,
    LAST_SUCCESS_LOGIN,
    DATEDIFF('day', LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) AS days_inactive,
    'Account inactive - potential orphaned access' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND LAST_SUCCESS_LOGIN < DATEADD(day, -90, CURRENT_TIMESTAMP())
ORDER BY days_inactive DESC;
```

*Remediation guidance (INACTIVE_USER):*

Step 1 — Revoke admin roles from inactive users first:
```sql
SELECT 'REVOKE ROLE ' || g.ROLE || ' FROM USER ' || g.GRANTEE_NAME || ';' AS revoke_sql,
       g.GRANTEE_NAME, g.ROLE, u.LAST_SUCCESS_LOGIN
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS g
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON g.GRANTEE_NAME = u.NAME
WHERE g.DELETED_ON IS NULL
  AND u.DELETED_ON IS NULL
  AND g.ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN')
  AND u.LAST_SUCCESS_LOGIN < DATEADD(day, -90, CURRENT_TIMESTAMP());
```

Step 2 — Generate disable commands:
```sql
SELECT 
    'ALTER USER ' || NAME || ' SET DISABLED = TRUE;' AS remediation_sql,
    NAME AS user_name, EMAIL, DEFAULT_ROLE, LAST_SUCCESS_LOGIN,
    DATEDIFF('day', LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) AS days_inactive
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND LAST_SUCCESS_LOGIN < DATEADD(day, -90, CURRENT_TIMESTAMP())
ORDER BY days_inactive DESC;
```

Step 3 — Optionally create tracking table and automated cleanup task:
```sql
CREATE TABLE IF NOT EXISTS SECURITY_AUDIT.DISABLED_USERS (
    USER_NAME VARCHAR, EMAIL VARCHAR,
    DISABLED_DATE TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    DISABLED_BY VARCHAR DEFAULT CURRENT_USER(),
    REASON VARCHAR, DAYS_INACTIVE NUMBER, PREVIOUS_ROLES ARRAY
);

CREATE OR REPLACE TASK auto_disable_inactive_users
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 2 * * 0 UTC'
AS BEGIN END;
```

---

**2.2 — Users who never logged in (LOW)**
```sql
SELECT 
    'NEVER_LOGGED_IN' AS finding_id,
    'LOW' AS severity,
    USER_NAME, EMAIL, DEFAULT_ROLE, CREATED_ON,
    DATEDIFF('day', CREATED_ON, CURRENT_TIMESTAMP()) AS days_since_created,
    'User created but never authenticated' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND LAST_SUCCESS_LOGIN IS NULL
  AND CREATED_ON < DATEADD(day, -30, CURRENT_TIMESTAMP())
ORDER BY days_since_created DESC;
```

---

**2.3 — Stale passwords, 90+ days (HIGH)**
```sql
SELECT 
    'STALE_PASSWORD' AS finding_id,
    'HIGH' AS severity,
    USER_NAME, EMAIL, PASSWORD_LAST_SET_TIME,
    DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) AS days_since_rotation,
    'Password not rotated within policy period' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND HAS_PASSWORD = TRUE
  AND PASSWORD_LAST_SET_TIME < DATEADD(day, -90, CURRENT_TIMESTAMP())
ORDER BY days_since_rotation DESC;
```

*Remediation guidance (STALE_PASSWORD):*

Step 1 — Generate password reset commands:
```sql
SELECT 
    'ALTER USER ' || NAME || ' SET MUST_CHANGE_PASSWORD = TRUE;' AS remediation_sql,
    NAME AS user_name, EMAIL,
    DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) AS days_since_rotation
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND HAS_PASSWORD = TRUE
  AND PASSWORD_LAST_SET_TIME < DATEADD(day, -90, CURRENT_TIMESTAMP())
ORDER BY days_since_rotation DESC;
```

Step 2 — For accounts > 365 days, consider disabling:
```sql
SELECT 'ALTER USER ' || NAME || ' SET DISABLED = TRUE;' AS disable_sql,
       NAME, DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) AS days_old
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND HAS_PASSWORD = TRUE
  AND PASSWORD_LAST_SET_TIME < DATEADD(day, -365, CURRENT_TIMESTAMP());
```

---

**2.4 — Disabled users with active grants (MEDIUM)**
```sql
SELECT 
    'DISABLED_USER_WITH_GRANTS' AS finding_id,
    'MEDIUM' AS severity,
    u.USER_NAME, u.DISABLED,
    COUNT(DISTINCT g.ROLE) AS active_role_count,
    'Disabled user still has role assignments' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS g ON u.NAME = g.GRANTEE_NAME
WHERE u.DISABLED = TRUE AND g.DELETED_ON IS NULL
GROUP BY u.USER_NAME, u.DISABLED
HAVING COUNT(DISTINCT g.ROLE) > 0;
```

---

### Domain 3 — Failed Authentication Analysis

**3.1 — Potential brute force attempts (HIGH)**
```sql
SELECT 
    'BRUTE_FORCE_ATTEMPT' AS finding_id,
    'HIGH' AS severity,
    USER_NAME, CLIENT_IP, REPORTED_CLIENT_TYPE,
    COUNT(*) AS failed_attempts,
    MIN(EVENT_TIMESTAMP) AS first_attempt,
    MAX(EVENT_TIMESTAMP) AS last_attempt,
    'Multiple failed login attempts detected' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'NO'
  AND EVENT_TIMESTAMP >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY USER_NAME, CLIENT_IP, REPORTED_CLIENT_TYPE
HAVING COUNT(*) >= 5
ORDER BY failed_attempts DESC;
```

*Remediation guidance (BRUTE_FORCE_ATTEMPT):*

Step 1 — Block suspicious IPs with network policy:
```sql
CREATE OR REPLACE NETWORK POLICY block_suspicious_ips
    ALLOWED_IP_LIST = ('0.0.0.0/0')
    BLOCKED_IP_LIST = ('<suspicious_ip_1>', '<suspicious_ip_2>')
    COMMENT = 'Block IPs with suspicious failed login patterns';
ALTER ACCOUNT SET NETWORK_POLICY = block_suspicious_ips;
```

Step 2 — Reset passwords for targeted accounts:
```sql
ALTER USER <USER_NAME> SET MUST_CHANGE_PASSWORD = TRUE;
```

Step 3 — Ensure password policy has lockout enabled:
```sql
ALTER PASSWORD POLICY enterprise_password_policy SET
    PASSWORD_MAX_RETRIES = 5
    PASSWORD_LOCKOUT_TIME_MINS = 30;
```

Step 4 — Create monitoring alert:
```sql
CREATE OR REPLACE ALERT brute_force_detection_alert
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'
    IF (EXISTS (
        SELECT 1 FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
        WHERE IS_SUCCESS = 'NO'
          AND EVENT_TIMESTAMP >= DATEADD(hour, -1, CURRENT_TIMESTAMP())
        GROUP BY USER_NAME, CLIENT_IP HAVING COUNT(*) >= 10
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'security_email_integration', 'security@company.com',
            'ALERT: Potential Brute Force Attack Detected',
            'Multiple failed login attempts detected in the last hour.'
        );
```

---

**3.2 — Failed logins from unknown IPs (MEDIUM)**
```sql
SELECT 
    'UNKNOWN_IP_LOGIN_FAILURE' AS finding_id,
    'MEDIUM' AS severity,
    USER_NAME, CLIENT_IP, ERROR_CODE, ERROR_MESSAGE, EVENT_TIMESTAMP,
    'Failed login from previously unseen IP address' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'NO'
  AND EVENT_TIMESTAMP >= DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND CLIENT_IP NOT IN (
      SELECT DISTINCT CLIENT_IP FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY 
      WHERE IS_SUCCESS = 'YES' AND EVENT_TIMESTAMP < DATEADD(day, -7, CURRENT_TIMESTAMP())
  )
ORDER BY EVENT_TIMESTAMP DESC;
```

---

### Domain 4 — Authentication Method Assessment

**4.1 — Authentication method distribution**
```sql
SELECT 
    'AUTH_METHOD_DISTRIBUTION' AS assessment_id,
    CASE 
        WHEN HAS_PASSWORD = TRUE AND HAS_RSA_PUBLIC_KEY = TRUE THEN 'Password + Key-Pair'
        WHEN HAS_PASSWORD = TRUE AND HAS_RSA_PUBLIC_KEY = FALSE THEN 'Password Only'
        WHEN HAS_RSA_PUBLIC_KEY = TRUE AND HAS_PASSWORD = FALSE THEN 'Key-Pair Only'
        WHEN HAS_PASSWORD = FALSE AND HAS_RSA_PUBLIC_KEY = FALSE THEN 'SSO/External Only'
        ELSE 'Unknown'
    END AS auth_method,
    COUNT(*) AS user_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL
GROUP BY 
    CASE 
        WHEN HAS_PASSWORD = TRUE AND HAS_RSA_PUBLIC_KEY = TRUE THEN 'Password + Key-Pair'
        WHEN HAS_PASSWORD = TRUE AND HAS_RSA_PUBLIC_KEY = FALSE THEN 'Password Only'
        WHEN HAS_RSA_PUBLIC_KEY = TRUE AND HAS_PASSWORD = FALSE THEN 'Key-Pair Only'
        WHEN HAS_PASSWORD = FALSE AND HAS_RSA_PUBLIC_KEY = FALSE THEN 'SSO/External Only'
        ELSE 'Unknown'
    END
ORDER BY user_count DESC;
```

**4.2 — Login authentication factors used (last 30 days)**
```sql
SELECT 
    'AUTH_FACTOR_USAGE' AS assessment_id,
    FIRST_AUTHENTICATION_FACTOR, SECOND_AUTHENTICATION_FACTOR,
    COUNT(*) AS login_count,
    COUNT(DISTINCT USER_NAME) AS unique_users
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP()) AND IS_SUCCESS = 'YES'
GROUP BY FIRST_AUTHENTICATION_FACTOR, SECOND_AUTHENTICATION_FACTOR
ORDER BY login_count DESC;
```

**4.3 — MFA coverage summary**
```sql
SELECT 
    'MFA_COVERAGE' AS assessment_id,
    COUNT(*) AS total_password_users,
    SUM(CASE WHEN HAS_MFA = TRUE THEN 1 ELSE 0 END) AS mfa_enabled,
    SUM(CASE WHEN HAS_MFA = FALSE OR HAS_MFA IS NULL THEN 1 ELSE 0 END) AS mfa_disabled,
    ROUND(SUM(CASE WHEN HAS_MFA = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS mfa_coverage_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL AND HAS_PASSWORD = TRUE;
```

**4.4 — MFA by privilege level**
```sql
SELECT 
    'MFA_BY_PRIVILEGE' AS assessment_id,
    CASE 
        WHEN g.ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'ORGADMIN') THEN 'Admin Roles'
        WHEN g.ROLE IN ('SYSADMIN', 'USERADMIN') THEN 'System Roles'
        ELSE 'Standard Roles'
    END AS role_category,
    COUNT(DISTINCT u.USER_NAME) AS user_count,
    SUM(CASE WHEN u.HAS_MFA = TRUE THEN 1 ELSE 0 END) AS with_mfa,
    SUM(CASE WHEN u.HAS_MFA = FALSE THEN 1 ELSE 0 END) AS without_mfa
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS g ON u.NAME = g.GRANTEE_NAME
WHERE u.DELETED_ON IS NULL AND g.DELETED_ON IS NULL
GROUP BY 
    CASE 
        WHEN g.ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'ORGADMIN') THEN 'Admin Roles'
        WHEN g.ROLE IN ('SYSADMIN', 'USERADMIN') THEN 'System Roles'
        ELSE 'Standard Roles'
    END;
```

**4.5 — Human users without SSO (MEDIUM)**
```sql
SELECT 
    'HUMAN_USER_NO_SSO' AS finding_id,
    'MEDIUM' AS severity,
    USER_NAME, EMAIL, HAS_PASSWORD, LAST_SUCCESS_LOGIN,
    'Human user authenticating with password instead of SSO' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL AND HAS_PASSWORD = TRUE AND EMAIL IS NOT NULL
  AND EMAIL NOT LIKE '%service%' AND EMAIL NOT LIKE '%svc%' AND EMAIL NOT LIKE '%bot%'
  AND USER_NAME NOT LIKE '%SVC%' AND USER_NAME NOT LIKE '%SERVICE%'
ORDER BY LAST_SUCCESS_LOGIN DESC;
```

**4.6 — Service accounts using password (HIGH)**
```sql
SELECT 
    'SERVICE_ACCOUNT_PASSWORD' AS finding_id,
    'HIGH' AS severity,
    USER_NAME, HAS_PASSWORD, HAS_RSA_PUBLIC_KEY, DEFAULT_ROLE,
    'Service account using password instead of key-pair auth' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL AND HAS_PASSWORD = TRUE AND HAS_RSA_PUBLIC_KEY = FALSE
  AND (USER_NAME LIKE '%SVC%' OR USER_NAME LIKE '%SERVICE%'
       OR USER_NAME LIKE '%ETL%' OR USER_NAME LIKE '%PIPELINE%'
       OR USER_NAME LIKE '%BOT%' OR EMAIL LIKE '%service%')
ORDER BY USER_NAME;
```

*Remediation guidance (SERVICE_ACCOUNT_PASSWORD):*

Step 1 — Generate RSA key pair (run locally, not in Snowflake):
```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
grep -v "BEGIN\|END" rsa_key.pub | tr -d '\n'
```

Step 2 — Set RSA public key for service accounts:
```sql
ALTER USER <SERVICE_ACCOUNT> SET RSA_PUBLIC_KEY = 'MIIBIj...';
```

Step 3 — After key-pair is configured and tested, disable password:
```sql
ALTER USER <SERVICE_ACCOUNT> SET PASSWORD = NULL;
```

---

### Domain 5 — Data Exfiltration Risk Assessment

**5.1 — Data exfiltration prevention parameters**
```sql
SHOW PARAMETERS LIKE 'PREVENT%' IN ACCOUNT;
SHOW PARAMETERS LIKE 'REQUIRE_STORAGE%' IN ACCOUNT;
```

*Remediation guidance (EXFIL_PREVENTION_DISABLED):*
```sql
ALTER ACCOUNT SET PREVENT_UNLOAD_TO_INLINE_URL = TRUE;
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = TRUE;
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION = TRUE;
```

**5.2 — External stages with broad access (HIGH)**
```sql
SELECT 
    'EXTERNAL_STAGE_RISK' AS finding_id,
    'HIGH' AS severity,
    STAGE_CATALOG AS database_name, STAGE_SCHEMA AS schema_name,
    STAGE_NAME, STAGE_URL, STAGE_OWNER, CREATED,
    'External stage may allow data exfiltration' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.STAGES
WHERE DELETED IS NULL AND STAGE_TYPE = 'External Named'
ORDER BY CREATED DESC;
```

*Remediation guidance:* Create approved storage integrations and remove unauthorized stages:
```sql
CREATE OR REPLACE STORAGE INTEGRATION approved_s3_integration
    TYPE = EXTERNAL_STAGE STORAGE_PROVIDER = 'S3' ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::ACCOUNT:role/snowflake-role'
    STORAGE_ALLOWED_LOCATIONS = ('s3://approved-bucket-only/')
    COMMENT = 'Approved storage integration - controlled access';
GRANT USAGE ON INTEGRATION approved_s3_integration TO ROLE DATA_EXPORT_ROLE;
```

**5.3 — Recent COPY/UNLOAD operations**
```sql
SELECT 
    'DATA_EXPORT_ACTIVITY' AS assessment_id,
    USER_NAME, ROLE_NAME, QUERY_TYPE,
    COUNT(*) AS operation_count,
    SUM(ROWS_PRODUCED) AS total_rows_exported,
    MAX(START_TIME) AS last_operation
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TYPE IN ('UNLOAD', 'COPY', 'GET')
  AND EXECUTION_STATUS = 'SUCCESS'
  AND START_TIME >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY USER_NAME, ROLE_NAME, QUERY_TYPE
ORDER BY total_rows_exported DESC;
```

**5.4 — Large data exports (MEDIUM)**
```sql
SELECT 
    'LARGE_DATA_EXPORT' AS finding_id,
    'MEDIUM' AS severity,
    USER_NAME, ROLE_NAME, DATABASE_NAME, QUERY_TYPE,
    ROWS_PRODUCED, BYTES_SCANNED / (1024*1024*1024) AS gb_scanned,
    START_TIME, LEFT(QUERY_TEXT, 200) AS query_preview,
    'Large data export operation detected' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TYPE IN ('UNLOAD', 'COPY', 'GET', 'SELECT')
  AND ROWS_PRODUCED > 1000000
  AND START_TIME >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY ROWS_PRODUCED DESC LIMIT 50;
```

---

### Domain 6 — Private Link Assessment

**6.1 — Network access patterns**
```sql
SELECT 
    'NETWORK_ACCESS_PATTERN' AS assessment_id,
    CASE 
        WHEN CLIENT_IP LIKE '10.%' OR CLIENT_IP LIKE '172.1%' OR CLIENT_IP LIKE '172.2%' 
             OR CLIENT_IP LIKE '172.3%' OR CLIENT_IP LIKE '192.168.%' THEN 'Private IP'
        ELSE 'Public IP'
    END AS ip_type,
    COUNT(*) AS login_count,
    COUNT(DISTINCT USER_NAME) AS unique_users,
    COUNT(DISTINCT CLIENT_IP) AS unique_ips
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP()) AND IS_SUCCESS = 'YES'
GROUP BY 
    CASE 
        WHEN CLIENT_IP LIKE '10.%' OR CLIENT_IP LIKE '172.1%' OR CLIENT_IP LIKE '172.2%' 
             OR CLIENT_IP LIKE '172.3%' OR CLIENT_IP LIKE '192.168.%' THEN 'Private IP'
        ELSE 'Public IP'
    END;
```

**6.2 — Public IP inventory**
```sql
SELECT 
    'PUBLIC_IP_INVENTORY' AS assessment_id,
    CLIENT_IP, COUNT(*) AS access_count,
    COUNT(DISTINCT USER_NAME) AS users_from_ip,
    MIN(EVENT_TIMESTAMP) AS first_seen, MAX(EVENT_TIMESTAMP) AS last_seen
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP()) AND IS_SUCCESS = 'YES'
  AND NOT (CLIENT_IP LIKE '10.%' OR CLIENT_IP LIKE '172.1%' OR CLIENT_IP LIKE '172.2%' 
           OR CLIENT_IP LIKE '172.3%' OR CLIENT_IP LIKE '192.168.%')
GROUP BY CLIENT_IP ORDER BY access_count DESC;
```

*Remediation guidance (NO_PRIVATE_LINK):*

Step 1 — Get Private Link configuration:
```sql
SELECT SYSTEM$GET_PRIVATELINK_CONFIG();
```

Step 2 — For AWS: Create VPC endpoint pointing to Snowflake's PrivateLink service,
configure DNS, update network policy to private IPs only, test, block public access.
For Azure: Create Private Endpoint, configure Private DNS zone, update policy, validate.

Step 3 — Verify after setup:
```sql
SELECT CLIENT_IP, COUNT(*) AS connections
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'YES' AND EVENT_TIMESTAMP >= DATEADD(day, -1, CURRENT_TIMESTAMP())
GROUP BY CLIENT_IP;
```

---

### Domain 7 — Network / Session / Password Policy Assessment

**7.1 — Network policy evaluation**
```sql
SHOW NETWORK POLICIES;
```

Assess: if zero policies exist, flag as CRITICAL. If ALLOW_ALL exists, flag as HIGH.

*Remediation guidance (NO_NETWORK_POLICY / ALLOW_ALL_POLICY):*

Step 1 — Inventory legitimate IP ranges:
```sql
SELECT CLIENT_IP, COUNT(*) AS login_count, COUNT(DISTINCT USER_NAME) AS unique_users,
       MIN(EVENT_TIMESTAMP) AS first_seen, MAX(EVENT_TIMESTAMP) AS last_seen
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'YES' AND EVENT_TIMESTAMP >= DATEADD(day, -90, CURRENT_TIMESTAMP())
GROUP BY CLIENT_IP ORDER BY login_count DESC;
```

Step 2 — Create restrictive network policy:
```sql
CREATE OR REPLACE NETWORK POLICY corporate_network_policy
    ALLOWED_IP_LIST = ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')
    BLOCKED_IP_LIST = ()
    COMMENT = 'Restrictive corporate network policy';
```

Step 3 — Test on a single user first, then apply at account level:
```sql
ALTER USER <TEST_USER> SET NETWORK_POLICY = corporate_network_policy;
ALTER ACCOUNT SET NETWORK_POLICY = corporate_network_policy;
```

**7.2 — Session duration analysis**
```sql
SELECT 
    'SESSION_DURATION' AS assessment_id,
    USER_NAME,
    AVG(DATEDIFF('minute', CREATED_ON, COALESCE(DESTROYED_ON, CURRENT_TIMESTAMP()))) AS avg_session_mins,
    MAX(DATEDIFF('minute', CREATED_ON, COALESCE(DESTROYED_ON, CURRENT_TIMESTAMP()))) AS max_session_mins,
    COUNT(*) AS session_count
FROM SNOWFLAKE.ACCOUNT_USAGE.SESSIONS
WHERE CREATED_ON >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY USER_NAME
HAVING MAX(DATEDIFF('minute', CREATED_ON, COALESCE(DESTROYED_ON, CURRENT_TIMESTAMP()))) > 480
ORDER BY max_session_mins DESC;
```

*Remediation guidance (NO_SESSION_POLICY):*
```sql
CREATE OR REPLACE SESSION POLICY standard_session_policy
    SESSION_IDLE_TIMEOUT_MINS = 60
    SESSION_UI_IDLE_TIMEOUT_MINS = 30
    COMMENT = 'Standard session timeout - 60 min idle, 30 min UI idle';

CREATE OR REPLACE SESSION POLICY admin_session_policy
    SESSION_IDLE_TIMEOUT_MINS = 30
    SESSION_UI_IDLE_TIMEOUT_MINS = 15
    COMMENT = 'Admin session timeout - 30 min idle, 15 min UI idle';

CREATE OR REPLACE SESSION POLICY service_session_policy
    SESSION_IDLE_TIMEOUT_MINS = 240
    SESSION_UI_IDLE_TIMEOUT_MINS = 60
    COMMENT = 'Service account sessions - 4 hour idle for long jobs';

ALTER ACCOUNT SET SESSION POLICY = standard_session_policy;
```

**7.3 — Password age distribution**
```sql
SELECT 
    'PASSWORD_AGE_DISTRIBUTION' AS assessment_id,
    CASE 
        WHEN DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) <= 30 THEN '0-30 days'
        WHEN DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) <= 90 THEN '31-90 days'
        WHEN DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) <= 180 THEN '91-180 days'
        ELSE '180+ days'
    END AS password_age_bucket,
    COUNT(*) AS user_count
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL AND HAS_PASSWORD = TRUE
GROUP BY 
    CASE 
        WHEN DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) <= 30 THEN '0-30 days'
        WHEN DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) <= 90 THEN '31-90 days'
        WHEN DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) <= 180 THEN '91-180 days'
        ELSE '180+ days'
    END
ORDER BY password_age_bucket;
```

*Remediation guidance (NO_PASSWORD_POLICY):*
```sql
CREATE OR REPLACE PASSWORD POLICY enterprise_password_policy
    PASSWORD_MIN_LENGTH = 14 PASSWORD_MAX_LENGTH = 256
    PASSWORD_MIN_UPPER_CASE_CHARS = 2 PASSWORD_MIN_LOWER_CASE_CHARS = 2
    PASSWORD_MIN_NUMERIC_CHARS = 2 PASSWORD_MIN_SPECIAL_CHARS = 2
    PASSWORD_MIN_AGE_DAYS = 1 PASSWORD_MAX_AGE_DAYS = 90
    PASSWORD_MAX_RETRIES = 5 PASSWORD_LOCKOUT_TIME_MINS = 30
    PASSWORD_HISTORY = 12
    COMMENT = 'Enterprise password policy - 90 day rotation, complexity requirements';
ALTER ACCOUNT SET PASSWORD POLICY = enterprise_password_policy;

CREATE OR REPLACE PASSWORD POLICY admin_password_policy
    PASSWORD_MIN_LENGTH = 16 PASSWORD_MAX_LENGTH = 256
    PASSWORD_MIN_UPPER_CASE_CHARS = 2 PASSWORD_MIN_LOWER_CASE_CHARS = 2
    PASSWORD_MIN_NUMERIC_CHARS = 2 PASSWORD_MIN_SPECIAL_CHARS = 2
    PASSWORD_MIN_AGE_DAYS = 1 PASSWORD_MAX_AGE_DAYS = 60
    PASSWORD_MAX_RETRIES = 3 PASSWORD_LOCKOUT_TIME_MINS = 60
    PASSWORD_HISTORY = 24
    COMMENT = 'Stricter policy for admin users - 60 day rotation';
```

---

### Domain 8 — Encryption & Tri-Secret Secure Assessment

**8.1 — Encryption status**
```sql
SELECT 'DATA_AT_REST' AS assessment_id,
       'Snowflake encrypts all data at rest by default (AES-256)' AS status,
       'COMPLIANT' AS finding;
```

Verify Tri-Secret Secure and periodic rekeying:
```sql
SHOW PARAMETERS LIKE '%ENCRYPTION%' IN ACCOUNT;
SHOW PARAMETERS LIKE '%PERIODIC_DATA_REKEYING%' IN ACCOUNT;
```

**8.2 — Potentially sensitive tables**
```sql
SELECT 
    'SENSITIVE_DATA_CANDIDATES' AS assessment_id,
    TABLE_CATALOG AS database_name, TABLE_SCHEMA AS schema_name,
    TABLE_NAME, ROW_COUNT, BYTES / (1024*1024*1024) AS size_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
WHERE DELETED IS NULL
  AND (TABLE_NAME ILIKE '%PII%' OR TABLE_NAME ILIKE '%SSN%' OR TABLE_NAME ILIKE '%CUSTOMER%'
       OR TABLE_NAME ILIKE '%PATIENT%' OR TABLE_NAME ILIKE '%FINANCIAL%'
       OR TABLE_NAME ILIKE '%CREDIT%' OR TABLE_NAME ILIKE '%PAYMENT%')
ORDER BY ROW_COUNT DESC;
```

---

### Domain 9 — RBAC Framework Evaluation

**9.1 — Role hierarchy depth**
```sql
WITH RECURSIVE role_hierarchy AS (
    SELECT GRANTEE_NAME AS child_role, NAME AS parent_role, 1 AS depth
    FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
    WHERE GRANTED_ON = 'ROLE' AND DELETED_ON IS NULL
    UNION ALL
    SELECT rh.child_role, g.NAME AS parent_role, rh.depth + 1
    FROM role_hierarchy rh
    JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES g ON rh.parent_role = g.GRANTEE_NAME
    WHERE g.GRANTED_ON = 'ROLE' AND g.DELETED_ON IS NULL AND rh.depth < 10
)
SELECT 'ROLE_HIERARCHY_DEPTH' AS assessment_id,
    MAX(depth) AS max_hierarchy_depth, COUNT(DISTINCT child_role) AS total_roles,
    CASE WHEN MAX(depth) > 7 THEN 'WARNING - Deep hierarchy may impact performance' ELSE 'OK' END AS finding
FROM role_hierarchy;
```

**9.2 — Roles with excessive privileges**
```sql
SELECT 
    'ROLE_PRIVILEGE_COUNT' AS assessment_id,
    GRANTEE_NAME AS role_name, COUNT(*) AS privilege_count,
    COUNT(DISTINCT GRANTED_ON) AS object_type_count,
    CASE WHEN COUNT(*) > 100 THEN 'HIGH - Review for least privilege'
         WHEN COUNT(*) > 50 THEN 'MEDIUM - Consider splitting role' ELSE 'OK' END AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE DELETED_ON IS NULL AND GRANTED_ON != 'ROLE'
GROUP BY GRANTEE_NAME ORDER BY privilege_count DESC LIMIT 20;
```

**9.3 — Users with multiple admin roles (HIGH)**
```sql
SELECT 
    'MULTI_ADMIN_ROLES' AS finding_id,
    'HIGH' AS severity,
    GRANTEE_NAME AS user_name,
    LISTAGG(ROLE, ', ') AS admin_roles,
    COUNT(*) AS admin_role_count,
    'User has multiple admin roles - separation of duties concern' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE DELETED_ON IS NULL
  AND ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN')
GROUP BY GRANTEE_NAME HAVING COUNT(*) > 1
ORDER BY admin_role_count DESC;
```

*Remediation guidance (MULTI_ADMIN_ROLES):*

Step 1 — Document current state:
```sql
SELECT GRANTEE_NAME, ROLE, GRANTED_BY, CREATED_ON
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE DELETED_ON IS NULL
  AND ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN')
ORDER BY GRANTEE_NAME, ROLE;
```

Step 2 — Create functional roles and revoke excess admin roles:
```sql
CREATE ROLE IF NOT EXISTS PLATFORM_ADMIN_ROLE;
CREATE ROLE IF NOT EXISTS SECURITY_ADMIN_ROLE;
CREATE ROLE IF NOT EXISTS DATA_ADMIN_ROLE;
GRANT ROLE SYSADMIN TO ROLE PLATFORM_ADMIN_ROLE;
GRANT ROLE SECURITYADMIN TO ROLE SECURITY_ADMIN_ROLE;
```

Step 3 — Implement ACCOUNTADMIN usage logging:
```sql
CREATE TABLE IF NOT EXISTS SECURITY_AUDIT.ACCOUNTADMIN_USAGE_LOG (
    USER_NAME VARCHAR, SESSION_ID VARCHAR, QUERY_ID VARCHAR,
    QUERY_TEXT VARCHAR, START_TIME TIMESTAMP_LTZ, JUSTIFICATION VARCHAR
);
```

**9.4 — Orphaned roles (LOW)**
```sql
SELECT 
    'ORPHANED_ROLE' AS finding_id, 'LOW' AS severity,
    r.NAME AS role_name, r.CREATED_ON,
    'Role has no users or parent roles assigned' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.ROLES r
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS gu ON r.NAME = gu.ROLE AND gu.DELETED_ON IS NULL
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES gr ON r.NAME = gr.NAME AND gr.DELETED_ON IS NULL
WHERE r.DELETED_ON IS NULL AND gu.ROLE IS NULL AND gr.NAME IS NULL
  AND r.NAME NOT IN ('PUBLIC', 'ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN');
```

**9.5 — Direct grants to users (MEDIUM)**
```sql
SELECT 
    'DIRECT_USER_GRANT' AS finding_id, 'MEDIUM' AS severity,
    GRANTEE_NAME AS user_name, GRANTED_ON AS object_type,
    NAME AS object_name, PRIVILEGE,
    'Direct grant to user instead of role - RBAC anti-pattern' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE DELETED_ON IS NULL AND GRANTED_ON != 'ROLE'
ORDER BY GRANTEE_NAME;
```

---

### Domain 10 — Network Security Assessment

**10.1 — IP access summary**
```sql
SELECT 
    'IP_INVENTORY' AS assessment_id,
    COUNT(DISTINCT CLIENT_IP) AS unique_ips_30d,
    COUNT(DISTINCT USER_NAME) AS unique_users,
    COUNT(*) AS total_logins
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP()) AND IS_SUCCESS = 'YES';
```

**10.2 — Access from suspicious IP ranges (MEDIUM)**
```sql
SELECT 
    'SUSPICIOUS_IP' AS finding_id, 'MEDIUM' AS severity,
    CLIENT_IP, COUNT(*) AS access_count,
    COUNT(DISTINCT USER_NAME) AS users_affected,
    'IP not in expected corporate ranges - verify legitimacy' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP()) AND IS_SUCCESS = 'YES'
  AND NOT (CLIENT_IP LIKE '10.%' OR CLIENT_IP LIKE '172.16.%' OR CLIENT_IP LIKE '192.168.%')
GROUP BY CLIENT_IP ORDER BY access_count DESC;
```

---

### Domain 11 — Trust Center Integration

Leverage Snowflake's built-in Trust Center for automated scanner findings, CIS Benchmark
compliance, and Threat Intelligence detection. These checks complement the manual queries
in Domains 1–10 with Snowflake's native security scanning engine.

**11.1 — Trust Center scanner inventory & coverage**

Check which scanner packages are enabled and identify coverage gaps:
```sql
SELECT
    'SCANNER_INVENTORY' AS assessment_id,
    scanner_package_name,
    scanner_name,
    is_enabled,
    run_schedule,
    CASE WHEN is_enabled = FALSE THEN 'DISABLED - Coverage Gap' ELSE 'Active' END AS status
FROM SNOWFLAKE.TRUST_CENTER.SCANNER_PACKAGES_VIEW
ORDER BY scanner_package_name, scanner_name;
```

Assess: Flag any disabled scanners from Security Essentials or CIS Benchmarks packages as
coverage gaps. All three scanner packages should be enabled:
- **Security Essentials** — baseline security hygiene
- **CIS Benchmarks** — industry compliance framework
- **Threat Intelligence** — active threat detection

*Remediation guidance (SCANNER_DISABLED):*

Enable all scanner packages:
```sql
CALL SNOWFLAKE.TRUST_CENTER.ENABLE_SCANNER_PACKAGE('SECURITY_ESSENTIALS');
CALL SNOWFLAKE.TRUST_CENTER.ENABLE_SCANNER_PACKAGE('CIS_BENCHMARKS');
CALL SNOWFLAKE.TRUST_CENTER.ENABLE_SCANNER_PACKAGE('THREAT_INTELLIGENCE');
```

**11.2 — Active Trust Center findings by severity (VARIES)**
```sql
SELECT
    'TC_FINDINGS_SEVERITY' AS assessment_id,
    severity,
    COUNT(*) AS finding_count
FROM SNOWFLAKE.TRUST_CENTER.FINDINGS_VIEW
WHERE state = 'OPEN'
GROUP BY severity
ORDER BY 
    CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END;
```

**11.3 — Detailed open findings from Trust Center**
```sql
SELECT
    'TC_FINDING_DETAIL' AS finding_id,
    severity,
    finding_title,
    finding_description,
    scanner_name,
    scanner_package_name,
    suggested_action,
    first_seen,
    last_seen,
    state
FROM SNOWFLAKE.TRUST_CENTER.FINDINGS_VIEW
WHERE state = 'OPEN'
ORDER BY 
    CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,
    last_seen DESC;
```

**11.4 — Entities at risk from Trust Center findings**
```sql
SELECT
    'TC_AT_RISK_ENTITY' AS finding_id,
    f.severity,
    f.finding_title,
    e.value:objectName::STRING AS entity_name,
    e.value:objectDomain::STRING AS entity_type,
    f.suggested_action
FROM SNOWFLAKE.TRUST_CENTER.FINDINGS_VIEW f,
    LATERAL FLATTEN(input => f.at_risk_entities) e
WHERE f.state = 'OPEN'
ORDER BY f.severity, entity_name;
```

**11.5 — Trust Center findings trend (last 30 days)**
```sql
SELECT
    'TC_TREND' AS assessment_id,
    ds.date,
    ds.severity,
    ds.open_findings_count,
    ds.resolved_findings_count
FROM SNOWFLAKE.TRUST_CENTER.TIME_SERIES_DAILY_FINDINGS ds
WHERE ds.date >= DATEADD(day, -30, CURRENT_DATE())
ORDER BY ds.date DESC, ds.severity;
```

**11.6 — Security Essentials findings (VARIES)**

Security Essentials scanner covers: MFA readiness, network policy, authentication policy,
and passwordless readiness.
```sql
SELECT
    'SEC_ESSENTIALS' AS finding_id,
    severity,
    finding_title,
    finding_description,
    suggested_action,
    at_risk_entities
FROM SNOWFLAKE.TRUST_CENTER.FINDINGS_VIEW
WHERE scanner_package_name = 'SECURITY_ESSENTIALS'
  AND state = 'OPEN'
ORDER BY 
    CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END;
```

**11.7 — CIS Benchmark findings (VARIES)**

CIS Benchmark scanner evaluates controls including: SSO configuration (1.1), SCIM
provisioning (1.2), password unset for SSO users (1.3), key-pair rotation (1.7),
admin idle timeout (1.9), ACCOUNTADMIN with email (1.11), admin default role (1.12),
tasks owned by admin (1.14–1.17), Tri-Secret Secure (4.9), data masking (4.10),
row-access policies (4.11), data retention (4.3–4.4).
```sql
SELECT
    'CIS_BENCHMARK' AS finding_id,
    severity,
    finding_title,
    finding_description,
    suggested_action,
    at_risk_entities
FROM SNOWFLAKE.TRUST_CENTER.FINDINGS_VIEW
WHERE scanner_package_name = 'CIS_BENCHMARKS'
  AND state = 'OPEN'
ORDER BY 
    CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END;
```

**11.8 — Threat Intelligence findings (VARIES)**

Detects active threats: suspicious IP connections, known bad actors, anomalous patterns.
```sql
SELECT
    'THREAT_INTEL' AS finding_id,
    severity,
    finding_title,
    finding_description,
    suggested_action,
    at_risk_entities,
    first_seen,
    last_seen
FROM SNOWFLAKE.TRUST_CENTER.FINDINGS_VIEW
WHERE scanner_package_name = 'THREAT_INTELLIGENCE'
  AND state = 'OPEN'
ORDER BY 
    CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END;
```

*Remediation guidance for Trust Center findings:*

Each Trust Center finding includes a `suggested_action` field with Snowflake's recommended
fix. Use these as the primary remediation path. For common patterns:

Scanner package management:
```sql
CALL SNOWFLAKE.TRUST_CENTER.ENABLE_SCANNER_PACKAGE('<PACKAGE_NAME>');
CALL SNOWFLAKE.TRUST_CENTER.DISABLE_SCANNER_PACKAGE('<PACKAGE_NAME>');
CALL SNOWFLAKE.TRUST_CENTER.SET_SCANNER_SCHEDULE('<PACKAGE_NAME>', '<CRON_EXPRESSION>');
```

Notification integration for ongoing monitoring:
```sql
CALL SNOWFLAKE.TRUST_CENTER.SET_NOTIFICATION_INTEGRATION(
    '<SCANNER_PACKAGE>', '<NOTIFICATION_INTEGRATION_NAME>'
);
```

---

### Domain 12 — CIS Benchmark Extended Checks

These checks address CIS Snowflake Benchmark controls not fully covered by Domains 1–10.
They run regardless of Trust Center scanner status, providing direct validation.

**12.1 — ACCOUNTADMIN users without email set (CIS 1.11, MEDIUM)**
```sql
SELECT
    'ADMIN_NO_EMAIL' AS finding_id,
    'MEDIUM' AS severity,
    u.NAME AS user_name,
    u.EMAIL,
    'ACCOUNTADMIN user has no email set - cannot receive security notifications' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS g ON u.NAME = g.GRANTEE_NAME
WHERE g.ROLE = 'ACCOUNTADMIN' AND g.DELETED_ON IS NULL AND u.DELETED_ON IS NULL
  AND (u.EMAIL IS NULL OR u.EMAIL = '');
```

*Remediation:*
```sql
ALTER USER <ADMIN_USER> SET EMAIL = 'admin@company.com';
```

**12.2 — ACCOUNTADMIN set as default role (CIS 1.12, HIGH)**
```sql
SELECT
    'ADMIN_DEFAULT_ROLE' AS finding_id,
    'HIGH' AS severity,
    NAME AS user_name,
    DEFAULT_ROLE,
    'ACCOUNTADMIN should never be set as default role' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL
  AND DEFAULT_ROLE = 'ACCOUNTADMIN';
```

*Remediation:*
```sql
ALTER USER <USER_NAME> SET DEFAULT_ROLE = 'SYSADMIN';
-- Or a purpose-built functional role
```

**12.3 — RSA key-pair rotation check (CIS 1.7, MEDIUM)**
```sql
SELECT
    'KEY_ROTATION_NEEDED' AS finding_id,
    'MEDIUM' AS severity,
    NAME AS user_name,
    HAS_RSA_PUBLIC_KEY,
    'User has RSA key - verify key rotation within 90 days via Trust Center or audit logs' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL
  AND HAS_RSA_PUBLIC_KEY = TRUE;
```

*Remediation:* Rotate RSA keys every 90 days. Generate new key pair, set RSA_PUBLIC_KEY_2,
validate connectivity, then swap to RSA_PUBLIC_KEY and unset RSA_PUBLIC_KEY_2.

**12.4 — Tasks owned by admin roles (CIS 1.14–1.17, HIGH)**
```sql
SELECT
    'ADMIN_OWNED_TASK' AS finding_id,
    'HIGH' AS severity,
    t.DATABASE_NAME,
    t.SCHEMA_NAME,
    t.NAME AS task_name,
    t.OWNER AS task_owner,
    'Task owned by admin role - should be owned by functional role' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.TASKS t
WHERE t.DELETED_ON IS NULL
  AND t.OWNER IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN');
```

*Remediation:*
```sql
GRANT OWNERSHIP ON TASK <DB>.<SCHEMA>.<TASK> TO ROLE <FUNCTIONAL_ROLE> REVOKE CURRENT GRANTS;
```

**12.5 — Data masking policy coverage (CIS 4.10, MEDIUM)**
```sql
SELECT
    'MASKING_POLICY_COVERAGE' AS assessment_id,
    COUNT(DISTINCT POLICY_NAME) AS total_masking_policies,
    COUNT(DISTINCT REF_COLUMN_NAME) AS columns_protected
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
WHERE POLICY_KIND = 'MASKING_POLICY';
```

Assess: If zero masking policies exist and sensitive tables were found in Domain 8,
flag as MEDIUM finding.

*Remediation:*
```sql
CREATE OR REPLACE MASKING POLICY pii_email_mask AS (val STRING) RETURNS STRING ->
    CASE WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'ACCOUNTADMIN') THEN val
         ELSE REGEXP_REPLACE(val, '.+@', '****@') END;

ALTER TABLE <DB>.<SCHEMA>.<TABLE> MODIFY COLUMN EMAIL SET MASKING POLICY pii_email_mask;
```

**12.6 — Row-access policy coverage (CIS 4.11, MEDIUM)**
```sql
SELECT
    'ROW_ACCESS_COVERAGE' AS assessment_id,
    COUNT(DISTINCT POLICY_NAME) AS total_row_access_policies,
    COUNT(DISTINCT REF_TABLE_NAME) AS tables_protected
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
WHERE POLICY_KIND = 'ROW_ACCESS_POLICY';
```

Assess: If zero row-access policies exist and the account has multi-tenant data or
sensitive tables, flag as MEDIUM.

**12.7 — Tri-Secret Secure / periodic rekeying (CIS 4.9, MEDIUM)**
```sql
SHOW PARAMETERS LIKE '%PERIODIC_DATA_REKEYING%' IN ACCOUNT;
SHOW PARAMETERS LIKE '%ENCRYPTION%' IN ACCOUNT;
```

Assess: If periodic rekeying is not enabled, flag as MEDIUM. Tri-Secret Secure requires
a customer-managed key (CMK) for additional encryption control.

*Remediation:*
```sql
ALTER ACCOUNT SET PERIODIC_DATA_REKEYING = TRUE;
-- For Tri-Secret Secure, contact Snowflake Support to configure CMK
```

**12.8 — Data retention and Time Travel (CIS 4.3–4.4, LOW)**
```sql
SELECT
    'RETENTION_CHECK' AS assessment_id,
    TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME,
    RETENTION_TIME, TABLE_TYPE,
    CASE WHEN RETENTION_TIME = 0 THEN 'No Time Travel - data recovery not possible'
         WHEN RETENTION_TIME > 7 THEN 'Extended retention - review storage cost impact'
         ELSE 'OK' END AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
WHERE DELETED IS NULL AND TABLE_CATALOG != 'SNOWFLAKE'
  AND (RETENTION_TIME = 0 OR RETENTION_TIME > 7)
ORDER BY RETENTION_TIME DESC;
```

---

### Assessment Summary Query
```sql
SELECT 
    'SECURITY_ASSESSMENT_SUMMARY' AS report_type,
    CURRENT_TIMESTAMP() AS assessment_date,
    CURRENT_USER() AS assessed_by,
    CURRENT_ACCOUNT() AS account_name;
```

### Assessment Checklist

| Area | Finding ID | Domain | Risk if Gap Found |
|------|-----------|--------|-------------------|
| MFA Coverage | USERS_WITHOUT_MFA | 1 | CRITICAL |
| Admin MFA | ACCOUNTADMIN_NO_MFA | 1 | CRITICAL |
| Data Exfiltration | EXFIL_PREVENTION_DISABLED | 5 | CRITICAL |
| Trust Center Scanners | SCANNER_DISABLED | 11 | HIGH |
| Trust Center Critical Findings | TC_FINDING_DETAIL | 11 | VARIES |
| CIS Benchmark Findings | CIS_BENCHMARK | 11 | VARIES |
| Threat Intelligence Findings | THREAT_INTEL | 11 | VARIES |
| Password Rotation | STALE_PASSWORD | 2 | HIGH |
| Service Account Auth | SERVICE_ACCOUNT_PASSWORD | 4 | HIGH |
| Brute Force | BRUTE_FORCE_ATTEMPT | 3 | HIGH |
| Network Policy | NO_NETWORK_POLICY | 7 | HIGH |
| Session Policy | NO_SESSION_POLICY | 7 | HIGH |
| RBAC Separation | MULTI_ADMIN_ROLES | 9 | HIGH |
| Private Link | NO_PRIVATE_LINK | 6 | HIGH |
| Admin Default Role | ADMIN_DEFAULT_ROLE | 12 | HIGH |
| Admin-Owned Tasks | ADMIN_OWNED_TASK | 12 | HIGH |
| Inactive Users | INACTIVE_USER | 2 | MEDIUM |
| Auth Method | HUMAN_USER_NO_SSO | 4 | MEDIUM |
| RBAC Structure | DIRECT_USER_GRANT | 9 | MEDIUM |
| Admin No Email | ADMIN_NO_EMAIL | 12 | MEDIUM |
| Key Rotation | KEY_ROTATION_NEEDED | 12 | MEDIUM |
| Masking Policies | MASKING_POLICY_COVERAGE | 12 | MEDIUM |
| Row Access Policies | ROW_ACCESS_COVERAGE | 12 | MEDIUM |
| Tri-Secret Secure | TRI_SECRET_NOT_ENABLED | 12 | MEDIUM |
| Role Sprawl | ORPHANED_ROLE | 9 | LOW |
| Data Retention | RETENTION_CHECK | 12 | LOW |

### Phase 1 — Report Output

Generate a self-contained HTML report saved to `snowflake-security-scanner/reports/`:
- **File name:** `Report-Security-Assessment-<DD-MM-YYYY>.html`
- **Must include:** Executive summary, total findings by severity, detailed findings
  table per domain, affected objects, discovery timestamp, "Report Generation Summary"
  banner at the TOP with total elapsed time for Phase 1.

---

## PHASE 2 — SECURITY RECOMMENDATIONS

Using exclusively the Phase 1 assessment findings as input, prepare a detailed, actionable
remediation plan. Organize all recommendations in strict priority order:

| Priority | SLA | Description |
|----------|-----|-------------|
| P0 — Critical | Within 24 hours | Immediate action required |
| P1 — High | Within 7 days | Urgent remediation |
| P2 — Medium | Within 30 days | Scheduled remediation |
| P3 — Low | Within 90 days | Best-practice improvements |

### Remediation Priority Matrix

| Finding | Severity | Effort | Priority | Timeline |
|---------|----------|--------|----------|----------|
| ACCOUNTADMIN without MFA | CRITICAL | Low | P0 | Immediate |
| Data Exfil Prevention | CRITICAL | Low | P1 | 24 hours |
| No Password Policy | HIGH | Low | P1 | 24 hours |
| Brute Force IPs | HIGH | Low | P1 | 24 hours |
| Stale Passwords | HIGH | Medium | P2 | 1 week |
| Session Policy | HIGH | Low | P2 | 1 week |
| Inactive Users | MEDIUM | Medium | P2 | 1 week |
| RBAC Separation | HIGH | High | P3 | 2 weeks |
| Network Policy | HIGH | Medium | P3 | 2 weeks |
| Private Link | HIGH | High | P3 | 1 month |

For each recommendation, provide step-by-step remediation guidance using the SQL commands
defined in the corresponding domain section above, along with business impact context.

**IMPORTANT:** Do NOT apply any fixes. This phase is documentation and guidance only.

### Remediation Verification Checklist

After applying remediations, verify each fix:
```sql
SELECT NAME, HAS_MFA FROM SNOWFLAKE.ACCOUNT_USAGE.USERS WHERE HAS_PASSWORD = TRUE AND DELETED_ON IS NULL;
SHOW PASSWORD POLICIES;
SHOW SESSION POLICIES;
SHOW NETWORK POLICIES;
SHOW PARAMETERS LIKE 'PREVENT%' IN ACCOUNT;
SHOW PARAMETERS LIKE 'REQUIRE_STORAGE%' IN ACCOUNT;
SELECT COUNT(*) AS remaining_inactive FROM SNOWFLAKE.ACCOUNT_USAGE.USERS 
WHERE DELETED_ON IS NULL AND DISABLED = FALSE AND LAST_SUCCESS_LOGIN < DATEADD(day, -90, CURRENT_TIMESTAMP());
SELECT GRANTEE_NAME, COUNT(*) AS admin_role_count FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN') AND DELETED_ON IS NULL
GROUP BY GRANTEE_NAME HAVING COUNT(*) > 1;
```

### Rollback Procedures

If any remediation causes issues:
```sql
ALTER USER <USER> UNSET AUTHENTICATION POLICY;
ALTER ACCOUNT UNSET PASSWORD POLICY;
ALTER ACCOUNT UNSET SESSION POLICY;
ALTER ACCOUNT UNSET NETWORK_POLICY;
ALTER USER <USER> SET DISABLED = FALSE;
ALTER ACCOUNT SET PREVENT_UNLOAD_TO_INLINE_URL = FALSE;
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = FALSE;
```

### Post-Remediation Monitoring
```sql
CREATE OR REPLACE TASK security_compliance_check
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 8 * * 1 UTC'
AS BEGIN END;
```

### Phase 2 — Report Output

Generate a self-contained HTML report saved to `snowflake-security-scanner/reports/`:
- **File name:** `Report-Security-Recommendation-<DD-MM-YYYY>.html`
- **Must include:** Reference to the source Phase 1 assessment report, prioritized
  recommendation table (P0–P3), detailed fix instructions per finding, estimated
  remediation effort, rollback procedures, "Report Generation Summary" banner at the
  TOP with total elapsed time for Phase 2.

---

## PHASE 3 — COMPLIANCE DASHBOARD

Using the assessment and recommendation data from Phases 1 and 2, build an interactive
compliance dashboard:

- **File name:** `Report-Compliance-Dashboard-<DD-MM-YYYY>.html`
- **Save to:** `snowflake-security-scanner/reports/`

### Dashboard Requirements

- **Category Breakdown:** Display finding count, completion percentage, and status by
  security category: Access Control, Authentication, Network Security, Data Protection,
  RBAC, Encryption, Auditing, Trust Center (Security Essentials, CIS Benchmarks, Threat
  Intelligence), CIS Extended Checks (Masking, Row-Access, Key Rotation, Admin Hygiene).
- **Priority Tracking:** Remediation timeline adherence for each priority level (P0–P3)
  against defined SLA windows (24hr / 7d / 30d / 90d).
- **Visual Indicators:** Progress bars and/or charts per priority bucket, per category,
  and for overall remediation completion.
- **Risk Flagging:** Highlight overdue or at-risk items where SLA deadlines have been
  breached or are within 48 hours of expiry.
- **Overall Compliance Health Score:** Single composite percentage reflecting overall
  remediation progress across all categories.
- **Technical Requirements:** Fully interactive, self-contained HTML with no external
  dependencies, refresh-ready, suitable for executive presentation.

---

## Execution Rules

1. Run all three phases strictly sequentially — do not skip, merge, or parallelize.
2. Capture and prominently display total elapsed time for Phase 1 and Phase 2 individually.
3. Substitute `<DD-MM-YYYY>` with today's actual date when naming all output files.
4. All HTML reports must be professionally styled, print-friendly, and stakeholder-ready.
5. Under no circumstances execute any DDL, DML, or configuration changes — assessment and documentation only.
6. Save all generated HTML reports exclusively to the `snowflake-security-scanner/reports/` folder.
7. For each phase report, display a "Report Generation Summary" banner at the TOP.

---

## Error Handling & Self-Healing

1. If any SQL query or workflow step fails, do NOT halt. Automatically diagnose the root
   cause, apply the appropriate fix, and retry before continuing.

2. For every failed and subsequently recovered step, log inline within the relevant
   phase report:
   - Step name / query identifier that failed
   - Exact error message received from Snowflake
   - Root cause diagnosis
   - Corrective fix applied
   - Retry outcome (Success / Failed after retry)

3. Upon successfully resolving any SQL query failure, update the corresponding query
   definition in this skill file with the corrected version. Prepend the corrected
   query with an inline comment:
   `-- [FIXED on <DD-MM-YYYY>]: <concise description of what was corrected and why>`

4. If a step fails and cannot be recovered after retry, mark it as SKIPPED with a clear
   root cause explanation, continue with remaining steps, and flag the skipped item in
   the final report under a "Manual Review Required" section.

5. Consolidate all self-healing actions into a "Self-Healing Summary" section appended
   to the Phase 1 and Phase 2 reports respectively, listing every corrected query/step,
   the fix applied, and the final resolution status.
