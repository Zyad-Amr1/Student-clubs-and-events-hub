# CampusConnect FastAPI backend

The backend exposes application liveness at `GET /health` and PostgreSQL readiness
at `GET /api/v1/health/db`.

## Local setup

From the repository root in Windows PowerShell:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

CI uses Python 3.12. On macOS or Linux, use `.venv/bin/python` for the commands below.

If `backend/.env` does not exist, copy the template from inside `backend`:

```powershell
Copy-Item .env.example .env
```

Edit `.env` locally. For the local PostgreSQL instance, use this URL format and
replace only the password placeholder with the URL-encoded password:

```dotenv
DATABASE_URL=postgresql+psycopg://campusconnect_user:YOUR_URL_ENCODED_DB_PASSWORD@localhost:5432/campusconnect_db
```

Encode reserved characters in the password, for example `@` as `%40` and `%` as
`%25`. Keep the completed URL in the ignored `.env` file. An exported
`DATABASE_URL` takes precedence over the file. Restart the API after a
configuration change.

## Windows troubleshooting

Keep Windows Security protections enabled. Do not disable Smart App Control,
Windows Code Integrity, or Microsoft Defender.

### SQLAlchemy compiled extensions

Windows Smart App Control or Code Integrity may block a SQLAlchemy compiled
`.pyd` extension and prevent the API from starting. If the Code Integrity log
names a file under `sqlalchemy\cyextension`, rebuild SQLAlchemy from source
without the Cython extensions.

From `backend` in PowerShell, check the installed version in the backend
virtual environment. This command reads package metadata without importing SQLAlchemy.

```powershell
.\.venv\Scripts\python.exe -m pip show SQLAlchemy
```

The following command was verified with Python 3.14.3 and SQLAlchemy 2.0.58.
Replace `2.0.58` with the installed version shown above if it differs. The
command uses the official PyPI source distribution, skips cached wheels, and
leaves other installed dependencies in place.

```powershell
$env:DISABLE_SQLALCHEMY_CEXT = "1"

.\.venv\Scripts\python.exe -m pip --isolated --disable-pip-version-check install `
  --index-url https://pypi.org/simple --force-reinstall --no-deps `
  --no-binary=SQLAlchemy --no-cache-dir SQLAlchemy==2.0.58
```

### Psycopg bundled DLL

If Windows Application Control blocks Psycopg's bundled DLL, select Psycopg's
pure-Python implementation and use the client library (`libpq.dll`) from your
PostgreSQL 18 installation. Run these commands in the same PowerShell session
before starting the API or running online Alembic commands. Adjust the path
if PostgreSQL was installed elsewhere.

```powershell
$env:Path = 'C:\Program Files\PostgreSQL\18\bin;' + $env:Path
$env:PSYCOPG_IMPL = 'python'
```

## Start and check connectivity

From `backend`, use the startup command verified on Windows with auto-reload
disabled.

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app
```

In a second terminal:

```powershell
curl.exe -i http://127.0.0.1:8000/health
curl.exe -i http://127.0.0.1:8000/api/v1/health/db
```

Both endpoints return HTTP 200 with `{"status":"ok"}` when their respective check
passes. Liveness is independent of PostgreSQL. Readiness runs `SELECT 1` and
returns HTTP 503 with `{"detail":"Database unavailable"}` if configuration,
connection, or query execution fails. This check does not change the schema.

The Android emulator can typically reach the host API at
`http://10.0.2.2:8000`.

## Database architecture

`app/config.py` resolves configuration from the environment and `backend/.env`.
`app/database.py` owns the lazily initialized SQLAlchemy engine, the shared
declarative base, and the `get_db` dependency. The dependency opens and closes a
session per request. Callers own their write transaction boundaries. The
readiness route uses a short-lived connection from the same engine.

## Migrations

