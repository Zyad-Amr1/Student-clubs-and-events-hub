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
Students. This change uses the existing schema and adds no migration.
