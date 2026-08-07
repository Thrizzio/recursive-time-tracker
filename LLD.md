# Low Level Design (LLD)

**Project:** Chronolog  
**Version:** 1.0  
**Status:** Active Development

---

# 1. Purpose

This document describes the implementation details of Chronolog. It documents the internal structure of the application, request lifecycle, authentication mechanism, API endpoints, database schema, frontend organization, and interactions with external services.

Unlike the High Level Design, this document focuses on implementation rather than architecture.

---

# 2. Technology Stack

## Frontend

- React
- TypeScript
- React Router
- Fetch API

## Backend

- Express
- TypeScript

## Database

- PostgreSQL
- Drizzle ORM

## Deployment

- Vercel
- Render
- Neon PostgreSQL

---

# 3. Folder Structure

## Backend

```
apps/api/src

auth/
    google.ts
    session.ts

db/
    client.ts
    schema.ts
    reset.ts

services/
    tasks.ts
    calendar.ts

server.ts
```

# Development Workflow

Chronolog uses a Git feature branch workflow.

## Branch Strategy

- `main` – Stable production branch
- Feature branches – One branch per feature or bug fix

Example:

feature/google-task-integration
feature/task-cache
fix/render-auth

## Development Process

1. Create a feature branch.
2. Implement a single feature.
3. Commit incrementally with descriptive messages.
4. Push branch to GitHub.
5. Open a Pull Request.
6. Review and test changes.
7. Merge into `main`.
8. Automatic deployment from `main`.

## Commit Style

Examples:

- Add Google Tasks integration
- Cache Google Tasks locally
- Fix OAuth callback redirect
- Add task refresh button

## Deployment

- Every merge to `main` triggers:
  - Backend deployment on Render.
  - Frontend deployment on Vercel.

```


### Responsibilities

**auth/**
- Google OAuth
- Session creation
- Session validation

**db/**
- Database client
- Schema definitions
- Database utilities

**services/**
- External Google API integrations

**server.ts**
- Express server
- REST endpoints
- Middleware
- Business logic

---

## Frontend

```
apps/web/src

components/
hooks/
pages/
services/
types/
utils/

App.tsx
main.tsx
```

Responsibilities

**pages/**
- Route-level pages

**components/**
- Reusable UI

**hooks/**
- Shared stateful logic

**services/**
- Backend API communication

---

# 4. Authentication Flow

Authentication uses Google OAuth with session-based authentication.

Flow:

```
Browser

↓

GET /auth/google

↓

Google Login

↓

/auth/google/callback

↓

Exchange authorization code

↓

Receive Google tokens

↓

Fetch Google user profile

↓

Create or update user

↓

Create session

↓

Store session cookie

↓

Redirect to frontend
```

Authenticated requests:

```
Browser

↓

Cookie

↓

requireAuth()

↓

Session lookup

↓

User lookup

↓

Endpoint
```

---

# 5. Session Management

Sessions are stored inside the sessions table.

Each session contains:

- Session ID
- User ID
- Expiration Time

The browser stores only the session identifier inside an HTTP-only cookie.

The backend validates every authenticated request using middleware.

---

# 6. Database Design

## Users

Purpose

Stores authenticated users and Google credentials.

Fields

- id
- googleId
- email
- name
- avatarUrl
- googleAccessToken
- googleRefreshToken
- googleTokenExpiresAt
- trackingStartedAt
- selectedTaskListId

---

## Sessions

Purpose

Maintains logged-in browser sessions.

Relationship

```
User

1

↓

Many Sessions
```

---

## Activities

Purpose

Stores reusable user-defined activities.

Relationship

```
User

1

↓

Many Activities
```

---

## Time Blocks

Purpose

Represents a logged time interval.

Relationship

```
User

1

↓

Many Time Blocks
```

---

## Activity Allocations

Purpose

Maps activities to a time block.

Relationship

```
Time Block

1

↓

Many Activity Allocations

↓

Activity
```

---

# 7. API Design

## Authentication

GET /auth/google

Purpose

Starts Google OAuth flow.

---

GET /auth/google/callback

Purpose

Processes Google callback.

---

GET /auth/me

Purpose

Returns authenticated user.

Authentication

Required

---

POST /auth/logout

Purpose

Destroys session.

---

## Activities

GET /activities

Returns user activities.

---

POST /activities

Creates activity.

---

## Tracking

POST /tracking/start

Stores tracking start time.

---

POST /tracking/reset

Resets active tracking.

---

POST /log-session

Creates:

- Time Block
- Activity Allocations

Updates tracking start.

---

## Tasks

GET /tasks/lists

Returns Google task lists.

---

GET /tasks

Returns incomplete tasks.

---

POST /tasks/complete

Marks Google tasks completed.

---

POST /settings/task-list

Stores selected task list.

---

## Calendar

GET /google/calendar

Returns today's calendar events.

---

## Timeline

GET /time-blocks

Returns historical logs.

---

# 8. Request Lifecycle

Every authenticated endpoint follows the same lifecycle.

```
Incoming Request

↓

Cookie

↓

Authentication Middleware

↓

Business Logic

↓

Database

↓

JSON Response
```

---

# 9. Middleware

Current middleware

## requireAuth

Responsibilities

- Read cookie
- Validate session
- Find user
- Store userId in res.locals
- Continue request

---

# 10. Google Integration

Google OAuth

Purpose

Authentication

---

Google Tasks

Purpose

Retrieve task lists

Retrieve incomplete tasks

Mark tasks completed

---

Google Calendar

Purpose

Retrieve today's events.

---

# 11. Frontend Flow

Application startup

```
main.tsx

↓

BrowserRouter

↓

App.tsx

↓

checkAuth()

↓

Dashboard

or

Login Screen
```

Dashboard

↓

Hooks

↓

Services

↓

Backend

↓

Database

---

# 12. Local Caching

Google Tasks are cached using localStorage.

Cache contains

- Tasks
- Selected List ID
- Timestamp

Cache expires after fifteen minutes.

---

# 13. Error Handling

Backend

- HTTP status codes
- try/catch
- Validation
- Authentication failures

Frontend

- Loading indicators
- Error messages
- Retry support

---

# 14. Current Limitations

- Desktop-first UI
- No offline mode
- Single-user architecture
- Google dependency
- No analytics
- No notifications

---

# 15. Future Improvements

- AI activity suggestions
- Weekly analytics
- Mobile application
- Notifications
- Export support
- Team workspaces
- Background synchronization