Alembic uses the same database URL and SQLAlchemy metadata as the application.
The first revision, `0001_create_users`, creates the `users` table. API startup
does not execute Alembic.

List repository revisions or preview SQL without connecting to PostgreSQL:

```powershell
.\.venv\Scripts\python.exe -m alembic heads
.\.venv\Scripts\python.exe -m alembic upgrade head --sql
```

After approval to apply the revision, use these commands from `backend` with
`DATABASE_URL` set to the intended database.

```powershell
.\.venv\Scripts\python.exe -m alembic current
.\.venv\Scripts\python.exe -m alembic upgrade head
```

For future revisions, import new model modules in the Alembic environment before
using `alembic revision --autogenerate -m "Describe the schema change"`, then
review the generated migration. Downgrading this initial revision drops the
`users` table and its data.

## User accounts

PostgreSQL generates the UUID primary key. Full name, email, university ID, and
password hash are required. Email is trimmed and Unicode case-folded. University ID is
trimmed and uppercased. PostgreSQL 18 with UTF-8 uses its built-in
`pg_unicode_fast` collation for these identifiers. Both identifiers have independent unique constraints
backed by indexes, and the database rejects attempts to change them after
insertion. The password hash column is for encoded hashes. The future credential
service must hash passwords before persisting them.

New users default to active Student accounts. The database accepts only
`student` and `student_affairs` as account types. Future public registration
must always create Students and must not expose an account-type selector.
Student Affairs accounts require a controlled administrative provisioning
process. Future club administrator permissions will be assigned per approved
club and will not be a global account type.

Faculty, department, academic year, and profile picture URL are optional.
Academic year must be positive when provided. These fields and full name can
be edited later. Profile editing will validate that a department belongs to
the selected faculty. PostgreSQL stores creation and update timestamps as
timezone-aware instants and refreshes the update timestamp on row changes.

## Tests

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

GitHub Actions runs the full suite on Python 3.12 with an ephemeral PostgreSQL 18
service. Missing database configuration fails the integration tests in Actions.
Locally, the suite skips the PostgreSQL tests unless
`CAMPUSCONNECT_AUTH_TEST_PG_PORT` is set.

To run those tests, use a separate disposable PostgreSQL instance listening on
loopback on a port other than 5432. Create an empty database named
`campusconnect_auth_test` accessible locally as `postgres` without a password
on that instance. The suite uses only that loopback instance and database name.
It upgrades and downgrades the test schema, removes the migration tracking table
it created, and checks that ORM metadata matches the migration.

```powershell
$env:CAMPUSCONNECT_AUTH_TEST_PG_PORT = '55483'
.\.venv\Scripts\python.exe -m pytest -q
```

## Student registration API

POST /api/v1/auth/register creates a Student account, returning HTTP 201.
Required JSON fields: full_name, email, university_id, password, confirm_password.
Email is validated and case-folded; university ID is trimmed and uppercased.
Names are trimmed. Passwords must be 8–128 characters and must match.
Extra fields, including account_type and is_active, are rejected (HTTP 422).
Student Affairs registration is not public.

Example request body:

```json
{
  "full_name": "Example Student",
  "email": "student@example.edu",
  "university_id": "23P0000",
  "password": "ExamplePassphrase#123",
  "confirm_password": "ExamplePassphrase#123"
}
```

HTTP 201 returns id, full_name, normalized email and university_id,
account_type (`student`), is_active and created_at. No password, password
confirmation or password hash is returned. Duplicate identifiers return
HTTP 409 with a generic conflict message; invalid fields return HTTP 422
without echoing submitted input (including passwords).

Password hashes use the Python standard-library scrypt implementation with
a unique random salt and memory-hard work factors (N=131072, r=8, p=1).
This avoids introducing optional third-party compiled cryptography extensions
on Windows. The stored hash encodes its scheme and work factors for later
verification. Hashing is performed before insert; uniqueness is enforced
by PostgreSQL constraints to avoid check-then-insert races.

