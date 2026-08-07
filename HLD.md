# High Level Design (HLD)

**Project:** Chronolog  
**Version:** 1.0  
**Status:** Active Development

---

# 1. Overview

Chronolog is a full-stack web application that enables retrospective time tracking through a React frontend, an Express backend, PostgreSQL for persistence, and Google APIs for authentication and productivity integrations.

The system follows a client-server architecture where the frontend is responsible for user interaction and presentation, while the backend owns authentication, business logic, database access, and communication with external services.

---

# 2. High Level Architecture

```
                    +----------------------+
                    |     React Client     |
                    |   (Vercel Hosted)    |
                    +----------+-----------+
                               |
                      HTTPS REST API
                               |
                               ▼
                    +----------------------+
                    |   Express Backend    |
                    |    (Render Hosted)   |
                    +----------+-----------+
                               |
        +----------------------+----------------------+
        |                      |                      |
        ▼                      ▼                      ▼
+---------------+     +----------------+     +----------------+
| PostgreSQL    |     | Google OAuth   |     | Google APIs    |
| (Neon)        |     | Authentication |     | Tasks & Calendar|
+---------------+     +----------------+     +----------------+
```

---

# 3. System Components

## Frontend

The frontend is built using React and TypeScript.

Primary responsibilities include:

- Rendering the user interface.
- Managing application state.
- Calling backend REST endpoints.
- Displaying loading and error states.
- Routing between Dashboard and Settings.
- Caching Google Tasks locally for improved responsiveness.

The frontend contains no business logic related to authentication or persistence.

---

## Backend

The backend is implemented using Express.

Responsibilities include:

- Google OAuth authentication.
- Session management.
- Database operations.
- Time logging workflow.
- Google Calendar integration.
- Google Tasks integration.
- Validation of authenticated requests.
- REST API implementation.

The backend acts as the single source of truth for application state.

---

## Database

Chronolog uses PostgreSQL with Drizzle ORM.

Persistent application data includes:

- Users
- Sessions
- Activities
- Time Blocks
- Activity Allocations

The relational model allows historical tracking while maintaining normalized data.

---

## External Services

Chronolog integrates with Google services for:

### Google OAuth

- User authentication
- Identity verification

### Google Tasks

- Fetch task lists
- Fetch incomplete tasks
- Mark tasks completed

### Google Calendar

- Read daily calendar events
- Display events during logging

---

# 4. Authentication Architecture

Chronolog uses session-based authentication.

Authentication flow:

1. User signs in with Google.
2. Google redirects to the backend callback.
3. Backend exchanges authorization code for tokens.
4. User information is retrieved from Google.
5. User record is created or updated.
6. Backend creates an application session.
7. Session ID is stored inside an HTTP-only cookie.
8. Every authenticated request passes through authentication middleware.

The frontend never directly communicates with Google after login.

---

# 5. Data Flow

## User Login

```
React

↓

GET /auth/google

↓

Google OAuth

↓

Callback

↓

Backend

↓

Database

↓

Session Cookie

↓

Dashboard
```

---

## Time Logging

```
Dashboard

↓

User allocates activities

↓

POST /log-session

↓

Backend

↓

Database

↓

Timeline refresh
```

---

## Google Tasks

```
Dashboard

↓

GET /tasks

↓

Backend

↓

Google Tasks API

↓

Frontend Cache

↓

Task Display
```

---

# 6. Database Overview

The application stores five primary entities.

## Users

Stores authenticated user information and Google credentials.

---

## Sessions

Maintains authenticated browser sessions.

Each session belongs to one user.

---

## Activities

Stores reusable activity categories created by users.

---

## Time Blocks

Represents an elapsed period between two logging events.

---

## Activity Allocations

Maps activities to a time block using percentage-based allocation.

This allows multiple activities to exist inside a single logged session.

---

# 7. Request Lifecycle

Every authenticated request follows the same lifecycle.

```
Browser Request

↓

Cookie Sent

↓

Authentication Middleware

↓

User Validation

↓

Business Logic

↓

Database / Google API

↓

JSON Response
```

