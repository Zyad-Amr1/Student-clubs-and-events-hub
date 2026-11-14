# CampusConnect — Sprint Forecast

**Course:** SET 312 — Agile Software Engineering  
**Project:** CampusConnect — Student Clubs & Events Hub  
**Folder:** `docs/week4/forecast.md`  
**Sprint duration:** 1 week  
**Development Sprints:** 4  
**Team:** Product Owner, Scrum Master, 2 Developers  
**Status:** Initial forecast based on completed team estimation; Sprint allocations remain subject to capacity review.

---

## 1. Purpose and assumptions

This document records the team's proposed sequence for delivering the current CampusConnect backlog over four one-week development Sprints.

The team has completed its Planning Poker session. The current Jira backlog contains **13 stories totaling 51 agreed Story Points**, matching the estimates recorded in `estimation.md`. These estimates represent the team's relative assessment of story size; they are not hours, days, or measured velocity.

The four-Sprint allocation below is a forecast for planning and discussion, not a guarantee that all 51 points will be completed. No completed Sprint velocity has been provided yet, so the team must review actual capacity during each Sprint Planning session and reforecast based on completed work.

Assumptions:
- The two Developers are the primary implementation capacity.
- The Product Owner owns backlog ordering, clarifies requirements, and accepts or rejects completed stories.
- The Scrum Master facilitates Scrum events, helps remove blockers, and keeps Jira current.
- All team members contribute to design, code, tests, and integration, in line with the course brief.
- The team reviews availability, dependencies, and the Definition of Done before selecting work for each Sprint.
- Stories count as completed only when they meet the team's Definition of Done and are accepted by the Product Owner.

## 2. Current backlog baseline

The following totals are based on the current Jira backlog and the completed team estimation recorded in `estimation.md`.

| Epic | Stories currently linked | Agreed points |
|---|---:|---:|
| Club Discovery | 4 | 11 |
| Event Management & Approval | 4 | 16 |
| Event Registration & Waiting List | 4 | 21 |
| My Events Calendar | 1 | 3 |
| **Total** | **13** | **51 SP** |

The My Events Calendar epic currently contains SCRUM-22, **View My Registered Events**. Its current title and description do not by themselves prove that a calendar interface is delivered. The team must refine this story or add a dedicated calendar-view story to satisfy the project brief's MVP requirement for a per-student My Events calendar.

## 3. Proposed four-Sprint allocation

The team completed estimation, and the allocations below use the agreed Jira values. This sequence follows the feature dependencies in the current backlog. It remains a forecast rather than a Sprint commitment; the team should confirm capacity and dependencies during each Sprint Planning session.

| Sprint | Proposed goal | Stories | Agreed points |
|---|---|---|---:|
| Sprint 1 | Deliver the club discovery experience | SCRUM-9, SCRUM-10, SCRUM-11, SCRUM-12 | 11 |
| Sprint 2 | Allow club administrators to create and submit events | SCRUM-13, SCRUM-14 | 8 |
| Sprint 3 | Enable Student Affairs review and student RSVP | SCRUM-16, SCRUM-15, SCRUM-18 | 13 |
| Sprint 4 | Complete cancellation, waiting-list, promotion, and My Events behavior | SCRUM-19, SCRUM-20, SCRUM-21, SCRUM-22 | 19 |
| | **Total** | **13 stories** | **51 SP** |

### Sprint 1 — Club Discovery (11 SP)

**Sprint Goal:** Students can discover university clubs and understand their activities.

Planned stories:
- SCRUM-9 — Browse University Clubs (3)
- SCRUM-10 — View Club Details (2)
- SCRUM-11 — View Upcoming Club Events (3)
- SCRUM-12 — Search and Filter University Clubs (3)

**Expected increment:** Students can browse clubs, open club details, see upcoming events, and search or filter the club list.

### Sprint 2 — Event Creation and Submission (8 SP)

**Sprint Goal:** Authorized club administrators can prepare events and submit them for review.

Planned stories:
- SCRUM-13 — Create University Event (5)
- SCRUM-14 — Submit Event for Approval (3)

**Expected increment:** Club administrators can create events and submit them into the approval workflow. Submitted events must not be treated as approved or published before Student Affairs approval.

### Sprint 3 — Event Review and RSVP (13 SP)

**Sprint Goal:** Student Affairs can review submitted events, and students can RSVP to approved events.

Planned stories:
- SCRUM-16 — View Pending Events for Approval (3)
- SCRUM-15 — Approve or Reject University Event (5)
- SCRUM-18 — RSVP to University Event (5)