Registration does **not** yet issue a JWT or sign the Student in. The
immediate sign-in acceptance criterion in CAMP-46 remains pending on the
Login/JWT phase; Flutter must not assume a token is returned from this endpoint.

## Login, JWT sessions and logout (CAMP-60)

The API provides the following routes after applying revision `0002_create_auth_sessions`:

- `POST /api/v1/auth/login` accepts `{"email": "...", "password": "..."}`.
  On success, responds with `{"access_token": "...", "token_type": "bearer", "expires_in": 3600}`.
  Invalid/disabled/nonexistent credentials all get the same HTTP 401 response.
- `GET /api/v1/auth/me` requires `Authorization: Bearer <access_token>` and
  returns the server-authorized account profile (including `account_type`).
- `POST /api/v1/auth/logout` requires the same header and returns HTTP 204;
  its server-side session is immediately revoked (future use of that JWT returns 401).

Signed JWTs use **HS256**, a 60-minute lifetime, a validated issuer/audience,
and required `sub`/`jti`/`iat`/`exp` claims. The token contains no email,
password, or client-supplied role. Each request checks the database session's
revocation and expiry state and the user's `is_active` status. Logout revokes
only the current device session, not other devices. Expired rows may be pruned
later as maintenance; never treat client-side token deletion as server revocation.

`JWT_SECRET_KEY` is required **only for JWT endpoints**. Generate a high-entropy
secret on the developer's machine and place it in ignored `backend/.env`.
For example, from the backend folder:

```powershell
.\.venv\Scripts\python.exe -c "import secrets; print(secrets.token_urlsafe(48))"
```

Copy that value into a local `JWT_SECRET_KEY=...` setting without sharing it.
The setting must be at least 32 UTF-8 bytes. Missing/short secrets cause
HTTP 503 on JWT endpoints rather than silently using a development key.
Use HTTPS outside localhost; do not print/store JWTs in app logs. In Flutter,
persist tokens only in platform secure storage, clear them on logout, and
clear/re-authenticate on 401. There is **no refresh-token endpoint yet**;
users must log in again after token expiry. Student Affairs accounts, when
provisioned through controlled administration, use the same login endpoint.

For a registration-to-home flow on Flutter: first call registration, then
immediately call login with the same credentials, store the returned JWT in
secure storage and call `/me` for backend-authorized routing. No client-side
UI mode selection can create privileges.

The second Alembic migration creates `auth_sessions` with a UUID token ID
(JWT `jti`), user foreign key, expiry, revocation and creation timestamps.
It is **not** applied automatically when the server starts. Review and migrate
the intended local PostgreSQL database separately. Local registration remains
available without a JWT secret, but login requires the second migration.

## Student Affairs authorization and provisioning

`GET /api/v1/auth/student-affairs` is a minimal authorization check. An active
Student Affairs account with a valid bearer token receives HTTP 200 and
`{"account_type":"student_affairs"}`. Missing, invalid, expired, or revoked
credentials receive HTTP 401. An authenticated Student receives HTTP 403.
The reusable `require_roles` dependency checks the current PostgreSQL account
type after validating the token and its session. Client role fields and token
role claims have no effect. Future club-scoped policies can build on
`current_identity` and check membership for the specific club being accessed.

Only an authorized operator with access to the intended database should run
the local provisioning command. From `backend` in an interactive terminal,
the command displays the configured database host and name and requires you
to type that target before it accepts account details. It refuses to proceed
when the target host or database name is missing:

```powershell
.\.venv\Scripts\python.exe -m app.auth.provision_student_affairs
```

Enter the full name, email, and University ID when prompted. Enter and confirm
the password at the hidden prompts. The CLI rejects command-line arguments
and refuses password entry when echo cannot be suppressed. It validates the
same fields as registration, hashes with scrypt, and creates a new Student
Affairs account. An existing email or University ID is rejected without
changing the existing account. Public registration continues to create only
Students. CAMP-63 provisioning uses the existing schema and adds no migration.

