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

# Git Workflow

Chronolog is developed using a Git Feature Branch Workflow.

## Branch Strategy

- **main** – Stable production branch.
- **feature/<feature-name>** – New feature development.
- **bugfix/<bug-name>** – Bug fixes.

Examples:

- feature/google-task-integration
- feature/task-cache
- bugfix/render-auth

## Development Process

1. Clone the repository.
2. Create a feature branch using `git checkout -b feature/<name>`.
3. Implement the feature.
4. Commit changes incrementally using descriptive commit messages.
5. Push the branch to GitHub.
6. Open a Pull Request (PR).
7. Review and test the implementation.
8. Merge the Pull Request into `main`.
9. Automatic deployment is triggered after merging.

## Commit Message Examples

- Add Google OAuth authentication
- Implement Google Tasks integration
- Add task caching
- Fix Render deployment issue
- Add task refresh button

## Pull Requests

Every feature is merged through a Pull Request. Pull Requests are used to:

- Review code changes.
- Discuss implementation.
- Keep `main` production-ready.
- Maintain project history.

## Version Control Benefits

Git provides:

- Branch isolation
- Change history
- Easy rollback
- Collaborative development
- Traceable feature implementation


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

## Environment Variables and Secrets Management

Chronolog separates configuration from application code using environment variables. Sensitive values such as database credentials, OAuth client credentials, and deployment URLs are never hardcoded into the codebase.

The backend retrieves configuration values through dedicated configuration functions before communicating with external services. Missing or invalid configuration causes application startup or authentication requests to fail immediately rather than allowing the application to continue in an invalid state.

The frontend only receives non-sensitive configuration values required for client-side operation. All sensitive credentials remain exclusively on the backend.

Example environment variables include:

- DATABASE_URL
- GOOGLE_CLIENT_ID
- GOOGLE_CLIENT_SECRET
- GOOGLE_CALLBACK_URL
- WEB_URL

A `.env.example` file is maintained to document the required configuration without exposing any secrets.

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