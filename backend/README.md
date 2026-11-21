# CampusConnect — FastAPI backend

Milestone 1 foundation scaffold. The only current endpoint is `GET /health`.
No registration, login, authorization, or database integration has been built yet.

## Local quick start

From the repository root:

```bash
cd backend
python -m venv .venv
```

Activate the virtual environment:

- Windows PowerShell: `.venv\Scripts\Activate.ps1`
- macOS/Linux: `source .venv/bin/activate`

Then:

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000/health`; it should return `{"status":"ok"}`.

Run backend tests:

```bash
pytest -q
```

## PostgreSQL

PostgreSQL is the approved project database. Copy `.env.example` to `.env` and replace placeholders **locally**. Do not commit secrets. The actual SQLAlchemy models, migrations, DB connectivity and AUTH-01 implementation come next; `/health` does not check PostgreSQL.

## API from Android emulator

The Android emulator usually reaches a backend running on the host at `http://10.0.2.2:8000`, provided the API is listening on the required interface. Avoid embedding a production API URL or secrets directly in the app.
