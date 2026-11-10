# SecARS - Secure Academic Records System

Final semester project for **Information and Database Security (906313)**, Al al-Bayt University,
Prince Al Hussein bin Abdullah II Faculty of Information Technology - First Semester 2026/2027.

SecARS is a university application (students, lecturers, courses, sections, enrolments, grades) built from scratch on
**Oracle Database Free**, **Java Spring Boot** and **React**. The goal is the security around the data: identity and
privileges, row-level security (VPD), SQL-injection defence, auditing, encryption, backup/restore and masking - each
proved by repeatable tests.

**Group members:** Abdullah Ibrahim Hassan, Abdulrahman Al-Otaibi

> All data in this project is fictional. Attacks and scans are performed only against the isolated LAB schema on localhost.

## Status

| Milestone | Due | Status | Tag |
|-----------|-----|--------|-----|
| M1 - Analysis & Design | 06/11/2026 | Delivered (see `docs/M1/`) | `M1` |
| M2 - System Development | 20/11/2026 | Built, under test (see `docs/M2/`) | `M2` |
| M3 - Security Implementation | 11/12/2026 | Planned | `M3` |
| M4 - Final Assessment & Delivery | 25/12/2026 | Planned | `FINAL` |

## M1 deliverables (`docs/M1/`)

| File | Content |
|------|---------|
| `M1_Requirements.pdf` | FR01-FR12, business rules, use cases for the four roles |
| `M1_ERD.pdf` | ERD, data dictionary, relationships, data classification |
| `M1_Architecture_DFD.pdf` | Architecture, DFD level 0 and 1, trust boundaries TB1-TB4 |
| `M1_STRIDE.xlsx` | STRIDE threat model (16 threats), rating key, data classification |
| `M1_TeamPlan.pdf` | Responsibilities, schedule, Git/release plan, risks |

## Architecture in one paragraph

React (`localhost:5173`) -> Spring Boot (`localhost:8080`, Spring Security, RBAC) -> Oracle (`FREEPDB1`, listener on
localhost) as the limited account `APP_USER`, which can only `EXECUTE` the PL/SQL package `ARS_API`. Tables, VPD
policies, audit tables and triggers belong to the separate schema `ARS_OWNER`. The vulnerable SQL-injection demo lives
only in the separate `ARS_LAB` schema and `lab/`.

## Repository layout

```
backend/        Spring Boot project (M2)
frontend/       React + Vite project (M2)
db/             01_admin_setup.sql, 02_schema.sql, 03_seed.sql (M2)
db/security/    users_roles.sql, api_packages.sql, vpd.sql, audit.sql (M3)
db/recovery/    export_import_steps.md, verify.sql, mask.sql (M4)
lab/            isolated_SQLi_demo/, README_SAFETY.md
docs/           M1/ M2/ M3/ M4/ and the final report
evidence/       screenshots/, test_log.xlsx, sanitized_logs/
contribution/   individual contributions and weekly log
```

## Prerequisites

JDK 21, Maven, Node.js LTS, Git, Oracle AI Database Free 26ai (preferably the official container; service name
`FREEPDB1`, verify the actual name), and SQL Developer or SQLcl. Check with `java -version`, `mvn -version`,
`node --version`, `git --version`.

## Running the project (M2)

**1. Database** (SQL*Plus, one time, in this order):

| Order | File | Run as | Purpose |
|-------|------|--------|---------|
| 1 | `db/01_admin_setup.sql` | SYS (container FREEPDB1) | Creates `ARS_OWNER` and `APP_USER` |
| 2 | `db/02_schema.sql` | ARS_OWNER | Nine tables |
| 3 | `db/03_seed.sql` | ARS_OWNER | Sample data (fictional) |
| 4 | `db/04_auth_package.sql` | ARS_OWNER | Login package `ARS_AUTH` |
| 5 | `db/05_student_package.sql` | ARS_OWNER | Student package `ARS_STUDENT` |
| 6 | `db/06_staff_packages.sql` | ARS_OWNER | Lecturer, registrar, auditor packages |

```
sqlplus ars_owner@localhost:1521/FREEPDB1
@db\02_schema.sql
```

**2. Demo passwords** (never stored in Git). Set the variables in the PowerShell window, then run the
`hashgen` profile. It prints one `UPDATE` per account; paste them into SQL*Plus as `ARS_OWNER` and `COMMIT`.

```powershell
cd backend
$env:DEMO_STUDENT_PW = "<min 10 characters>"
$env:DEMO_LECTURER_PW = "<min 10 characters>"
$env:DEMO_REGISTRAR_PW = "<min 10 characters>"
$env:DEMO_AUDITOR_PW = "<min 10 characters>"
mvn spring-boot:run "-Dspring-boot.run.profiles=hashgen"
```

**3. Backend** (keep this window open):

```powershell
cd backend
$env:DB_PASSWORD = "<APP_USER password>"
mvn spring-boot:run
```

Wait for `Started SecarsApplication`. The API runs on `http://localhost:8080`.

**4. Frontend** (second window):

```powershell
cd frontend
npm install
npm run dev
```

Open `http://localhost:5173/login`.

**5. Tests**: follow `docs/M2/M2_FunctionalTests.md` (demo accounts and expected results are listed there).

Configuration is read from environment variables only. `.env.example` lists the names; never commit real values.

## Secrets policy

No passwords, wallets, keys or real data in Git. Only `.env.example` with placeholders is committed.

## Release plan

- Annotated, timestamped Git tags: `M1` (06/11/2026), `M2` (20/11/2026), `M3` (11/12/2026), `FINAL` (25/12/2026).
- `main` holds reviewable work; changes go through short-lived `feature/<area>-<topic>` branches and pull requests
  reviewed by a second member. Commit messages: `<type>(<area>): <what>`.
- Defects found in an earlier milestone are fixed and submitted with the next one.
- No code changes after the `FINAL` tag (25/12/2026); the group discussion in Week 14 (10-14/01/2027) uses it.

Details: `docs/RELEASE_PLAN.md` and `docs/M1/M1_TeamPlan.pdf`.
