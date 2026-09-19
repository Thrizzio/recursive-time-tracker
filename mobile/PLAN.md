# Chronolog Flutter Mobile App — Approved Implementation Plan

Package: `com.chronolog.app` · Android only · Riverpod · Dio + cookie_jar

---

## API Endpoint Map

All endpoints live on the existing Express backend. One new endpoint is added for mobile auth.

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| GET | `/health` | ✗ | Health check |
| GET | `/auth/google` | ✗ | Web-only: redirect to Google consent |
| GET | `/auth/google/callback` | ✗ | Web-only: OAuth callback |
| **POST** | **`/auth/mobile/google`** | **✗** | **NEW — mobile auth bridge** |
| GET | `/auth/me` | ✓ | Current user profile + tracking state |
| POST | `/auth/logout` | ✗ | Delete session, clear cookie |
| GET | `/activities` | ✓ | List user's activities |
| POST | `/activities` | ✓ | Create activity `{ name, color }` |
| GET | `/tasks/lists` | ✓ | List Google Task Lists |
| GET | `/tasks` | ✓ | Get tasks from selected list |
| POST | `/tasks/complete` | ✓ | Mark tasks complete `{ taskIds }` |
| POST | `/settings/task-list` | ✓ | Set selected task list `{ taskListId }` |
| POST | `/tracking/start` | ✓ | Start tracking (sets `trackingStartedAt`) |
| POST | `/tracking/reset` | ✓ | Reset tracking (nulls `trackingStartedAt`) |
| POST | `/log-session` | ✓ | Create time block with allocations |
| GET | `/time-blocks` | ✓ | Get time blocks (optional date filter) |
| GET | `/time-summary` | ✓ | Aggregated time summary (optional date range) |
| GET | `/google/calendar` | ✓ | Google Calendar events `{ start, end }` |

**No edit/delete endpoints exist** for activities or time blocks. The Flutter app matches this: display + create only. Tasks are display + complete only (no task creation).

---

## Authentication Decision

### Strategy: Server Auth Code via `google_sign_in`

```
Flutter
  ↓  google_sign_in with serverClientId = existing GOOGLE_CLIENT_ID
  ↓  scopes: userinfo.profile, userinfo.email, tasks, calendar.readonly
  ↓
GoogleSignInAccount.serverAuthCode
  ↓
POST /auth/mobile/google { serverAuthCode }
  ↓
Backend exchanges code for tokens (access + refresh)
  ↓
Upsert user, store Google tokens, create session
  ↓
Set-Cookie: chronolog_session=...  (cookie only, no sessionId in body)
  ↓
Response: { user: { id, email, name, avatarUrl, trackingStartedAt, selectedTaskListId } }
  ↓
cookie_jar stores the cookie → all subsequent requests are authenticated
```

### Verified: redirect_uri Caveat

**`getGoogleTokens()` cannot be reused unchanged.** It hardcodes `redirect_uri: GOOGLE_CALLBACK_URL` (the web callback). When exchanging a server auth code obtained from a mobile native client, Google requires `redirect_uri` to be an **empty string** `""` (or omitted entirely).

**Fix:** Modify `getGoogleTokens()` to accept an optional `redirectUri` parameter, defaulting to `GOOGLE_CALLBACK_URL`. The mobile endpoint passes `""`. This is one line of signature change + one line of usage change. The web callback path is unaffected.

```typescript
// Before
export async function getGoogleTokens(code: string) {
  const { GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_CALLBACK_URL } = getGoogleConfig();
  // ...
  redirect_uri: GOOGLE_CALLBACK_URL,
}

// After
export async function getGoogleTokens(code: string, redirectUri?: string) {
  const { GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_CALLBACK_URL } = getGoogleConfig();
  // ...
  redirect_uri: redirectUri ?? GOOGLE_CALLBACK_URL,
}
```

### Refresh Token Safety

