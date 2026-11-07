-- =====================================================================
-- SecARS - M2 schema (Oracle AI Database Free, PDB FREEPDB1)
-- Run as ARS_OWNER (created by 01_admin_setup.sql).
-- Matches docs/M1/M1_ERD.pdf. Security objects (VPD, audit, ARS_API)
-- are NOT in this file; they belong to db/security/ in M3.
-- Not re-runnable as-is: drop the tables first if you need to rebuild.
-- =====================================================================

SET DEFINE OFF

-- ---------------------------------------------------------------- people
CREATE TABLE students (
  student_id      NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name       VARCHAR2(100) NOT NULL,
  national_id     VARCHAR2(10)  NOT NULL,
  dob             DATE          NOT NULL,
  phone           VARCHAR2(20),
  major           VARCHAR2(60)  NOT NULL,
  admission_year  NUMBER(4)     NOT NULL,
  CONSTRAINT uq_students_national_id UNIQUE (national_id),
  CONSTRAINT ck_students_nid CHECK (REGEXP_LIKE(national_id, '^[0-9]{10}$')),
  CONSTRAINT ck_students_adm CHECK (admission_year BETWEEN 2015 AND 2030)
);

CREATE TABLE lecturers (
  lecturer_id  NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name    VARCHAR2(100) NOT NULL,
  department   VARCHAR2(80)  NOT NULL
);

-- ---------------------------------------------------------- login accounts
CREATE TABLE app_users (
  user_id         NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username        VARCHAR2(50)  NOT NULL,
  password_hash   VARCHAR2(120) NOT NULL,
  app_role        VARCHAR2(20)  NOT NULL,
  active          NUMBER(1)     DEFAULT 1 NOT NULL,
  failed_attempts NUMBER(3)     DEFAULT 0 NOT NULL,
  locked_until    TIMESTAMP,
  last_login      TIMESTAMP,
  student_id      NUMBER(10),
  lecturer_id     NUMBER(10),
  created_at      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT uq_app_users_username UNIQUE (username),
  CONSTRAINT uq_app_users_student  UNIQUE (student_id),
  CONSTRAINT uq_app_users_lecturer UNIQUE (lecturer_id),
  CONSTRAINT fk_au_student  FOREIGN KEY (student_id)  REFERENCES students(student_id),
  CONSTRAINT fk_au_lecturer FOREIGN KEY (lecturer_id) REFERENCES lecturers(lecturer_id),
  CONSTRAINT ck_au_role   CHECK (app_role IN ('STUDENT','LECTURER','REGISTRAR','AUDITOR')),
  CONSTRAINT ck_au_active CHECK (active IN (0,1)),
  CONSTRAINT ck_user_identity CHECK (
       (app_role = 'STUDENT'  AND student_id IS NOT NULL AND lecturer_id IS NULL)
    OR (app_role = 'LECTURER' AND lecturer_id IS NOT NULL AND student_id IS NULL)
    OR (app_role IN ('REGISTRAR','AUDITOR') AND student_id IS NULL AND lecturer_id IS NULL))
);

-- ------------------------------------------------------- courses and sections
CREATE TABLE courses (
  course_id     NUMBER(10)   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code          VARCHAR2(10) NOT NULL,
  title         VARCHAR2(120) NOT NULL,
  credit_hours  NUMBER(1)    NOT NULL,
  CONSTRAINT uq_courses_code UNIQUE (code),
  CONSTRAINT ck_courses_credits CHECK (credit_hours BETWEEN 1 AND 4)
);

CREATE TABLE course_offerings (
  offering_id       NUMBER(10)   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  course_id         NUMBER(10)   NOT NULL,
  lecturer_id       NUMBER(10)   NOT NULL,
  term              VARCHAR2(10) NOT NULL,
  section_no        NUMBER(2)    NOT NULL,
  status            VARCHAR2(10) DEFAULT 'OPEN' NOT NULL,
  capacity          NUMBER(3)    DEFAULT 40 NOT NULL,
  status_changed_at TIMESTAMP,
  CONSTRAINT fk_co_course   FOREIGN KEY (course_id)   REFERENCES courses(course_id),
  CONSTRAINT fk_co_lecturer FOREIGN KEY (lecturer_id) REFERENCES lecturers(lecturer_id),
  CONSTRAINT uq_offering    UNIQUE (course_id, term, section_no),
  CONSTRAINT ck_co_section  CHECK (section_no > 0),
  CONSTRAINT ck_co_status   CHECK (status IN ('OPEN','SUBMITTED','PUBLISHED')),
  CONSTRAINT ck_co_capacity CHECK (capacity > 0)
);

