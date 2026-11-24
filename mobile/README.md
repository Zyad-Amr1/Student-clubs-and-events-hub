# CampusConnect — Android Flutter student journey

This is the Flutter Android app based on the Flutter Foundation branch.
The student registration, login, secure session, profile, and read-only club
discovery journey connects to the existing FastAPI backend.

## Prerequisites

- Flutter SDK compatible with `mobile/pubspec.yaml` (Flutter 3.47+).
- Android SDK and an Android emulator or connected Android phone.
- FastAPI backend running on your development computer.
- PostgreSQL schema applied **only to your authorized development database**.
  Do not use or migrate a production database for demonstrations.
- Backend `JWT_SECRET_KEY` configured in ignored `backend/.env`.

## Windows PowerShell — run the app

From the repository root:

```powershell
git fetch origin
git switch feat/flutter-student-discovery-integration
cd mobile
flutter doctor
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

In another PowerShell window, from the repo root, start your **approved**
backend environment (after verifying its database configuration):

```powershell
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The emulator uses `10.0.2.2` to reach the host computer. A physical Android
device needs a reachable **HTTPS** URL. Plaintext LAN IP addresses are
not allowed by the Flutter client; do not use them for registration or login.

The Dart `HttpClient` does **not** rely on the Android network security XML
to enforce its cleartext policy. The Flutter API client itself permits HTTP
only when the host is exactly `10.0.2.2` and the build is non-release.
It rejects other HTTP hosts before sending any request, and disables HTTP
redirect following. Release builds require HTTPS. The debug Android network
policy also permits only the emulator bridge. Internet permission
is in the main manifest. Android Keystore encrypts session tokens
(AES/GCM) before they
are persisted; Android backup is disabled to avoid restoring encrypted data
without its Keystore key.

## Exact backend contracts

- `POST /api/v1/auth/register`: Student registration; **does not issue JWT**.
- `POST /api/v1/auth/login`: obtain JWT bearer token.
- `GET /api/v1/auth/me`: authoritative Student profile.
- `POST /api/v1/auth/logout`: revoke the session; local token is cleared.
- `GET /api/v1/clubs?page=1&page_size=20`: approved active club list.
- `GET /api/v1/clubs/{club_id}?page=1&page_size=20`: approved,
  published, upcoming events for the club.

Do not send CAMP-9 search/filter query parameters until that PR is integrated.
No clubs or events are bundled as production fixture data. The tests use
explicit synthetic responses from a mocked transport and in-memory token store.

## Verification

```powershell
cd mobile
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Flutter CI is scoped to this integration branch and is not part of Flutter
Foundation PR #15. Unit/widget tests with mock HTTP do not prove a device was
connected to a real FastAPI/PostgreSQL environment; that needs separate,
authorized end-to-end verification. No Jira status should be changed based
solely on this branch.