- `google_sign_in` v7+ provides `serverAuthCode` when `serverClientId` is set during initialization; no legacy `forceCodeForRefreshToken` needed.
- Google returns a `refresh_token` on first authorization only. The mobile endpoint must use the **same guard as the existing callback** (line 86 of server.ts):
  ```typescript
  ...(tokens.refresh_token ? { googleRefreshToken: tokens.refresh_token } : {})
  ```
  This ensures an existing stored `googleRefreshToken` is **never overwritten with null**.

### Session Handling

- Session ID is set via `Set-Cookie` only — **not returned in the response body**.
- `cookie_jar` (with `PersistCookieJar`) stores the cookie and sends it automatically on all subsequent Dio requests.
- Cookie properties (`httpOnly`, `secure: true`, `sameSite: none`) are compatible with Dio — these are browser-only restrictions.
- CORS stays minimal: Flutter's Dio doesn't send `Origin` headers, so no CORS changes needed.

### No JWT

The existing session system works for the mobile client. No JWT, no access/refresh token scheme, no second auth system.

---

## Pre-Phase 3 Testing Decision (To Be Resolved)

Before coding Phase 3, we must decide how to test against the backend given:
- The cookie has `secure: true` (requires HTTPS)
- The `POST /auth/mobile/google` endpoint won't exist on production yet

**Options — I will propose these at the start of Phase 3 and wait for your choice:**

| Option | How | Tradeoff |
|--------|-----|----------|
| A. HTTPS tunnel | `ngrok http 3000` → test against local backend over HTTPS | Simplest; requires ngrok installed. Note: The mobile flow does NOT use `GOOGLE_CALLBACK_URL`, so no Google Console changes are needed for a tunnel. |
| B. Branch deploy on Render | Push backend branch to Render preview/staging | Tests real infra; may need Render config |
| C. Dev-only `secure` toggle | `secure: process.env.NODE_ENV === "production"` in cookie config | Allows HTTP locally; must never ship to prod |

---

## Notification Semantics

### 2-Hour Tracking Reminder

**Verified: wall-clock time since `trackingStartedAt`, not active elapsed time.**

The web code (Dashboard.tsx L441–464) computes:
```
elapsed = Date.now() - new Date(trackingStartedAt).getTime()
boundaryIdx = floor(elapsed / TWO_HOURS_MS)
```

This is pure wall-clock. The Flutter app must match exactly:
- When tracking is active, schedule a notification at `trackingStartedAt + 2h`, `+4h`, `+6h`, etc.
- Use `flutter_local_notifications` scheduled notifications, targeting the **server's `trackingStartedAt`** timestamp (from `GET /auth/me` or `POST /tracking/start` response), not when the phone learned about it.
- Cancel pending reminders on tracking reset or log-session.

### Timer Completion

- Schedule a notification at the computed `endsAt` timestamp.
- Use `flutter_local_notifications` scheduling — **not** `android_alarm_manager_plus`.
- `android_alarm_manager_plus` will only be added if `flutter_local_notifications` scheduling proves insufficient for exact timing during testing.

---

## WebSocket Notes (Phase 6)

- The `ws` library will be used on the backend (attached to the existing HTTP server).
- The Flutter WebSocket client must **explicitly read the current `chronolog_session` cookie from the PersistCookieJar** and send it in the `Cookie` header during the WebSocket handshake. Dart's `WebSocket.connect()` does not share Dio's cookie jar — this must be handled manually.
- This will be verified during Phase 6 implementation; if the approach fails, alternatives will be documented before proceeding.

---

## Phases

### Phase 2: Flutter Foundation

Scaffold the project, configure dependencies, establish structure.