-- ---------------------------------------------------- enrolments and grades
CREATE TABLE enrollments (
  enrollment_id  NUMBER(10)   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id     NUMBER(10)   NOT NULL,
  offering_id    NUMBER(10)   NOT NULL,
  grade          NUMBER(5,2),
  enrolled_at    TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT fk_en_student  FOREIGN KEY (student_id)  REFERENCES students(student_id),
  CONSTRAINT fk_en_offering FOREIGN KEY (offering_id) REFERENCES course_offerings(offering_id),
  CONSTRAINT uq_enrollment  UNIQUE (student_id, offering_id),
  CONSTRAINT ck_en_grade CHECK (grade IS NULL OR grade BETWEEN 0 AND 100)
);

-- ------------------------------------- post-closure grade change workflow
CREATE TABLE grade_change_requests (
  request_id      NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  enrollment_id   NUMBER(10)    NOT NULL,
  requested_by    NUMBER(10)    NOT NULL,
  old_grade       NUMBER(5,2),
  new_grade       NUMBER(5,2)   NOT NULL,
  reason          VARCHAR2(500) NOT NULL,
  status          VARCHAR2(10)  DEFAULT 'PENDING' NOT NULL,
  decided_by      NUMBER(10),
  requested_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  decided_at      TIMESTAMP,
  decision_note   VARCHAR2(500),
  CONSTRAINT fk_gcr_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id),
  CONSTRAINT fk_gcr_requester  FOREIGN KEY (requested_by)  REFERENCES app_users(user_id),
  CONSTRAINT fk_gcr_decider    FOREIGN KEY (decided_by)    REFERENCES app_users(user_id),
  CONSTRAINT ck_gcr_old    CHECK (old_grade IS NULL OR old_grade BETWEEN 0 AND 100),
  CONSTRAINT ck_gcr_new    CHECK (new_grade BETWEEN 0 AND 100),
  CONSTRAINT ck_gcr_reason CHECK (LENGTH(TRIM(reason)) >= 10),
  CONSTRAINT ck_gcr_status CHECK (status IN ('PENDING','APPROVED','REJECTED')),
  -- four-eyes rule (SR08): the decider must differ from the requester
  CONSTRAINT ck_sod CHECK (decided_by IS NULL OR decided_by <> requested_by),
  CONSTRAINT ck_decision CHECK (
       (status = 'PENDING'  AND decided_by IS NULL AND decided_at IS NULL)
    OR (status <> 'PENDING' AND decided_by IS NOT NULL AND decided_at IS NOT NULL))
);

-- ------------------------------------------------ audit (append-only by design)
CREATE TABLE grade_audit (
  event_id       NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  enrollment_id  NUMBER(10)    NOT NULL,
  old_grade      NUMBER(5,2),
  new_grade      NUMBER(5,2),
  actor          VARCHAR2(50)  NOT NULL,
  actor_role     VARCHAR2(20)  NOT NULL,
  change_type    VARCHAR2(12)  NOT NULL,
  event_time     TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  reason         VARCHAR2(500),
  request_id     NUMBER(10),
  CONSTRAINT fk_ga_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id),
  CONSTRAINT fk_ga_request    FOREIGN KEY (request_id)    REFERENCES grade_change_requests(request_id),
  CONSTRAINT ck_ga_type CHECK (change_type IN ('ENTRY','EDIT','POST_CLOSE')),
  CONSTRAINT ck_audit_reason CHECK (change_type <> 'POST_CLOSE'
       OR (reason IS NOT NULL AND request_id IS NOT NULL))
);

CREATE TABLE security_events (
  event_id    NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor       VARCHAR2(50),
  event_type  VARCHAR2(30)  NOT NULL,
  outcome     VARCHAR2(10)  NOT NULL,
  event_time  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  source_ip   VARCHAR2(45),
  details     VARCHAR2(400),
  CONSTRAINT ck_se_outcome CHECK (outcome IN ('SUCCESS','DENIED','FAILURE'))
);

-- ------------------------------------------------------------- indexes
-- uq_* above already index the unique keys; these cover the foreign keys
-- that the application joins on.
CREATE INDEX ix_co_lecturer   ON course_offerings(lecturer_id);
CREATE INDEX ix_en_offering   ON enrollments(offering_id);
CREATE INDEX ix_gcr_enrollment ON grade_change_requests(enrollment_id);
CREATE INDEX ix_ga_enrollment ON grade_audit(enrollment_id);
CREATE INDEX ix_se_time       ON security_events(event_time);

-- ------------------------------------------------------ self-check
SELECT COUNT(*) AS tables_created FROM user_tables
 WHERE table_name IN ('STUDENTS','LECTURERS','APP_USERS','COURSES',
                      'COURSE_OFFERINGS','ENROLLMENTS',
                      'GRADE_CHANGE_REQUESTS','GRADE_AUDIT','SECURITY_EVENTS');
-- expected: 9
