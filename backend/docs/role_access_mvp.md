# CampusConnect MVP — Role Access Operations

These notes describe the narrowly scoped role-authentication foundation.
Do not run the commands or migrate an existing database without separate
authorization and independent review.

## Identity and permissions

- `student` and `student_affairs` are the only global account types.
- Club Admin is a *current club-specific database grant* to an active Student.
- A grant is **usable only while its club is approved and active**. Pending,
  rejected and inactive clubs can retain historical grants but do not confer
  administrator access. The draft-creation API returns the same 404 for an
  inaccessible club as for an unknown one.
- Student Affairs can assign/replace an administrator only for approved,
  active clubs. Use `PUT /api/v1/auth/student-affairs/clubs/{club_id}/administrator`
  with the existing Student UUID after external institutional verification.
- Student Affairs can **revoke** the grant at any time, including when the
  club is unapproved/inactive, using
  `DELETE /api/v1/auth/student-affairs/clubs/{club_id}/administrator`.
  The operation is idempotent for an existing club and responds HTTP 204.
  JWT identity alone never bypasses the current membership check.
- Migration 0006 enforces **at most one** administrator per club.
  A club can temporarily have no administrator.

## One Student Affairs account — operational policy

Only the interactive trusted CLI `python -m app.auth.provision_student_affairs`
may provision the MVP account. Its resolved target database is explicitly
displayed and must be typed back; environment `DATABASE_URL` can override
`.env`. The CLI checks the database for an existing Student Affairs account
after validating interactive account input, before inserting. It refuses to
create a second account. **This is not a concurrency-proof database singleton
constraint**; no new account-type migration was introduced.

If access to the existing Student Affairs account is lost, do **not** create
another account, alter a row through public registration or publish a shared
password. Escalate to the authorized university administrator to verify the
target database and account ownership, securely rotate the existing password
using the established password hasher, revoke existing sessions, and audit
the change. That restricted recovery operation is **not exposed by this MVP
API/CLI** and requires separate authorization and testing.

## Migration safety

Apply 0005 then 0006 only to a dedicated disposable test database for CI.
0006 refuses preexisting duplicate grants and never deletes or selects a
preferred administrator. If a non-disposable database ever requires migration,
review duplicate-grant records with the authorized Student Affairs operator
before **separately approving** any migration. Never use the existing
`campusconnect_db` for tests or demonstrations.

## Public authentication resource bounds

For public POST `/api/v1/auth/login` and `/register`, a minimal in-memory
fixed rolling 60-second window allows 20 login and 8 registration attempts
per *real ASGI connection peer*, respectively. Malformed requests and
nonexistent email addresses count. Excess attempts return HTTP 429 with a
`Retry-After` header; excess tracked peers fail closed with HTTP 503.
Client-submitted forwarding headers are not consulted by the application.
If deployed behind a proxy, configure the ASGI server's trusted proxy list
correctly or all users sharing a proxy may share one quota. Enforcement is
**in-process/per worker**, not distributed: multiple workers/replicas have
independent counters. Deployment-wide blocking requires external coordination
in the future. These bounds are for a small university MVP, not a global
anti-abuse service.

At most **two** simultaneous scrypt calls may run in a Python process; extra
password-hash work fails promptly with HTTP 503 (`Retry-After: 1`) rather
than queueing unbounded expensive allocations. scrypt work factors and stored
hash format remain unchanged. The administrative provisioning CLI reports a
safe error on local hash capacity exhaustion.

Trusted Student Affairs CLI provisioning also uses a PostgreSQL transaction-
scoped advisory lock held from the singleton check through insertion/commit.
Two concurrent CLI processes against the **same database** cannot both create
the initial account. This does not prevent privileged direct database writes
from bypassing the policy and is not a database-level singleton constraint.