**Expected increment:** Authorized Student Affairs officers can review pending events and approve or reject them. Students can register for approved events when seats are available.

### Sprint 4 — Waiting List and My Events (19 SP)

**Sprint Goal:** Students can manage registrations, and the system handles full events and cancellations correctly.

Planned stories:
- SCRUM-19 — Join Event Waiting List (5)
- SCRUM-20 — Cancel Event Registration (3)
- SCRUM-21 — Automatically Promote Students from Waiting List (8)
- SCRUM-22 — View My Registered Events (3)

**Expected increment:** Students can join a waiting list, cancel registrations, and view their registered events. When a registered student cancels, the first student on the waiting list is promoted, as required by the project brief.

**Capacity warning:** Sprint 4 has the largest proposed workload at 19 SP. The team has agreed estimates, but it has not yet established actual velocity from completed Sprints. With two Developers, the team must not assume that 19 SP is achievable in one week. Review availability and dependencies during Sprint Planning; move lower-priority work or reduce Sprint scope if needed. Do not mark incomplete work as Done to preserve the forecast.

## 4. Capacity and velocity tracking

Actual team velocity is **not yet known** because no completed Sprint results have been provided. The 51-point backlog total and the proposed Sprint allocations are not velocity.

For each completed Sprint:

**Sprint velocity = Story Points of stories completed and accepted during that Sprint.**

Only stories that meet the Definition of Done and are accepted by the Product Owner count. Partially completed stories do not count as completed points.

| Sprint | Forecast points | Completed and accepted points | Notes |
|---|---:|---:|---|
| Sprint 1 | 11 | To be measured | Establish the first baseline. |
| Sprint 2 | 8 | To be measured | Reforecast using Sprint 1 results. |
| Sprint 3 | 13 | To be measured | Reforecast using observed delivery. |
| Sprint 4 | 19 | To be measured | Adjust scope to actual capacity. |

After at least two completed Sprints, use the team's observed average velocity as a better guide for future planning. Continue reviewing capacity and scope each week.

## 5. Risks and responses

| Risk | Possible impact | Response |
|---|---|---|
| The agreed estimates may change if story scope changes | Sprint allocations may become unrealistic | Re-estimate affected stories with the team and update this forecast and Jira. |
| Two Developers have limited weekly availability | Planned work may exceed capacity | Confirm availability and select a realistic amount of work. |
| Event approval rules are unclear | Events may be published without authorization | Define roles, permissions, and status transitions before implementation. |
| Registration and waiting-list logic is complex | Duplicate registrations or incorrect seat allocation | Define edge cases and add automated tests for capacity, cancellation, and promotion. |
| Sprint 4 is heavily loaded | Stories may not meet the Definition of Done | Move lower-priority work or reduce scope rather than claiming incomplete work is Done. |
| My Events Calendar requirement is not explicit in SCRUM-22 | The MVP may miss a mandatory requirement | Refine SCRUM-22 or add a dedicated calendar story and estimate it with the team. |
| Backlog currently has only 13 stories | It is below the course brief's 15-story minimum | Add at least two original, valuable stories and estimate them with the team. |

## 6. Reforecasting rules

At the end of each Sprint, the team should:

1. Review which stories were completed and accepted.
2. Record actual velocity using accepted stories only.
3. Discuss differences between forecast and completed work.
4. Reorder the Product Backlog with the Product Owner.
5. Adjust the next Sprint forecast to match observed capacity.
6. Carry unfinished work back to the Product Backlog and re-plan it; do not automatically count it as completed.
7. Update this document if the agreed estimates, backlog scope, or Sprint allocation changes.

## 7. Relationship to the course timeline

The course project brief describes **Sprint 0 plus four one-week development Sprints**. This document covers the four development Sprints only. Sprint 0 setup activities should be tracked separately, including project vision, repository and Jira setup, initial backlog, and the team's Definition of Done.

The course brief also expects a working MVP demonstration, tested implementation, and evidence of the team's Agile process. Completing this forecast document alone does not demonstrate those later deliverables.

## 8. Conclusion

The team has completed Planning Poker for the current Jira backlog of 13 stories, with **51 agreed Story Points**. A four-Sprint, one-week forecast has been proposed using those values. Since no completed Sprint velocity is available yet, the allocations must be reviewed against actual team capacity and adjusted as the team learns from each Sprint.

Two project-level gaps remain visible: the backlog needs at least two additional original stories to reach the course brief's minimum of 15, and the My Events Calendar MVP requirement needs to be made explicit in the relevant story. Resolve these gaps with the team and update the forecast if the backlog or estimates change.
