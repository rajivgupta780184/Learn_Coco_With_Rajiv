# Snowflake Security Scanner — Skill Documentation

**Skill Name:** `snowflake-security-scanner`
**File:** `SKILL.md`
**Last Updated:** April 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Purpose and Use Cases](#purpose-and-use-cases)
3. [Prerequisites](#prerequisites)
4. [Trigger Keywords](#trigger-keywords)
5. [Three-Phase Workflow](#three-phase-workflow)
6. [Phase 1 — Security Assessment](#phase-1--security-assessment)
   - [Domain 1: Critical User Security Vulnerabilities](#domain-1-critical-user-security-vulnerabilities)
   - [Domain 2: Inactive & Stale Account Assessment](#domain-2-inactive--stale-account-assessment)
   - [Domain 3: Failed Authentication Analysis](#domain-3-failed-authentication-analysis)
   - [Domain 4: Authentication Method Assessment](#domain-4-authentication-method-assessment)
   - [Domain 5: Data Exfiltration Risk Assessment](#domain-5-data-exfiltration-risk-assessment)
   - [Domain 6: Private Link Assessment](#domain-6-private-link-assessment)
   - [Domain 7: Network / Session / Password Policy Assessment](#domain-7-network--session--password-policy-assessment)
   - [Domain 8: Encryption & Tri-Secret Secure Assessment](#domain-8-encryption--tri-secret-secure-assessment)
   - [Domain 9: RBAC Framework Evaluation](#domain-9-rbac-framework-evaluation)
   - [Domain 10: Network Security Assessment](#domain-10-network-security-assessment)
   - [Domain 11: Trust Center Integration](#domain-11-trust-center-integration)
   - [Domain 12: CIS Benchmark Extended Checks](#domain-12-cis-benchmark-extended-checks)
   - [Assessment Checklist](#assessment-checklist)
   - [Phase 1 Report Output](#phase-1-report-output)
7. [Phase 2 — Security Recommendations](#phase-2--security-recommendations)
   - [Priority Classification](#priority-classification)
   - [Remediation Priority Matrix](#remediation-priority-matrix)
   - [Remediation Verification Checklist](#remediation-verification-checklist)
   - [Rollback Procedures](#rollback-procedures)
   - [Phase 2 Report Output](#phase-2-report-output)
8. [Phase 3 — Compliance Dashboard](#phase-3--compliance-dashboard)
   - [Dashboard Panels](#dashboard-panels)
   - [Visual Indicators and Scoring](#visual-indicators-and-scoring)
   - [Phase 3 Report Output](#phase-3-report-output)
9. [SQL Query Inventory](#sql-query-inventory)
10. [Data Sources](#data-sources)
11. [Finding Severity Definitions](#finding-severity-definitions)
12. [Execution Rules](#execution-rules)
13. [Error Handling and Self-Healing](#error-handling-and-self-healing)
14. [Report File Inventory](#report-file-inventory)
15. [Troubleshooting](#troubleshooting)

---

## Overview

The **Snowflake Security Scanner** is a Cortex Code skill that performs a comprehensive, three-phase security audit of a Snowflake account across **12 security domains**. It scans user security, authentication methods, network configuration, RBAC structure, data protection, encryption, Trust Center findings, and CIS Benchmark compliance — then produces three professional HTML reports: an Assessment, a Recommendation plan, and a Compliance Dashboard.

The skill is **assessment and documentation only**. No DDL, DML, or configuration changes are ever executed. All queries target `SNOWFLAKE.ACCOUNT_USAGE` and `SNOWFLAKE.TRUST_CENTER` views.

---

## Purpose and Use Cases

| Use Case | Description |
|----------|-------------|
| **Full Security Audit** | Scan all 12 domains for a complete account security posture review |
| **MFA Gap Analysis** | Identify users without MFA, especially privileged ACCOUNTADMIN users |
| **Brute Force Detection** | Detect repeated failed login attempts from suspicious IPs |
| **Inactive User Cleanup** | Find stale accounts (90+ days) with orphaned access |
| **Data Exfiltration Prevention** | Audit COPY/UNLOAD operations and external stage exposure |
| **RBAC Review** | Evaluate role hierarchy depth, privilege sprawl, and separation of duties |
| **CIS Benchmark Compliance** | Validate against CIS Snowflake Benchmark controls |
| **Trust Center Integration** | Surface Security Essentials, CIS, and Threat Intelligence findings |
| **Network Security Audit** | Assess network policies, Private Link status, and IP access patterns |
| **Policy Gap Detection** | Identify missing password, session, authentication, and masking policies |
| **Executive Compliance Reporting** | Generate stakeholder-ready dashboard with health scores |

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| **Snowflake Role** | `ACCOUNTADMIN` (required for ACCOUNT_USAGE and TRUST_CENTER views) |
| **Warehouse** | Any active warehouse (X-SMALL is sufficient) |
| **Data Latency** | `ACCOUNT_USAGE` views have up to 45-minute delay |
| **Trust Center** | Optional — scanner packages should be enabled for full Domain 11 coverage |
| **Execution Time** | ~10-20 minutes for full three-phase workflow |

---

## Trigger Keywords

The skill activates when user input matches any of these topics:

- Security audit / security scan / security assessment
- Vulnerability scan / vulnerability report
- Compliance review / compliance dashboard
- Risk evaluation / risk assessment
- MFA gaps / MFA coverage
- Password policy / session policy
- Network security / network policy
- RBAC issues / role-based access control
- Data exfiltration prevention
- Inactive user management
- Trust Center findings
- CIS benchmarks / CIS compliance
- Data masking / row-access policies
- Security reports / security posture

---

## Three-Phase Workflow

The skill executes three phases **strictly sequentially** — no skipping, merging, or parallelizing:

```
Phase 1: Security Assessment ──► Phase 2: Recommendations ──► Phase 3: Compliance Dashboard
```

| Phase | Purpose | Input | Output |
|-------|---------|-------|--------|
| **Phase 1** | Scan 12 security domains and capture findings | Live ACCOUNT_USAGE + TRUST_CENTER data | Assessment HTML report |
| **Phase 2** | Produce prioritized remediation plan | Phase 1 findings | Recommendation HTML report |
| **Phase 3** | Build interactive compliance dashboard | Phase 1 + Phase 2 data | Compliance Dashboard HTML |

---

## Phase 1 — Security Assessment

Phase 1 performs a comprehensive scan across all 12 security domains. Every finding is captured with: finding ID, severity (Critical/High/Medium/Low), affected resource, and description.

### Domain 1: Critical User Security Vulnerabilities

**Focus:** MFA coverage for all users and privileged accounts, weak default roles.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 1.1 | `USERS_WITHOUT_MFA` | **CRITICAL** | Users with password auth but no MFA enabled |
| 1.2 | `ACCOUNTADMIN_NO_MFA` | **CRITICAL** | ACCOUNTADMIN role holders without MFA |
| 1.3 | `WEAK_DEFAULT_ROLE` | MEDIUM | Users with PUBLIC or NULL default role |

**Key Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.USERS`

**MFA Detection Logic:**
- Filters for `HAS_PASSWORD = TRUE AND HAS_MFA = FALSE`
- Joins with `GRANTS_TO_USERS` to identify ACCOUNTADMIN holders specifically

**Remediation Approach:**
- Create tiered authentication policies: `human_user_mfa_policy` (UI users) and `service_account_policy` (key-pair)
- Generate `ALTER USER ... SET AUTHENTICATION POLICY` statements per affected user
- Optionally set account-level default: `ALTER ACCOUNT SET AUTHENTICATION POLICY`

---

### Domain 2: Inactive & Stale Account Assessment

**Focus:** Identify orphaned access from inactive, never-logged-in, or password-stale users.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 2.1 | `INACTIVE_USER` | MEDIUM | Users inactive for 90+ days |
| 2.2 | `NEVER_LOGGED_IN` | LOW | Users created 30+ days ago but never authenticated |
| 2.3 | `STALE_PASSWORD` | **HIGH** | Passwords not rotated within 90 days |
| 2.4 | `DISABLED_USER_WITH_GRANTS` | MEDIUM | Disabled users still holding active role assignments |

**Key Data Sources:** `SNOWFLAKE.ACCOUNT_USAGE.USERS`, `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS`

**Remediation Approach:**
1. Revoke admin roles from inactive users first
2. Generate `ALTER USER ... SET DISABLED = TRUE` for inactive accounts
3. Optionally create tracking table (`SECURITY_AUDIT.DISABLED_USERS`) and automated cleanup task
4. Force password reset via `ALTER USER ... SET MUST_CHANGE_PASSWORD = TRUE` for stale passwords
5. Disable accounts with passwords older than 365 days

---

### Domain 3: Failed Authentication Analysis

**Focus:** Detect brute force attempts and failed logins from unknown IP addresses.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 3.1 | `BRUTE_FORCE_ATTEMPT` | **HIGH** | 5+ failed login attempts from same user/IP in 7 days |
| 3.2 | `UNKNOWN_IP_LOGIN_FAILURE` | MEDIUM | Failed logins from IPs never seen in successful logins |

**Key Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY`

**Brute Force Detection Threshold:** `COUNT(*) >= 5` failed attempts grouped by `USER_NAME`, `CLIENT_IP`, `REPORTED_CLIENT_TYPE` within 7 days.

**Remediation Approach:**
1. Block suspicious IPs via network policy (`BLOCKED_IP_LIST`)
2. Reset passwords for targeted accounts
3. Set password lockout: `PASSWORD_MAX_RETRIES = 5, PASSWORD_LOCKOUT_TIME_MINS = 30`
4. Create monitoring alert (`brute_force_detection_alert`) with email notification

---

### Domain 4: Authentication Method Assessment

**Focus:** Evaluate authentication method distribution, MFA coverage by privilege level, and SSO adoption.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 4.1 | `AUTH_METHOD_DISTRIBUTION` | Assessment | Distribution: Password Only, Key-Pair Only, Password+Key, SSO/External |
| 4.2 | `AUTH_FACTOR_USAGE` | Assessment | Which auth factors are actually used in the last 30 days |
| 4.3 | `MFA_COVERAGE` | Assessment | Overall MFA coverage percentage for password users |
| 4.4 | `MFA_BY_PRIVILEGE` | Assessment | MFA adoption by role category (Admin/System/Standard) |
| 4.5 | `HUMAN_USER_NO_SSO` | MEDIUM | Human users authenticating with password instead of SSO |
| 4.6 | `SERVICE_ACCOUNT_PASSWORD` | **HIGH** | Service accounts using password instead of key-pair auth |

**Key Data Sources:** `SNOWFLAKE.ACCOUNT_USAGE.USERS`, `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY`

**Service Account Detection Logic:** Matches usernames containing `SVC`, `SERVICE`, `ETL`, `PIPELINE`, `BOT` or emails containing `service`.

**Remediation for Service Accounts:**
1. Generate RSA key pair locally (openssl commands provided)
2. `ALTER USER <SVC_ACCOUNT> SET RSA_PUBLIC_KEY = '...'`
3. After testing key-pair: `ALTER USER <SVC_ACCOUNT> SET PASSWORD = NULL`

---

### Domain 5: Data Exfiltration Risk Assessment

**Focus:** Prevent unauthorized data export via external stages, COPY/UNLOAD, and account parameters.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 5.1 | `EXFIL_PREVENTION_DISABLED` | **CRITICAL** | Account-level exfil prevention parameters not enabled |
| 5.2 | `EXTERNAL_STAGE_RISK` | **HIGH** | External named stages that may allow data exfiltration |
| 5.3 | `DATA_EXPORT_ACTIVITY` | Assessment | Recent COPY/UNLOAD/GET operations by user and role |
| 5.4 | `LARGE_DATA_EXPORT` | MEDIUM | Exports exceeding 1M rows in the last 7 days |

**Critical Account Parameters Checked:**
```
PREVENT_UNLOAD_TO_INLINE_URL
REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION
REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION
```

**Key Data Sources:** `SNOWFLAKE.ACCOUNT_USAGE.STAGES`, `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY`, Account parameters (`SHOW PARAMETERS`)

**Remediation:** Enable all three exfil prevention parameters via `ALTER ACCOUNT SET`, create approved storage integrations, and restrict GRANT on integrations to specific roles.

---

### Domain 6: Private Link Assessment

**Focus:** Assess whether Snowflake traffic flows over public internet or private network connectivity.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 6.1 | `NETWORK_ACCESS_PATTERN` | Assessment | Distribution of logins from private vs public IPs |
| 6.2 | `PUBLIC_IP_INVENTORY` | Assessment | All public IPs accessing the account (last 30 days) |

**Key Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY`

**Private IP Detection:** IPs matching `10.x`, `172.16-31.x`, `192.168.x` ranges.

**Remediation:** Configure AWS VPC Endpoint or Azure Private Endpoint, update DNS, create restrictive network policy for private IPs only.

---

### Domain 7: Network / Session / Password Policy Assessment

**Focus:** Evaluate security policies governing network access, session lifecycle, and password strength.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 7.1 | `NO_NETWORK_POLICY` / `ALLOW_ALL_POLICY` | **CRITICAL** / **HIGH** | No network policy or overly permissive policy |
| 7.2 | `NO_SESSION_POLICY` | **HIGH** | Sessions exceeding 8 hours without timeout policy |
| 7.3 | `NO_PASSWORD_POLICY` | **HIGH** | No enterprise password policy configured |

**Key Data Sources:** `SHOW NETWORK POLICIES`, `SNOWFLAKE.ACCOUNT_USAGE.SESSIONS`, `SNOWFLAKE.ACCOUNT_USAGE.USERS`

**Network Policy Assessment Rules:**
- Zero policies → **CRITICAL**
- ALLOW_ALL exists → **HIGH**
- Only narrow policies → Review for completeness

**Remediation Provides:**
- Enterprise password policy (14 char min, complexity, 90-day rotation, 12-history, lockout)
- Admin password policy (16 char min, 60-day rotation, 24-history, stricter lockout)
- Session policies: standard (60 min idle), admin (30 min idle), service (240 min idle)
- Network policy creation from legitimate IP inventory

---

### Domain 8: Encryption & Tri-Secret Secure Assessment

**Focus:** Verify data-at-rest encryption and evaluate Tri-Secret Secure / periodic rekeying status.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 8.1 | `DATA_AT_REST` | Assessment | Confirm AES-256 encryption (always compliant in Snowflake) |
| 8.2 | `SENSITIVE_DATA_CANDIDATES` | Assessment | Tables with PII-like names (customer, SSN, payment, etc.) |

**Table Name Patterns Scanned:** `%PII%`, `%SSN%`, `%CUSTOMER%`, `%PATIENT%`, `%FINANCIAL%`, `%CREDIT%`, `%PAYMENT%`

**Account Parameters Checked:** `ENCRYPTION`, `PERIODIC_DATA_REKEYING`

---

### Domain 9: RBAC Framework Evaluation

**Focus:** Evaluate role hierarchy depth, privilege concentration, separation of duties, and RBAC anti-patterns.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 9.1 | `ROLE_HIERARCHY_DEPTH` | Assessment | Recursive hierarchy depth (flag if > 7 levels) |
| 9.2 | `ROLE_PRIVILEGE_COUNT` | Assessment | Roles with excessive privilege counts (>100 = HIGH, >50 = MEDIUM) |
| 9.3 | `MULTI_ADMIN_ROLES` | **HIGH** | Users with multiple admin roles (separation of duties concern) |
| 9.4 | `ORPHANED_ROLE` | LOW | Roles with no users or parent roles assigned |
| 9.5 | `DIRECT_USER_GRANT` | MEDIUM | Privileges granted directly to users instead of roles |

**Key Data Sources:** `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES`, `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS`, `SNOWFLAKE.ACCOUNT_USAGE.ROLES`

**RBAC Anti-Patterns Detected:**
- Direct grants to users (bypasses role hierarchy)
- Users with 2+ admin roles (ACCOUNTADMIN + SECURITYADMIN, etc.)
- Orphaned roles (no members, no parent)
- Roles with 100+ privileges (overly broad)
- Hierarchy depth > 7 levels (performance and manageability)

**Remediation:** Create functional roles (`PLATFORM_ADMIN_ROLE`, `SECURITY_ADMIN_ROLE`, `DATA_ADMIN_ROLE`), revoke excess admin roles, implement ACCOUNTADMIN usage logging table.

---

### Domain 10: Network Security Assessment

**Focus:** IP access inventory and detection of suspicious non-corporate IP ranges.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 10.1 | `IP_INVENTORY` | Assessment | Total unique IPs, users, and logins (30 days) |
| 10.2 | `SUSPICIOUS_IP` | MEDIUM | Access from IPs outside expected corporate ranges |

**Key Data Source:** `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY`

---

### Domain 11: Trust Center Integration

**Focus:** Leverage Snowflake's native Trust Center for automated scanner findings, CIS Benchmarks, and Threat Intelligence.

| Query ID | Finding ID | Severity | Description |
|----------|-----------|----------|-------------|
| 11.1 | `SCANNER_INVENTORY` | Assessment | Which scanner packages are enabled/disabled |
| 11.2 | `TC_FINDINGS_SEVERITY` | Assessment | Open findings count by severity |
| 11.3 | `TC_FINDING_DETAIL` | **VARIES** | Detailed open findings with suggested actions |
| 11.4 | `TC_AT_RISK_ENTITY` | **VARIES** | Specific entities (users, tables) flagged by Trust Center |
| 11.5 | `TC_TREND` | Assessment | 30-day trend of open vs resolved findings |
| 11.6 | `SEC_ESSENTIALS` | **VARIES** | Security Essentials scanner findings (MFA, network, auth) |
| 11.7 | `CIS_BENCHMARK` | **VARIES** | CIS Snowflake Benchmark scanner findings |
| 11.8 | `THREAT_INTEL` | **VARIES** | Threat Intelligence findings (suspicious IPs, known bad actors) |

**Key Data Sources:** `SNOWFLAKE.TRUST_CENTER.SCANNER_PACKAGES_VIEW`, `SNOWFLAKE.TRUST_CENTER.FINDINGS_VIEW`, `SNOWFLAKE.TRUST_CENTER.TIME_SERIES_DAILY_FINDINGS`

**Three Scanner Packages (all should be enabled):**

| Package | Purpose |
|---------|---------|
| **Security Essentials** | Baseline security hygiene (MFA readiness, network policy, auth policy, passwordless readiness) |
| **CIS Benchmarks** | CIS Snowflake Benchmark controls (SSO, SCIM, key rotation, admin hygiene, encryption, masking, row-access) |
| **Threat Intelligence** | Active threat detection (suspicious IPs, known bad actors, anomalous patterns) |

**Trust Center Management SQL:**
```sql
CALL SNOWFLAKE.TRUST_CENTER.ENABLE_SCANNER_PACKAGE('<PACKAGE_NAME>');
CALL SNOWFLAKE.TRUST_CENTER.DISABLE_SCANNER_PACKAGE('<PACKAGE_NAME>');
CALL SNOWFLAKE.TRUST_CENTER.SET_SCANNER_SCHEDULE('<PACKAGE_NAME>', '<CRON_EXPRESSION>');
CALL SNOWFLAKE.TRUST_CENTER.SET_NOTIFICATION_INTEGRATION('<PACKAGE>', '<INTEGRATION>');
```

---

### Domain 12: CIS Benchmark Extended Checks

**Focus:** Direct validation of CIS Snowflake Benchmark controls not fully covered by Domains 1-10. These run regardless of Trust Center scanner status.

| Query ID | Finding ID | CIS Control | Severity | Description |
|----------|-----------|-------------|----------|-------------|
| 12.1 | `ADMIN_NO_EMAIL` | CIS 1.11 | MEDIUM | ACCOUNTADMIN users without email (can't receive security notifications) |
| 12.2 | `ADMIN_DEFAULT_ROLE` | CIS 1.12 | **HIGH** | ACCOUNTADMIN set as default role |
| 12.3 | `KEY_ROTATION_NEEDED` | CIS 1.7 | MEDIUM | Users with RSA keys — verify 90-day rotation |
| 12.4 | `ADMIN_OWNED_TASK` | CIS 1.14-1.17 | **HIGH** | Tasks owned by admin roles instead of functional roles |
| 12.5 | `MASKING_POLICY_COVERAGE` | CIS 4.10 | MEDIUM | Assess data masking policy coverage (policy count, columns protected) |
| 12.6 | `ROW_ACCESS_COVERAGE` | CIS 4.11 | MEDIUM | Assess row-access policy coverage (policy count, tables protected) |
| 12.7 | `TRI_SECRET_NOT_ENABLED` | CIS 4.9 | MEDIUM | Periodic rekeying / Tri-Secret Secure status |
| 12.8 | `RETENTION_CHECK` | CIS 4.3-4.4 | LOW | Tables with 0 retention (no recovery) or >7 days (cost impact) |

**Key Data Sources:** `SNOWFLAKE.ACCOUNT_USAGE.USERS`, `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS`, `SNOWFLAKE.ACCOUNT_USAGE.TASKS`, `SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES`, `SNOWFLAKE.ACCOUNT_USAGE.TABLES`, Account parameters

**Remediation Examples:**
- `ALTER USER <ADMIN> SET EMAIL = 'admin@company.com'`
- `ALTER USER <USER> SET DEFAULT_ROLE = 'SYSADMIN'`
- `GRANT OWNERSHIP ON TASK ... TO ROLE <FUNCTIONAL_ROLE> REVOKE CURRENT GRANTS`
- Create masking policies: `CREATE MASKING POLICY pii_email_mask AS ...`
- Enable rekeying: `ALTER ACCOUNT SET PERIODIC_DATA_REKEYING = TRUE`

---

### Assessment Checklist

Complete inventory of all findings checked during Phase 1, with their severity:

| Area | Finding ID | Domain | Risk if Gap Found |
|------|-----------|--------|-------------------|
| MFA Coverage | `USERS_WITHOUT_MFA` | 1 | CRITICAL |
| Admin MFA | `ACCOUNTADMIN_NO_MFA` | 1 | CRITICAL |
| Data Exfiltration | `EXFIL_PREVENTION_DISABLED` | 5 | CRITICAL |
| Trust Center Scanners | `SCANNER_DISABLED` | 11 | HIGH |
| Trust Center Critical Findings | `TC_FINDING_DETAIL` | 11 | VARIES |
| CIS Benchmark Findings | `CIS_BENCHMARK` | 11 | VARIES |
| Threat Intelligence Findings | `THREAT_INTEL` | 11 | VARIES |
| Password Rotation | `STALE_PASSWORD` | 2 | HIGH |
| Service Account Auth | `SERVICE_ACCOUNT_PASSWORD` | 4 | HIGH |
| Brute Force | `BRUTE_FORCE_ATTEMPT` | 3 | HIGH |
| Network Policy | `NO_NETWORK_POLICY` | 7 | HIGH |
| Session Policy | `NO_SESSION_POLICY` | 7 | HIGH |
| RBAC Separation | `MULTI_ADMIN_ROLES` | 9 | HIGH |
| Private Link | `NO_PRIVATE_LINK` | 6 | HIGH |
| Admin Default Role | `ADMIN_DEFAULT_ROLE` | 12 | HIGH |
| Admin-Owned Tasks | `ADMIN_OWNED_TASK` | 12 | HIGH |
| Inactive Users | `INACTIVE_USER` | 2 | MEDIUM |
| Auth Method | `HUMAN_USER_NO_SSO` | 4 | MEDIUM |
| RBAC Structure | `DIRECT_USER_GRANT` | 9 | MEDIUM |
| Admin No Email | `ADMIN_NO_EMAIL` | 12 | MEDIUM |
| Key Rotation | `KEY_ROTATION_NEEDED` | 12 | MEDIUM |
| Masking Policies | `MASKING_POLICY_COVERAGE` | 12 | MEDIUM |
| Row Access Policies | `ROW_ACCESS_COVERAGE` | 12 | MEDIUM |
| Tri-Secret Secure | `TRI_SECRET_NOT_ENABLED` | 12 | MEDIUM |
| Role Sprawl | `ORPHANED_ROLE` | 9 | LOW |
| Data Retention | `RETENTION_CHECK` | 12 | LOW |

### Phase 1 Report Output

| Property | Value |
|----------|-------|
| **Filename** | `Report-Security-Assessment-DD-MM-YYYY.html` |
| **Location** | `snowflake-security-scanner/reports/` |

**Required Sections:**
- Report Generation Summary banner (TOP) with total Phase 1 elapsed time
- Executive summary with total findings by severity
- Detailed findings table per domain
- Affected objects and discovery timestamps
- Assessment checklist completion status

---

## Phase 2 — Security Recommendations

Using exclusively Phase 1 findings as input, Phase 2 produces a prioritized, actionable remediation plan with SQL commands, effort estimates, and rollback procedures.

### Priority Classification

| Priority | SLA | Description |
|----------|-----|-------------|
| **P0 — Critical** | Within 24 hours | Immediate action required |
| **P1 — High** | Within 7 days | Urgent remediation |
| **P2 — Medium** | Within 30 days | Scheduled remediation |
| **P3 — Low** | Within 90 days | Best-practice improvements |

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

### Remediation Verification Checklist

After remediation is applied, verify each fix with these queries:

| Check | Verification Query |
|-------|-------------------|
| MFA coverage | `SELECT NAME, HAS_MFA FROM SNOWFLAKE.ACCOUNT_USAGE.USERS WHERE HAS_PASSWORD = TRUE AND DELETED_ON IS NULL` |
| Password policy | `SHOW PASSWORD POLICIES` |
| Session policy | `SHOW SESSION POLICIES` |
| Network policy | `SHOW NETWORK POLICIES` |
| Exfil prevention | `SHOW PARAMETERS LIKE 'PREVENT%' IN ACCOUNT` |
| Storage integration | `SHOW PARAMETERS LIKE 'REQUIRE_STORAGE%' IN ACCOUNT` |
| Remaining inactive | `SELECT COUNT(*) FROM ... WHERE LAST_SUCCESS_LOGIN < DATEADD(day, -90, ...)` |
| Admin role separation | `SELECT GRANTEE_NAME, COUNT(*) FROM ... WHERE ROLE IN (...) GROUP BY ... HAVING COUNT(*) > 1` |

### Rollback Procedures

If any remediation causes issues, rollback commands are provided:

| Remediation | Rollback Command |
|------------|-----------------|
| Authentication policy | `ALTER USER <USER> UNSET AUTHENTICATION POLICY` |
| Password policy | `ALTER ACCOUNT UNSET PASSWORD POLICY` |
| Session policy | `ALTER ACCOUNT UNSET SESSION POLICY` |
| Network policy | `ALTER ACCOUNT UNSET NETWORK_POLICY` |
| Disabled user | `ALTER USER <USER> SET DISABLED = FALSE` |
| Exfil prevention | `ALTER ACCOUNT SET PREVENT_UNLOAD_TO_INLINE_URL = FALSE` |
| Storage integration req | `ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = FALSE` |

### Phase 2 Report Output

| Property | Value |
|----------|-------|
| **Filename** | `Report-Security-Recommendation-DD-MM-YYYY.html` |
| **Location** | `snowflake-security-scanner/reports/` |

**Required Sections:**
- Report Generation Summary banner (TOP) with total Phase 2 elapsed time
- Reference to source Phase 1 assessment report filename
- Prioritized recommendation table (P0 through P3)
- Detailed fix instructions per finding with SQL commands
- Estimated remediation effort
- Rollback procedures
- Verification checklist
- Post-remediation monitoring task

---

## Phase 3 — Compliance Dashboard

### Dashboard Panels

| Panel | Content |
|-------|---------|
| **Category Breakdown** | Finding count, completion %, and status for each security category |
| **Priority Tracking** | Remediation timeline adherence for P0–P3 against SLA windows |
| **Risk Flagging** | Overdue items (SLA breached) and at-risk items (within 48 hours of expiry) |
| **Overall Health Score** | Single composite compliance percentage |

**Security Categories in Dashboard:**

| # | Category | Covers |
|---|----------|--------|
| 1 | Access Control | User MFA, inactive accounts, stale passwords |
| 2 | Authentication | Auth methods, SSO adoption, service account auth |
| 3 | Network Security | Network policies, Private Link, IP access patterns |
| 4 | Data Protection | Exfil prevention, external stages, export activity |
| 5 | RBAC | Role hierarchy, privilege sprawl, admin separation |
| 6 | Encryption | AES-256 compliance, Tri-Secret Secure, periodic rekeying |
| 7 | Auditing | Session policies, password policies, monitoring |
| 8 | Trust Center | Security Essentials, CIS Benchmarks, Threat Intelligence |
| 9 | CIS Extended | Masking policies, row-access policies, key rotation, admin hygiene, data retention |

### Visual Indicators and Scoring

| Indicator | Description |
|-----------|-------------|
| Progress bars | Per priority bucket, per category, and overall remediation |
| Health score | Single composite percentage across all categories |
| Risk highlights | Color-coded: red (overdue), amber (at-risk within 48h), green (compliant) |

### Phase 3 Report Output

| Property | Value |
|----------|-------|
| **Filename** | `Report-Compliance-Dashboard-DD-MM-YYYY.html` |
| **Location** | `snowflake-security-scanner/reports/` |

**Technical Requirements:**
- Fully interactive, self-contained HTML
- No external dependencies
- Refresh-ready for ongoing progress tracking
- Suitable for executive presentation
- Print-friendly styling

---

## SQL Query Inventory

Complete inventory of all SQL queries executed during the assessment:

| Domain | Query ID | Target | Finding ID | Severity |
|--------|----------|--------|------------|----------|
| 1 | 1.1 | USERS | `USERS_WITHOUT_MFA` | CRITICAL |
| 1 | 1.2 | USERS + GRANTS_TO_USERS | `ACCOUNTADMIN_NO_MFA` | CRITICAL |
| 1 | 1.3 | USERS | `WEAK_DEFAULT_ROLE` | MEDIUM |
| 2 | 2.1 | USERS | `INACTIVE_USER` | MEDIUM |
| 2 | 2.2 | USERS | `NEVER_LOGGED_IN` | LOW |
| 2 | 2.3 | USERS | `STALE_PASSWORD` | HIGH |
| 2 | 2.4 | USERS + GRANTS_TO_USERS | `DISABLED_USER_WITH_GRANTS` | MEDIUM |
| 3 | 3.1 | LOGIN_HISTORY | `BRUTE_FORCE_ATTEMPT` | HIGH |
| 3 | 3.2 | LOGIN_HISTORY | `UNKNOWN_IP_LOGIN_FAILURE` | MEDIUM |
| 4 | 4.1 | USERS | `AUTH_METHOD_DISTRIBUTION` | Assessment |
| 4 | 4.2 | LOGIN_HISTORY | `AUTH_FACTOR_USAGE` | Assessment |
| 4 | 4.3 | USERS | `MFA_COVERAGE` | Assessment |
| 4 | 4.4 | USERS + GRANTS_TO_USERS | `MFA_BY_PRIVILEGE` | Assessment |
| 4 | 4.5 | USERS | `HUMAN_USER_NO_SSO` | MEDIUM |
| 4 | 4.6 | USERS | `SERVICE_ACCOUNT_PASSWORD` | HIGH |
| 5 | 5.1 | Account parameters | `EXFIL_PREVENTION_DISABLED` | CRITICAL |
| 5 | 5.2 | STAGES | `EXTERNAL_STAGE_RISK` | HIGH |
| 5 | 5.3 | QUERY_HISTORY | `DATA_EXPORT_ACTIVITY` | Assessment |
| 5 | 5.4 | QUERY_HISTORY | `LARGE_DATA_EXPORT` | MEDIUM |
| 6 | 6.1 | LOGIN_HISTORY | `NETWORK_ACCESS_PATTERN` | Assessment |
| 6 | 6.2 | LOGIN_HISTORY | `PUBLIC_IP_INVENTORY` | Assessment |
| 7 | 7.1 | SHOW NETWORK POLICIES | `NO_NETWORK_POLICY` | CRITICAL/HIGH |
| 7 | 7.2 | SESSIONS | `NO_SESSION_POLICY` | Assessment |
| 7 | 7.3 | USERS | `NO_PASSWORD_POLICY` | Assessment |
| 8 | 8.1 | Static check | `DATA_AT_REST` | Assessment |
| 8 | 8.2 | TABLES | `SENSITIVE_DATA_CANDIDATES` | Assessment |
| 9 | 9.1 | GRANTS_TO_ROLES (recursive) | `ROLE_HIERARCHY_DEPTH` | Assessment |
| 9 | 9.2 | GRANTS_TO_ROLES | `ROLE_PRIVILEGE_COUNT` | Assessment |
| 9 | 9.3 | GRANTS_TO_USERS | `MULTI_ADMIN_ROLES` | HIGH |
| 9 | 9.4 | ROLES + GRANTS | `ORPHANED_ROLE` | LOW |
| 9 | 9.5 | GRANTS_TO_USERS | `DIRECT_USER_GRANT` | MEDIUM |
| 10 | 10.1 | LOGIN_HISTORY | `IP_INVENTORY` | Assessment |
| 10 | 10.2 | LOGIN_HISTORY | `SUSPICIOUS_IP` | MEDIUM |
| 11 | 11.1 | SCANNER_PACKAGES_VIEW | `SCANNER_INVENTORY` | Assessment |
| 11 | 11.2 | FINDINGS_VIEW | `TC_FINDINGS_SEVERITY` | Assessment |
| 11 | 11.3 | FINDINGS_VIEW | `TC_FINDING_DETAIL` | VARIES |
| 11 | 11.4 | FINDINGS_VIEW (FLATTEN) | `TC_AT_RISK_ENTITY` | VARIES |
| 11 | 11.5 | TIME_SERIES_DAILY_FINDINGS | `TC_TREND` | Assessment |
| 11 | 11.6 | FINDINGS_VIEW | `SEC_ESSENTIALS` | VARIES |
| 11 | 11.7 | FINDINGS_VIEW | `CIS_BENCHMARK` | VARIES |
| 11 | 11.8 | FINDINGS_VIEW | `THREAT_INTEL` | VARIES |
| 12 | 12.1 | USERS + GRANTS_TO_USERS | `ADMIN_NO_EMAIL` | MEDIUM |
| 12 | 12.2 | USERS | `ADMIN_DEFAULT_ROLE` | HIGH |
| 12 | 12.3 | USERS | `KEY_ROTATION_NEEDED` | MEDIUM |
| 12 | 12.4 | TASKS | `ADMIN_OWNED_TASK` | HIGH |
| 12 | 12.5 | POLICY_REFERENCES | `MASKING_POLICY_COVERAGE` | Assessment |
| 12 | 12.6 | POLICY_REFERENCES | `ROW_ACCESS_COVERAGE` | Assessment |
| 12 | 12.7 | Account parameters | `TRI_SECRET_NOT_ENABLED` | MEDIUM |
| 12 | 12.8 | TABLES | `RETENTION_CHECK` | LOW |

---

## Data Sources

All queries target these Snowflake system views:

| Schema | View | Used By Domains |
|--------|------|-----------------|
| `SNOWFLAKE.ACCOUNT_USAGE` | `USERS` | 1, 2, 4, 7, 8, 12 |
| `SNOWFLAKE.ACCOUNT_USAGE` | `GRANTS_TO_USERS` | 1, 2, 4, 9, 12 |
| `SNOWFLAKE.ACCOUNT_USAGE` | `GRANTS_TO_ROLES` | 9 |
| `SNOWFLAKE.ACCOUNT_USAGE` | `ROLES` | 9 |
| `SNOWFLAKE.ACCOUNT_USAGE` | `LOGIN_HISTORY` | 3, 4, 6, 7, 10 |
| `SNOWFLAKE.ACCOUNT_USAGE` | `SESSIONS` | 7 |
| `SNOWFLAKE.ACCOUNT_USAGE` | `QUERY_HISTORY` | 5 |
| `SNOWFLAKE.ACCOUNT_USAGE` | `STAGES` | 5 |
| `SNOWFLAKE.ACCOUNT_USAGE` | `TABLES` | 8, 12 |
| `SNOWFLAKE.ACCOUNT_USAGE` | `TASKS` | 12 |
| `SNOWFLAKE.ACCOUNT_USAGE` | `POLICY_REFERENCES` | 12 |
| `SNOWFLAKE.TRUST_CENTER` | `SCANNER_PACKAGES_VIEW` | 11 |
| `SNOWFLAKE.TRUST_CENTER` | `FINDINGS_VIEW` | 11 |
| `SNOWFLAKE.TRUST_CENTER` | `TIME_SERIES_DAILY_FINDINGS` | 11 |

---

## Finding Severity Definitions

| Severity | Description | Expected SLA |
|----------|-------------|-------------|
| **CRITICAL** | Immediate security risk — active exploitation possible, no compensating controls | P0: 24 hours |
| **HIGH** | Significant risk — missing fundamental security controls | P1: 7 days |
| **MEDIUM** | Moderate risk — security best practice not followed | P2: 30 days |
| **LOW** | Minor risk — improvement opportunity, housekeeping | P3: 90 days |
| **Assessment** | Informational — no direct risk, provides context for other findings | N/A |

---

## Execution Rules

| # | Rule |
|---|------|
| 1 | Run all three phases strictly sequentially — no skipping, merging, or parallelizing |
| 2 | Scan all 12 security domains in Phase 1 — none may be omitted |
| 3 | Capture and display total elapsed time for Phase 1 and Phase 2 individually |
| 4 | Substitute `DD-MM-YYYY` with today's actual date in all filenames |
| 5 | All HTML reports must be professionally styled, print-friendly, executive-ready |
| 6 | No DDL, DML, or configuration changes — assessment and documentation only |
| 7 | Save all reports exclusively to `snowflake-security-scanner/reports/` |
| 8 | Display "Report Generation Summary" banner at TOP of Phase 1 and Phase 2 reports |

---

## Error Handling and Self-Healing

The skill includes a built-in self-healing mechanism for query failures:

### Failure Response Flow

```
Query Fails ──► Diagnose Root Cause ──► Apply Fix ──► Retry
                                                        │
                                         ┌──────────────┤
                                         ▼              ▼
                                      Success        Failed Again
                                         │              │
                                  Log & Continue    Mark SKIPPED
                                                        │
                                              Flag in "Manual Review
                                              Required" section
```

### What Gets Logged for Each Failure

| Field | Description |
|-------|-------------|
| Step name / query ID | Which query or step failed |
| Error message | Exact Snowflake error |
| Root cause diagnosis | Why it failed |
| Corrective fix | What was changed |
| Retry outcome | Success or Failed after retry |

### Self-Healing Actions

- On successful recovery: the corrected query is updated in the skill file with an inline comment:
  ```sql
  -- [FIXED on DD-MM-YYYY]: <description of what was corrected and why>
  ```
- All self-healing actions are consolidated into a "Self-Healing Summary" section appended to Phase 1 and Phase 2 reports
- If a step fails and cannot be recovered: marked as SKIPPED with clear root cause, flagged under "Manual Review Required" section

---

## Report File Inventory

| Phase | Filename Pattern | Description |
|-------|-----------------|-------------|
| Phase 1 | `Report-Security-Assessment-DD-MM-YYYY.html` | Security findings across all 12 domains |
| Phase 2 | `Report-Security-Recommendation-DD-MM-YYYY.html` | Prioritized remediation plan with SQL and rollback |
| Phase 3 | `Report-Compliance-Dashboard-DD-MM-YYYY.html` | Interactive compliance tracking dashboard |

All reports saved to: `snowflake-security-scanner/reports/`

---

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| Permission errors on ACCOUNT_USAGE views | Insufficient role | Switch to `ACCOUNTADMIN` |
| TRUST_CENTER views not found | Trust Center not enabled or role lacks access | Enable Trust Center scanners; log Domain 11 queries as SKIPPED |
| `SCANNER_PACKAGES_VIEW` returns 0 rows | No scanner packages installed | Call `ENABLE_SCANNER_PACKAGE()` for each package |
| Query returns 0 findings for a domain | No security issues in that domain | Expected — record as "No findings" |
| SESSIONS view query is slow | Large session history | Add date filter: `DATEADD(day, -7, ...)` |
| `GRANTS_TO_ROLES` recursive CTE times out | Very deep or wide role hierarchy | Reduce `depth < 10` to `depth < 5` |
| LOGIN_HISTORY subquery in 3.2 is slow | Large login history | Reduce lookback window for the subquery |
| Phase 2 references missing findings | Phase 1 incomplete | Ensure Phase 1 completes fully before Phase 2 |
| Reports not in expected folder | Path mismatch | Verify `snowflake-security-scanner/reports/` |
| Self-healing loop | Query cannot be auto-fixed | Marked as SKIPPED in "Manual Review Required" section |
| HTML reports display issues | Browser compatibility | Use a modern browser (Chrome, Firefox, Edge) |
