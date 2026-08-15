# Authentication Architecture

## Overview

Chronolog uses Google OAuth for identity verification and server-side
sessions for application authentication.

## Authentication Flow

1. User requests `GET /auth/google`.
2. Backend generates the Google OAuth authorization URL using
   `getGoogleAuthUrl()`.
3. User authenticates with Google and grants the requested scopes.
4. Google redirects to `/auth/google/callback?code=...`.
5. Backend exchanges the authorization code for Google tokens.
6. Backend retrieves the Google user's profile.
7. The user is created or updated in the `users` table.
8. Chronolog creates a server-side session.
9. The session ID is sent to the browser as an HTTP-only cookie.
10. Subsequent protected requests are authenticated through `requireAuth`.

## Session Authentication

The browser stores:

`chronolog_session=<session_id>`

The cookie contains only the session identifier.

The actual session is stored server-side:

`session_id -> user_id -> expires_at`

## Protected Requests

For an authenticated endpoint:

Browser
→ `chronolog_session` cookie
→ `requireAuth`
→ `getSessionUserId`
→ `res.locals.userId`
→ Route handler

## Security Properties

- Google passwords are never stored by Chronolog.
- Session IDs are stored server-side.
- Authentication cookies use `httpOnly`.
- Production cookies use `secure`.
- Sessions have an expiration time.
- Google credentials are supplied through environment variables.