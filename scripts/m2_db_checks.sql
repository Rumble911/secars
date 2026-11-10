-- SecARS - M2 database checks
-- Run in SQL*Plus as ARS_OWNER on FREEPDB1:
--   sqlplus ARS_OWNER/<password>@localhost:1521/FREEPDB1 @scripts/m2_db_checks.sql
-- Section 3 must be run separately as SYSTEM (it reads DBA views).
-- Expected results are written above each query.

SET PAGESIZE 200
SET LINESIZE 200
SET FEEDBACK OFF
SET HEADING ON
COLUMN object_name FORMAT A30
COLUMN grantee     FORMAT A16
COLUMN table_name  FORMAT A20
COLUMN privilege   FORMAT A16
COLUMN username    FORMAT A16
COLUMN event_type  FORMAT A20

PROMPT
PROMPT === 1. Every package, table and view is VALID (expect NO rows) ===
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_type IN ('PACKAGE', 'PACKAGE BODY', 'TABLE', 'VIEW')
   AND status <> 'VALID'
 ORDER BY object_name;

PROMPT
PROMPT === 2. APP_USER has EXECUTE only, nothing else (expect NO rows) ===
SELECT grantee, table_name, privilege
  FROM user_tab_privs_made
 WHERE grantee = 'APP_USER'
   AND privilege <> 'EXECUTE'
 ORDER BY table_name;

PROMPT
PROMPT === 2b. What APP_USER can execute (expect only the ARS_* packages) ===
SELECT table_name AS package_name, privilege
  FROM user_tab_privs_made
 WHERE grantee = 'APP_USER'
 ORDER BY table_name;

PROMPT
PROMPT === 4. Audit tables: APP_USER has no UPDATE or DELETE (expect NO rows) ===
SELECT grantee, table_name, privilege
  FROM user_tab_privs_made
 WHERE grantee = 'APP_USER'
   AND table_name IN ('GRADE_AUDIT', 'SECURITY_EVENTS')
   AND privilege IN ('UPDATE', 'DELETE', 'INSERT', 'SELECT');

PROMPT
PROMPT === 5. Seed roles (expect ROLE_COUNT: STUDENT 1, LECTURER 1, REGISTRAR 2, AUDITOR 1) ===
SELECT app_role, COUNT(*) AS role_count
  FROM app_users
 GROUP BY app_role
 ORDER BY app_role;

PROMPT
PROMPT === 5b. Demo accounts have real hashes, not placeholders (expect LENGTH 60, none PENDING) ===
SELECT username, LENGTH(password_hash) AS hash_len
  FROM app_users
 ORDER BY username;

PROMPT
PROMPT === 6. Evidence after the test run ===
PROMPT --- security events by type and outcome
SELECT event_type, outcome, COUNT(*) AS n
  FROM security_events
 GROUP BY event_type, outcome
 ORDER BY event_type, outcome;

PROMPT --- grade audit by change type
SELECT change_type, COUNT(*) AS n
  FROM grade_audit
 GROUP BY change_type
 ORDER BY change_type;

PROMPT --- grade change requests
SELECT request_id, enrollment_id, new_grade, status, requested_by
  FROM grade_change_requests
 ORDER BY request_id;

PROMPT --- account lock state
SELECT username, failed_attempts, locked_until
  FROM app_users
 ORDER BY username;

PROMPT
PROMPT === 7. Sections by status for term 2026-1 ===
SELECT status, COUNT(*) AS n
  FROM course_offerings
 WHERE term = '2026-1'
 GROUP BY status
 ORDER BY status;

PROMPT
PROMPT === 8. Constraint check: a grade above 100 is refused (expect ORA-02290) ===
-- Uncomment to run. It must fail; a success means BR01 is broken.
-- UPDATE enrollments SET grade = 101 WHERE enrollment_id = (SELECT MIN(enrollment_id) FROM enrollments);

PROMPT
PROMPT === 6-unlock. Run ONLY when you need to unlock student1 after T04 ===
-- UPDATE app_users SET failed_attempts = 0, locked_until = NULL WHERE username = 'student1';
-- COMMIT;

-- ------------------------------------------------------------------
-- SECTION 3: run as SYSTEM (separate session), expect:
--   SYS PRIVILEGES of APP_USER: CREATE SESSION only
--   ROLE GRANTS of APP_USER: none
-- ------------------------------------------------------------------
-- SELECT privilege FROM dba_sys_privs WHERE grantee = 'APP_USER' ORDER BY privilege;
-- SELECT granted_role FROM dba_role_privs WHERE grantee = 'APP_USER';

SET FEEDBACK ON
