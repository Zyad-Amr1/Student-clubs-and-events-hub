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
| CAMP-37 | Deferred. No complete acceptance evidence claimed. | Advanced manual schedule adjustment | Explicitly deferred |
| CAMP-38 | Deferred. No complete acceptance evidence claimed. | Editing published interviews with two-hour notice | Explicitly deferred |
| CAMP-39 | Deferred. No complete acceptance evidence claimed. | Student rescheduling requests | Explicitly deferred |
| CAMP-40 | Deferred. Cancellation audit tests do not establish full attendance correction and audit history. | Attendance correction and complete audit history | Explicitly deferred |
| CAMP-41 | Deferred. No complete acceptance evidence claimed. | Second chance after no-show | Explicitly deferred |
| CAMP-42 | Deferred. No complete acceptance evidence claimed. | Automatic rejection and restoration policy | Explicitly deferred |
| CAMP-43 | Deferred. Archived cancelled detail coverage does not establish full detailed interview history. | Full interview history | Explicitly deferred |
| CAMP-44 | Deferred. No scheduled reminder mechanism or complete acceptance evidence located. | Automated interview reminders | Explicitly deferred |
| CAMP-46 | `test_user_postgresql.py::test_registration_creates_only_student_without_returning_secrets`; `test_login_me_and_logout_revoke_session`; `test_account_management.py::test_private_profile_and_password_change` | Student registration, shared login, own profile and credential update | Flutter registration/login/profile and secure session acceptance |
| CAMP-47 | `test_user_postgresql.py::test_login_me_and_logout_revoke_session`, `test_disabled_account_cannot_login`, `test_disabling_account_invalidates_existing_session` | Login, logout and session invalidation | Flutter secure persistence and restart acceptance |
| CAMP-48 | `test_user_postgresql.py::test_postgresql_defaults_and_profile_updates`; `test_private_profile_and_password_change` | Profile reads and permitted edits | Flutter profile screen and validation |
| CAMP-49 | `test_user_postgresql.py::test_student_affairs_can_use_same_login_without_self_registration`; `test_provision_student_affairs.py::*` | Student Affairs uses shared login and controlled provisioning | Flutter Affairs sign-in route and dashboard |
| CAMP-50 | `test_user_postgresql.py::test_protected_endpoints_reject_missing_or_invalid_tokens`, `test_expired_and_unregistered_tokens_cannot_access_me`, `test_student_role_cannot_be_overridden_by_client` | Authenticated role checks and forged/missing token rejection | Flutter unauthorized and expired-session UX |
| CAMP-51 | `test_user_postgresql.py::test_postgresql_rejects_duplicate_normalized_identifiers`, `test_registration_rejects_duplicates_atomically` | Normalized unique identifiers and duplicate registration rejection | Flutter field errors |
| CAMP-52 | `test_user_postgresql.py::test_disabled_account_cannot_login`, `test_disabling_account_invalidates_existing_session`; `test_account_management.py::test_private_profile_and_password_change` | Account/profile security and session invalidation | Flutter account settings behavior |
| CAMP-53 | Deferred. No complete acceptance evidence claimed. | Advanced interview policy | Explicitly deferred |
| CAMP-54 | Deferred. No complete acceptance evidence claimed. | Advanced interview policy | Explicitly deferred |
| CAMP-55 | Deferred. No complete acceptance evidence claimed. | Advanced interview policy | Explicitly deferred |
| CAMP-56 | `test_event_creation.py::test_archive_cancels_bookings_notices_admin_and_reactivation_keeps_cancellations`; `test_portal_access.py::test_archived_club_remains_visible_read_only_to_its_original_admin` | Archive status, reason and read-only archived access | Flutter archived status and reason display |
| Club Head workflow | `test_club_head.py::test_club_head_race_rejection_reopening_and_assignment`; `test_student_affairs_singleton_includes_inactive_accounts` | One pending request/head per club, rejection reopening, approval assignment and database singleton | Flutter vacancy/application/review workflow |

CAMP-37–44 and CAMP-53–55 are explicitly deferred. Their partial or adjacent regression coverage is not acceptance evidence for those Stories.

The database-backed suite verifies the backend transitions. Android acceptance still needs a demo against the configured backend, especially the promoted-student refresh, calendar status synchronization and interview history screen. The existing endpoint returns reservation details through `GET /api/v1/me/reservations`; no separate backend calendar endpoint was found.

## Isolated demo database

Use a dedicated local database name and database role, separate from `campusconnect_db` and any production URL. Set the connection string only in ignored `backend/.env`. Use an operator-selected strong password and URL-encode reserved characters.

From the repository root in PowerShell, create `.env` from the example only when it is absent. This preserves any existing development configuration:

```powershell
cd backend
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
```

For a clean demo setup, create a dedicated local PostgreSQL role and empty database using a password entered interactively. Do not reuse the development or production database role. Example with `psql` available on `PATH`:

```powershell
psql -h localhost -U postgres -d postgres
```

At the `psql` prompt, run `CREATE ROLE campusconnect_demo LOGIN;`, then `\password campusconnect_demo` and enter a unique demo password, followed by `CREATE DATABASE campusconnect_demo OWNER campusconnect_demo;` and `\q`. Set `DATABASE_URL` in `backend/.env` to the local `campusconnect_demo` URL using the URL-encoded demo password. Keep the `.env` file local and ignored.

Before any schema or account writes, print and verify the exact configured target. This extra confirmation applies before Alembic as well as before secure account provisioning:

```powershell
.\.venv\Scripts\python.exe -c "from app.config import get_database_url; print(get_database_url().render_as_string(hide_password=True))"
```

Run from the `backend` directory. Compare the printed host, port and database with the intended local demo target. Stop if they differ. Then initialize the empty demo database and verify its migration head:

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m alembic current
.\.venv\Scripts\python.exe -m app.auth.provision_student_affairs
```

The provisioning command prints the database target and asks for exact confirmation. Enter the officer’s name, university email and ID, then enter the password at the hidden prompt. It refuses to create a second Student Affairs account. Keep the password in the operator’s password manager.

Register realistic demo students with university email addresses and unique university IDs through the app or `POST /api/v1/auth/register`. Use a student to request a named club such as Robotics Society. Sign in as Student Affairs and approve it. The creator receives scoped Club Admin access. To demonstrate Club Head approval, use another student to apply to that active club, then approve the request as Student Affairs. Create a second club request/student pair if the demo needs to show rejection and vacancy reopening.

As the Robotics Society Club Admin, create and submit a future event with seat capacity one. Use a clear title such as `Robotics Showcase — FIFO Demo`. Student Affairs approves it. Student A reserves the seat and Student B joins the waitlist. Student A cancels. Student B refreshes the app and sees the reservation promoted to confirmed. Confirm reservation details and state through `GET /api/v1/me/reservations` for each student's own login.

Start the API from `backend` with `.env` pointing at the demo database:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Keep the backend bound to localhost. For the Android emulator, configure the app's API base URL as `http://10.0.2.2:8000`. Check `http://127.0.0.1:8000/health` and `http://127.0.0.1:8000/api/v1/health/db` from the host. No LAN firewall rule is needed for the emulator's host loopback mapping.

Final demo order: start PostgreSQL if needed, confirm `DATABASE_URL` still names `campusconnect_demo`, start the API with the command above, check both health URLs, launch the Android app manually, sign in as the provisioned Affairs account, approve the club and event, then sign in as Club Admin and the two students to demonstrate Head approval and FIFO promotion. Do not start or rebuild the emulator as part of backend initialization. Never point this rehearsal at `campusconnect_db` or production, and do not use production credentials.
