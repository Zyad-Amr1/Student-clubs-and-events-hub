# CampusConnect — Week 4: MVP Forecast and Sprint Plan

**Course:** SET312 — Agile Software Engineering, Group 1  
**Project:** CampusConnect — Student Clubs & Events Hub  
**Jira:** [CAMP project](https://zamr26689.atlassian.net/jira/software/projects/CAMP/boards/2)  
**Reviewed against Jira:** 23 November 2026  
**Status:** **REVISED PLANNING DRAFT — NOT A SPRINT COMMITMENT, NOT APPROVED OR RESUBMITTED**

## 1. Purpose and evidence classification

This document gives an **illustrative, dependency-aware forecast** for the mandatory university MVP. It reconciles the historic [`SCRUM-*` Week 4 forecast](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/blob/docs/week4-submission/docs/week4/forecast.md) against the **current `CAMP-*` backlog** without overwriting the historical submission.

The **official SET312 Group 1 project brief** requires Sprint 0 (setup), four **one-week** development Sprints, the complete MVP and real-user feedback in **Sprint 3 / Week 10**, improvements and release in **Sprint 4 / Week 11**, and a live demonstration in **Week 12**. The dates of the actual lab/Sprint calendar have **not** been verified, so no dates are invented here.

**Important distinctions:**

- **Jira provisional points** are neither measured velocity nor team-agreed Planning Poker results.
- **A proposed Sprint allocation** is not evidence that the Sprint took place, that the stories were accepted, or that Jira has been updated.
- **A merged backend subtask** is not a completed end-to-end parent Story without its applicable UI, tests, and Product Owner acceptance.
- The revised Week 4 LMS submission is **not confirmed**; the older incomplete Week 4 submission was reported as submitted.

## 2. Current backlog and MVP release line

Live Jira has **49 User Stories with 231 provisional Story Points**. This meets the university-wide requirement for at least 15 stories **by count**, but is far larger than the mandatory MVP.

The four mandatory MVP epics contain **13 Stories and 56 provisional Story Points**. The remaining **36 Stories and 175 provisional points** are supporting and additional scope, including authentication and club management; they are **not automatically promised for the MVP**.

| Epic / release line | CAMP stories | Stories | Provisional points |
|---|---|---:|---:|
| [CAMP-1 — Club Pages & Discovery](https://zamr26689.atlassian.net/browse/CAMP-1) | CAMP-7–9 | 3 | 11 |
| [CAMP-2 — Event Creation & Student Affairs Approval](https://zamr26689.atlassian.net/browse/CAMP-2) | CAMP-10–13 | 4 | 16 |
| [CAMP-3 — RSVP & FIFO Waiting List](https://zamr26689.atlassian.net/browse/CAMP-3) | CAMP-14–17 | 4 | 21 |
| [CAMP-4 — My Events Calendar](https://zamr26689.atlassian.net/browse/CAMP-4) | CAMP-18–19 | 2 | 8 |
| **MVP RELEASE LINE** | **CAMP-7–19** | **13** | **56** |
| Supporting / additional scope **outside the 56 SP** | Remaining CAMP Stories | 36 | 175 |
| **All current Jira Stories (not a Sprint commitment)** | All story issues | **49** | **231** |

**Required key business rule:** When a published event is full, new RSVPs join a FIFO waiting list; a confirmed reservation cancellation must automatically promote the first eligible waiting student without overbooking. The related mandatory Stories are [CAMP-14](https://zamr26689.atlassian.net/browse/CAMP-14) to [CAMP-17](https://zamr26689.atlassian.net/browse/CAMP-17).

**Dependencies outside the 56-point sum:** Authentication, Student Affairs role access, club admin permissions, integration, deployment, TDD/BDD, and Flutter may take extra capacity. For example, the current Jira estimates for parent authentication Stories CAMP-46 (5), CAMP-47 (5), and CAMP-52 (3) total **13 additional provisional points**, though their backend portions have been merged as subtasks. Do not sum these with the 56 SP as if all were new, unfinished implementation hours, and do not count backend subtasks as accepted Story Points.

## 3. Proposed sequence (scenario only; NOT current Jira Sprint commitments)

The official timeline requires the MVP to be completed in **Sprint 3**, not deferred to Sprint 4. The following outline distributes the **56 provisional MVP points across Sprints 1–3**; it assumes significant parallel team capacity, working Flutter integration, and suitable prerequisite authentication. **No team commitment, actual Sprint start, or dates are claimed.**

| Academic phase | Proposed Sprint goal and demonstrable increment | Proposed mandatory stories | Provisional MVP SP |
|---|---|---|---:|
| **Sprint 0 — Week 7 (setup)** | Agree vision/DoD, choose backlog, initialize GitHub and Jira, estimate with team | No accepted MVP work claimed | — |
| **Sprint 1 — Week 8 (walking skeleton)** | Students can discover clubs; club admin can create and submit an unpublished event draft through an integrated vertical flow | CAMP-7 (3), CAMP-8 (5), CAMP-9 (3), CAMP-10 (5), CAMP-11 (3) | **19** |
| **Sprint 2 — Week 9 (deliver)** | Student Affairs approves/publishes events; students can RSVP or join FIFO queue; target runnable deployment/Docker and five passing BDD scenarios | CAMP-12 (5), CAMP-13 (3), CAMP-14 (5), CAMP-15 (5) | **18** |
| **Sprint 3 — Week 10 (MVP & feedback)** | Cancellations automatically promote the first waiting student; registered events appear in a real calendar; demonstrate **all four MVP epics** and collect real feedback from at least three users | CAMP-16 (3), CAMP-17 (8), CAMP-18 (5), CAMP-19 (3) | **19** |
| **Sprint 4 — Week 11 (improve)** | Apply actual user feedback and critical fixes, perform final retrospective, and create the genuine `v1.0` tag; stretch features only if capacity allows | **To be selected after feedback** | **Not estimated** |
| **Total proposed MVP work in Sprints 1–3** | **A planning scenario only** | **13 mandatory Stories** | **56** |

This draft is **not equivalent to the current live Jira sprint configuration**: the last verified board had one Future milestone (`Milestone 1 - Authentication Foundation`), no active/closed sprint, and no agreed one-week dates. This table must not be copied into Jira without separate approval and team capacity review.

### Walking skeleton and sequencing qualification

The original brief asks for **one first end-to-end slice/story per team member** in Sprint 1. The table proposes five MVP Stories but **does not prove** that each of 4–5 team members has their own completed slice or merged code/tests. Authenticated mobile navigation, event creation permissions, and Flutter screens may make this plan too aggressive. Reorder and split Stories into *vertical, usable slices* with the team rather than counting isolated backend endpoints as accepted user outcomes.

### Sprint 3 gate and feedback

By the **end of Sprint 3**, the four epics and FIFO rule must be demonstrated as a working app and feedback from **at least three real users** recorded; subsequent backlog changes must be traceable to that evidence. Neither the feedback nor any Sprint completion is currently verified. Sprint 4 is for feedback-driven improvements and release, **not for first-time completion of mandatory RSVP/calendars**.

## 4. Baseline throughput, capacity assumptions, and forecast risk

With **56 provisional MVP points across three development Sprints before Sprint 3 ends**, the **required average MVP throughput is approximately 18.7 accepted points per Sprint**, **excluding** required authentication and other supporting effort. This is a *mathematical requirement of the proposal*, **not a measured or agreed velocity**.

| Hypothetical accepted MVP throughput | Three-Sprint capacity | Difference from 56-SP MVP | Interpretation |
|---:|---:|---:|---|
| 12 SP/Sprint | 36 SP | 20 SP short | MVP would likely miss the Sprint 3 target if estimates remained stable |
| 19 SP/Sprint | 57 SP | 1 SP buffer | Extremely tight even before accounting for auth, Flutter, integration and defects |
| 22 SP/Sprint | 66 SP | 10 SP buffer | More tolerance, but still entirely unproven without real team delivery |

**Baseline choice:** No honest team velocity baseline can be established yet. For initial **what-if planning only**, the table's 19 SP/Sprint scenario exposes the minimum rough pace, rather than asserting that the team can deliver it. There are no accepted Sprint outcomes from which to compute actual velocity.

**Capacity warning:** The authentication milestone and Flutter development are not included in the 56 MVP points, so even a 19 SP/Sprint MVP pace could be unrealistic. The team must measure capacity, split high-risk Stories such as CAMP-17 using SPIDR into *vertical slices*, and revise the forecast following genuine Sprint Reviews. **Never lower the DoD or falsely mark stories Done to fit the table.**

## 5. Known risks and proposed mitigations

| Risk | Why it matters | Proposed response (not yet claimed complete) |
|---|---|---|
| Flutter screens / integration not verified | Backend code alone cannot deliver the end-to-end MVP | Align backend/mobile contracts; add real Android and E2E evidence |
| Authentication and club-admin permissions have prerequisites | Sprint 1 draft creation depends on correct role and scope enforcement | Identify prerequisite work without counting backend subtask merges as full Story acceptance |
| FIFO promotion under concurrent requests | Seat capacity and fairness are a mandatory rule | Write true TDD/BDD scenarios; test duplicates, cancellation, ordering, and atomicity |
| 56 SP before end of Sprint 3 | The required throughput is high and unmeasured | Confirm authentic availability, perform Planning Poker, refine/split oversized Stories |
| Only one Future Jira sprint verified | A document is not proof of five timeboxed Sprints | When team/schedule available, coordinate lawful future Sprint setup and record actual events |
| User feedback not yet gathered | Separate 2-mark rubric category | Run real user sessions after an operational MVP; record issues and genuine backlog changes |
| Old Week 4 references 13 `SCRUM-*` / 51 SP | Contradicts live 13 `CAMP-*` / 56 SP MVP baseline | Preserve historical draft; use new cross-references only in revised work |
| CI missing separate linter and BDD evidence | 4-mark engineering-quality component | Add actual lint/BDD gates with development team; keep missing items visibly open |

## 6. Tracking actual Sprint progress (do not prefill)

Only Stories meeting the team's agreed Definition of Done **and actually accepted** count toward measured Sprint velocity. No hypothetical figures above should appear as earned points in Jira.

| Sprint | Proposed MVP SP (scenario) | Actual accepted MVP SP | Actual review / velocity evidence |
|---|---:|---|---|
| Sprint 1 | 19 | **NOT VERIFIED** | No closed Sprint / acceptance record verified |
| Sprint 2 | 18 | **NOT VERIFIED** | No closed Sprint / acceptance record verified |
| Sprint 3 | 19 | **NOT VERIFIED** | No closed Sprint / acceptance record verified |
| Sprint 4 | To be determined | **NOT VERIFIED** | No closed Sprint / acceptance record verified |

After each genuine one-week Sprint, reconcile actual Jira statuses and evidence, calculate accepted story points, and reforecast the remaining MVP. The Product Owner's approval/rejection and the Sprint Review record need to be real and traceable.

## 7. Reflection (Week 4)

The current backlog provides a full 13-story mandatory MVP map totaling 56 **provisional** Story Points, but the estimates do not yet reflect a recorded team consensus or reliable observed delivery speed. The proposed first-three-Sprint plan has little room for authentication, Flutter integration, test infrastructure or defects, making it a **high-risk scenario**, not a promise. The team's safest response is to preserve the MVP release line, validate vertical slices and genuine capacity early, and reforecast as soon as there is real Sprint evidence. Future scope such as club management and interview scheduling should not displace the four mandatory epics.

## Sources / restrictions

- **Academic specification:** *Agile SW_Project_Brief_Group1 (1)(1).pdf*, pp. 1–2, 4, 7.
- **Current Jira:** [CAMP board](https://zamr26689.atlassian.net/jira/software/projects/CAMP/boards/2), read-only audit, 23 Nov 2026; 49 Stories, 231 provisional points in total; 13 mandatory Stories, 56 points.
- **Historical baseline:** [Original forecast on archived Week 4 branch](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/blob/docs/week4-submission/docs/week4/forecast.md), 13 SCRUM Stories and 51 provisional points.
- **Backend evidence:** [PR #8](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/pull/8) and [PR #9](https://github.com/Zyad-Amr1/Student-clubs-and-events-hub/pull/9) (backend portions only, not accepted parent Stories).
- **Academic evidence limit:** The actual Week 4 lab instructions are not directly in this project audit; this draft follows the user-confirmed five-file submission checklist. Nothing here is evidence of team Planning Poker, active Sprints, accepted stories, feedback sessions, or LMS resubmission.
