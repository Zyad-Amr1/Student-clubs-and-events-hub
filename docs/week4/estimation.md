# CampusConnect — Estimation and INVEST Review

**Course:** SET 312 — Agile Software Engineering  
**Project:** CampusConnect — Student Clubs & Events Hub  
**Folder:** `docs/week4/estimation.md`  
**Estimation method:** Planning Poker  
**Estimation status:** Team voting completed; final values listed below are taken from the current Jira backlog.

---

## 1. Purpose and estimation status

This document records the team's Story Point estimates, the relative estimation scale, a preliminary INVEST review, and the Planning Poker process.

The team has confirmed that it completed its Planning Poker session. The table below records the values currently shown in Jira as the agreed estimates.

The team did not retain individual member vote values or a round-by-round voting log. Therefore, this document records the final estimates without inventing individual votes, vote distributions, or the number of rounds.

## 2. Relative estimation scale

The team uses Story Points to compare the relative effort, complexity, and uncertainty of stories. They are not hours or days.

| Points | Relative size |
|---:|---|
| 1 | Very small |
| 2 | Small |
| 3 | Medium |
| 5 | Large |
| 8 | Very large |

## 3. Final story point estimates

| Jira ID | User story | Final agreed estimate |
|---|---|---:|
| SCRUM-9 | Browse University Clubs | 3 |
| SCRUM-10 | View Club Details | 2 |
| SCRUM-11 | View Upcoming Club Events | 3 |
| SCRUM-12 | Search and Filter University Clubs | 3 |
| SCRUM-13 | Create University Event | 5 |
| SCRUM-14 | Submit Event for Approval | 3 |
| SCRUM-15 | Approve or Reject University Event | 5 |
| SCRUM-16 | View Pending Events for Approval | 3 |
| SCRUM-18 | RSVP to University Event | 5 |
| SCRUM-19 | Join Event Waiting List | 5 |
| SCRUM-20 | Cancel Event Registration | 3 |
| SCRUM-21 | Automatically Promote Students from Waiting List | 8 |
| SCRUM-22 | View My Registered Events | 3 |
| | **Total** | **51 SP** |

**Backlog estimate:** 51 Story Points across 13 Jira stories.

This total represents the estimated size of the current backlog. It is not the team's velocity. Actual velocity can only be measured after completed Sprints.

## 4. Preliminary INVEST review

INVEST helps the team assess whether a user story is suitable for implementation.

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

This is a preliminary review to guide refinement. It does not claim that every story is perfectly independent or fully refined.

## 5. Planning Poker record

**Session status:** Completed  
**Participants:** Product Owner, Scrum Master, Developer 1, Developer 2  
**Method:** Planning Poker  
**Outcome:** The team completed estimation and recorded the final Story Point values shown in Section 3.

The team did not retain individual vote values or a round-by-round record. The document therefore records the agreed estimates only and does not reconstruct missing voting details.

### Process followed

1. The Product Owner presented each story and explained its value and acceptance criteria.
2. Team members discussed questions and clarified assumptions.
3. Members selected estimates using the team's Story Point scale.
4. Estimates were compared and discussed.
5. The team reached an agreed estimate for each story.
6. The resulting estimates were recorded in Jira.

## 6. Follow-up actions

- Keep Jira Story Point estimates consistent with the final values in this document.
- Refine unclear acceptance criteria before implementation.
- Revisit an estimate if the story's scope changes materially.
- Track completed Story Points at the end of each Sprint.
- Use completed Sprint results to establish actual team velocity; do not treat the 51-point backlog total as velocity.

## 7. Conclusion

The team completed Planning Poker for the current 13-story Jira backlog. The estimates recorded in this document total **51 Story Points**. These points represent relative backlog size, while actual team velocity will become measurable after the team completes Sprints.

**Additional backlog requirement:** The overall course project brief requires at least 15 original user stories. The current 13 stories meet the Week 4 screenshot threshold of at least 12, but the team still needs to add at least two more original stories to satisfy the overall project brief.