| # | Task |
|---|------|
| 1 | `flutter create` in `mobile/` with package `com.chronolog.app` |
| 2 | Add all dependencies to `pubspec.yaml` (riverpod, dio, cookie_jar, dio_cookie_manager, google_sign_in, go_router, flutter_local_notifications) |
| 3 | Set up project structure: `app/`, `core/`, `features/`, `shared/` |
| 4 | Implement `ApiClient` (Dio + PersistCookieJar + interceptors + 60s timeout) |
| 5 | Configure base URL via `--dart-define=API_URL=...` |
| 6 | Set up GoRouter with placeholder screens |
| 7 | Create Chronolog dark theme (zinc/neutral surfaces, cyan accent) |
| 8 | Create shared error/loading widgets |

**Done means:**
- [ ] `flutter analyze` — zero warnings
- [ ] `flutter build apk --debug` — successful
- [ ] App launches on emulator showing a placeholder screen
- [ ] ApiClient can make a GET to `/health` and receive `{ status: "ok" }`
- [ ] No Flutter code in `packages/shared`

---

### Phase 3: Authentication

Implement Google Sign-In against the existing backend.

| # | Task |
|---|------|
| 1 | **Pre-coding:** Propose testing strategy (tunnel / branch deploy / dev toggle) and wait for approval |
| 2 | Add `POST /auth/mobile/google` endpoint to backend (modify `getGoogleTokens` for `redirect_uri`) |
| 3 | Implement Flutter login screen with Google Sign-In button |
| 4 | Configure `google_sign_in` with `serverClientId` and required scopes |
| 5 | Send `serverAuthCode` to backend, receive session cookie |
| 6 | Implement session check on app start (`GET /auth/me`) |
| 7 | Implement logout (`POST /auth/logout` + clear cookie jar) |
| 8 | Handle auth errors: expired session → redirect to login |

**Done means:**
- [ ] Google Sign-In works on emulator/device
- [ ] Follow official docs for the installed `google_sign_in` version (API differs between v6 and v7)
- [ ] Note: `redirect_uri` and refresh-token behavior are unconfirmed until tested in this phase
- [ ] Log explicitly whether a `refresh_token` was returned by the mobile code exchange
- [ ] Verify Calendar and Tasks endpoints still work after forcing the access token to expire (confirming refresh token functions properly)
- [ ] Backend receives server auth code, exchanges for tokens, creates session
- [ ] `GET /auth/me` returns user data with the session cookie
- [ ] Refresh token is never overwritten with null
- [ ] Session ID is not in the response body
- [ ] Logout clears session on both client and server
- [ ] App restart with valid session → goes to dashboard (not login)
- [ ] App restart with expired/missing session → goes to login

---

### Phase 4a: Core Tracking & Timeline

Dashboard tracking, log-session, today's summary, today's timeline.

| # | Task |
|---|------|
| 1 | Dashboard screen: show tracking state from `user.trackingStartedAt` |
| 2 | Live elapsed clock (1-second tick, computed from `trackingStartedAt`) |
| 3 | Start tracking (`POST /tracking/start`) |
| 4 | Reset tracking (`POST /tracking/reset`) |
| 5 | Log session flow: select activities → allocate percentages → `POST /log-session` |
| 6 | Today's summary panel (`GET /time-summary` with today's date range) |
| 7 | Today's timeline: `GET /time-blocks` filtered to today, rendered as cards |
| 8 | Loading / error / retry states for all network calls |
| 9 | Render cold-start handling: 60s timeout, "Server waking up..." messaging |

**Done means:**
- [ ] Can start tracking, see elapsed time ticking
- [ ] Can reset tracking
- [ ] Can log a session with activity allocations
- [ ] After logging, trackingStartedAt resets and new block appears in timeline
- [ ] Today's summary shows per-activity totals with colors
- [ ] All screens have loading, error, and retry states
- [ ] No infinite spinners on timeout/failure

---

### Phase 4b: Activities, Tasks & Calendar

Secondary features: activity management, Google Tasks, calendar agenda.

