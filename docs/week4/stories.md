# CampusConnect — Week 4: User Stories & Acceptance Criteria

**Course:** SET312 — Agile Software Engineering, Group 1  
**Project:** CampusConnect — Student Clubs & Events Hub  
**Current Jira project:** [CAMP](https://zamr26689.atlassian.net/jira/software/projects/CAMP/boards/2)  
**Reviewed:** 23 November 2026  
**Status:** **REVISED DRAFT — NOT TEAM-APPROVED OR RESUBMITTED**

## Purpose and scope

This document replaces *obsolete active references* to historical `SCRUM-*` issues with the first **six ordered mandatory-MVP Stories in the current `CAMP-*` Jira backlog**: `CAMP-7` through `CAMP-12`. The former Week 4 `stories.md` remains available on the [historical submission branch](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/blob/docs/week4-submission/docs/week4/stories.md); it has not been deleted or rewritten.

Jira currently has **49 Stories**, including **13 mandatory-MVP Stories** (`CAMP-7`–`CAMP-19`) with **56 provisional Story Points**. Estimates and story descriptions below were read from Jira; the more specific **user-story wording and Given–When–Then examples are *proposed refinements***, not claims that Jira was updated or executable BDD tests passed.

> **Definition:** A scenario in this document is an *acceptance specification*, not evidence that an executable `.feature` test exists or passed. Do not report these as the five passing Gherkin scenarios required by the final project brief.

---

## 1. CAMP-7 — Browse University Clubs

**Epic:** [CAMP-1 — Club Pages & Discovery](https://zamr26689.atlassian.net/browse/CAMP-1)  
**Jira:** [CAMP-7](https://zamr26689.atlassian.net/browse/CAMP-7) · **3 SP (provisional)** · **In Progress**  
**User story — proposed phrasing:** As a **student**, I want to browse approved, active university clubs so that I can discover opportunities to participate on campus.

**Scenario A — Approved, active clubs are discoverable (success)**

```gherkin
Given I am authenticated as an active student
And the catalogue contains an approved active club named "Robotics Club"
And the catalogue also contains pending or inactive clubs
When I open the clubs browsing page
Then I can see the "Robotics Club" name and its public description
And pending or inactive clubs are not displayed
```

**Scenario B — No matching published clubs (edge case)**

```gherkin
Given I am authenticated as an active student
And no approved active clubs are available
When I open the clubs browsing page
Then I see a clear empty-state message
And I do not see a broken page or an unhandled error
```

**Evidence boundary:** The backend portion is merged in [PR #8](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/pull/8); Flutter integration and end-to-end acceptance are **not verified**. Keep parent Story **In Progress**.

## 2. CAMP-8 — View Club Details & Upcoming Events

**Epic:** [CAMP-1 — Club Pages & Discovery](https://zamr26689.atlassian.net/browse/CAMP-1)  
**Jira:** [CAMP-8](https://zamr26689.atlassian.net/browse/CAMP-8) · **5 SP (provisional)** · **In Progress**  
**User story — proposed phrasing:** As a **student**, I want to open a club's page and see its upcoming approved, published events so that I can decide whether to join an activity.

**Scenario A — Club and eligible upcoming events appear (success)**

```gherkin
Given I am authenticated as an active student
And "Robotics Club" is approved and active
And it has an upcoming event that is approved and published
And it has another event that is still pending approval
When I open the "Robotics Club" details page
Then I can see the club description and the approved published upcoming event
And I cannot see the event that is pending approval
```

**Scenario B — Hidden or missing club is not exposed (error case)**

```gherkin
Given I am authenticated as an active student
And a club is either missing, unapproved, or inactive
When I try to open that club's details page
Then I receive an understandable not-found state
And no unpublished club or event information is exposed
```

**Evidence boundary:** The CAMP-8 backend was merged in [PR #9](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/pull/9) (merge commit `b84a88972205700c5642a688367ced2dabf8ea04`); its separate [hosted GitHub Actions CI run](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/actions/runs/45150241147) passed **84 tests with one warning**. **Codex reported successful local application of Alembic migration `0004_create_events` to `localhost:5432/campusconnect_db`**, but that local database migration has **not been independently inspected by this documentation audit**; GitHub CI does not verify the developer’s local database. Flutter integration and end-to-end story acceptance remain **unverified**.

## 3. CAMP-9 — Search & Filter Clubs

**Epic:** [CAMP-1 — Club Pages & Discovery](https://zamr26689.atlassian.net/browse/CAMP-1)  
**Jira:** [CAMP-9](https://zamr26689.atlassian.net/browse/CAMP-9) · **3 SP (provisional)** · **To Do**  
**User story — proposed phrasing:** As a **student**, I want to search clubs by name and filter by category so that I can find clubs relevant to my interests.

**Scenario A — Search and category filter (success)**

```gherkin
Given I am authenticated as an active student
And the catalogue contains approved active clubs in different categories
When I search for "Robotics" and select the "Technology" category
Then I see only approved active clubs matching the search and filter
And I do not see clubs from another category
```

**Scenario B — Search finds nothing (edge case)**

```gherkin
Given I am authenticated as an active student
When I search for a club name that has no approved active match
Then I see a clear no-results message
And I can clear the search or filter to browse again
```

**Evidence boundary:** Story currently **To Do**. No accepted Flutter or end-to-end implementation evidenced.

## 4. CAMP-10 — Club Admin Creates Event

**Epic:** [CAMP-2 — Event Creation & Student Affairs Approval](https://zamr26689.atlassian.net/browse/CAMP-2)  
**Jira:** [CAMP-10](https://zamr26689.atlassian.net/browse/CAMP-10) · **5 SP (provisional)** · **To Do**  
**User story — proposed phrasing:** As an **authorized club administrator**, I want to save a draft event for my own active club so that I can prepare an activity before requesting Student Affairs approval.

**Scenario A — Valid draft is saved (success)**

```gherkin
Given I am an administrator authorized to manage "Robotics Club"
And "Robotics Club" is active
When I enter a valid title, description, date, venue, and positive seat capacity
And I save the new event
Then the event is stored as a draft for "Robotics Club"
And it is not publicly visible as an approved event
```

**Scenario B — Invalid or unauthorized creation is blocked (error case)**

```gherkin
Given I am not authorized to administer "Robotics Club"
When I attempt to save an event for that club
Then the request is rejected
And no draft event is created for that club
```

**Evidence boundary:** The events **data model** exists after PR #9, but the event-creation workflow, admin permissions, Flutter screen, and Story acceptance are **not verified**. Do not mistake a database model for a completed Story.

## 5. CAMP-11 — Submit Event for Approval

**Epic:** [CAMP-2 — Event Creation & Student Affairs Approval](https://zamr26689.atlassian.net/browse/CAMP-2)  
**Jira:** [CAMP-11](https://zamr26689.atlassian.net/browse/CAMP-11) · **3 SP (provisional)** · **To Do**  
**User story — proposed phrasing:** As a **club administrator**, I want to submit a valid draft event for Student Affairs review so that it can be approved before becoming public.

**Scenario A — Valid draft enters the approval queue (success)**

```gherkin
Given I administer the active club that owns a valid draft event
When I submit the event for approval
Then the event status becomes "Pending Approval"
And the event is available to the Student Affairs review workflow
And it is not publicly published
```

**Scenario B — An incomplete draft cannot be submitted (error case)**

```gherkin
Given I administer a club with a draft event missing a required venue
When I submit the event for approval
Then the submission is rejected with a useful validation message
And the event does not become publicly visible
```

**Evidence boundary:** No verified submitted, approved or published event workflow yet. Do not equate backend data states with a working approval journey.

## 6. CAMP-12 — Student Affairs Reviews Events

**Epic:** [CAMP-2 — Event Creation & Student Affairs Approval](https://zamr26689.atlassian.net/browse/CAMP-2)  
**Jira:** [CAMP-12](https://zamr26689.atlassian.net/browse/CAMP-12) · **5 SP (provisional)** · **To Do**  
**User story — proposed phrasing:** As a **Student Affairs officer**, I want to approve or reject submitted club events so that only properly reviewed activities may become eligible for publication.

**Scenario A — Officer approves a pending event (success)**

```gherkin
Given I am authenticated as an authorized Student Affairs officer
And a club event is awaiting approval
When I approve that event
Then its approval status becomes "Approved"
And the event becomes eligible for publication
And approval alone does not automatically publish it
```

**Scenario B — Unauthorized approval is prevented (error case)**

```gherkin
Given I am authenticated as a student who is not a Student Affairs officer
And an event is awaiting approval
When I try to approve the event
Then the action is denied
And the event remains in its previous approval state
```

**Evidence boundary:** Role-based Student Affairs authorization foundation exists, but the event-review workflow is **not verified**. Publication is a separate mandatory Story: [CAMP-13](https://zamr26689.atlassian.net/browse/CAMP-13).

---

## Mandatory key rule and BDD traceability beyond these six stories

The *official Group 1 project brief (p. 4)* requires: when an event is full, later RSVPs join a waiting list, and cancelling a confirmed booking automatically promotes the **first** waiting student. This is tracked by [CAMP-14](https://zamr26689.atlassian.net/browse/CAMP-14) through [CAMP-17](https://zamr26689.atlassian.net/browse/CAMP-17); the rule remains mandatory even though its Stories occur after the first six in Jira priority order.

**Additional candidate scenario — FIFO promotion (proposed, not executable evidence):**

```gherkin
Given an approved published event has a full seat capacity
And Student A joined its waiting list before Student B
When a confirmed attendee cancels a reservation
Then Student A is automatically promoted to a confirmed reservation
And Student B remains on the waiting list
And the event does not exceed its seat capacity
```

This example must be implemented as a genuinely executable test in the future `features/` suite before counting it toward the final project's five passing scenarios.

## Required refinement before team acceptance

- Confirm these proposed examples against business rules and user feedback, and update Jira acceptance criteria only with authorization.
- Specify exact UI states and accessible feedback for unauthenticated users, 403 responses and 404 responses.
- Clarify club-scoped permissions and valid event state transitions, including rejection reasons and resubmission rules.
- Test capacity, duplicates, cancellations and FIFO ordering under concurrent requests when implementation begins.
- Keep [CAMP-18](https://zamr26689.atlassian.net/browse/CAMP-18) explicitly as a calendar view; do not replace it with a plain list.
- Record team review/approval only if it actually occurs. Do not claim planning sessions, approved estimates or passing BDD from this document.

## Source register

1. **Official:** *Agile SW_Project_Brief_Group1 (1)(1).pdf*, pp. 1–2, 4, 7 (assignment scope, team obligations and key rule).
2. **Current:** [CAMP Jira backlog](https://zamr26689.atlassian.net/jira/software/projects/CAMP/boards/2), observed 23 November 2026.
3. **Historical:** [`docs/week4/stories.md` from old Week 4 branch](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/blob/docs/week4-submission/docs/week4/stories.md) (superseded issue references; preserved).
4. **Development:** [PR #8](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/pull/8) and [PR #9](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/pull/9) (backend only).

**Submission status:** This revised file is a locally prepared draft. It has **not** been committed, reviewed by the whole team, or uploaded as an improved LMS submission.
