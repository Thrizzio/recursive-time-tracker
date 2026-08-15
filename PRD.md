# Product Requirements Document (PRD)

**Project:** Chronolog  
**Version:** 1.0  
**Status:** Active Development

---

# 1. Overview

## Purpose

Chronolog is a retrospective time-tracking application that enables users to reconstruct how their time was spent instead of requiring continuous timer-based tracking.

Rather than asking users to start and stop timers throughout the day, Chronolog assumes time is continuously passing. Whenever a user chooses to log their work, they allocate the elapsed time across one or more activities, creating an accurate historical record with minimal interruption to their workflow.

---

# 2. Problem Statement

Traditional time-tracking applications depend on users remembering to start and stop timers.

This approach has several drawbacks:

- Users frequently forget to start or stop tracking.
- Context switching interrupts deep work.
- Manual corrections are common.
- Logged data becomes inaccurate over time.

Many users remember what they worked on but not exactly when they switched tasks. Existing timer-first workflows do not match this behavior.

Chronolog addresses this by allowing users to reconstruct time after the work has already been completed.

---

# 3. Goals

## Primary Goals

- Reduce friction in personal time tracking.
- Eliminate the need for live timer management.
- Produce an accurate historical timeline.
- Integrate existing productivity tools into the logging workflow.
- Keep daily logging fast and intuitive.

## Non Goals

Chronolog is **not** intended to be:

- A project management platform.
- A team collaboration tool.
- An employee surveillance application.
- An automated activity monitoring system.

---

# 4. Target Users

Chronolog is designed for individuals who want insight into how they spend their time.

Primary users include:

- Students
- Software developers
- Freelancers
- Researchers
- Knowledge workers

---

# 5. Core Product Concepts

## Activity

A reusable category representing work performed by the user.

Examples:

- Programming
- Studying
- Reading
- Gym
- Meetings

---

## Time Block

A continuous period between two logging events.

Each time block represents elapsed time that the user later categorizes.

---

## Activity Allocation

A percentage-based distribution of a time block across one or more activities.

Example:

```
Last 2 hours

Programming    70%
Reading        20%
Planning       10%
```

Percentages must total exactly 100%.

---

## Retrospective Logging

Instead of tracking work in real time, users periodically describe how the previous period was spent.

This is the defining workflow of Chronolog.

---

# 6. Functional Requirements

## FR-1 Authentication

Users shall be able to authenticate using their Google account.

Acceptance Criteria

- Google OAuth login.
- Persistent authenticated sessions.
- Secure logout.

---

## FR-2 Activity Management

Users shall be able to create reusable activities.

Acceptance Criteria

- Create activity.
- Assign color.
- View activity list.
- Activities persist across sessions.

---

## FR-3 Tracking Session

Users shall be able to begin a tracking session.

Acceptance Criteria

- Tracking start time is recorded.
- Only one active session exists.

---

## FR-4 Log Time

Users shall be able to retrospectively log the elapsed time.

Acceptance Criteria

- Multiple activities may be selected.
- Percentages must total 100%.
- Time block is created.
- Tracking automatically continues after logging.

---

## FR-5 Timeline

Users shall be able to view previously logged time blocks.

Acceptance Criteria

- Chronological ordering.
- Activity breakdown.
- Duration displayed.

---

## FR-6 Google Calendar Integration

Users shall be able to view today's Google Calendar events during logging.

Acceptance Criteria

- Fetch today's events.
- Display alongside logging workflow.
- Read-only integration.

---

## FR-7 Google Tasks Integration

Users shall be able to integrate Google Tasks into their workflow.

Acceptance Criteria

- Select Google Task List.
- View incomplete tasks.
- Mark tasks complete during logging.
- Synchronize completion with Google.

---

## FR-8 Settings

Users shall be able to configure application preferences.

Acceptance Criteria

- Select active Google Task List.
- Refresh task cache.
- Persist settings across sessions.

---

# 7. User Journey

## First-Time User

1. Sign in with Google.
2. Create initial activities.
3. Start tracking.

---

## Daily Workflow

1. Begin tracking.
2. Continue normal work.
3. Open log dialog periodically.
4. Allocate elapsed time.
5. Complete relevant Google Tasks.
6. Continue working.

---

# 8. Non-Functional Requirements

## Performance

- Dashboard should load within 2 seconds under normal conditions.
- Logging interactions should feel immediate.

## Reliability

- User data must persist across refreshes.
- Failed third-party API requests must not corrupt time logs.

## Security

- Authentication handled via Google OAuth.
- Sessions stored securely.
- Secrets managed using environment variables.

## Usability

- Minimal number of clicks to complete a log.
- Responsive interface for desktop and laptop usage.

---

# 9. Success Criteria

The product is considered successful if users can:

- Track an entire day without manually starting and stopping timers.
- Maintain an accurate historical timeline.
- Integrate Google Tasks naturally into the logging workflow.
- Complete a logging session in under one minute.

---

# 10. Future Scope

Potential future enhancements include:

- Analytics dashboard
- Weekly and monthly reporting
- Notification reminders
- Export functionality
- Team workspaces
- AI-generated activity suggestions
- Calendar write-back
- Mobile application

---

# 11. Assumptions & Constraints

## Assumptions

- Users possess a Google account.
- Internet connectivity is available during synchronization.
- Users log work periodically rather than continuously.

## Constraints

- Google API rate limits
- Browser-based application.
- Google OAuth required for integrations.

---

# 12. Summary

Chronolog rethinks traditional time tracking by replacing continuous timer management with retrospective allocation. The product focuses on minimizing interruption while maintaining an accurate record of how users spend their time, integrating naturally with existing Google productivity tools to create a lightweight personal productivity system.