| # | Task |
|---|------|
| 1 | Activities screen: list activities with colors (`GET /activities`) |
| 2 | Create activity form: name + color picker → `POST /activities` |
| 3 | Tasks panel: display tasks from selected list (`GET /tasks`) |
| 4 | Mark tasks complete (`POST /tasks/complete`) |
| 5 | Task list selection in settings (`GET /tasks/lists`, `POST /settings/task-list`) |
| 6 | Calendar agenda: today's events (`GET /google/calendar`) |
| 7 | Bottom navigation: Dashboard / Activities, with settings accessible via menu |

**Done means:**
- [ ] Activities page shows all activities with colors
- [ ] Can create a new activity
- [ ] Tasks panel displays incomplete tasks from selected list
- [ ] Can mark tasks complete
- [ ] Can change selected task list in settings
- [ ] Calendar shows today's events
- [ ] Navigation between dashboard and activities works

---

### Phase 5: Pomodoro Timer

Timestamp-based timer, local state only (no backend persistence for v1).

| # | Task |
|---|------|
| 1 | Timer state model: `endsAt`-based, `remaining = endsAt - DateTime.now()` |
| 2 | Timer states: stopped → running → paused → completed |
| 3 | Start / pause / resume / reset actions |
| 4 | Timer as Riverpod provider (application state, not widget state) |
| 5 | Timer survives widget rebuilds and navigation |
| 6 | Timer recovers after app backgrounding (recalculates from `endsAt`) |
| 7 | Duration presets: 25 min, 50 min |
| 8 | "Start focus" from task tap |
| 9 | Persist timer state to `shared_preferences` |

**Done means:**
- [ ] Timer shows countdown, handles all state transitions
- [ ] Source of truth is `endsAt` timestamp, not a decrementing counter
- [ ] Timer survives navigating away and back
- [ ] Timer shows correct remaining time after app goes to background and returns
- [ ] Tapping a task starts the timer
- [ ] Timer state persists across app restarts

---

### Phase 6: WebSockets

Backend WebSocket server + Flutter client + web listener.

| # | Task |
|---|------|
| 1 | Add `ws` to backend, attach to HTTP server |
| 2 | Authenticate WebSocket upgrade using session cookie from request headers (associate socket with `userId`) |
| 3 | Broadcast events from route handlers: `tracking.started`, `tracking.reset`, `time-block.created`, `task.completed`. **Events must be broadcast only to sockets authenticated as the same user, never globally.** |
| 4 | Flutter: WebSocket client that reads cookie from `PersistCookieJar` and sends in handshake `Cookie` header |
| 5 | Auto-reconnect with exponential backoff (initial 1s, max 30s) |
| 6 | After reconnect: fetch authoritative state via REST, then resume listening |
| 7 | Handle app background → foreground: reconnect + REST resync |
| 8 | **Separate commit:** Add WebSocket listener to React web app for cross-client sync |

**Done means:**
- [ ] WebSocket connects with authenticated session
- [ ] WebSocket events are scoped strictly to the authenticated user (never broadcast across different users)
- [ ] Flutter receives events when web app changes state (and vice versa)
- [ ] Disconnection triggers automatic reconnect with backoff
- [ ] After reconnect, REST data is refreshed before processing new events
- [ ] App backgrounding + foregrounding reconnects cleanly
- [ ] Web app receives events from Flutter changes (separate commit)
- [ ] Verified: cookie from PersistCookieJar is sent in WebSocket handshake

---

### Phase 7: Android Notifications

Local notifications for tracking reminders and timer completion.

| # | Task |
|---|------|
| 1 | Configure `flutter_local_notifications` with Android notification channel |
| 2 | Request `POST_NOTIFICATIONS` permission (Android 13+) |
| 3 | 2-hour tracking reminder: scheduled at `trackingStartedAt + 2h`, `+4h`, etc. (wall-clock, matching web semantics exactly) |
| 4 | Schedule only the next few reminders (e.g. 2-3 boundaries) rather than indefinitely into the future |
| 5 | Re-schedule/refresh reminders on app open and on tracking-state sync |
| 6 | Set up boot receiver (`RECEIVE_BOOT_COMPLETED`) so notifications survive device reboot |
| 7 | Handle `SCHEDULE_EXACT_ALARM` with graceful fallback to inexact scheduling if exact alarm permission is denied |
| 8 | Cancel tracking reminders on reset or log-session |
| 9 | Timer completion notification: scheduled at `endsAt` timestamp |
| 10 | Cancel timer notification on reset |

