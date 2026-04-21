---
name: security-assessment
description: Snowflake security posture assessment, vulnerability identification, authentication audit, access control evaluation, network security review, and compliance gap analysis. Use when: security audit, vulnerability scan, security assessment, compliance review, risk evaluation, or generating security findings report. This skill is for ASSESSMENT ONLY - see security-remediation skill for fixes.
---

# Security Assessment Skill - Snowflake Account Evaluation

## Overview
This skill performs comprehensive security assessment of a Snowflake account, identifying vulnerabilities, evaluating security controls, and generating findings with risk ratings. **This is an ASSESSMENT-ONLY skill** - remediation guidance is provided in a separate skill.

---

## 1. Security & Vulnerability Assessment

### 1.1 Critical User Security Vulnerabilities
```sql
-- [FIXED on 18-02-2026]: Changed USER_NAME to NAME (correct column in USERS table)
-- FINDING: Users without MFA (CRITICAL RISK)
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

-- [FIXED on 18-02-2026]: Changed u.USER_NAME to u.NAME (correct column in USERS table)
-- FINDING: ACCOUNTADMIN users without MFA (CRITICAL RISK)
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

-- FINDING: Users with default/weak roles
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

### 1.2 Inactive & Stale Account Assessment
```sql
-- [FIXED on 18-02-2026]: Changed USER_NAME to NAME (correct column in USERS table)
-- FINDING: Inactive users (no login 90+ days)
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

-- FINDING: Users who never logged in
SELECT 
    'NEVER_LOGGED_IN' AS finding_id,
    'LOW' AS severity,
    USER_NAME,
    EMAIL,
    DEFAULT_ROLE,
    CREATED_ON,
    DATEDIFF('day', CREATED_ON, CURRENT_TIMESTAMP()) AS days_since_created,
    'User created but never authenticated' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND LAST_SUCCESS_LOGIN IS NULL
  AND CREATED_ON < DATEADD(day, -30, CURRENT_TIMESTAMP())
ORDER BY days_since_created DESC;

-- FINDING: Stale passwords (not rotated 90+ days)
SELECT 
    'STALE_PASSWORD' AS finding_id,
    'HIGH' AS severity,
    USER_NAME,
    EMAIL,
    PASSWORD_LAST_SET_TIME,
    DATEDIFF('day', PASSWORD_LAST_SET_TIME, CURRENT_TIMESTAMP()) AS days_since_rotation,
    'Password not rotated within policy period' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL 
  AND HAS_PASSWORD = TRUE
  AND PASSWORD_LAST_SET_TIME < DATEADD(day, -90, CURRENT_TIMESTAMP())
ORDER BY days_since_rotation DESC;

-- FINDING: Disabled users with active grants
SELECT 
    'DISABLED_USER_WITH_GRANTS' AS finding_id,
    'MEDIUM' AS severity,
    u.USER_NAME,
    u.DISABLED,
    COUNT(DISTINCT g.ROLE) AS active_role_count,
    'Disabled user still has role assignments' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS g ON u.NAME = g.GRANTEE_NAME
WHERE u.DISABLED = TRUE
  AND g.DELETED_ON IS NULL
GROUP BY u.USER_NAME, u.DISABLED
HAVING COUNT(DISTINCT g.ROLE) > 0;
```

### 1.3 Failed Authentication Analysis
```sql
-- FINDING: Potential brute force attempts
SELECT 
    'BRUTE_FORCE_ATTEMPT' AS finding_id,
    'HIGH' AS severity,
    USER_NAME,
    CLIENT_IP,
    REPORTED_CLIENT_TYPE,
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

