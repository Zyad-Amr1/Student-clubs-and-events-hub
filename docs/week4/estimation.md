# CampusConnect — Estimation and INVEST Review

**Course:** SET 312 — Agile Software Engineering  
**Project:** CampusConnect — Student Clubs & Events Hub  
**Folder:** `docs/week4/estimation.md`  
**Status:** Draft — estimates discussed but not finalized

---

## 1. Purpose and estimation status

This document records the current Jira Story Point values, a preliminary INVEST review, and the team's planned Planning Poker process.

The team has discussed the estimates, but has **not finalized them through Planning Poker**. Accordingly:
- The values below are the estimates currently visible in Jira.
- They are provisional discussion values, not confirmed team estimates.
- No individual votes, consensus, or completed Planning Poker session are claimed.
- The team must confirm or revise the values after a real estimation session.

## 2. Relative estimation scale

The current backlog uses these Story Point values:

| Points | Relative size |
|---:|---|
| 1 | Very small |
| 2 | Small |
| 3 | Medium |
| 5 | Large |
| 8 | Very large |

Story Points represent relative effort, complexity, and uncertainty. They are not hours or days.

## 3. Current Jira estimates — provisional

| Jira ID | User story | Current Jira estimate | Status |
|---|---|---:|---|
| SCRUM-9 | Browse University Clubs | 3 | Provisional |
| SCRUM-10 | View Club Details | 2 | Provisional |
| SCRUM-11 | View Upcoming Club Events | 3 | Provisional |
| SCRUM-12 | Search and Filter University Clubs | 3 | Provisional |
| SCRUM-13 | Create University Event | 5 | Provisional |
| SCRUM-14 | Submit Event for Approval | 3 | Provisional |
| SCRUM-15 | Approve or Reject University Event | 5 | Provisional |
| SCRUM-16 | View Pending Events for Approval | 3 | Provisional |
| SCRUM-18 | RSVP to University Event | 5 | Provisional |
| SCRUM-19 | Join Event Waiting List | 5 | Provisional |
| SCRUM-20 | Cancel Event Registration | 3 | Provisional |
| SCRUM-21 | Automatically Promote Students from Waiting List | 8 | Provisional |
| SCRUM-22 | View My Registered Events | 3 | Provisional |
| | **Total** | **51 SP** | **Not finalized** |

The 51 SP total is only the sum of the current Jira values. It is not measured velocity and must not be presented as a finalized team estimate.

## 4. Preliminary INVEST review

INVEST helps the team assess whether each story is suitable for implementation.

| Criterion | Review question |
|---|---|
| Independent | Can the story be implemented with minimal dependency on other stories? |
| Negotiable | Does it describe an outcome without prescribing every implementation detail? |
| Valuable | Does it provide value to a student or university stakeholder? |
| Estimable | Is there enough information for developers to estimate it? |
| Small | Can it reasonably fit within a Sprint? |
| Testable | Can its acceptance criteria be verified? |

### Review of the six stories in `stories.md`

| Story | Preliminary assessment | Refinement needed |
|---|---|---|
| SCRUM-9 — Browse University Clubs | Clear user value and testable basic outcome | Confirm which club fields appear in the list. |
| SCRUM-10 — View Club Details | Valuable and testable | Agree on the minimum club details. |
| SCRUM-13 — Create University Event | Valuable; may be relatively large | Define required event fields and validation. |
| SCRUM-14 — Submit Event for Approval | Clear workflow value | Confirm permitted status transitions and role permissions. |
| SCRUM-15 — Approve or Reject University Event | Valuable and testable | Define rejection handling and authorization. |
| SCRUM-18 — RSVP to University Event | Valuable and testable | Confirm capacity handling and full-event behavior. |

This is a preliminary team discussion aid, not a claim that every story has passed all INVEST criteria.

## 5. Planning Poker record

**Session status:** Not completed  
**Current situation:** Estimates have been discussed but not finalized.

**Expected participants:** Product Owner, Scrum Master, Developer 1, Developer 2  
**Method:** Planning Poker  
**Session date:** To be recorded after the actual session  
**Final consensus:** Pending

### Planned procedure

1. The Product Owner presents one story and explains its value and acceptance criteria.
2. The team asks questions and clarifies assumptions.
3. Each participant independently selects a Story Point value.
4. Everyone reveals their estimate at the same time.
5. If estimates differ, the highest and lowest estimators explain their reasoning.
6. The team discusses the differences and votes again.
7. The agreed estimate is recorded in Jira. If agreement is not reached, record the open question and revisit the story.

### Voting record — complete during the actual session

Do not fill this table with guessed or reconstructed votes.

| Jira ID | PO | Scrum Master | Developer 1 | Developer 2 | Final agreed points |
|---|---:|---:|---:|---:|---:|
| SCRUM-9 | — | — | — | — | Pending |
| SCRUM-10 | — | — | — | — | Pending |
| SCRUM-11 | — | — | — | — | Pending |
| SCRUM-12 | — | — | — | — | Pending |
| SCRUM-13 | — | — | — | — | Pending |
| SCRUM-14 | — | — | — | — | Pending |
| SCRUM-15 | — | — | — | — | Pending |
| SCRUM-16 | — | — | — | — | Pending |
| SCRUM-18 | — | — | — | — | Pending |
| SCRUM-19 | — | — | — | — | Pending |
| SCRUM-20 | — | — | — | — | Pending |
| SCRUM-21 | — | — | — | — | Pending |
| SCRUM-22 | — | — | — | — | Pending |

## 6. Actions after estimation

- Refine unclear acceptance criteria with the developers.
- Conduct Planning Poker with all four team members.
- Record actual votes and the agreed result.
- Update Jira estimates where the team changes them.
- Recalculate the backlog total after estimates are finalized.
- Use completed Sprint results, not backlog estimates, to establish actual velocity.

## 7. Conclusion

The current Jira backlog contains 13 stories totaling 51 provisional Story Points. The team has discussed these values but has not finalized them through Planning Poker. This document intentionally records that status honestly and should be updated after the real estimation session.

**Additional backlog requirement:** The overall course project brief requires at least 15 original user stories. The current 13 stories meet the Week 4 screenshot threshold of at least 12, but the team must add at least two more stories to meet the overall project brief.
