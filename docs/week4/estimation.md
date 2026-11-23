# CampusConnect — Week 4: Estimation & INVEST Review

**Course:** SET312 — Agile Software Engineering, Group 1  
**Source:** [live CAMP backlog](https://zamr26689.atlassian.net/jira/software/projects/CAMP/boards/2), reviewed 23 November 2026  
**Status:** **REVISED AUDIT DRAFT — PROVISIONAL ESTIMATES; NO TEAM CONSENSUS CLAIMED**  
**Predecessor:** [original Week 4 estimation draft](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/blob/docs/week4-submission/docs/week4/estimation.md) (preserved; historical `SCRUM-*`)

## 1. Estimation basis and honesty boundary

The current Jira project contains **49 User Stories**, so the university-wide requirement for **at least 15 stories** is satisfied as a count. This document intentionally focuses on the **13 mandatory-MVP Stories** (CAMP-7–CAMP-19), which total **56 provisional Story Points**. Authentication and other supporting work are *not included* in the 56 SP figure and may consume additional capacity. The separate historical Week 4 forecast used **13 `SCRUM-*` stories and 51 SP**; that was a different baseline, not an error to silently rewrite in history.

Story Points estimate *relative effort, complexity and uncertainty*; they are **not work hours, completed points, measured team velocity or signed-off Sprint commitments**. The current point values have **not been independently verified as agreed through a real Planning Poker session**. No voting records, meeting attendance or participant consensus are supplied.

## 2. Current live Jira estimates — mandatory MVP

| Jira story | Mandatory MVP feature | Epic | Provisional SP |
|---|---|---|---:|
| [CAMP-7](https://zamr26689.atlassian.net/browse/CAMP-7) | Browse University Clubs | [CAMP-1](https://zamr26689.atlassian.net/browse/CAMP-1) | 3 |
| [CAMP-8](https://zamr26689.atlassian.net/browse/CAMP-8) | View Club Details & Upcoming Events | [CAMP-1](https://zamr26689.atlassian.net/browse/CAMP-1) | 5 |
| [CAMP-9](https://zamr26689.atlassian.net/browse/CAMP-9) | Search & Filter Clubs | [CAMP-1](https://zamr26689.atlassian.net/browse/CAMP-1) | 3 |
| [CAMP-10](https://zamr26689.atlassian.net/browse/CAMP-10) | Club Admin Creates Event | [CAMP-2](https://zamr26689.atlassian.net/browse/CAMP-2) | 5 |
| [CAMP-11](https://zamr26689.atlassian.net/browse/CAMP-11) | Submit Event for Approval | [CAMP-2](https://zamr26689.atlassian.net/browse/CAMP-2) | 3 |
| [CAMP-12](https://zamr26689.atlassian.net/browse/CAMP-12) | Student Affairs Reviews Events | [CAMP-2](https://zamr26689.atlassian.net/browse/CAMP-2) | 5 |
| [CAMP-13](https://zamr26689.atlassian.net/browse/CAMP-13) | Publish Approved Events | [CAMP-2](https://zamr26689.atlassian.net/browse/CAMP-2) | 3 |
| [CAMP-14](https://zamr26689.atlassian.net/browse/CAMP-14) | Register for Available Event | [CAMP-3](https://zamr26689.atlassian.net/browse/CAMP-3) | 5 |
| [CAMP-15](https://zamr26689.atlassian.net/browse/CAMP-15) | Join FIFO Waiting List | [CAMP-3](https://zamr26689.atlassian.net/browse/CAMP-3) | 5 |
| [CAMP-16](https://zamr26689.atlassian.net/browse/CAMP-16) | Cancel Event Reservation | [CAMP-3](https://zamr26689.atlassian.net/browse/CAMP-3) | 3 |
| [CAMP-17](https://zamr26689.atlassian.net/browse/CAMP-17) | Auto-Promote First Waiting Student | [CAMP-3](https://zamr26689.atlassian.net/browse/CAMP-3) | 8 |
| [CAMP-18](https://zamr26689.atlassian.net/browse/CAMP-18) | View My Events Calendar | [CAMP-4](https://zamr26689.atlassian.net/browse/CAMP-4) | 5 |
| [CAMP-19](https://zamr26689.atlassian.net/browse/CAMP-19) | View Event Details from Calendar | [CAMP-4](https://zamr26689.atlassian.net/browse/CAMP-4) | 3 |
| **Total mandatory MVP** | **13 Stories** | **Four mandatory epics** | **56** |

**Epic totals (recomputed from Jira):**

| Epic | Stories | Provisional SP |
|---|---:|---:|
| CAMP-1 — Club Pages & Discovery | 3 | 11 |
| CAMP-2 — Event Creation & Student Affairs Approval | 4 | 16 |
| CAMP-3 — RSVP & FIFO Waiting List | 4 | 21 |
| CAMP-4 — My Events Calendar | 2 | 8 |
| **Total** | **13** | **56** |

## 3. INVEST audit (reviewer assessment, not team approval)

**INVEST = Independent · Negotiable · Valuable · Estimable · Small · Testable.**

The current Jira story descriptions use similar generic acceptance criteria for many stories (role access, UI errors, backend/Flutter tests). These are valuable quality expectations, but **not sufficient on their own** to validate each story's distinct business outcome. All 13 Stories require team-level acceptance-criteria review before formal INVEST sign-off.

| Story | Preliminary positive signal | Risk / proposed refinement |
|---|---|---|
| [CAMP-7](https://zamr26689.atlassian.net/browse/CAMP-7) | Testable public catalogue outcome | Clarify non-student access and empty-state UX |
| [CAMP-8](https://zamr26689.atlassian.net/browse/CAMP-8) | Club/event view has clear user value | Clarify pagination, time boundary, unavailable-club handling |
| [CAMP-9](https://zamr26689.atlassian.net/browse/CAMP-9) | Search and category filtering deliver value | Confirm search semantics and whether two paths fit 3 SP |
| [CAMP-10](https://zamr26689.atlassian.net/browse/CAMP-10) | Visible draft-event outcome | Confirm fields, validity, ownership and active-club authorization |
| [CAMP-11](https://zamr26689.atlassian.net/browse/CAMP-11) | Distinct submit-for-review transition | Define invalid draft and repeated-submission behavior |
| [CAMP-12](https://zamr26689.atlassian.net/browse/CAMP-12) | Officer decision is demonstrable | Clarify rejection behavior, permissions, repeat decisions |
| [CAMP-13](https://zamr26689.atlassian.net/browse/CAMP-13) | Public visibility is separately testable | Define approved != published and exact visibility conditions |
| [CAMP-14](https://zamr26689.atlassian.net/browse/CAMP-14) | Confirmed RSVP is testable | Specify atomic capacity checks, duplicate RSVP, concurrent clients |
| [CAMP-15](https://zamr26689.atlassian.net/browse/CAMP-15) | FIFO queue admission is testable | Define consistent ordering, ties, duplicate queue entries |
| [CAMP-16](https://zamr26689.atlassian.net/browse/CAMP-16) | Cancellation changes reservation state | Specify cancel queued vs confirmed, effects and idempotency |
| [CAMP-17](https://zamr26689.atlassian.net/browse/CAMP-17) | Critical FIFO promotion rule, 8 SP | High complexity: assess smaller vertical slices and concurrency |
| [CAMP-18](https://zamr26689.atlassian.net/browse/CAMP-18) | Mandatory calendar display has user value | Specify actual calendar view, local dates and status updates |
| [CAMP-19](https://zamr26689.atlassian.net/browse/CAMP-19) | Calendar-to-event detail flow is testable | Clarify inaccessible/deleted events and status refresh |

**INVEST summary:** User value is clear across the four epics. The main weaknesses are insufficiently differentiated acceptance criteria, cross-story dependencies (e.g. approval → publication → RSVP), and uncertain smallness for the 8-SP FIFO promotion rule. *Testable* and *Small* are **pending refinement**, not certified as passed.

## 4. SPIDR splitting examples — proposals only

SPIDR means **Spikes, Paths, Interfaces, Data, Rules**. The original brief emphasizes tested business logic and a working vertical slice. Never replace one usable customer outcome with a backend-only Story counted as Done.

- **CAMP-17 (8 SP):** Consider separate *vertical, demonstrable* paths: a first eligible student is automatically promoted after a confirmed cancellation; then handle concurrent cancellations/reservations and deterministic ties. The final split and point values are **not agreed**. Do not change Jira without team refinement.
- **CAMP-10 (5 SP):** If too large, separate minimal valid event draft creation from nontrivial edit/validation paths, each involving usable API + UI + tests where relevant. Preserve club ownership checks in every path.
- **CAMP-18 (5 SP):** Keep the core calendar view (not a generic events list) within the mandatory MVP; richer filters and convenience UI can be considered later.

No Story Points were recalculated based on these splitting ideas. All 56 SP still reflect **current Jira**, not a new estimate.

## 5. Planning Poker evidence — not yet verified

| Field | Verified record |
|---|---|
| Session held | **NOT VERIFIED** |
| Date and attendees | **NOT VERIFIED** |
| Individual initial votes | **NOT VERIFIED** |
| Re-votes and discussion | **NOT VERIFIED** |
| Final consensus | **NOT VERIFIED** |
| Provisional points visible in Jira | **VERIFIED** — table above |

The team should record votes *during an actual future session*, not reconstruct them to improve an earlier academic submission. A minimal honest template follows:

| Story | Current Jira SP | Actual attendee votes | Discussion/uncertainty | Agreed SP | Session date |
|---|---:|---|---|---|---|
| CAMP-7 | 3 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-8 | 5 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-9 | 3 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-10 | 5 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-11 | 3 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-12 | 5 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-13 | 3 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-14 | 5 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-15 | 5 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-16 | 3 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-17 | 8 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-18 | 5 | Not recorded | Pending real review | Not verified | Not verified |
| CAMP-19 | 3 | Not recorded | Pending real review | Not verified | Not verified |

## 6. Estimation and risk interpretation

1. **The 56-point number is not velocity.** Only completed, accepted stories in a completed Sprint can contribute to measured velocity.
2. **The official Week 10 Sprint 3 goal is the complete MVP.** Covering 56 provisional MVP SP by then is a significant capacity risk; authentication, role provisioning, Flutter and CI/BDD work add effort beyond this figure.
3. **The largest rules-based Story (CAMP-17, 8 SP)** carries concurrency risk; agree precise conditions and implement genuine TDD and BDD evidence later.
4. **Jira currently has one Future milestone, not a completed Scrum Sprint.** This file is not a Sprint Planning record or evidence of accepted points.
5. **Team onboarding is paused.** No member identity, voting outcome or task ownership is inferred.

## 7. Required follow-up (when the team is available)

- Run actual Planning Poker, with dated attendance and authentic voting evidence.
- Review the 13 MVP Stories against all six INVEST criteria and clarify the relevant business rule in each Story.
- Update point values and split oversized Stories **in Jira only after approval**; then recalculate the baseline and forecast.
- Compare proposed work against actual one-week capacity before Sprint commitment.
- Keep a read-only archived copy of the historical SCRUM-* estimate document; never label its 51 SP as current CAMP data.

**Submission note:** This is an independently prepared documentation revision, not a claim of a completed team estimation meeting, a GitHub merge, or a revised LMS submission. The *exact separate Week 4 lab handout* has not yet been directly inspected here; verify any additional required submission fields against it.