## Club browsing API

`GET /api/v1/clubs` requires a valid bearer token for an active Student account.
It returns approved and active clubs only, ordered by name and UUID. Pending,
rejected, and inactive records are excluded. The `page` query parameter starts
at 1 (default 1, maximum 10,000); `page_size` defaults to 20 and is capped at
100. Invalid pagination values return HTTP 422. Missing or invalid sessions
return HTTP 401; other account types return HTTP 403.

The response contains a `clubs` array with only `id`, `name`, `description`,
`category`, and nullable `logo_url`, plus `page`, `page_size`, and `total`.
For example, an empty result is `{"clubs":[],"page":1,"page_size":20,"total":0}`.
Approval status, active state, and database timestamps are not exposed.

The PostgreSQL `clubs` table is added by Alembic revision
`0003_create_clubs`, after `0002_create_auth_sessions`.

### Search and category filtering (CAMP-9)

The existing Student-only `GET /api/v1/clubs` endpoint accepts two optional query
parameters. `search` matches a literal substring of the club name without case
sensitivity (maximum 120 characters). `category` matches the full category value
without case sensitivity (maximum 80 characters); partial category names are not
matches. Both values are trimmed before use, and blank values have no filtering
effect. If both parameters are present, results must match **both** filters.
Literal `%` and `_` characters in search text are not treated as SQL wildcards.

For example:

```http
GET /api/v1/clubs?search=robotics&category=Technology&page=1&page_size=20
Authorization: Bearer <student-access-token>
```

Filtering happens only among approved active clubs, before pagination, so
`total` counts the filtered visible clubs across all pages. The response format,
stable ordering, status codes (401/403/422), and page limits are unchanged.
Oversized search/category values receive HTTP 422. No additional migration is
required for these read-only filters.

`GET /api/v1/clubs/{club_id}` returns details for an approved, active club and
a bounded page of its upcoming events. It requires an active Student session;
missing or invalid credentials return HTTP 401, other account types return
HTTP 403, and nonexistent or hidden clubs return HTTP 404. Events are included
only when their approval status is `approved`, their explicit `is_published`
flag is true, and `starts_at` is later than the request's UTC time boundary.
They are ordered by start time and UUID. Pagination uses the same `page` and
`page_size` defaults and limits as club browsing.

The response shape is `{"club": {...}, "events": [...], "page": 1,
"page_size": 20, "total": 0}`. The club uses the safe club summary fields;
each event contains only `id`, `title`, `description`, `venue`, `starts_at`,
`ends_at`, and `seat_capacity`. Approval state, publication state, timestamps,
and event-to-club identifiers are not returned. Event approval defaults to
`draft`, and `is_published` defaults to false, so approval alone does not
publish an event.

The PostgreSQL `events` table is added by Alembic revision
`0004_create_events`, after `0003_create_clubs`.

## Submit a club draft event for Student Affairs approval (CAMP-11)

After the club-scoped administrator association and event tables are available,
an active authenticated **Student** with a server-managed administrator grant
for the specified active club can submit their existing draft:

`POST /api/v1/clubs/{club_id}/events/{event_id}/submit`

Requires `Authorization: Bearer <access_token>` and **forbids any request body**. Any nonempty request body, including `{}`, returns HTTP 422 without changing event state. A successful
request returns HTTP 200 and the event fields, with `approval_status: "pending"`
and `is_published: false`. Submission does **not** perform an approval decision,
publish the event, or notify Student Affairs. Public Club Details continues to
hide both drafts and pending events.

Responses: 401 for missing/invalid authentication; 403 for Student Affairs
(non-Student roles); 404 for unknown, inactive, or unmanaged clubs and events
(without revealing their existence); 409 if the event is not an unpublished
draft; 422 for an invalid UUID or draft schedule/details. The event's persisted
start must still be in the future and timezone-aware at submission time.
The state transition is protected by PostgreSQL row locks and a single
transaction; concurrent duplicate requests cannot both succeed.

