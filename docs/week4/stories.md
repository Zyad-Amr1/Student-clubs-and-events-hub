# CampusConnect — User Stories and Acceptance Criteria

**Course:** SET 312 — Agile Software Engineering  
**Project:** CampusConnect — Student Clubs & Events Hub  
**Folder:** `docs/week4/stories.md`  
**Status:** Draft for team review

This document records six representative, prioritized user stories from the current Jira backlog. Each story includes a happy path and an error/alternative path in Given–When–Then format.

> The Jira backlog currently contains 13 stories. The course project brief asks each team to build a backlog of at least 15 original stories. The current 13-story backlog satisfies the Week 4 screenshot instruction of at least 12 stories, but two additional stories are still needed to meet the overall project brief.

---

## 1. SCRUM-9 — Browse University Clubs

**Epic:** Club Discovery  
**Current Jira estimate:** 3 Story Points

**User story**

As a student, I want to browse available university clubs so that I can discover clubs that match my interests.

**Happy path**
- **Given** I am on the Clubs page
- **When** the page loads and clubs are available
- **Then** I see a list of available clubs with their names and descriptions.

**Alternative/error path**
- **Given** I am on the Clubs page
- **When** no clubs are available
- **Then** I see a clear empty-state message rather than a blank or broken page.

## 2. SCRUM-10 — View Club Details

**Epic:** Club Discovery  
**Current Jira estimate:** 2 Story Points

**User story**

As a student, I want to view a club's details so that I can understand its activities and decide whether it interests me.

**Happy path**
- **Given** I am viewing the clubs list
- **When** I select a club
- **Then** I see the club's name, description, and available club information.

**Alternative/error path**
- **Given** I try to open a club's details
- **When** the club cannot be found or its details cannot be loaded
- **Then** I see an understandable error message and can return to the clubs list.

## 3. SCRUM-13 — Create University Event

**Epic:** Event Management & Approval  
**Current Jira estimate:** 5 Story Points

**User story**

As a club administrator, I want to create a university event so that I can organize activities for students.

**Happy path**
- **Given** I am logged in as an authorized club administrator
- **When** I submit an event form with all required valid information
- **Then** the event is saved with a status indicating that it still requires approval.

**Alternative/error path**
- **Given** I am creating an event
- **When** I submit the form with missing or invalid required information
- **Then** the system identifies the invalid fields and does not save the event as ready for approval.

## 4. SCRUM-14 — Submit Event for Approval

**Epic:** Event Management & Approval  
**Current Jira estimate:** 3 Story Points

**User story**

As a club administrator, I want to submit a created event for approval so that Student Affairs can review it before publication.

**Happy path**
- **Given** I am an authorized club administrator and have completed an event
- **When** I submit the event for approval
- **Then** its status becomes Pending Approval and it appears in the Student Affairs review queue.

**Alternative/error path**
- **Given** I have created an event with missing required information
- **When** I attempt to submit it
- **Then** the system prevents submission and explains what must be completed.

## 5. SCRUM-15 — Approve or Reject University Event

**Epic:** Event Management & Approval  
**Current Jira estimate:** 5 Story Points

**User story**

As a Student Affairs officer, I want to approve or reject submitted events so that only reviewed events are published.

**Happy path**
- **Given** I am an authorized Student Affairs officer viewing a pending event
- **When** I approve the event
- **Then** its status changes to Approved and it becomes eligible for publication.

**Alternative/error path**
- **Given** I am not authorized to review events
- **When** I attempt to approve or reject an event
- **Then** the system denies the action and leaves the event status unchanged.

## 6. SCRUM-18 — RSVP to University Event

**Epic:** Event Registration & Waiting List  
**Current Jira estimate:** 5 Story Points

**User story**

As a student, I want to register for an approved university event so that I can reserve a seat and participate.

**Happy path**
- **Given** I am logged in as a student and an approved event has available seats
- **When** I select RSVP
- **Then** my registration is confirmed and one seat is reserved for me.

**Alternative/error path**
- **Given** I have already registered for an event
- **When** I try to register for the same event again
- **Then** the system prevents a duplicate registration and keeps my existing registration unchanged.

---

## Refinement notes

Before implementation, the team should clarify:
1. The minimum information displayed on a club card and club details page.
2. Required event fields and validation rules.
3. Event status transitions and permissions for each role.
4. How event capacity is enforced and how a full event sends a student to the waiting list.
5. The exact behavior expected from the My Events Calendar MVP epic.

The course project brief defines a key business rule: when an event is full, new RSVPs join the waiting list; when a registration is cancelled, the first person on the waiting list is promoted. This rule should be covered by acceptance criteria and automated tests.

## Scope gap to resolve

The current Jira epic is named **My Events Calendar**, but SCRUM-22 is titled **View My Registered Events**. The current story does not explicitly specify a calendar view. The team should either refine SCRUM-22 so its acceptance criteria clearly deliver the required per-student calendar, or create a separate calendar story. Do not claim the calendar requirement is complete until this is resolved.
