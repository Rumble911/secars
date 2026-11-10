-- =====================================================================
-- SecARS - M2 staff packages (run as ARS_OWNER)
-- One package per role (SR08 separation of duties). APP_USER may only
-- EXECUTE them. Each procedure re-checks the caller's role from APP_USERS
-- and refuses (and logs) anything outside that role's scope.
-- Business errors use ORA-20xxx codes; the backend shows only those messages.
-- =====================================================================

-- ------------------------------------------------------------ LECTURER
CREATE OR REPLACE PACKAGE ars_lecturer AS
  PROCEDURE my_offerings(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE offering_grades(p_username IN VARCHAR2, p_offering_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE set_grade(p_username IN VARCHAR2, p_enrollment_id IN NUMBER, p_grade IN NUMBER);
  PROCEDURE submit_offering(p_username IN VARCHAR2, p_offering_id IN NUMBER);
END ars_lecturer;
/

CREATE OR REPLACE PACKAGE BODY ars_lecturer AS

  FUNCTION my_lecturer_id(p_username IN VARCHAR2) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT lecturer_id INTO v_id
      FROM app_users
     WHERE username = p_username AND app_role = 'LECTURER';
    RETURN v_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END my_lecturer_id;

  -- Logs the refusal in its own committed transaction, then raises.
  PROCEDURE deny(p_username IN VARCHAR2, p_detail IN VARCHAR2) IS
  BEGIN
    INSERT INTO security_events (actor, event_type, outcome, details)
    VALUES (p_username, 'ACCESS_DENIED', 'DENIED', SUBSTR(p_detail, 1, 400));
    COMMIT;
    raise_application_error(-20403, 'Not allowed');
  END deny;

  PROCEDURE my_offerings(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT co.offering_id,
             co.term,
             co.section_no,
             co.status,
             co.capacity,
             c.code,
             c.title,
             c.credit_hours,
             (SELECT COUNT(*) FROM enrollments e WHERE e.offering_id = co.offering_id) AS enrolled
        FROM app_users au
        JOIN course_offerings co ON co.lecturer_id = au.lecturer_id
        JOIN courses c           ON c.course_id = co.course_id
       WHERE au.username = p_username
         AND au.app_role = 'LECTURER'
       ORDER BY co.term DESC, c.code, co.section_no;
  END my_offerings;

  PROCEDURE offering_grades(p_username IN VARCHAR2, p_offering_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
    v_lect  NUMBER := my_lecturer_id(p_username);
    v_count NUMBER := 0;
  BEGIN
    IF v_lect IS NULL THEN
      deny(p_username, 'Not a lecturer account');
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM course_offerings
     WHERE offering_id = p_offering_id AND lecturer_id = v_lect;

    IF v_count = 0 THEN
      deny(p_username, 'Offering ' || p_offering_id || ' is not taught by this lecturer');
    END IF;

    OPEN p_cursor FOR
      SELECT e.enrollment_id,
             s.student_id,
             s.full_name,
             e.grade,
             co.status
        FROM enrollments e
        JOIN students s          ON s.student_id = e.student_id
        JOIN course_offerings co ON co.offering_id = e.offering_id
       WHERE e.offering_id = p_offering_id
       ORDER BY s.full_name;
  END offering_grades;

  PROCEDURE set_grade(p_username IN VARCHAR2, p_enrollment_id IN NUMBER, p_grade IN NUMBER) IS
    v_lect   NUMBER := my_lecturer_id(p_username);
    v_status VARCHAR2(10);
    v_old    NUMBER;
  BEGIN
    IF v_lect IS NULL THEN
      deny(p_username, 'Not a lecturer account');
    END IF;

    IF p_grade IS NULL OR p_grade < 0 OR p_grade > 100 THEN
      raise_application_error(-20011, 'Grade must be between 0 and 100');
    END IF;

    BEGIN
      SELECT co.status, e.grade
        INTO v_status, v_old
        FROM enrollments e
        JOIN course_offerings co ON co.offering_id = e.offering_id
       WHERE e.enrollment_id = p_enrollment_id
         AND co.lecturer_id = v_lect;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        deny(p_username, 'Enrollment ' || p_enrollment_id || ' is not in this lecturer section');
    END;

    -- BR03/BR04: direct edits only while the section is OPEN.
    IF v_status <> 'OPEN' THEN
      raise_application_error(-20012, 'Section is closed. Grade changes need an approved request.');
    END IF;

    UPDATE enrollments SET grade = p_grade WHERE enrollment_id = p_enrollment_id;

    INSERT INTO grade_audit (enrollment_id, old_grade, new_grade, actor, actor_role, change_type)
    VALUES (p_enrollment_id, v_old, p_grade, p_username, 'LECTURER',
            CASE WHEN v_old IS NULL THEN 'ENTRY' ELSE 'EDIT' END);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END set_grade;

  PROCEDURE submit_offering(p_username IN VARCHAR2, p_offering_id IN NUMBER) IS
    v_lect   NUMBER := my_lecturer_id(p_username);
    v_status VARCHAR2(10);
  BEGIN
    IF v_lect IS NULL THEN
      deny(p_username, 'Not a lecturer account');
    END IF;

    BEGIN
      SELECT status INTO v_status
        FROM course_offerings
       WHERE offering_id = p_offering_id AND lecturer_id = v_lect;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        deny(p_username, 'Offering ' || p_offering_id || ' is not taught by this lecturer');
    END;

    -- BR02: the status only moves forward, OPEN -> SUBMITTED.
    IF v_status <> 'OPEN' THEN
      raise_application_error(-20013, 'Only open sections can be submitted');
    END IF;

    UPDATE course_offerings
       SET status = 'SUBMITTED', status_changed_at = SYSTIMESTAMP
     WHERE offering_id = p_offering_id;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END submit_offering;

END ars_lecturer;
/

-- ----------------------------------------------------------- REGISTRAR
CREATE OR REPLACE PACKAGE ars_registrar AS
  PROCEDURE all_offerings(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE offering_enrollments(p_username IN VARCHAR2, p_offering_id IN NUMBER, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE publish_offering(p_username IN VARCHAR2, p_offering_id IN NUMBER);
  PROCEDURE request_change(p_username IN VARCHAR2, p_enrollment_id IN NUMBER,
                           p_new_grade IN NUMBER, p_reason IN VARCHAR2);
  PROCEDURE pending_requests(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE decide_request(p_username IN VARCHAR2, p_request_id IN NUMBER,
                           p_approve IN NUMBER, p_note IN VARCHAR2);
END ars_registrar;
/

CREATE OR REPLACE PACKAGE BODY ars_registrar AS

  FUNCTION role_of(p_username IN VARCHAR2) RETURN VARCHAR2 IS
    v_role VARCHAR2(20);
  BEGIN
    SELECT app_role INTO v_role FROM app_users WHERE username = p_username;
    RETURN v_role;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
  END role_of;

  PROCEDURE deny(p_username IN VARCHAR2, p_detail IN VARCHAR2) IS
  BEGIN
    INSERT INTO security_events (actor, event_type, outcome, details)
    VALUES (p_username, 'ACCESS_DENIED', 'DENIED', SUBSTR(p_detail, 1, 400));
    COMMIT;
    raise_application_error(-20403, 'Not allowed');
  END deny;

  PROCEDURE require_registrar(p_username IN VARCHAR2) IS
  BEGIN
    IF NVL(role_of(p_username), 'NONE') <> 'REGISTRAR' THEN
      deny(p_username, 'Registrar action attempted by a non-registrar account');
    END IF;
  END require_registrar;

  PROCEDURE all_offerings(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    require_registrar(p_username);
    OPEN p_cursor FOR
      SELECT co.offering_id,
             co.term,
             co.section_no,
             co.status,
             c.code,
             c.title,
             l.full_name AS lecturer_name,
             (SELECT COUNT(*) FROM enrollments e WHERE e.offering_id = co.offering_id) AS enrolled
        FROM course_offerings co
        JOIN courses c   ON c.course_id = co.course_id
        JOIN lecturers l ON l.lecturer_id = co.lecturer_id
       ORDER BY co.term DESC, c.code, co.section_no;
  END all_offerings;

  PROCEDURE offering_enrollments(p_username IN VARCHAR2, p_offering_id IN NUMBER, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    require_registrar(p_username);
    -- national_id, dob and phone are deliberately not returned (TH-09).
    OPEN p_cursor FOR
      SELECT e.enrollment_id,
             s.student_id,
             s.full_name,
             e.grade,
             co.status
        FROM enrollments e
        JOIN students s          ON s.student_id = e.student_id
        JOIN course_offerings co ON co.offering_id = e.offering_id
       WHERE e.offering_id = p_offering_id
       ORDER BY s.full_name;
  END offering_enrollments;

  PROCEDURE publish_offering(p_username IN VARCHAR2, p_offering_id IN NUMBER) IS
    v_status VARCHAR2(10);
  BEGIN
    require_registrar(p_username);

    SELECT status INTO v_status FROM course_offerings WHERE offering_id = p_offering_id;

    IF v_status <> 'SUBMITTED' THEN
      raise_application_error(-20021, 'Only submitted sections can be published');
    END IF;

    UPDATE course_offerings
       SET status = 'PUBLISHED', status_changed_at = SYSTIMESTAMP
     WHERE offering_id = p_offering_id;

    COMMIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      ROLLBACK;
      raise_application_error(-20022, 'Section not found');
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END publish_offering;

  PROCEDURE request_change(p_username IN VARCHAR2, p_enrollment_id IN NUMBER,
                           p_new_grade IN NUMBER, p_reason IN VARCHAR2) IS
    v_user_id NUMBER;
    v_status  VARCHAR2(10);
    v_old     NUMBER;
  BEGIN
    require_registrar(p_username);

    IF p_new_grade IS NULL OR p_new_grade < 0 OR p_new_grade > 100 THEN
      raise_application_error(-20011, 'Grade must be between 0 and 100');
    END IF;

    -- BR04: the reason must be at least 10 characters.
    IF LENGTH(TRIM(p_reason)) < 10 THEN
      raise_application_error(-20031, 'Reason must be at least 10 characters');
    END IF;

    BEGIN
      SELECT co.status, e.grade
        INTO v_status, v_old
        FROM enrollments e
        JOIN course_offerings co ON co.offering_id = e.offering_id
       WHERE e.enrollment_id = p_enrollment_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        raise_application_error(-20032, 'Enrolment not found');
    END;

    IF v_status = 'OPEN' THEN
      raise_application_error(-20033, 'Section is still open. The lecturer can change the grade directly.');
    END IF;

    SELECT user_id INTO v_user_id FROM app_users WHERE username = p_username;

    INSERT INTO grade_change_requests (enrollment_id, requested_by, old_grade, new_grade, reason)
    VALUES (p_enrollment_id, v_user_id, v_old, p_new_grade, TRIM(p_reason));

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END request_change;

  PROCEDURE pending_requests(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    require_registrar(p_username);
    OPEN p_cursor FOR
      SELECT r.request_id,
             r.enrollment_id,
             s.full_name,
             c.code,
             r.old_grade,
             r.new_grade,
             r.reason,
             ru.username AS requested_by,
             r.requested_at
        FROM grade_change_requests r
        JOIN app_users ru        ON ru.user_id = r.requested_by
        JOIN enrollments e       ON e.enrollment_id = r.enrollment_id
        JOIN students s          ON s.student_id = e.student_id
        JOIN course_offerings co ON co.offering_id = e.offering_id
        JOIN courses c           ON c.course_id = co.course_id
       WHERE r.status = 'PENDING'
       ORDER BY r.requested_at;
  END pending_requests;

  -- FR06 / BR05: the approving registrar must differ from the requester.
  -- The change and its POST_CLOSE audit row are written in ONE transaction.
  PROCEDURE decide_request(p_username IN VARCHAR2, p_request_id IN NUMBER,
                           p_approve IN NUMBER, p_note IN VARCHAR2) IS
    v_me      NUMBER;
    v_req_by  NUMBER;
    v_enr     NUMBER;
    v_new     NUMBER;
    v_reason  VARCHAR2(500);
    v_status  VARCHAR2(10);
    v_old     NUMBER;
  BEGIN
    require_registrar(p_username);

    SELECT user_id INTO v_me FROM app_users WHERE username = p_username;

    BEGIN
      SELECT requested_by, enrollment_id, new_grade, reason, status
        INTO v_req_by, v_enr, v_new, v_reason, v_status
        FROM grade_change_requests
       WHERE request_id = p_request_id
         FOR UPDATE;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        raise_application_error(-20034, 'Request not found');
    END;

    IF v_status <> 'PENDING' THEN
      raise_application_error(-20035, 'This request was already decided');
    END IF;

    IF v_req_by = v_me THEN
      deny(p_username, 'Self-approval attempt on request ' || p_request_id);
    END IF;

    IF p_approve = 1 THEN
      SELECT grade INTO v_old FROM enrollments WHERE enrollment_id = v_enr FOR UPDATE;

      UPDATE enrollments SET grade = v_new WHERE enrollment_id = v_enr;

      INSERT INTO grade_audit (enrollment_id, old_grade, new_grade, actor, actor_role,
                               change_type, reason, request_id)
      VALUES (v_enr, v_old, v_new, p_username, 'REGISTRAR', 'POST_CLOSE', v_reason, p_request_id);

      UPDATE grade_change_requests
         SET status = 'APPROVED', decided_by = v_me, decided_at = SYSTIMESTAMP,
             decision_note = SUBSTR(p_note, 1, 500)
       WHERE request_id = p_request_id;
    ELSE
      UPDATE grade_change_requests
         SET status = 'REJECTED', decided_by = v_me, decided_at = SYSTIMESTAMP,
             decision_note = SUBSTR(p_note, 1, 500)
       WHERE request_id = p_request_id;
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END decide_request;

END ars_registrar;
/

-- -------------------------------------------------------------- AUDITOR
CREATE OR REPLACE PACKAGE ars_auditor AS
  PROCEDURE grade_audit(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR);
  PROCEDURE security_events(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR);
END ars_auditor;
/

CREATE OR REPLACE PACKAGE BODY ars_auditor AS

  -- FR07: read-only. Nothing here writes, and the role is checked on every call.
  PROCEDURE require_auditor(p_username IN VARCHAR2) IS
    v_role VARCHAR2(20);
  BEGIN
    SELECT app_role INTO v_role FROM app_users WHERE username = p_username;
    IF v_role <> 'AUDITOR' THEN
      raise_application_error(-20403, 'Not allowed');
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error(-20403, 'Not allowed');
  END require_auditor;

  PROCEDURE grade_audit(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    require_auditor(p_username);
    OPEN p_cursor FOR
      SELECT event_time, actor, actor_role, change_type, enrollment_id,
             old_grade, new_grade, reason, request_id
        FROM grade_audit
       ORDER BY event_time DESC
       FETCH FIRST 200 ROWS ONLY;
  END grade_audit;

  PROCEDURE security_events(p_username IN VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
  BEGIN
    require_auditor(p_username);
    OPEN p_cursor FOR
      SELECT event_time, actor, event_type, outcome, source_ip, details
        FROM security_events
       ORDER BY event_time DESC
       FETCH FIRST 200 ROWS ONLY;
  END security_events;

END ars_auditor;
/

GRANT EXECUTE ON ars_lecturer  TO app_user;
GRANT EXECUTE ON ars_registrar TO app_user;
GRANT EXECUTE ON ars_auditor   TO app_user;

-- Self-check: all three packages compiled.
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('ARS_LECTURER','ARS_REGISTRAR','ARS_AUDITOR')
 ORDER BY object_name, object_type;
-- expected: six rows, all VALID
