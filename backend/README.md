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
There are no schema revisions in this phase. API startup does not execute Alembic.

List repository revisions or preview SQL without connecting to PostgreSQL:

```powershell
.\.venv\Scripts\python.exe -m alembic heads
.\.venv\Scripts\python.exe -m alembic upgrade head --sql
```

Once models and reviewed revisions exist, use these commands from `backend`
with `DATABASE_URL` set to the intended database:

```powershell
.\.venv\Scripts\python.exe -m alembic current
.\.venv\Scripts\python.exe -m alembic revision --autogenerate -m "Describe the schema change"
.\.venv\Scripts\python.exe -m alembic upgrade head
```

Import new model modules in the Alembic environment before autogenerating so
their tables are registered in the shared metadata. Review generated revisions
before applying them.

## Tests

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

Tests use mocked database connections and run without PostgreSQL credentials or
a running database.
