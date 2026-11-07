-- =====================================================================
-- SecARS - M2 authentication package (run as ARS_OWNER)
-- APP_USER has NO table privileges. It may only call these procedures.
-- The package runs with the owner's rights, so it can read APP_USERS
-- and write SECURITY_EVENTS, while APP_USER cannot touch those tables.
-- Policy: 5 consecutive failures lock the account for 15 minutes.
-- =====================================================================

CREATE OR REPLACE PACKAGE ars_auth AS
  -- Returns the login data for a username. Unknown user -> p_user_id IS NULL.
  PROCEDURE get_login_state(
    p_username     IN  VARCHAR2,
    p_user_id      OUT NUMBER,
    p_hash         OUT VARCHAR2,
    p_role         OUT VARCHAR2,
    p_active       OUT NUMBER,
    p_locked_until OUT TIMESTAMP,
    p_student_id   OUT NUMBER,
    p_lecturer_id  OUT NUMBER);

  -- Records a wrong password (or a lock-out attempt) and locks at 5 failures.
  PROCEDURE record_failure(p_username IN VARCHAR2, p_ip IN VARCHAR2);

  -- Resets the failure counter and records a successful login.
  PROCEDURE record_success(p_username IN VARCHAR2, p_ip IN VARCHAR2);
END ars_auth;
/

CREATE OR REPLACE PACKAGE BODY ars_auth AS

  PROCEDURE get_login_state(
    p_username     IN  VARCHAR2,
    p_user_id      OUT NUMBER,
    p_hash         OUT VARCHAR2,
    p_role         OUT VARCHAR2,
    p_active       OUT NUMBER,
    p_locked_until OUT TIMESTAMP,
    p_student_id   OUT NUMBER,
    p_lecturer_id  OUT NUMBER) IS
  BEGIN
    SELECT user_id, password_hash, app_role, active, locked_until, student_id, lecturer_id
      INTO p_user_id, p_hash, p_role, p_active, p_locked_until, p_student_id, p_lecturer_id
      FROM app_users
     WHERE username = p_username;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_user_id := NULL;
      p_hash := NULL;
      p_role := NULL;
      p_active := NULL;
      p_locked_until := NULL;
      p_student_id := NULL;
      p_lecturer_id := NULL;
  END get_login_state;

  PROCEDURE record_failure(p_username IN VARCHAR2, p_ip IN VARCHAR2) IS
    v_fails NUMBER := 0;
  BEGIN
    UPDATE app_users
       SET failed_attempts = failed_attempts + 1,
           locked_until = CASE
                            WHEN failed_attempts + 1 >= 5
                            THEN SYSTIMESTAMP + INTERVAL '15' MINUTE
                            ELSE locked_until
                          END
     WHERE username = p_username;

    IF SQL%ROWCOUNT = 1 THEN
      SELECT failed_attempts INTO v_fails FROM app_users WHERE username = p_username;
    END IF;

    INSERT INTO security_events (actor, event_type, outcome, source_ip, details)
    VALUES (p_username, 'LOGIN_FAILED', 'FAILURE', p_ip, 'Invalid credentials');

    IF v_fails >= 5 THEN
      INSERT INTO security_events (actor, event_type, outcome, source_ip, details)
      VALUES (p_username, 'ACCOUNT_LOCKED', 'DENIED', p_ip, 'Locked for 15 minutes');
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END record_failure;

  PROCEDURE record_success(p_username IN VARCHAR2, p_ip IN VARCHAR2) IS
  BEGIN
    UPDATE app_users
       SET failed_attempts = 0,
           locked_until = NULL,
           last_login = SYSTIMESTAMP
     WHERE username = p_username;

    INSERT INTO security_events (actor, event_type, outcome, source_ip, details)
    VALUES (p_username, 'LOGIN', 'SUCCESS', p_ip, 'Login accepted');

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END record_success;

END ars_auth;
/

-- Only the runtime account may run these procedures, and nothing else.
GRANT EXECUTE ON ars_auth TO app_user;

-- Quick self-check: the package compiled without errors.
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name = 'ARS_AUTH'
 ORDER BY object_type;
-- expected: two rows (PACKAGE, PACKAGE BODY), both VALID
