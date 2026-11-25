# Backend release readiness

Baseline: `c1584273e6606715830f1d39913935d71d9eb454`. The checks below are backend acceptance evidence from the PostgreSQL test suite. They do not establish Flutter acceptance or an end-to-end Android demo.

## Story evidence

The existing suite already covers the requested backend journeys. No duplicate journey test was added. The regression tests on this branch cover cancelled events after club reactivation and access to cancelled interview details after archival.

| Story | Backend evidence | Criteria demonstrated by backend | Remaining acceptance |
|---|---|---|---|
| CAMP-7 | `test_user_postgresql.py::test_student_browses_only_approved_active_clubs` | Active approved club visibility and role checks | Flutter browse and errors |
| CAMP-8 | `test_user_postgresql.py::test_club_details_*` | Club details, event visibility and paging | Flutter details view |
| CAMP-9 | `test_user_postgresql.py::test_club_search_*`; `tests/bdd/test_club_discovery_bdd.py` | Search, category, paging and hidden club behavior | Flutter filter integration |
| CAMP-10 | `test_event_creation.py::test_authorized_club_admin_creates_draft*` | Scoped draft creation and input validation | Flutter event form |
| CAMP-11 | `test_event_submission.py::test_draft_submits_once*`; `test_reactivated_club_cannot_submit_or_review_cancelled_events` | Valid draft submission, pending state and cancelled-draft rejection | Flutter submit/error state |
| CAMP-12 | `test_event_approval.py::test_*` | Affairs-only approval and rejection, pending queue, atomic decision | Flutter Affairs review |
| CAMP-13 | `test_event_approval.py::test_approve_publishes_future_pending_event_and_public_details` | Approved publication and public visibility | Flutter published event view |
| CAMP-14 | `test_event_reservations.py::test_student_reserves_published_event*`, `test_capacity_is_enforced_for_concurrent_students` | Student RSVP, duplicate prevention and seat capacity | Flutter reservation interaction |
| CAMP-15 | `test_event_reservations.py::test_student_reserves_published_event*` | Full event adds student to ordered waitlist | Flutter waitlist status |
| CAMP-16 | `test_event_reservations.py::test_fifo_waitlist_promotion_is_atomic_and_returns_to_next_student` | Owner cancellation and persistent state change | Flutter cancel/status refresh |
| CAMP-17 | `test_event_reservations.py::test_fifo_waitlist_promotion_is_atomic_and_returns_to_next_student`, `test_concurrent_cancellations_promote_distinct_waiters_without_overbooking` | FIFO promotion, concurrency and capacity | Flutter refresh for promoted student |
| CAMP-18 | `test_event_reservations.py::test_reservation_list_is_current_student_scoped_and_contains_event_details` | Current student’s reservation list and status | Flutter calendar refresh and display |
| CAMP-19 | `test_event_reservations.py::test_reservation_list_is_current_student_scoped_and_contains_event_details` | Reservation details from the student endpoint | Flutter opening calendar details |
| CAMP-20 | `test_club_management.py::test_club_request_workflow_and_scope` | Student request creation and duplicate/pending constraints | Flutter request form |
| CAMP-21 | `test_club_management.py::test_club_request_workflow_and_scope`, `test_approval_and_withdrawal_have_one_winner` | Owner edit/withdraw rules and concurrent state change | Flutter edit and confirm flows |
| CAMP-22 | `test_club_management.py::test_club_request_workflow_and_scope`, `test_approval_and_withdrawal_have_one_winner` | Affairs review, approved club creation and creator grant | Flutter review and rejection reason |
| CAMP-23 | `test_club_management.py::test_club_request_workflow_and_scope` | Owner-scoped request history and decision reasons | Flutter history screen |
| CAMP-24 | `test_club_management.py::test_club_request_workflow_and_scope` | Scoped club profile edit and immutable name | Flutter profile editor |
| CAMP-25 | `test_event_creation.py::test_archive_cancels_bookings_notices_admin_and_reactivation_keeps_cancellations`; `test_interview_lifecycle.py::test_archiving_club_cancels_interviews_without_rejecting_applications` | Archive preview/confirmation, cancellation, reasons, history, notifications and read-only student interview details | Flutter archive and historical detail views |
| CAMP-26 | `test_event_creation.py::test_reactivated_club_cannot_submit_or_review_cancelled_events`; `test_interview_lifecycle.py::test_archiving_club_cancels_interviews_without_rejecting_applications` | Reactivation preserves cancelled event/interview state; new event works | Flutter reactivation and cancelled-state display |
| CAMP-27 | `test_event_creation.py::test_archive_cancels_bookings_notices_admin_and_reactivation_keeps_cancellations` | Lifecycle notices and reason are persisted | Flutter notifications |
| CAMP-28 | `test_interview_booking.py::test_interview_booking_capacity_fcfs_and_partial_publication` | Day capacity and booking limits | Flutter day setup |
| CAMP-29 | `test_interview_booking.py::test_interview_booking_capacity_fcfs_and_partial_publication` | Eligible student day selection and capacity | Flutter day selection |
| CAMP-30 | `test_interview_booking.py::test_interview_booking_capacity_fcfs_and_partial_publication` | Availability setup and valid schedule inputs | Flutter availability editor |
| CAMP-31 | `test_interview_booking.py::test_interview_booking_capacity_fcfs_and_partial_publication` | FCFS schedule generation | Flutter generated schedule view |
| CAMP-32 | `test_interview_booking.py::test_interview_booking_capacity_fcfs_and_partial_publication` | Schedule publication and partial publication | Flutter publish controls |
| CAMP-33 | `test_interview_lifecycle.py::test_expiry_new_day_notices_and_attendance` | Unscheduled/expired applicant states | Flutter unscheduled state |
| CAMP-34 | `test_interview_lifecycle.py::test_cancellation_scopes_audit_and_selection_race`, `test_archiving_club_cancels_interviews_without_rejecting_applications` | Scoped cancellation, reasons, audit and archival cancellation | Flutter cancellation preview and reason |
| CAMP-35 | `test_interview_lifecycle.py::test_expiry_new_day_notices_and_attendance` | Attendance recording and invalid-state handling | Flutter attendance controls |
| CAMP-36 | `test_interview_lifecycle.py::test_archiving_club_cancels_interviews_without_rejecting_applications` | Interview notification/calendar record and archived historical details | Flutter notification/calendar entry |
| CAMP-37 | `test_interview_booking.py::test_interview_booking_capacity_fcfs_and_partial_publication` | Schedule adjustment before publication | Flutter adjustment controls |
| CAMP-38 | No dedicated backend acceptance test located | Two-hour published-schedule edit policy is unverified in backend | Story describes a later-release policy; confirm scope or add implementation and backend/UI acceptance |
| CAMP-39 | No dedicated backend acceptance test located | Student reschedule-request workflow is unverified in backend | Story describes a later-release policy; confirm scope or add implementation and backend/UI acceptance |
| CAMP-40 | `test_interview_lifecycle.py::test_cancellation_scopes_audit_and_selection_race` | Cancellation and attendance audit records | Flutter history display |
| CAMP-41 | No dedicated backend acceptance test located | Second chance after no-show is unverified in backend | Story describes advanced policy; confirm scope or add implementation and backend/UI acceptance |
| CAMP-42 | No dedicated backend acceptance test located | Automatic rejection/restoration policy is unverified in backend | Story describes advanced policy; confirm scope or add implementation and backend/UI acceptance |
| CAMP-43 | `test_interview_lifecycle.py::test_archiving_club_cancels_interviews_without_rejecting_applications` | Current cancelled appointment detail and reason | Flutter historical detail access |
| CAMP-44 | No scheduled reminder mechanism or dedicated test located | Automated reminders are unverified in backend | Story describes later-release notifications; confirm scope or implement and verify separately |