---

# 8. Frontend Architecture

The frontend follows a component-based architecture.

High level organization:

```
App

├── Dashboard
│
├── Settings
│
├── Components
│
├── Hooks
│
└── Services
```

Responsibilities are separated into:

- Components for UI
- Hooks for reusable stateful logic
- Services for API communication
- Pages for route-level composition

---

# 9. Backend Architecture

The backend is organized by responsibility.

```
server

├── Authentication
│
├── Database
│
├── Google Services
│
└── REST Endpoints
```

Authentication, persistence, and third-party integrations remain independent modules.

---

# 10. Deployment Architecture

| Component | Platform |
|-----------|----------|
| Frontend | Vercel |
| Backend | Render |
| Database | Neon PostgreSQL |

Environment variables are used to configure:

- Database connection
- Google OAuth credentials
- Callback URLs
- Frontend URL

No secrets are committed to source control.

---

# 11. Design Decisions

### Session-Based Authentication

Chosen over JWT to allow server-controlled session invalidation and simplified OAuth integration.

---

### Retrospective Tracking

Rather than continuously recording activity, Chronolog assumes time is always passing and allows users to reconstruct elapsed time.

---

## Asynchronous Data Fetching

Chronolog communicates with the backend asynchronously using the Fetch API and the async/await programming model.

Frontend components do not directly perform API requests. Instead, reusable service modules encapsulate HTTP communication, while custom React hooks manage loading states, error states, caching, and data synchronization.

This separation provides:

- Reusable API communication
- Centralized loading and error management
- Cleaner React components
- Better maintainability

---

## React State Synchronization

Chronolog uses React's `useEffect` hook to synchronize component state with external systems such as backend APIs, browser timers, localStorage, and browser events.

Side effects are isolated from rendering logic to keep React components predictable. Each effect has a clearly defined dependency list so that it only executes when the required state changes.

Primary uses of `useEffect` include:

- Initial data loading
- Synchronizing timer updates
- Listening to browser storage events
- Fetching backend data
- Cleaning up timers and event listeners

---     

## Frontend Component Architecture

The frontend follows a component-based architecture where pages are composed from smaller, reusable UI components.

Each component has a single responsibility, improving readability, maintainability, and reusability.

Examples include:

- Dashboard – Main application page that coordinates data and user interactions.
- Timeline – Displays previously logged time blocks.
- ActivityModal – Handles retrospective time logging.
- Header – Displays user information and navigation.
- Settings – Manages application preferences.

Data flows from parent components to child components through props, while reusable logic is extracted into custom React hooks.

---

## Client State Management

Chronolog uses React's `useState` hook to manage component-level state.

State is used to store:

- Authentication information
- Activities
- Tasks
- Calendar events
- Loading indicators
- Error messages
- Modal visibility
- Timer state

Whenever state changes, React automatically re-renders only the affected components, ensuring the user interface stays synchronized with application data.

---

### Google Integration

Google Tasks and Calendar are integrated directly into the logging workflow to reduce context switching.

---

### Local Task Cache

Task data is cached on the client with a TTL to reduce unnecessary Google API requests and improve responsiveness.

---

## Development Workflow

Chronolog follows a feature branch workflow.

- `main` contains production-ready code.
- New features and bug fixes are developed on separate feature branches.
- Changes are committed incrementally with descriptive commit messages.
- Features are merged into `main` through Pull Requests after review and testing.

This workflow minimizes regressions and keeps the main branch deployable.

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

# 12. Current Limitations

Current limitations include:

- Desktop-first interface.
- Single-user application.
- Requires Google account.
- Depends on third-party Google APIs.
- No offline synchronization.
- No analytics or reporting.

---

# 13. Future Architecture

The current architecture allows future expansion through:

- Analytics module
- Notification service
- AI-assisted activity suggestions
- Mobile client
- Team workspaces
- Additional productivity integrations

These additions can be introduced without significant architectural changes due to the existing separation between frontend, backend, persistence, and external services.