Administrator grants are not accepted from the request or JWT; they are looked
up in the database by `club_id` and authenticated user ID. There is no public
club-administrator assignment API. The event is never made public merely by
creation or submission. The feature adds **no new database migration** beyond
CAMP-10's `0005_club_administrators`, and is currently a stacked PR pending
that prerequisite's integration.

## Student event reservations (CAMP-14–17)

All routes below require a current bearer session for an active **Student**.
Student Affairs accounts receive HTTP 403; missing, invalid, expired, revoked,
or inactive-user sessions receive HTTP 401. Club Admins remain Students and
may reserve events as students.

### Reserve a seat or join the waitlist

`POST /api/v1/events/{event_id}/reservations` has no request body. The event
must belong to an active approved club and be both approved and published, with
a start time in the future. A free seat returns HTTP 201 with `status:
"confirmed"`; a full event returns HTTP 201 with `status: "waitlisted"` and a
1-based `waitlist_position`. A duplicate active reservation returns HTTP 409;
an unknown or unavailable event returns HTTP 404.

```json
{
  "event_id": "<event-uuid>",
  "status": "waitlisted",
  "waitlist_position": 2,
  "event": {
    "id": "<event-uuid>",
    "club_id": "<club-uuid>",
    "title": "Engineering Workshop",
    "description": "Practical robotics session",
    "venue": "Engineering Hall",
    "starts_at": "2030-05-10T10:00:00Z",
    "ends_at": "2030-05-10T12:00:00Z",
    "seat_capacity": 40
  }
}
```

### Cancel a reservation

`DELETE /api/v1/events/{event_id}/reservations` cancels only the authenticated
Student's own reservation. It returns HTTP 204 on success and HTTP 404 when
that Student has no reservation for the event. Cancelling a waitlist entry does
not release a confirmed seat. Cancelling a confirmed reservation promotes the
earliest active Student still on the waitlist in the same transaction, while
the event remains available and in the future. Started events do not promote
waitlisted students.

### Read the current Student's reservations

`GET /api/v1/me/reservations` returns only the authenticated Student's active
confirmed and waitlisted reservations. The `reservations` array uses the same
object shape shown above; event details include the event and club UUID, title,
description, venue, start/end time, and seat capacity. Confirmed entries have
`waitlist_position: null`; waitlisted entries have their current 1-based
position among active Student waitlist entries. Results are ordered by event
start time.

### Persistence and concurrency

Alembic revision `0007_event_reservations` follows
`0006_one_admin_per_club`. It creates one table with a unique
`(event_id, user_id)` constraint, foreign keys to events and users, a checked
confirmed/waitlisted state, and a PostgreSQL identity value used as persisted
FIFO order. RSVP and cancellation lock the event row before reading or changing
seat counts. Promotion updates the earliest eligible queue entry and commits
with the cancellation, so concurrent requests cannot oversubscribe a published
event through these APIs. Cancelling deletes the active reservation row, which
allows the Student to register again later.

## Student account management

Authenticated students use `GET /api/v1/auth/me` and
`PUT /api/v1/auth/me` for their own profile. The update replaces the name and
optional academic fields. Email and university ID are read-only. Omit
`picture_base64` to keep the current avatar or send null to remove it. Uploaded
JPEG/PNG files are limited to 512 KiB and 2048 × 2048 pixels and stored as small,
re-encoded JPEGs without their original metadata.

`GET /api/v1/auth/academic-catalog` provides the university demo catalog.
It includes Engineering (Computer, Electrical and Mechanical Engineering),
Science (Computer Science, Mathematics and Physics), Business (Accounting and
Management), and academic years 1 through 5. These fields remain optional.