-- FINDING: Failed logins from unknown IPs
SELECT 
    'UNKNOWN_IP_LOGIN_FAILURE' AS finding_id,
    'MEDIUM' AS severity,
    USER_NAME,
    CLIENT_IP,
    ERROR_CODE,
    ERROR_MESSAGE,
    EVENT_TIMESTAMP,
    'Failed login from previously unseen IP address' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'NO'
  AND EVENT_TIMESTAMP >= DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND CLIENT_IP NOT IN (
      SELECT DISTINCT CLIENT_IP 
      FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY 
      WHERE IS_SUCCESS = 'YES' 
        AND EVENT_TIMESTAMP < DATEADD(day, -7, CURRENT_TIMESTAMP())
  )
ORDER BY EVENT_TIMESTAMP DESC;
```

---

## 2. Authentication Method Assessment (SSO, OAuth, Key-Pair)

### 2.1 Current Authentication Landscape
```sql
-- Assessment: Authentication method distribution
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

-- Assessment: Login authentication factors used (last 30 days)
SELECT 
    'AUTH_FACTOR_USAGE' AS assessment_id,
    FIRST_AUTHENTICATION_FACTOR,
    SECOND_AUTHENTICATION_FACTOR,
    COUNT(*) AS login_count,
    COUNT(DISTINCT USER_NAME) AS unique_users
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND IS_SUCCESS = 'YES'
GROUP BY FIRST_AUTHENTICATION_FACTOR, SECOND_AUTHENTICATION_FACTOR
ORDER BY login_count DESC;

-- Assessment: Security integrations inventory
SELECT 
    'SECURITY_INTEGRATION' AS assessment_id,
    "name" AS integration_name,
    "type" AS integration_type,
    "enabled" AS is_enabled,
    "created_on" AS created_date
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
-- Run: SHOW SECURITY INTEGRATIONS; first
;
```

### 2.2 SSO/OAuth Gap Analysis
```sql
-- FINDING: Human users without SSO (should use federated auth)
SELECT 
    'HUMAN_USER_NO_SSO' AS finding_id,
    'MEDIUM' AS severity,
    USER_NAME,
    EMAIL,
    HAS_PASSWORD,
    LAST_SUCCESS_LOGIN,
    'Human user authenticating with password instead of SSO' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL
  AND HAS_PASSWORD = TRUE
  AND EMAIL IS NOT NULL
  AND EMAIL NOT LIKE '%service%'
  AND EMAIL NOT LIKE '%svc%'
  AND EMAIL NOT LIKE '%bot%'
  AND USER_NAME NOT LIKE '%SVC%'
  AND USER_NAME NOT LIKE '%SERVICE%'
ORDER BY LAST_SUCCESS_LOGIN DESC;

-- FINDING: Service accounts using password (should use key-pair)
SELECT 
    'SERVICE_ACCOUNT_PASSWORD' AS finding_id,
    'HIGH' AS severity,
    USER_NAME,
    HAS_PASSWORD,
    HAS_RSA_PUBLIC_KEY,
    DEFAULT_ROLE,
    'Service account using password instead of key-pair auth' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL
  AND HAS_PASSWORD = TRUE
  AND HAS_RSA_PUBLIC_KEY = FALSE
  AND (USER_NAME LIKE '%SVC%' 
       OR USER_NAME LIKE '%SERVICE%'
       OR USER_NAME LIKE '%ETL%'
       OR USER_NAME LIKE '%PIPELINE%'
       OR USER_NAME LIKE '%BOT%'
       OR EMAIL LIKE '%service%')
ORDER BY USER_NAME;
```

---

## 3. Data Exfiltration Risk Assessment

### 3.1 Account Parameter Audit
```sql
-- Assessment: Data exfiltration prevention parameters
SELECT 
    'EXFIL_PREVENTION_PARAMS' AS assessment_id,
    KEY AS parameter_name,
    VALUE AS current_value,
    CASE 
        WHEN KEY = 'PREVENT_UNLOAD_TO_INLINE_URL' AND VALUE = 'false' THEN 'CRITICAL - Enable to prevent inline URL unloads'
        WHEN KEY = 'REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION' AND VALUE = 'false' THEN 'HIGH - Enable to control stage creation'
        WHEN KEY = 'REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION' AND VALUE = 'false' THEN 'HIGH - Enable to control stage operations'
        WHEN KEY = 'PREVENT_UNLOAD_TO_INTERNAL_STAGES' AND VALUE = 'false' THEN 'MEDIUM - Consider enabling for sensitive data'
        ELSE 'OK'
    END AS assessment