The database-backed suite verifies the backend transitions. Android acceptance still needs a demo against the configured backend, especially the promoted-student refresh, calendar status synchronization and interview history screen. The existing endpoint returns reservation details through `GET /api/v1/me/reservations`; no separate backend calendar endpoint was found.

## Isolated demo database

Use a dedicated local database name and database role, separate from `campusconnect_db` and any production URL. Set the connection string only in ignored `backend/.env`. Use an operator-selected strong password and URL-encode reserved characters.

From the repository root in PowerShell:

```powershell
cd backend
Copy-Item .env.example .env
```

Edit `backend/.env` to point to an empty demo database on the local PostgreSQL instance. Initialize it and check the schema:

Use `createdb campusconnect_demo` with the local PostgreSQL client on `PATH`. If a dedicated demo role is available, create the database owned by that role. Then set `DATABASE_URL` in `.env` to `campusconnect_demo` and run:

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m alembic current
.\.venv\Scripts\python.exe -m app.auth.provision_student_affairs
```

The provisioning command prints the database target and asks for exact confirmation. Enter the officer’s name, university email and ID, then enter the password at the hidden prompt. It refuses to create a second Student Affairs account. Keep the password in the operator’s password manager.

Register demo students through `POST /api/v1/auth/register` or the app. Use one student to submit a club request. Sign in as Student Affairs and approve it. The creator is granted administration for that club. Create a second student for RSVP demonstrations. As the Club Admin, create and submit a future event. As Student Affairs, approve it. Set capacity to one. Student A reserves the seat and Student B joins the waitlist. Student A cancels, then Student B refreshes `GET /api/v1/me/reservations` and sees confirmed status.

Start the API from `backend` with `.env` pointing at the demo database:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Check `http://127.0.0.1:8000/health` and `http://127.0.0.1:8000/api/v1/health/db`. For a device on the same network, configure the app with the computer’s LAN address and allow inbound TCP 8000 only on the private network profile. Use the same local demo database throughout rehearsal. Never point the demo build at production or use production credentials.