**Done means:**
- [ ] Notification permission requested on first relevant action
- [ ] 2-hour reminder fires at correct wall-clock boundary relative to server's `trackingStartedAt`
- [ ] Only next few reminder boundaries are scheduled, re-scheduled on app open and state sync
- [ ] Boot receiver restores reminders after reboot
- [ ] `SCHEDULE_EXACT_ALARM` handled with inexact fallback when not granted
- [ ] Timer notification fires when timer reaches zero
- [ ] Notifications are cancelled when tracking/timer is reset
- [ ] No `android_alarm_manager_plus` unless `flutter_local_notifications` scheduling proved insufficient (documented)

---

### Phase 8: Testing & Cleanup

Final verification and polish.

| # | Task |
|---|------|
| 1 | `flutter analyze` — zero warnings |
| 2 | `flutter test` — unit tests for timer logic, API client, auth repository |
| 3 | `flutter build apk --release` — successful build |
| 4 | `npm run build` in `apps/web` — web app still builds |
| 5 | `npm run build` in `apps/api` — backend still builds |
| 6 | Existing `npm run test` in `apps/api` — backend tests still pass |
| 7 | Code cleanup, remove TODOs, verify no secrets in code |
| 8 | Update README with mobile setup instructions |
| 9 | Create PR from `feature/flutter-mobile-app` branch |

**Done means:**
- [ ] All automated checks pass
- [ ] Web app unbroken
- [ ] Backend unbroken and tests pass
- [ ] PR created with clean commit history

---

## Your Setup Checklist

Complete these **before Phase 3**.

### 1. Find Your Google Cloud Project
- Go to [Google Cloud Console → APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials)
- Open the project that contains the existing Chronolog OAuth client (the one with your `GOOGLE_CLIENT_ID`)

### 2. Create an Android OAuth Client ID
1. Click **+ CREATE CREDENTIALS → OAuth client ID**
2. Application type: **Android**
3. Name: `Chronolog Android`
4. Package name: `com.chronolog.app`
5. SHA-1 fingerprint — get your debug fingerprint:
   ```
   keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```
   Copy the SHA-1 line (e.g., `AB:CD:EF:...`)
6. Click **CREATE**

### 3. Note the Web Client ID
- In the same Credentials page, find the existing **Web application** OAuth client
- Copy its **Client ID** — this is the `serverClientId` for `google_sign_in`
- This is the same `GOOGLE_CLIENT_ID` from your backend `.env`

### 4. Check OAuth Consent Screen
1. Go to **APIs & Services → OAuth consent screen**
2. Verify these scopes are listed:
   - `userinfo.profile`
   - `userinfo.email`
   - `Google Tasks API` (`tasks`)
   - `Google Calendar API` (`calendar.readonly`)
3. **Publishing status:** If set to "Testing", only test users can authenticate. Either:
   - Add your Google account to the **Test users** list, OR
   - Publish the app (moves to "In production" — allows any Google account)
4. If using "Testing" mode, verify your test account is listed

### 5. Verify APIs Are Enabled
- Go to **APIs & Services → Enabled APIs**
- Confirm these are enabled:
  - Google Tasks API
  - Google Calendar API

### Summary

- [ ] Android OAuth client created with debug SHA-1 for `com.chronolog.app`
- [ ] Web client ID noted (same as `GOOGLE_CLIENT_ID`)
- [ ] OAuth consent screen has all 4 scopes
- [ ] Publishing status checked; test user added if in "Testing" mode
- [ ] Google Tasks API enabled
- [ ] Google Calendar API enabled