FROM TABLE(FLATTEN(INPUT => PARSE_JSON(SYSTEM$GET_SNOWFLAKE_PLATFORM_INFO())))
WHERE KEY LIKE 'PREVENT%' OR KEY LIKE 'REQUIRE_STORAGE%'
-- Alternative: SHOW PARAMETERS LIKE 'PREVENT%' IN ACCOUNT;
;
```

### 3.2 External Stage Risk Assessment
```sql
-- FINDING: External stages with broad access
SELECT 
    'EXTERNAL_STAGE_RISK' AS finding_id,
    'HIGH' AS severity,
    STAGE_CATALOG AS database_name,
    STAGE_SCHEMA AS schema_name,
    STAGE_NAME,
    STAGE_URL,
    STAGE_OWNER,
    CREATED,
    'External stage may allow data exfiltration' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.STAGES
WHERE DELETED IS NULL 
  AND STAGE_TYPE = 'External Named'
ORDER BY CREATED DESC;

-- Assessment: Recent COPY/UNLOAD operations (potential exfiltration vectors)
SELECT 
    'DATA_EXPORT_ACTIVITY' AS assessment_id,
    USER_NAME,
    ROLE_NAME,
    QUERY_TYPE,
    COUNT(*) AS operation_count,
    SUM(ROWS_PRODUCED) AS total_rows_exported,
    MAX(START_TIME) AS last_operation
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TYPE IN ('UNLOAD', 'COPY', 'GET')
  AND EXECUTION_STATUS = 'SUCCESS'
  AND START_TIME >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY USER_NAME, ROLE_NAME, QUERY_TYPE
ORDER BY total_rows_exported DESC;

-- FINDING: Large data exports (potential exfiltration)
SELECT 
    'LARGE_DATA_EXPORT' AS finding_id,
    'MEDIUM' AS severity,
    USER_NAME,
    ROLE_NAME,
    DATABASE_NAME,
    QUERY_TYPE,
    ROWS_PRODUCED,
    BYTES_SCANNED / (1024*1024*1024) AS gb_scanned,
    START_TIME,
    LEFT(QUERY_TEXT, 200) AS query_preview,
    'Large data export operation detected' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TYPE IN ('UNLOAD', 'COPY', 'GET', 'SELECT')
  AND ROWS_PRODUCED > 1000000
  AND START_TIME >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY ROWS_PRODUCED DESC
