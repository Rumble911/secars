# Weekly log

Short written status per week: who did what, decisions, problems, next steps. Commit history is the primary evidence of each member's contribution.

## Week of 02/11/2026 (M1)
- Group formed; name SecARS agreed.
- M1 documents drafted (requirements, ERD, architecture/DFD, STRIDE, team plan); to be reviewed by the second member of each deliverable.
- Repository created with the mandatory structure; tag `M1` planned for 06/11/2026.

## Week of 09/11/2026 (M2)
- Built the database packages (login, student, lecturer, registrar, auditor), the Spring Boot API and the four role screens; merged to `main` at `4a97d17`, tag `M2` pushed.
- Added the functional test plan (30 tests, `docs/M2/M2_FunctionalTests.md`) and the test runner `scripts/m2_api_checks.ps1` with DB checks in `scripts/m2_db_checks.sql`.
- Fixed: `registrar2` was missing from the seed and the hash tool (M1 needs two registrars for the four-eyes rule).
- Open before the M2 gate: test results not yet written into the test plan; FR05 admin screens (students, courses, sections, enrolments) not built; some endpoint names differ from the requirements document.
- Next: M3 on branch `feature/db-security` (VPD, auditing, least privilege, SQL injection lab).
