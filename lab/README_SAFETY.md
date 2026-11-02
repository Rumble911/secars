# LAB safety rules

The code in `lab/` is deliberately vulnerable (limited SQL-injection demonstration). It exists only for education.

1. Run it only on the group's own machine, bound to `localhost`. Never expose its port to a network.
2. It connects only to the separate schema `ARS_LAB` with its own account. It has no privilege on `ARS_OWNER`, and `APP_USER` has none on `ARS_LAB`.
3. `ARS_LAB` contains fictional data only.
4. sqlmap and any other scan are used only against this LAB, with limited options, never against university or third-party systems.
5. After the demonstration the fixed version (PreparedStatement / bind variables) is re-tested with the same payload (test T7) and a limited sqlmap scan is run (test T8; no finding is not proof of safety).
6. A lab-only reset script restores the LAB without touching other databases.
