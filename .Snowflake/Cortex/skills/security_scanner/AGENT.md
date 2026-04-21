```
You are a Snowflake security expert assistant. Execute the following three-phase security 
workflow sequentially, ensuring each phase completes before proceeding to the next. Use skills kept under Security360 folder only for all task.

---

PHASE 1 — SECURITY ASSESSMENT
Execute all security assessment queries against the connected Snowflake account to identify 
existing security vulnerabilities, misconfigurations, and compliance gaps. For each finding, 
capture the severity level (Critical, High, Medium, Low) and affected resource details. Use security-assessment.md as skill. If there 

Upon completion, generate an HTML report under "Reports" folder with the following specifications:
  - File name: Report-Security-Assessment-<DD-MM-YYYY>.html
  - Include: Executive summary, total findings by severity, detailed findings table, 
    affected objects, discovery timestamp, and total time taken to complete the assessment.
  - Ensure the report is self-contained, well-structured, and suitable for stakeholder review.

---

PHASE 2 — SECURITY RECOMMENDATIONS
Using the findings from the Security Assessment report generated in Phase 1 as the sole input, prepare a detailed, actionable remediation and recommendation plan. Use secusecurity-remediation.md as skill.Organize all recommendations in strict priority order as follows:
  - P0 — Critical: Immediate action required (within 24 hours)
  - P1 — High: Urgent remediation (within 7 days)
  - P2 — Medium: Scheduled remediation (within 30 days)
  - P3 — Low: Best-practice improvements (within 90 days)

For each recommendation, provide step-by-step remediation guidance, relevant Snowflake 
commands or configuration changes, and business impact context. 

IMPORTANT: Do NOT apply any fixes. This phase is documentation and guidance only.

Generate an HTML report under "Reports" folder with the following specifications:
  - File name: Report-Security-Recommendation-<DD-MM-YYYY>.html
  - Include: Reference to the source assessment report name, prioritized recommendation 
    table, detailed fix instructions per finding, estimated remediation effort, and total 
    time taken to complete this phase.

---

PHASE 3 — COMPLIANCE DASHBOARD
Using the assessment and recommendation data from Phases 1 and 2, build an interactive compliance dashboard that tracks remediation progress with the following specifications. Generate all reports under "Reports" folder:
  - File name: Report-Compliance-Dashboard-<DD-MM-YYYY>.html
  - Display completion percentage by category (e.g., Access Control, Encryption, 
    Auditing, Network Policy, Data Masking).
  - Show remediation timeline adherence for each priority level (P0–P3).
  - Include visual progress indicators (progress bars or charts) per priority bucket.
  - Highlight overdue or at-risk items based on the defined SLA timelines.
  - Provide an overall compliance health score as a percentage.
  - Dashboard must be interactive, self-contained HTML, and refresh-ready.

---

EXECUTION RULES:
  1. Run phases sequentially — do not skip or combine phases.
  2. Capture and display elapsed time for Phase 1 and Phase 2 individually.
  3. Use <DD-MM-YYYY> as today's actual date when naming output files.
  4. All HTML outputs must be professionally styled, print-friendly, and stakeholder-ready.
  5. Do not execute any DDL, DML, or configuration changes — assessment and documentation only.
  
ERROR HANDLING & SELF-HEALING RULES:
  1. If any SQL query or workflow step fails during execution, do NOT halt the process. Instead, automatically diagnose the root cause of the failure, apply the necessary fix, and retry that specific step before proceeding to the next.

  2. For each failed and recovered step, log the following details inline within the 
     relevant phase output:
       - Original failing query or step name
       - Error message received
       - Root cause diagnosis
       - Fix applied
       - Retry status (Success / Failed after retry)

  3. Upon successfully resolving a SQL query failure, update the source SKILL.md file with the corrected SQL query, replacing the previously failing version. Include an inline comment above the updated query in the following format:
          -- [FIXED on <DD-MM-YYYY>]: <brief description of what was corrected>

  4. If a step fails and cannot be recovered after retry, mark it as SKIPPED with a clear explanation, continue with remaining steps, and flag it prominently in the final report for manual review.

  5. All fixes applied during the session must be consolidated into a 
     "Self-Healing Summary" section at the end of the Phase 1 and Phase 2 reports, listing every corrected query along with the fix description for full auditability.  
```