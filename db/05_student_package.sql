-- =====================================================================
-- SecARS - M2 student package (run as ARS_OWNER)
-- APP_USER may only EXECUTE this package. The package runs with the
-- owner's rights and finds the student from the username it is given,
-- so a student can only ever see their own enrolments.
-- Rule: a grade is shown only after the offering is PUBLISHED.
-- =====================================================================

CREATE OR REPLACE PACKAGE ars_student AS
  -- Returns the signed-in student's enrolments. Empty result for any non-student.
  PROCEDURE list_my_enrollments(
    p_username IN  VARCHAR2,
    p_cursor   OUT SYS_REFCURSOR);
END ars_student;
/

CREATE OR REPLACE PACKAGE BODY ars_student AS

  PROCEDURE list_my_enrollments(
    p_username IN  VARCHAR2,
    p_cursor   OUT SYS_REFCURSOR) IS
  BEGIN
    OPEN p_cursor FOR
      SELECT co.term,
             c.code,
             c.title,
             c.credit_hours,
             co.section_no,
             l.full_name,
             co.status,
             CASE WHEN co.status = 'PUBLISHED' THEN e.grade END AS grade
        FROM app_users au
        JOIN enrollments e         ON e.student_id = au.student_id
        JOIN course_offerings co   ON co.offering_id = e.offering_id
        JOIN courses c             ON c.course_id = co.course_id
        JOIN lecturers l           ON l.lecturer_id = co.lecturer_id
       WHERE au.username = p_username
         AND au.app_role = 'STUDENT'
       ORDER BY co.term DESC, c.code;

    INSERT INTO security_events (actor, event_type, outcome, details)
    VALUES (p_username, 'ENROLLMENTS_VIEWED', 'SUCCESS', 'Student listed own enrolments');

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END list_my_enrollments;

END ars_student;
/

GRANT EXECUTE ON ars_student TO app_user;

-- Self-check: the package compiled without errors.
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name = 'ARS_STUDENT'
 ORDER BY object_type;
-- expected: two rows (PACKAGE, PACKAGE BODY), both VALID
