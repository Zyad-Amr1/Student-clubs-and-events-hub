# Android acceptance against a disposable PostgreSQL database

These three `integration_test` suites use the app's real `IoApiTransport`, Android Keystore token store, FastAPI, and PostgreSQL. They create unique student, club, and event records on each run. Run them **sequentially** on one Android emulator because they share the app's secure token store. The club suite creates 22 approved clubs, archives one, and leaves one request pending. Use a disposable database; never aim these tests at the development, demo, or production database.

## One-time database setup

Use a local PostgreSQL server and a new role/database named `campusconnect_acceptance`. With `psql` from the PostgreSQL installation:

```powershell
psql -h 127.0.0.1 -U postgres -d postgres
```

At the `psql` prompt, run `CREATE ROLE campusconnect_acceptance LOGIN;`, then `\password campusconnect_acceptance` and enter a unique password. Run `CREATE DATABASE campusconnect_acceptance OWNER campusconnect_acceptance;` and `\q`. Create this database only if it does not already exist; later runs reuse it without clearing data.

From `D:\CampusConnect-Acceptance\backend`, set the database URL only in the current PowerShell process. Enter the URL at a hidden prompt, with the database password URL-encoded:

```powershell
$acceptanceUrl = Read-Host 'postgresql+psycopg://campusconnect_acceptance:<password>@127.0.0.1:5432/campusconnect_acceptance' -AsSecureString
$acceptancePtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($acceptanceUrl)
try { $env:DATABASE_URL = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($acceptancePtr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($acceptancePtr) }
Remove-Variable acceptanceUrl, acceptancePtr
$env:JWT_SECRET_KEY = python -c "import secrets; print(secrets.token_urlsafe(48))"
python -c "from app.config import get_database_url; u=get_database_url(); assert u.host in ('localhost','127.0.0.1') and u.database == 'campusconnect_acceptance' and u.username == 'campusconnect_acceptance', 'Wrong database target'; print(u.render_as_string(hide_password=True))"
```

The assertion must pass and print the intended local target **before** either command below writes to the database:

```powershell
python -m alembic upgrade head
python -m alembic current
python -m app.auth.provision_student_affairs
```

Provisioning is interactive and enforces one Student Affairs account. On later runs, retain the account and password; do not provision a second account. No `.env` file is created or overwritten.

Start FastAPI in this same PowerShell process, after checking the target again:

```powershell
python -c "from app.config import get_database_url; u=get_database_url(); assert u.host in ('localhost','127.0.0.1') and u.database == 'campusconnect_acceptance' and u.username == 'campusconnect_acceptance'; print(u.render_as_string(hide_password=True))"
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

The Android emulator reaches host loopback at `http://10.0.2.2:8000`. Check `http://127.0.0.1:8000/health` and `http://127.0.0.1:8000/api/v1/health/db` from the host. Keep this acceptance database separate from the manual demo database in `backend/docs/release-readiness.md`.

## Run the suites

Create `mobile/.env.acceptance.local.json` locally with the disposable Student Affairs email and password entered during provisioning:

```json
{
  "ACCEPTANCE_AFFAIRS_EMAIL": "<disposable affairs email>",
  "ACCEPTANCE_AFFAIRS_PASSWORD": "<disposable affairs password>",
  "API_BASE_URL": "http://10.0.2.2:8000"
}
```

The `.env.*` pattern in the repository `.gitignore` excludes this file. From `D:\CampusConnect-Acceptance\mobile`, with the backend running and an Android emulator selected, run each suite separately:

```powershell
flutter devices
flutter test integration_test/auth_acceptance_test.dart -d <android-device-id> --dart-define-from-file=.env.acceptance.local.json
flutter test integration_test/club_discovery_acceptance_test.dart -d <android-device-id> --dart-define-from-file=.env.acceptance.local.json
flutter test integration_test/reservation_calendar_acceptance_test.dart -d <android-device-id> --dart-define-from-file=.env.acceptance.local.json
```

The authentication test rebuilds the Flutter app **inside the same Android process** and verifies restoration from Android Keystore. It does not prove survival of a genuine process restart. For that final device check, sign in using the installed debug app, then run `adb shell am force-stop com.example.campusconnect` and `adb shell monkey -p com.example.campusconnect 1`; verify the correct portal reopens without a new login. Repeat after logout and verify the portal does not reopen. Perform this only during the final device acceptance session.

## Evidence and limits

| Suite | Story evidence | Limits |
| --- | --- | --- |
| `auth_acceptance_test.dart` | CAMP-46, CAMP-47, CAMP-52: student registration, duplicate email/ID rejection, invalid and valid student login, shared Affairs login, role navigation, same-process session restoration, logout and backend token revocation | Genuine Android process restart remains a separate device check |
| `club_discovery_acceptance_test.dart` | CAMP-7–9, CAMP-68: only approved active clubs visible, server search and category filter, two pages, UI filter reset, details with upcoming published event | Final visual/usability acceptance remains on device |
| `reservation_calendar_acceptance_test.dart` | CAMP-14–19, CAMP-70–71: published one-seat event, two students, waitlist, cancellation, FIFO promotion, refreshed calendar and event details | Earlier PostgreSQL tests remain the concurrency evidence; this journey is sequential |

These suites add Android and live-backend evidence. They do not by themselves close complete Jira Stories or replace the existing backend concurrency and authorization tests.
