-- =====================================================================
-- SecARS - M2 admin setup (run ONCE, as SYS AS SYSDBA)
-- Creates the two schemas used by the project:
--   ARS_OWNER : owns all tables, VPD policies, audit objects, ARS_API
--   APP_USER  : the limited account the Spring Boot backend connects with
-- Passwords are asked at run time and are NOT stored in this file.
-- Run from SQL*Plus:  sqlplus / as sysdba  @db/01_admin_setup.sql
-- =====================================================================

SET ECHO ON
SET DEFINE ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

ALTER SESSION SET CONTAINER = FREEPDB1;

ACCEPT ars_owner_pw PROMPT 'Password for ARS_OWNER: ' HIDE
ACCEPT app_user_pw  PROMPT 'Password for APP_USER: '  HIDE

-- ---------------------------------------------------------------- owner
CREATE USER ars_owner IDENTIFIED BY "&ars_owner_pw"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW,
      CREATE PROCEDURE, CREATE TRIGGER, CREATE SEQUENCE TO ars_owner;

-- ---------------------------------------------------------- app account
-- Least privilege: only the ability to log in. Table access is denied by
-- default. In M3, EXECUTE on ARS_API is granted to this account and nothing else.
CREATE USER app_user IDENTIFIED BY "&app_user_pw"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA 0 ON users;

GRANT CREATE SESSION TO app_user;

-- ------------------------------------------------------------- check
SELECT username, account_status, default_tablespace
  FROM dba_users
 WHERE username IN ('ARS_OWNER', 'APP_USER')
 ORDER BY username;
-- expected: two rows, both OPEN

UNDEFINE ars_owner_pw
UNDEFINE app_user_pw