LIMIT 50;
```

---

## 4. MFA & PAT Assessment

### 4.1 MFA Coverage Analysis
```sql
-- Assessment: MFA enrollment summary
SELECT 
    'MFA_COVERAGE' AS assessment_id,
    COUNT(*) AS total_password_users,
    SUM(CASE WHEN HAS_MFA = TRUE THEN 1 ELSE 0 END) AS mfa_enabled,
    SUM(CASE WHEN HAS_MFA = FALSE OR HAS_MFA IS NULL THEN 1 ELSE 0 END) AS mfa_disabled,
    ROUND(SUM(CASE WHEN HAS_MFA = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS mfa_coverage_pct
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL AND HAS_PASSWORD = TRUE;

-- Assessment: MFA by role privilege level
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

-- Assessment: Authentication policy inventory
-- Run: SHOW AUTHENTICATION POLICIES;
SELECT 
    'AUTH_POLICY_INVENTORY' AS assessment_id,
    'Check if authentication policies exist and enforce MFA' AS note;
```

### 4.2 PAT Token Assessment
```sql
-- Assessment: Programmatic access token usage
-- Note: Direct PAT visibility requires appropriate privileges
SELECT 
    'PAT_ASSESSMENT' AS assessment_id,
    'Review SHOW PROGRAMMATIC ACCESS TOKENS for token inventory' AS note,
    'Assess token expiration dates and rotation schedule' AS recommendation;
```

---

## 5. Private Link Assessment

### 5.1 Network Connectivity Analysis
```sql
-- Assessment: Current network access patterns
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
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND IS_SUCCESS = 'YES'
GROUP BY 
    CASE 
        WHEN CLIENT_IP LIKE '10.%' OR CLIENT_IP LIKE '172.1%' OR CLIENT_IP LIKE '172.2%' 
             OR CLIENT_IP LIKE '172.3%' OR CLIENT_IP LIKE '192.168.%' THEN 'Private IP'
        ELSE 'Public IP'
    END;

-- Assessment: Unique public IPs accessing account
SELECT 
    'PUBLIC_IP_INVENTORY' AS assessment_id,
    CLIENT_IP,
    COUNT(*) AS access_count,
    COUNT(DISTINCT USER_NAME) AS users_from_ip,
    MIN(EVENT_TIMESTAMP) AS first_seen,
    MAX(EVENT_TIMESTAMP) AS last_seen
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND IS_SUCCESS = 'YES'
  AND NOT (CLIENT_IP LIKE '10.%' OR CLIENT_IP LIKE '172.1%' OR CLIENT_IP LIKE '172.2%' 
           OR CLIENT_IP LIKE '172.3%' OR CLIENT_IP LIKE '192.168.%')
GROUP BY CLIENT_IP
ORDER BY access_count DESC;

-- FINDING: Private Link recommendation
SELECT 
    'PRIVATELINK_RECOMMENDATION' AS finding_id,
    CASE 
        WHEN public_ip_logins > private_ip_logins * 2 THEN 'LOW'
        WHEN public_ip_logins > 0 AND sensitive_data_access = TRUE THEN 'HIGH'
        ELSE 'MEDIUM'
    END AS priority,
    public_ip_logins,
    private_ip_logins,
    'Consider Private Link to eliminate public internet exposure' AS recommendation
FROM (
    SELECT 
        SUM(CASE WHEN NOT (CLIENT_IP LIKE '10.%' OR CLIENT_IP LIKE '172.%' OR CLIENT_IP LIKE '192.168.%') THEN 1 ELSE 0 END) AS public_ip_logins,
        SUM(CASE WHEN CLIENT_IP LIKE '10.%' OR CLIENT_IP LIKE '172.%' OR CLIENT_IP LIKE '192.168.%' THEN 1 ELSE 0 END) AS private_ip_logins,
        TRUE AS sensitive_data_access  -- Adjust based on data classification
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
    WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP())
);
```

---

## 6. Network/Session/Password Policy Assessment

### 6.1 Network Policy Evaluation
```sql
-- Assessment: Network policy coverage
-- Run: SHOW NETWORK POLICIES;
SELECT 
    'NETWORK_POLICY_CHECK' AS assessment_id,
    CASE 
        WHEN COUNT(*) = 0 THEN 'CRITICAL - No network policies defined'
        ELSE 'Network policies exist - verify coverage'
    END AS finding
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Assessment: Users/accounts without network policy
SELECT 
    'NO_NETWORK_POLICY' AS finding_id,
    'HIGH' AS severity,
    USER_NAME,
    DEFAULT_ROLE,
    'User has no network policy restriction' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL
-- Network policy per user requires additional checks via SHOW PARAMETERS
;

-- FINDING: Logins from high-risk geolocations (requires IP geolocation)
SELECT 
    'GEOLOCATION_RISK' AS assessment_id,
    CLIENT_IP,
    COUNT(*) AS login_count,
    'Review IP geolocation for risk assessment' AS note
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND IS_SUCCESS = 'YES'
GROUP BY CLIENT_IP
ORDER BY login_count DESC
LIMIT 20;
```

### 6.2 Session Policy Evaluation
```sql
-- Assessment: Session duration analysis
SELECT 
    'SESSION_DURATION' AS assessment_id,
    USER_NAME,
    AVG(DATEDIFF('minute', CREATED_ON, COALESCE(DESTROYED_ON, CURRENT_TIMESTAMP()))) AS avg_session_mins,
    MAX(DATEDIFF('minute', CREATED_ON, COALESCE(DESTROYED_ON, CURRENT_TIMESTAMP()))) AS max_session_mins,
    COUNT(*) AS session_count
FROM SNOWFLAKE.ACCOUNT_USAGE.SESSIONS
WHERE CREATED_ON >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY USER_NAME
HAVING MAX(DATEDIFF('minute', CREATED_ON, COALESCE(DESTROYED_ON, CURRENT_TIMESTAMP()))) > 480  -- 8 hours
ORDER BY max_session_mins DESC;

-- Assessment: Session policy inventory
-- Run: SHOW SESSION POLICIES;
SELECT 
    'SESSION_POLICY_CHECK' AS assessment_id,
    'Review session timeout and idle timeout configurations' AS note;
```

### 6.3 Password Policy Evaluation
```sql
-- Assessment: Password policy inventory
-- Run: SHOW PASSWORD POLICIES;
SELECT 
    'PASSWORD_POLICY_CHECK' AS assessment_id,
    'Verify password complexity, rotation, and lockout settings' AS note;

-- Assessment: Password age distribution
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

---

## 7. Encryption & Tri-Secret Secure Assessment

### 7.1 Encryption Status Check
```sql
-- Assessment: Current encryption configuration
-- Run: SHOW PARAMETERS LIKE '%ENCRYPTION%' IN ACCOUNT;
SELECT 
    'ENCRYPTION_CHECK' AS assessment_id,
    'Verify if Tri-Secret Secure is enabled (Business Critical+ required)' AS note,
    'Check SYSTEM$GET_CMK_INFO() for customer-managed key status' AS action;

-- Assessment: Data at rest encryption (always enabled by Snowflake)
SELECT 
    'DATA_AT_REST' AS assessment_id,
    'Snowflake encrypts all data at rest by default (AES-256)' AS status,
    'COMPLIANT' AS finding;

-- Assessment: Check if periodic rekeying is enabled
-- Run: SHOW PARAMETERS LIKE '%PERIODIC_DATA_REKEYING%' IN ACCOUNT;
SELECT 
    'REKEYING_CHECK' AS assessment_id,
    'Verify if periodic data rekeying is enabled for compliance' AS note;
```

### 7.2 Data Classification for Encryption Needs
```sql
-- Assessment: Identify potentially sensitive tables
SELECT 
    'SENSITIVE_DATA_CANDIDATES' AS assessment_id,
    TABLE_CATALOG AS database_name,
    TABLE_SCHEMA AS schema_name,
    TABLE_NAME,
    ROW_COUNT,
    BYTES / (1024*1024*1024) AS size_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
WHERE DELETED IS NULL
  AND (TABLE_NAME ILIKE '%PII%'
       OR TABLE_NAME ILIKE '%SSN%'
       OR TABLE_NAME ILIKE '%CUSTOMER%'
       OR TABLE_NAME ILIKE '%PATIENT%'
       OR TABLE_NAME ILIKE '%FINANCIAL%'
       OR TABLE_NAME ILIKE '%CREDIT%'
       OR TABLE_NAME ILIKE '%PAYMENT%')
ORDER BY ROW_COUNT DESC;
```

---

## 8. RBAC Framework Evaluation

### 8.1 Role Structure Analysis
```sql
-- Assessment: Role inventory and hierarchy depth
WITH RECURSIVE role_hierarchy AS (
    SELECT 
        GRANTEE_NAME AS child_role,
        NAME AS parent_role,
        1 AS depth
    FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
    WHERE GRANTED_ON = 'ROLE' AND DELETED_ON IS NULL
    UNION ALL
    SELECT 
        rh.child_role,
        g.NAME AS parent_role,
        rh.depth + 1
    FROM role_hierarchy rh
    JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES g 
        ON rh.parent_role = g.GRANTEE_NAME
    WHERE g.GRANTED_ON = 'ROLE' 
      AND g.DELETED_ON IS NULL 
      AND rh.depth < 10
)
SELECT 
    'ROLE_HIERARCHY_DEPTH' AS assessment_id,
    MAX(depth) AS max_hierarchy_depth,
    COUNT(DISTINCT child_role) AS total_roles,
    CASE 
        WHEN MAX(depth) > 7 THEN 'WARNING - Deep hierarchy may impact performance'
        ELSE 'OK'
    END AS finding
FROM role_hierarchy;

-- Assessment: Roles with excessive privileges
SELECT 
    'ROLE_PRIVILEGE_COUNT' AS assessment_id,
    GRANTEE_NAME AS role_name,
    COUNT(*) AS privilege_count,
    COUNT(DISTINCT GRANTED_ON) AS object_type_count,
    CASE 
        WHEN COUNT(*) > 100 THEN 'HIGH - Review for least privilege'
        WHEN COUNT(*) > 50 THEN 'MEDIUM - Consider splitting role'
        ELSE 'OK'
    END AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE DELETED_ON IS NULL AND GRANTED_ON != 'ROLE'
GROUP BY GRANTEE_NAME
ORDER BY privilege_count DESC
LIMIT 20;

-- Assessment: Users with multiple admin roles
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
GROUP BY GRANTEE_NAME
HAVING COUNT(*) > 1
ORDER BY admin_role_count DESC;
```

### 8.2 Orphaned Grants & Access Gaps
```sql
-- FINDING: Roles with no users assigned
SELECT 
    'ORPHANED_ROLE' AS finding_id,
    'LOW' AS severity,
    r.NAME AS role_name,
    r.CREATED_ON,
    'Role has no users or parent roles assigned' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.ROLES r
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS gu ON r.NAME = gu.ROLE AND gu.DELETED_ON IS NULL
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES gr ON r.NAME = gr.NAME AND gr.DELETED_ON IS NULL
WHERE r.DELETED_ON IS NULL
  AND gu.ROLE IS NULL
  AND gr.NAME IS NULL
  AND r.NAME NOT IN ('PUBLIC', 'ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN');

-- FINDING: Direct grants to users (should use roles)
SELECT 
    'DIRECT_USER_GRANT' AS finding_id,
    'MEDIUM' AS severity,
    GRANTEE_NAME AS user_name,
    GRANTED_ON AS object_type,
    NAME AS object_name,
    PRIVILEGE,
    'Direct grant to user instead of role - RBAC anti-pattern' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE DELETED_ON IS NULL
  AND GRANTED_ON != 'ROLE'
ORDER BY GRANTEE_NAME;

-- Assessment: Future grants coverage
SELECT 
    'FUTURE_GRANTS' AS assessment_id,
    GRANTEE_NAME AS role_name,
    GRANT_ON AS object_type,
    COUNT(*) AS future_grant_count
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE DELETED_ON IS NULL
  AND GRANT_OPTION = 'true'  -- Indicates future grant capability
GROUP BY GRANTEE_NAME, GRANT_ON
ORDER BY future_grant_count DESC;
```

---

## 9. Network Security Assessment

### 9.1 Network Rule Inventory
```sql
-- Assessment: Network rules and policies
-- Run: SHOW NETWORK RULES;
-- Run: SHOW NETWORK POLICIES;
SELECT 
    'NETWORK_CONTROLS' AS assessment_id,
    'Review network rules and policies for completeness' AS action,
    'Verify egress controls for external access functions' AS note;

-- Assessment: External access integrations (potential data egress)
-- Run: SHOW EXTERNAL ACCESS INTEGRATIONS;
SELECT 
    'EXTERNAL_ACCESS' AS assessment_id,
    'Review external access integrations for data egress risk' AS note;
```

### 9.2 IP Allowlist Analysis
```sql
-- Assessment: Unique IPs accessing account
SELECT 
    'IP_INVENTORY' AS assessment_id,
    COUNT(DISTINCT CLIENT_IP) AS unique_ips_30d,
    COUNT(DISTINCT USER_NAME) AS unique_users,
    COUNT(*) AS total_logins
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND IS_SUCCESS = 'YES';

-- FINDING: Access from suspicious IP ranges
SELECT 
    'SUSPICIOUS_IP' AS finding_id,
    'MEDIUM' AS severity,
    CLIENT_IP,
    COUNT(*) AS access_count,
    COUNT(DISTINCT USER_NAME) AS users_affected,
    'IP not in expected corporate ranges - verify legitimacy' AS finding
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(day, -30, CURRENT_TIMESTAMP())
  AND IS_SUCCESS = 'YES'
  -- Add your expected IP ranges here
  AND NOT (CLIENT_IP LIKE '10.%' 
           OR CLIENT_IP LIKE '172.16.%' 
           OR CLIENT_IP LIKE '192.168.%'
           -- Add corporate public IP ranges
           )
GROUP BY CLIENT_IP
ORDER BY access_count DESC;
```

---

## 10. Consolidated Assessment Summary

### 10.1 Generate Assessment Report
```sql
-- MASTER ASSESSMENT SUMMARY
SELECT 
    'SECURITY_ASSESSMENT_SUMMARY' AS report_type,
    CURRENT_TIMESTAMP() AS assessment_date,
    CURRENT_USER() AS assessed_by,
    CURRENT_ACCOUNT() AS account_name;

-- Vulnerability Count by Severity
SELECT 
    severity,
    COUNT(*) AS finding_count
FROM (
    -- Users without MFA
    SELECT 'CRITICAL' AS severity FROM SNOWFLAKE.ACCOUNT_USAGE.USERS 
    WHERE DELETED_ON IS NULL AND HAS_PASSWORD = TRUE AND HAS_MFA = FALSE
    UNION ALL
    -- Inactive users
    SELECT 'MEDIUM' AS severity FROM SNOWFLAKE.ACCOUNT_USAGE.USERS 
    WHERE DELETED_ON IS NULL AND LAST_SUCCESS_LOGIN < DATEADD(day, -90, CURRENT_TIMESTAMP())
    UNION ALL
    -- Failed logins (potential attacks)
    SELECT 'HIGH' AS severity FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
    WHERE IS_SUCCESS = 'NO' AND EVENT_TIMESTAMP >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    GROUP BY USER_NAME, CLIENT_IP HAVING COUNT(*) >= 5
)
GROUP BY severity
ORDER BY 
    CASE severity 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        ELSE 4 
    END;
```

---

## Assessment Checklist

| Area | Assessment Query | Risk if Gap Found |
|------|-----------------|-------------------|
| **MFA Coverage** | Users without MFA | CRITICAL |
| **Admin MFA** | ACCOUNTADMIN without MFA | CRITICAL |
| **Data Exfiltration** | Prevention parameters disabled | CRITICAL |
| **Inactive Users** | 90+ days no login | MEDIUM |
| **Password Rotation** | 90+ days stale | HIGH |
| **Authentication Method** | Password-only human users | MEDIUM |
| **Service Account Auth** | Password instead of key-pair | HIGH |
| **Network Policy** | No policy configured | HIGH |
| **Session Policy** | Extended sessions allowed | MEDIUM |
| **Private Link** | Public IP access to sensitive data | HIGH |
| **RBAC Structure** | Direct grants to users | MEDIUM |
| **Role Sprawl** | Orphaned or excessive roles | LOW |
| **Encryption** | Tri-Secret not enabled (if required) | MEDIUM |

---

## Next Steps
After running this assessment:
1. Export findings to CSV/report format
2. Prioritize by severity (CRITICAL → HIGH → MEDIUM → LOW)
3. Use **security-remediation** skill for fix implementation
4. Schedule recurring assessments (monthly recommended)
