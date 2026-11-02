# SecARS release plan

## Tags

| Tag | Date | Must contain | Gate before tagging |
|-----|------|--------------|---------------------|
| `M1` | 06/11/2026 | `docs/M1/` (5 files), README, `.env.example`, folder structure | All five files open; ERD, DFD and STRIDE names match; at least 6 threats |
| `M2` | 20/11/2026 | `db/01_admin_setup.sql`, `02_schema.sql`, `03_seed.sql`, `backend/`, `frontend/`, `M2_FunctionalTests.pdf`, run steps in README | Fresh clone runs against real Oracle; four role accounts log in |
| `M3` | 11/12/2026 | `db/security/*.sql`, `lab/`, `M3_AccessMatrix.pdf`, `M3_SecurityTests.xlsx`, `M3_BeforeAfter.pdf`, evidence | T1-T10 executed with request/SQL, result and log record; M2 defects fixed |
| `FINAL` | 25/12/2026 | Everything, `db/recovery/*`, `evidence/test_log.xlsx`, `M4_FinalReport.pdf`, `contribution/individual_contributions.pdf` | Clean-machine rebuild passed; secrets removed; T1-T13 PASS/FAIL table complete |

Create tags as annotated tags and push them: `git tag -a M1 -m "M1 - Analysis & Design"` then `git push origin M1`.

## Branching and review

- `main`: last reviewed state. No direct pushes of security-relevant changes.
- `feature/<area>-<topic>` (areas: db, api, ui, lab, docs) merged by pull request.
- Security-relevant changes (privileges, VPD, audit, secrets) need a reviewer other than the author.
- Commit format: `<type>(<area>): <what>` with types `feat`, `fix`, `test`, `docs`, `chore`.

## Before every tag

1. Run the secret scan (no `.env`, wallets, keys, passwords in the tree or history).
2. Re-run the scripts from scratch on a clean schema.
3. Check that evidence entries have test ID, date, tester, steps, expected, actual, PASS/FAIL.
4. Tag, push the tag, and record the commit hash in `contribution/weekly_log.md`.