`POST /api/v1/auth/me/password` takes `current_password`, `new_password`, and
`confirm_password`. An incorrect current password returns 400. The current
session continues until logout or expiry. `POST /api/v1/auth/logout` revokes
the calling session.

`GET /api/v1/auth/me/managed-clubs` lists the caller's current active,
approved club assignments (possibly empty) for the Student Profile.

## Club creation requests and club profile edits

- Students use `GET/POST /api/v1/me/club-requests` to list their history and
  create a request. `PUT /api/v1/me/club-requests/{id}` edits a pending request,
  and `POST /api/v1/me/club-requests/{id}/withdraw` closes it without deleting it.
- Student Affairs uses `GET /api/v1/student-affairs/club-requests` for the
  pending queue and `GET /api/v1/student-affairs/club-requests/{id}/similar`
  to compare active clubs in the same category. Submit `decision: "approve"`
  or `decision: "reject"` with a student-visible `reason` on rejection to
  `POST /api/v1/student-affairs/club-requests/{id}/decision`. Approval publishes
  the club and assigns its creator in the same transaction.
- Verified admins use `GET/PUT /api/v1/club-admin/clubs/{id}/profile` for
  approved and active clubs they administer. The update accepts description,
  category, and optional `logo_base64`. Club names are read-only after approval.

Both request lists accept `page` and return 20 items plus `has_more`. Request
forms accept name, description, category, and optional `logo_base64`. Logo
uploads follow the profile picture rules, including keep and remove behavior.
Conflicting names, a second pending request, and edits or decisions after
closure return 409. Name matching folds case and collapses whitespace.

Alembic revision `0008_club_requests` adds the request history table after
`0007_event_reservations`. Partial unique indexes enforce one pending request
per student and one pending request per normalized name. An advisory
transaction lock protects the handoff from pending request to active club,
and row locks serialize competing decisions and withdrawals.

## Membership applications and interview booking

Students submit from Club Details using `POST /api/v1/clubs/{id}/applications`.
`GET /api/v1/me/applications` shows their history. `GET /api/v1/me/memberships`
shows accepted applications as memberships. Club admins use
`GET /api/v1/club-admin/clubs/{id}/applications` and post a decision of
`accepted` or `interview_required` to `…/applications/{application_id}/decision`.
The original submission time and review milestones are retained. This foundation
has one application per student and club. Reapplication, rejection and
post-interview membership decisions require separate lifecycle rules.

Interview days use **UTC** for both the calendar date and the configured
availability windows. Admins manage these through
`GET /api/v1/club-admin/clubs/{id}/interview-days` and
`PUT …/interview-days/by-date/{YYYY-MM-DD}`. The update sends `capacity`,
`duration_minutes`, and `periods` with `start_minute` and `end_minute` measured
from midnight UTC. A day can be published before its availability is configured.

An eligible applicant uses `GET/PUT/DELETE /api/v1/me/applications/{id}/interview`
to see/select/change a day or withdraw their unpublished selection. PUT takes
only `day_id`. Selecting a day reserves capacity without assigning a time.
The admin previews via `GET …/interview-days/{day_id}/schedule` and publishes
all or a subset via POST to the same route, passing selection IDs and their
previewed start and end timestamps. Publication rejects stale previews and
checks existing appointments across both the club and the applicant.
Published appointments retain their times when the schedule regenerates.

The Student Calendar opens Interview Calendar, which loads confirmation
notices and published times from `GET /api/v1/me/interview-appointments`.
Unpublished times are private to the administrator. Changes and cancellations
after publication, attendance and reminders belong to later stories.

Migration `0009_membership_applications` adds membership records after `0008`.
Migration `0010_interview_booking` adds days, preserved day selection history,
and confirmed times. Club row locks serialize day selections and capacity
edits. An advisory transaction lock serializes publication across clubs to
prevent one applicant from receiving overlapping appointments.
