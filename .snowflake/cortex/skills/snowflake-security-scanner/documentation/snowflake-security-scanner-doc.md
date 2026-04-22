# Snowflake Security Scanner — Documentation

**Author:** Rajiv Gupta
**LinkedIn:** [https://www.linkedin.com/in/rajiv-gupta-618b0228/](https://www.linkedin.com/in/rajiv-gupta-618b0228/)
**Version:** 1.0
**Last Updated:** April 22, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Three-Phase Workflow](#three-phase-workflow)
   - [Phase 1 — Security Assessment](#phase-1--security-assessment)
   - [Phase 2 — Security Recommendations](#phase-2--security-recommendations)
   - [Phase 3 — Compliance Dashboard](#phase-3--compliance-dashboard)
6. [Security Domains Reference](#security-domains-reference)
   - [Domain 1 — Critical User Security Vulnerabilities](#domain-1--critical-user-security-vulnerabilities)
   - [Domain 2 — Inactive & Stale Account Assessment](#domain-2--inactive--stale-account-assessment)
   - [Domain 3 — Failed Authentication Analysis](#domain-3--failed-authentication-analysis)
   - [Domain 4 — Authentication Method Assessment](#domain-4--authentication-method-assessment)
   - [Domain 5 — Data Exfiltration Risk Assessment](#domain-5--data-exfiltration-risk-assessment)
   - [Domain 6 — Private Link Assessment](#domain-6--private-link-assessment)
   - [Domain 7 — Network / Session / Password Policy Assessment](#domain-7--network--session--password-policy-assessment)
   - [Domain 8 — Encryption & Tri-Secret Secure Assessment](#domain-8--encryption--tri-secret-secure-assessment)
   - [Domain 9 — RBAC Framework Evaluation](#domain-9--rbac-framework-evaluation)
   - [Domain 10 — Network Security Assessment](#domain-10--network-security-assessment)
   - [Domain 11 — Trust Center Integration](#domain-11--trust-center-integration)
   - [Domain 12 — CIS Benchmark Extended Checks](#domain-12--cis-benchmark-extended-checks)
7. [Finding Severity Definitions](#finding-severity-definitions)
8. [Remediation Priority Matrix](#remediation-priority-matrix)
9. [Assessment Checklist](#assessment-checklist)
10. [Remediation Verification & Rollback](#remediation-verification--rollback)
11. [Error Handling & Self-Healing](#error-handling--self-healing)
12. [Execution Rules](#execution-rules)
13. [Report Output Specifications](#report-output-specifications)
14. [Data Sources](#data-sources)
15. [Frequently Asked Questions](#frequently-asked-questions)

---

## Overview

The Snowflake Security Scanner is a Cortex Code skill that performs a comprehensive, read-only security posture assessment of a Snowflake account. It evaluates 12 security domains, produces prioritized remediation recommendations, and generates an interactive compliance dashboard — all without making any DDL, DML, or configuration changes.

### Key Capabilities

- Scans 12 security domains covering user security, authentication, network, data protection, RBAC, encryption, Trust Center, and CIS Benchmarks.
- Identifies findings at four severity levels: Critical, High, Medium, and Low.
- Produces three HTML reports: Assessment, Recommendations, and Compliance Dashboard.
- Includes step-by-step remediation SQL for every finding with rollback procedures.
- Integrates with Snowflake Trust Center for automated scanner findings, CIS Benchmark validation, and Threat Intelligence detection.
- Features self-healing: if a query fails, the skill auto-diagnoses, fixes, retries, and logs the correction.

### What This Skill Does NOT Do

- It does **not** execute any DDL, DML, or configuration changes.
- It does **not** modify account settings, users, roles, policies, or any Snowflake objects.
- It is strictly an assessment and documentation tool.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Snowflake Security Scanner                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PHASE 1: Security Assessment                                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐         ┌──────────┐  │
│  │ Domain 1 │ │ Domain 2 │ │ Domain 3 │  ...    │Domain 12 │  │
│  │ User Sec │ │ Inactive │ │ Auth Fail│         │CIS Extnd │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘         └────┬─────┘  │
│       │             │            │                     │        │
│       └─────────────┴────────────┴─────────────────────┘        │
│                          │                                      │
│                          ▼                                      │
│            ┌──────────────────────────┐                         │
│            │  Assessment HTML Report  │                         │
│            └────────────┬─────────────┘                         │
│                         │                                       │
│  PHASE 2: Recommendations                                      │
│            ┌────────────▼─────────────┐                         │
│            │ Prioritized Remediation  │                         │
│            │ Plan (P0-P3) with SQL    │                         │
│            └────────────┬─────────────┘                         │
│                         │                                       │
│            ┌────────────▼─────────────┐                         │
│            │ Recommendation HTML Rpt  │                         │
│            └────────────┬─────────────┘                         │
│                         │                                       │
│  PHASE 3: Compliance Dashboard                                 │
│            ┌────────────▼─────────────┐                         │
│            │ Interactive Dashboard    │                         │
│            │ (HTML, self-contained)   │                         │
│            └──────────────────────────┘                         │
│                                                                 │
│  All reports → snowflake-security-scanner/reports/              │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Input:** Read-only SQL queries against `SNOWFLAKE.ACCOUNT_USAGE` views and `SNOWFLAKE.TRUST_CENTER` views.
2. **Processing:** Findings are categorized by domain, tagged with severity, and mapped to remediation steps.
3. **Output:** Three self-contained HTML reports saved to the `snowflake-security-scanner/reports/` directory.

---

## Prerequisites

### Required Role and Privileges

The scanner requires a role with read access to Snowflake metadata views. **ACCOUNTADMIN** is recommended for full coverage.

```sql
SELECT CURRENT_ROLE(), CURRENT_USER();
```

Minimum required access:
- `SNOWFLAKE.ACCOUNT_USAGE.USERS` — User account metadata
- `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS` — Role grants to users
- `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES` — Role-to-role grants
- `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY` — Authentication events
- `SNOWFLAKE.ACCOUNT_USAGE.SESSIONS` — Session metadata
- `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` — Query execution logs
- `SNOWFLAKE.ACCOUNT_USAGE.STAGES` — Stage inventory
- `SNOWFLAKE.ACCOUNT_USAGE.TABLES` — Table metadata
- `SNOWFLAKE.ACCOUNT_USAGE.ROLES` — Role definitions
- `SNOWFLAKE.ACCOUNT_USAGE.TASKS` — Task ownership
- `SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES` — Masking and row-access policy bindings
- `SNOWFLAKE.TRUST_CENTER.SCANNER_PACKAGES_VIEW` — Trust Center scanner inventory
- `SNOWFLAKE.TRUST_CENTER.FINDINGS_VIEW` — Trust Center findings
- `SNOWFLAKE.TRUST_CENTER.TIME_SERIES_DAILY_FINDINGS` — Findings trend data
- `SHOW PARAMETERS` / `SHOW NETWORK POLICIES` / `SHOW PASSWORD POLICIES` — Account-level parameters

### Workspace Setup

The skill expects the following directory structure:

```
snowflake-security-scanner/
├── SKILL.md                          # Skill definition (do not modify manually)
├── documentation/
│   └── snowflake-security-scanner-doc.md  # This file
└── reports/                          # Generated HTML reports land here
    ├── Report-Security-Assessment-<DD-MM-YYYY>.html
    ├── Report-Security-Recommendation-<DD-MM-YYYY>.html
    └── Report-Compliance-Dashboard-<DD-MM-YYYY>.html
```

---

## Quick Start

1. Open Snowsight and navigate to the workspace containing this skill.
2. Ensure you are using the **ACCOUNTADMIN** role (or equivalent with read access to `SNOWFLAKE.ACCOUNT_USAGE` and `SNOWFLAKE.TRUST_CENTER`).
3. Invoke the skill by asking Cortex Code:
   > "Run the Snowflake Security Scanner"
4. The scanner will execute all three phases sequentially and save reports to `snowflake-security-scanner/reports/`.
5. Review the generated HTML reports by opening them from the workspace file browser.

---

## Three-Phase Workflow

The scanner executes three phases **strictly sequentially**. Each phase must fully complete before the next begins.

### Phase 1 — Security Assessment

Performs a comprehensive security scan across all 12 security domains. For each finding, the scanner captures:

| Field | Description |
|-------|-------------|
| `finding_id` | Unique identifier for the finding type (e.g., `USERS_WITHOUT_MFA`) |
| `severity` | Risk level: Critical, High, Medium, or Low |
| `affected_resource` | The specific user, role, object, or configuration affected |
| `description` | Human-readable explanation of the security gap |

**Output:** `Report-Security-Assessment-<DD-MM-YYYY>.html`

Report contents:
- Executive summary with overall security posture
- Total findings by severity (Critical / High / Medium / Low)
- Detailed findings table per domain
- Affected objects and resources
- Discovery timestamp for each finding
- "Report Generation Summary" banner at the top with total elapsed time

### Phase 2 — Security Recommendations

Takes Phase 1 findings as input and produces a detailed, actionable remediation plan organized by priority:

| Priority | SLA | Description |
|----------|-----|-------------|
| **P0 — Critical** | Within 24 hours | Immediate action required |
| **P1 — High** | Within 7 days | Urgent remediation |
| **P2 — Medium** | Within 30 days | Scheduled remediation |
| **P3 — Low** | Within 90 days | Best-practice improvements |

Each recommendation includes:
- Step-by-step remediation SQL from the corresponding domain section
- Business impact context
- Estimated remediation effort (Low / Medium / High)
- Rollback procedures in case of issues

**Output:** `Report-Security-Recommendation-<DD-MM-YYYY>.html`

Report contents:
- Reference to the source Phase 1 assessment report
- Prioritized recommendation table (P0–P3)
- Detailed fix instructions per finding
- Estimated remediation effort
- Rollback procedures
- Verification queries to confirm remediation success
- "Report Generation Summary" banner at the top with total elapsed time

### Phase 3 — Compliance Dashboard

Generates an interactive, self-contained HTML dashboard using data from Phases 1 and 2.

**Output:** `Report-Compliance-Dashboard-<DD-MM-YYYY>.html`

Dashboard features:
- **Category Breakdown:** Finding count, completion percentage, and status by security category (Access Control, Authentication, Network Security, Data Protection, RBAC, Encryption, Auditing, Trust Center, CIS Extended Checks).
- **Priority Tracking:** Remediation timeline adherence for each priority level (P0–P3) against defined SLA windows.
- **Visual Indicators:** Progress bars and/or charts per priority bucket, per category, and for overall remediation completion.
- **Risk Flagging:** Highlights overdue or at-risk items where SLA deadlines have been breached or are within 48 hours of expiry.
- **Overall Compliance Health Score:** Single composite percentage reflecting overall remediation progress.
- **Technical:** Fully interactive, self-contained HTML with no external dependencies, print-friendly, suitable for executive presentation.

---

## Security Domains Reference

### Domain 1 — Critical User Security Vulnerabilities

Evaluates the most critical user-level security gaps.

| Finding ID | Severity | Description |
|------------|----------|-------------|
| `USERS_WITHOUT_MFA` | CRITICAL | Users with password authentication but no MFA enabled |
| `ACCOUNTADMIN_NO_MFA` | CRITICAL | ACCOUNTADMIN-role users without MFA protection |
| `WEAK_DEFAULT_ROLE` | MEDIUM | Users with PUBLIC or no default role set |

**Key queries target:** `SNOWFLAKE.ACCOUNT_USAGE.USERS`, `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS`

**Remediation highlights:**
- Create tiered authentication policies (`human_user_mfa_policy`, `service_account_policy`)
- Generate per-user `ALTER USER ... SET AUTHENTICATION POLICY` statements
- Create admin-specific MFA policy for ACCOUNTADMIN users
- Optionally set account-level authentication policy default

### Domain 2 — Inactive & Stale Account Assessment

Identifies dormant accounts that represent unauthorized access risk.

| Finding ID | Severity | Description |
|------------|----------|-------------|
| `INACTIVE_USER` | MEDIUM | Users with no login activity for 90+ days |
| `NEVER_LOGGED_IN` | LOW | Users created 30+ days ago who have never authenticated |
| `STALE_PASSWORD` | HIGH | Passwords not rotated within 90 days |
| `DISABLED_USER_WITH_GRANTS` | MEDIUM | Disabled users that still hold active role assignments |

**Remediation highlights:**
- Revoke admin roles from inactive users first
- Generate `ALTER USER ... SET DISABLED = TRUE` commands
- Create tracking table (`SECURITY_AUDIT.DISABLED_USERS`) and optional automated cleanup task
- Force password reset with `MUST_CHANGE_PASSWORD = TRUE`
- Disable accounts with passwords older than 365 days

### Domain 3 — Failed Authentication Analysis

Detects potential brute force attacks and suspicious login patterns.

| Finding ID | Severity | Description |
|------------|----------|-------------|
| `BRUTE_FORCE_ATTEMPT` | HIGH | 5+ failed login attempts from the same user/IP in 7 days |
| `UNKNOWN_IP_LOGIN_FAILURE` | MEDIUM | Failed logins from IP addresses never seen in successful logins |

**Key queries target:** `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY` (last 7 days)

**Remediation highlights:**
- Block suspicious IPs via network policy (`BLOCKED_IP_LIST`)
- Reset passwords for targeted user accounts
- Configure password policy lockout (`PASSWORD_MAX_RETRIES`, `PASSWORD_LOCKOUT_TIME_MINS`)
- Create automated brute force detection alert with email notification

### Domain 4 — Authentication Method Assessment

Provides a comprehensive view of how users authenticate and identifies weak patterns.

| Finding / Assessment ID | Severity | Description |
|------------------------|----------|-------------|
| `AUTH_METHOD_DISTRIBUTION` | Info | Breakdown of auth methods: Password Only, Key-Pair Only, Password+Key-Pair, SSO/External Only |
| `AUTH_FACTOR_USAGE` | Info | Login authentication factors used in the last 30 days |
| `MFA_COVERAGE` | Info | MFA adoption percentage across all password-based users |
| `MFA_BY_PRIVILEGE` | Info | MFA coverage segmented by role privilege level (Admin / System / Standard) |
| `HUMAN_USER_NO_SSO` | MEDIUM | Human users authenticating via password instead of SSO |
| `SERVICE_ACCOUNT_PASSWORD` | HIGH | Service accounts using password instead of key-pair authentication |

**Remediation highlights:**
- Migrate service accounts to RSA key-pair authentication (includes `openssl` key generation commands)
- Set RSA public key and disable password for service accounts
- Transition human users to SSO/SAML

### Domain 5 — Data Exfiltration Risk Assessment

Evaluates account-level protections against unauthorized data export.

| Finding / Assessment ID | Severity | Description |
|------------------------|----------|-------------|
| `EXFIL_PREVENTION_DISABLED` | CRITICAL | `PREVENT_UNLOAD_TO_INLINE_URL` or `REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_*` not enabled |
| `EXTERNAL_STAGE_RISK` | HIGH | External named stages that could allow data exfiltration |
| `DATA_EXPORT_ACTIVITY` | Info | COPY/UNLOAD/GET operations in the last 30 days |
| `LARGE_DATA_EXPORT` | MEDIUM | Individual export operations exceeding 1M rows in the last 7 days |

**Remediation highlights:**
- Enable exfiltration prevention parameters:
  - `PREVENT_UNLOAD_TO_INLINE_URL = TRUE`
  - `REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = TRUE`
  - `REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION = TRUE`
- Create approved storage integrations with restricted `STORAGE_ALLOWED_LOCATIONS`

### Domain 6 — Private Link Assessment

Assesses whether the account uses private connectivity (AWS PrivateLink / Azure Private Link) versus public internet.

| Assessment ID | Description |
|---------------|-------------|
| `NETWORK_ACCESS_PATTERN` | Ratio of private IP vs. public IP logins in the last 30 days |
| `PUBLIC_IP_INVENTORY` | Full inventory of public IPs accessing the account |

**Remediation highlights:**
- Retrieve Private Link configuration: `SYSTEM$GET_PRIVATELINK_CONFIG()`
- AWS: Create VPC endpoint, configure DNS, update network policy, block public access
- Azure: Create Private Endpoint, configure Private DNS zone, validate

### Domain 7 — Network / Session / Password Policy Assessment

Evaluates the account's network, session, and password policy posture.

| Finding / Assessment ID | Severity | Description |
|------------------------|----------|-------------|
| `NO_NETWORK_POLICY` / `ALLOW_ALL_POLICY` | CRITICAL / HIGH | No network policy exists or a permissive ALLOW_ALL policy is in use |
| `SESSION_DURATION` | Info | Users with sessions exceeding 8 hours |
| `NO_SESSION_POLICY` | HIGH | No session timeout policy configured |
| `PASSWORD_AGE_DISTRIBUTION` | Info | Breakdown of password ages across users |
| `NO_PASSWORD_POLICY` | HIGH | No password complexity or rotation policy configured |

**Remediation highlights:**
- Create restrictive network policy from legitimate IP inventory
- Test on a single user before applying at account level
- Create tiered session policies: standard (60 min idle), admin (30 min idle), service (240 min idle)
- Create enterprise password policy (14+ chars, 90-day rotation, lockout after 5 retries)
- Create stricter admin password policy (16+ chars, 60-day rotation, lockout after 3 retries)

### Domain 8 — Encryption & Tri-Secret Secure Assessment

Validates encryption configuration and identifies potentially sensitive data.

| Assessment ID | Description |
|---------------|-------------|
| `DATA_AT_REST` | Confirms Snowflake's default AES-256 encryption at rest |
| `SENSITIVE_DATA_CANDIDATES` | Tables with names suggesting sensitive data (PII, SSN, CUSTOMER, PATIENT, FINANCIAL, CREDIT, PAYMENT) |

**Checks performed:**
- `SHOW PARAMETERS LIKE '%ENCRYPTION%' IN ACCOUNT`
- `SHOW PARAMETERS LIKE '%PERIODIC_DATA_REKEYING%' IN ACCOUNT`

### Domain 9 — RBAC Framework Evaluation

Evaluates the role-based access control structure for security anti-patterns.

| Finding / Assessment ID | Severity | Description |
|------------------------|----------|-------------|
| `ROLE_HIERARCHY_DEPTH` | Info | Maximum depth of the role hierarchy (warns if > 7 levels) |
| `ROLE_PRIVILEGE_COUNT` | Info | Roles with excessive privilege counts (flags > 50 or > 100) |
| `MULTI_ADMIN_ROLES` | HIGH | Users holding multiple admin roles (separation of duties concern) |
| `ORPHANED_ROLE` | LOW | Roles with no users or parent roles assigned |
| `DIRECT_USER_GRANT` | MEDIUM | Grants made directly to users instead of roles (RBAC anti-pattern) |

**Remediation highlights:**
- Create functional roles (`PLATFORM_ADMIN_ROLE`, `SECURITY_ADMIN_ROLE`, `DATA_ADMIN_ROLE`)
- Revoke excess admin roles and assign functional roles instead
- Implement ACCOUNTADMIN usage logging table
- Transfer ownership of orphaned roles or drop them

### Domain 10 — Network Security Assessment

Provides a network-level view of account access patterns.

| Finding / Assessment ID | Severity | Description |
|------------------------|----------|-------------|
| `IP_INVENTORY` | Info | Count of unique IPs, users, and total logins in 30 days |
| `SUSPICIOUS_IP` | MEDIUM | IPs outside expected corporate ranges (non-RFC 1918) |

### Domain 11 — Trust Center Integration

Leverages Snowflake's built-in Trust Center to supplement manual domain checks with automated scanner findings.

| Finding / Assessment ID | Severity | Description |
|------------------------|----------|-------------|
| `SCANNER_INVENTORY` | Info | Inventory of all Trust Center scanner packages and their enabled/disabled status |
| `SCANNER_DISABLED` | HIGH | Scanner packages that are disabled (coverage gaps) |
| `TC_FINDINGS_SEVERITY` | VARIES | Count of open Trust Center findings by severity |
| `TC_FINDING_DETAIL` | VARIES | Full details of all open Trust Center findings |
| `TC_AT_RISK_ENTITY` | VARIES | Specific entities (users, objects) at risk from open findings |
| `TC_TREND` | Info | 30-day trend of open and resolved findings |
| `SEC_ESSENTIALS` | VARIES | Open findings from the Security Essentials scanner |
| `CIS_BENCHMARK` | VARIES | Open findings from the CIS Benchmarks scanner |
| `THREAT_INTEL` | VARIES | Open findings from the Threat Intelligence scanner |

**Three scanner packages evaluated:**
1. **Security Essentials** — Baseline security hygiene (MFA readiness, network policy, authentication policy, passwordless readiness)
2. **CIS Benchmarks** — Industry compliance framework (SSO, SCIM, key-pair rotation, admin controls, Tri-Secret Secure, data masking, row-access policies, data retention)
3. **Threat Intelligence** — Active threat detection (suspicious IP connections, known bad actors, anomalous patterns)

**Remediation highlights:**
- Enable disabled scanner packages: `CALL SNOWFLAKE.TRUST_CENTER.ENABLE_SCANNER_PACKAGE('<PACKAGE_NAME>')`
- Set scanner schedules: `CALL SNOWFLAKE.TRUST_CENTER.SET_SCANNER_SCHEDULE('<PACKAGE_NAME>', '<CRON>')`
- Configure notification integrations for ongoing monitoring

### Domain 12 — CIS Benchmark Extended Checks

Direct validation of CIS Snowflake Benchmark controls not fully covered by Domains 1–10. These run regardless of Trust Center scanner status.

| Finding ID | CIS Control | Severity | Description |
|------------|-------------|----------|-------------|
| `ADMIN_NO_EMAIL` | 1.11 | MEDIUM | ACCOUNTADMIN users without an email set (cannot receive security notifications) |
| `ADMIN_DEFAULT_ROLE` | 1.12 | HIGH | Users with ACCOUNTADMIN set as their default role |
| `KEY_ROTATION_NEEDED` | 1.7 | MEDIUM | Users with RSA keys that may need rotation (verify within 90 days) |
| `ADMIN_OWNED_TASK` | 1.14–1.17 | HIGH | Tasks owned by admin roles instead of functional roles |
| `MASKING_POLICY_COVERAGE` | 4.10 | MEDIUM | Number of masking policies and protected columns (flags zero if sensitive tables found) |
| `ROW_ACCESS_COVERAGE` | 4.11 | MEDIUM | Number of row-access policies and protected tables |
| `TRI_SECRET_NOT_ENABLED` | 4.9 | MEDIUM | Periodic data rekeying not enabled; Tri-Secret Secure not configured |
| `RETENTION_CHECK` | 4.3–4.4 | LOW | Tables with zero Time Travel retention or extended retention > 7 days |

**Remediation highlights:**
- Set email for admin users: `ALTER USER <USER> SET EMAIL = 'admin@company.com'`
- Change admin default role: `ALTER USER <USER> SET DEFAULT_ROLE = 'SYSADMIN'`
- Transfer task ownership: `GRANT OWNERSHIP ON TASK ... TO ROLE <FUNCTIONAL_ROLE>`
- Create masking policies for PII columns
- Create row-access policies for multi-tenant data
- Enable periodic rekeying: `ALTER ACCOUNT SET PERIODIC_DATA_REKEYING = TRUE`

---

## Finding Severity Definitions

| Severity | Definition | Example Findings |
|----------|------------|-----------------|
| **CRITICAL** | Immediate risk of unauthorized access or data breach. Must be addressed within 24 hours. | Users without MFA, ACCOUNTADMIN without MFA, exfiltration prevention disabled, no network policy |
| **HIGH** | Significant security gap that could lead to compromise if exploited. Remediate within 7 days. | Stale passwords, brute force attempts, service accounts using passwords, no session/password policy, admin default role, admin-owned tasks, multiple admin roles, Trust Center scanners disabled |
| **MEDIUM** | Security weakness that should be scheduled for remediation within 30 days. | Inactive users, weak default roles, no SSO for human users, direct user grants, suspicious IPs, admin no email, key rotation, masking/row-access coverage, Tri-Secret Secure |
| **LOW** | Best-practice improvement to address within 90 days. | Users who never logged in, orphaned roles, data retention configuration |

---

## Remediation Priority Matrix

The following matrix maps findings to remediation priorities with effort estimates:

| Finding | Severity | Effort | Priority | Timeline |
|---------|----------|--------|----------|----------|
| ACCOUNTADMIN without MFA | CRITICAL | Low | P0 | Immediate |
| Users without MFA | CRITICAL | Low | P0 | Immediate |
| Data Exfil Prevention Disabled | CRITICAL | Low | P1 | 24 hours |
| No Network Policy | CRITICAL/HIGH | Medium | P1 | 24 hours |
| No Password Policy | HIGH | Low | P1 | 24 hours |
| Brute Force IPs | HIGH | Low | P1 | 24 hours |
| Trust Center Scanners Disabled | HIGH | Low | P1 | 24 hours |
| Stale Passwords | HIGH | Medium | P2 | 1 week |
| Service Account Password Auth | HIGH | Medium | P2 | 1 week |
| Session Policy | HIGH | Low | P2 | 1 week |
| Admin Default Role | HIGH | Low | P2 | 1 week |
| Admin-Owned Tasks | HIGH | Medium | P2 | 1 week |
| Inactive Users | MEDIUM | Medium | P2 | 1 week |
| RBAC Separation (Multi-Admin) | HIGH | High | P3 | 2 weeks |
| Direct User Grants | MEDIUM | Medium | P3 | 2 weeks |
| Human Users without SSO | MEDIUM | High | P3 | 2 weeks |
| Private Link | HIGH | High | P3 | 1 month |
| Masking Policy Coverage | MEDIUM | Medium | P3 | 1 month |
| Row-Access Policy Coverage | MEDIUM | Medium | P3 | 1 month |
| Key Rotation | MEDIUM | Medium | P3 | 1 month |
| Tri-Secret Secure | MEDIUM | High | P3 | 1 month |
| Orphaned Roles | LOW | Low | P3 | 90 days |
| Data Retention | LOW | Low | P3 | 90 days |

---

## Assessment Checklist

This is the master checklist the scanner validates during Phase 1:

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

---

## Remediation Verification & Rollback

### Verification Queries

After applying remediations, run these verification queries to confirm each fix:

```sql
-- MFA coverage
SELECT NAME, HAS_MFA FROM SNOWFLAKE.ACCOUNT_USAGE.USERS WHERE HAS_PASSWORD = TRUE AND DELETED_ON IS NULL;

-- Password policy
SHOW PASSWORD POLICIES;

-- Session policy
SHOW SESSION POLICIES;

-- Network policy
SHOW NETWORK POLICIES;

-- Exfiltration prevention
SHOW PARAMETERS LIKE 'PREVENT%' IN ACCOUNT;
SHOW PARAMETERS LIKE 'REQUIRE_STORAGE%' IN ACCOUNT;

-- Remaining inactive users
SELECT COUNT(*) AS remaining_inactive FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
WHERE DELETED_ON IS NULL AND DISABLED = FALSE AND LAST_SUCCESS_LOGIN < DATEADD(day, -90, CURRENT_TIMESTAMP());

-- Users with multiple admin roles
SELECT GRANTEE_NAME, COUNT(*) AS admin_role_count FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'USERADMIN', 'ORGADMIN') AND DELETED_ON IS NULL
GROUP BY GRANTEE_NAME HAVING COUNT(*) > 1;
```

### Rollback Procedures

If any remediation causes operational issues, use these rollback commands:

```sql
-- Remove authentication policy from user
ALTER USER <USER> UNSET AUTHENTICATION POLICY;

-- Remove account-level password policy
ALTER ACCOUNT UNSET PASSWORD POLICY;

-- Remove account-level session policy
ALTER ACCOUNT UNSET SESSION POLICY;

-- Remove account-level network policy
ALTER ACCOUNT UNSET NETWORK_POLICY;

-- Re-enable disabled user
ALTER USER <USER> SET DISABLED = FALSE;

-- Revert exfiltration prevention
ALTER ACCOUNT SET PREVENT_UNLOAD_TO_INLINE_URL = FALSE;
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = FALSE;
```

### Post-Remediation Monitoring

Set up a recurring task to monitor ongoing compliance:

```sql
CREATE OR REPLACE TASK security_compliance_check
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 8 * * 1 UTC'
AS BEGIN END;
```

---

## Error Handling & Self-Healing

The scanner includes a built-in self-healing mechanism to maximize assessment coverage even when individual queries fail.

### How It Works

1. **Auto-Recovery:** If any SQL query or workflow step fails, the scanner does not halt. It automatically diagnoses the root cause, applies a fix, and retries.

2. **Inline Logging:** For every failed-and-recovered step, the scanner logs within the relevant phase report:
   - Step name / query identifier that failed
   - Exact error message received from Snowflake
   - Root cause diagnosis
   - Corrective fix applied
   - Retry outcome (Success / Failed after retry)

3. **Skill File Updates:** When a query failure is successfully resolved, the corrected query is written back to the SKILL.md file with an inline comment:
   ```sql
   -- [FIXED on <DD-MM-YYYY>]: <concise description of what was corrected and why>
   ```

4. **Graceful Degradation:** If a step fails and cannot be recovered after retry, it is marked as **SKIPPED** with a clear root cause explanation. The scanner continues with remaining steps and flags the skipped item in the final report under a "Manual Review Required" section.

5. **Self-Healing Summary:** All self-healing actions are consolidated into a dedicated "Self-Healing Summary" section appended to the Phase 1 and Phase 2 reports, listing every corrected query/step, the fix applied, and the final resolution status.

### Known Historical Fixes

The following queries have been corrected through the self-healing mechanism:

| Date | Query | Fix Applied |
|------|-------|-------------|
| 18-02-2026 | 1.1 `USERS_WITHOUT_MFA` | Changed `USER_NAME` to `NAME` (correct column in USERS table) |
| 18-02-2026 | 1.2 `ACCOUNTADMIN_NO_MFA` | Changed `u.USER_NAME` to `u.NAME` (correct column in USERS table) |
| 18-02-2026 | 2.1 `INACTIVE_USER` | Changed `USER_NAME` to `NAME` (correct column in USERS table) |

---

## Execution Rules

1. All three phases execute **strictly sequentially** — do not skip, merge, or parallelize.
2. Total elapsed time for Phase 1 and Phase 2 is captured and prominently displayed in each report.
3. `<DD-MM-YYYY>` in file names is replaced with the actual date of execution.
4. All HTML reports are professionally styled, print-friendly, and stakeholder-ready.
5. **No DDL, DML, or configuration changes** are executed — assessment and documentation only.
6. All reports are saved exclusively to the `snowflake-security-scanner/reports/` folder.
7. Each phase report includes a "Report Generation Summary" banner at the top.

---

## Report Output Specifications

### Phase 1 — Security Assessment Report

| Property | Value |
|----------|-------|
| **File name** | `Report-Security-Assessment-<DD-MM-YYYY>.html` |
| **Location** | `snowflake-security-scanner/reports/` |
| **Format** | Self-contained HTML, no external dependencies |
| **Contents** | Executive summary, finding counts by severity, detailed findings per domain, affected objects, timestamps, report generation summary banner |

### Phase 2 — Security Recommendation Report

| Property | Value |
|----------|-------|
| **File name** | `Report-Security-Recommendation-<DD-MM-YYYY>.html` |
| **Location** | `snowflake-security-scanner/reports/` |
| **Format** | Self-contained HTML, no external dependencies |
| **Contents** | Reference to Phase 1 report, prioritized recommendations (P0–P3), remediation SQL per finding, effort estimates, rollback procedures, verification queries, report generation summary banner |

### Phase 3 — Compliance Dashboard

| Property | Value |
|----------|-------|
| **File name** | `Report-Compliance-Dashboard-<DD-MM-YYYY>.html` |
| **Location** | `snowflake-security-scanner/reports/` |
| **Format** | Interactive self-contained HTML, no external dependencies |
| **Contents** | Category breakdown, priority tracking with SLA adherence, progress bars/charts, risk flagging for overdue items, overall compliance health score |

---

## Data Sources

All scanner queries are read-only and target the following Snowflake system views:

| View / Command | Domains Used In | Purpose |
|----------------|----------------|---------|
| `SNOWFLAKE.ACCOUNT_USAGE.USERS` | 1, 2, 4, 7, 12 | User account metadata, MFA status, password age, login history |
| `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS` | 1, 2, 9, 12 | Role assignments to users |
| `SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES` | 9 | Role-to-role hierarchy |
| `SNOWFLAKE.ACCOUNT_USAGE.ROLES` | 9 | Role definitions |
| `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY` | 3, 4, 6, 7, 10 | Authentication events, IP addresses, factors |
| `SNOWFLAKE.ACCOUNT_USAGE.SESSIONS` | 7 | Session duration and metadata |
| `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` | 5 | COPY/UNLOAD/GET operations, large exports |
| `SNOWFLAKE.ACCOUNT_USAGE.STAGES` | 5 | External stage inventory |
| `SNOWFLAKE.ACCOUNT_USAGE.TABLES` | 8, 12 | Table metadata, sensitive data candidates, retention settings |
| `SNOWFLAKE.ACCOUNT_USAGE.TASKS` | 12 | Task ownership |
| `SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES` | 12 | Masking and row-access policy bindings |
| `SNOWFLAKE.TRUST_CENTER.SCANNER_PACKAGES_VIEW` | 11 | Trust Center scanner inventory |
| `SNOWFLAKE.TRUST_CENTER.FINDINGS_VIEW` | 11 | Trust Center findings |
| `SNOWFLAKE.TRUST_CENTER.TIME_SERIES_DAILY_FINDINGS` | 11 | Findings trend data |
| `SHOW PARAMETERS IN ACCOUNT` | 5, 7, 8, 12 | Account-level configuration parameters |
| `SHOW NETWORK POLICIES` | 7 | Network policy inventory |

**Note:** `SNOWFLAKE.ACCOUNT_USAGE` views have a latency of up to 45 minutes. Findings reflect data available at query time, not real-time state.

---

## Frequently Asked Questions

### Q: Do I need ACCOUNTADMIN to run the scanner?

**A:** ACCOUNTADMIN is recommended for full coverage. A custom role with `IMPORTED PRIVILEGES` on the `SNOWFLAKE` database can also work, but some Trust Center queries and `SHOW PARAMETERS` commands may require higher privileges.

### Q: Will the scanner make any changes to my account?

**A:** No. The scanner is strictly read-only. It executes `SELECT` queries and `SHOW` commands only. All remediation SQL is provided as documentation — it is never executed automatically.

### Q: How long does a full scan take?

**A:** Typically 5–15 minutes depending on account size and query latency. Phase 1 (assessment) takes the longest. Elapsed time is captured and displayed in each report.

### Q: What happens if a query fails during the scan?

**A:** The self-healing mechanism auto-diagnoses, fixes, and retries. If recovery fails, the step is marked as SKIPPED and flagged for manual review. The scan continues with remaining checks.

### Q: Can I run individual domains instead of the full scan?

**A:** The skill is designed to run all 12 domains sequentially. However, you can ask Cortex Code to "run only Domain 1" or similar — the individual SQL queries are self-contained and can be executed independently.

### Q: How often should I run the scanner?

**A:** Recommended cadence:
- **Weekly:** For accounts with active development and frequent user changes
- **Monthly:** For stable production accounts
- **On-demand:** After significant changes (role restructuring, new integrations, security incidents)

### Q: Where are the reports saved?

**A:** All HTML reports are saved to `snowflake-security-scanner/reports/` in the workspace. File names include the execution date for version tracking.

### Q: Does the scanner integrate with Snowflake Trust Center?

**A:** Yes. Domain 11 queries Trust Center views for automated scanner findings, CIS Benchmark compliance, and Threat Intelligence detection. This supplements the manual checks in Domains 1–10.

### Q: What CIS Benchmark controls are covered?

**A:** The scanner covers these CIS Snowflake Benchmark controls directly or via Trust Center:
- 1.1 (SSO configuration), 1.2 (SCIM), 1.3 (password unset for SSO), 1.7 (key-pair rotation), 1.9 (admin idle timeout), 1.11 (admin email), 1.12 (admin default role), 1.14–1.17 (admin-owned tasks)
- 4.3–4.4 (data retention), 4.9 (Tri-Secret Secure), 4.10 (data masking), 4.11 (row-access policies)

### Q: Can the scanner detect active threats?

**A:** Domain 3 detects brute force attempts and unknown IP login failures. Domain 11 (Trust Center Threat Intelligence) provides additional active threat detection for suspicious IP connections, known bad actors, and anomalous patterns.
