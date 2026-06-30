# Tracking Mode Transition Plan

## Goal
Switch the app from a planning-first flow to a live tracking flow:
- Before pressing Start: the user declares what they plan to do.
- After pressing Start: the app begins tracking time and the user logs what they actually did.

## Core Logic Switch
Introduce a simple mode state:

```ts
type SessionMode = 'planning' | 'tracking' | 'paused' | 'completed';
```

Use this state to decide what the UI and actions should do.

## Behavior
### 1. In planning mode
- The user can enter a planned activity or a short task description.
- The app shows the usual "what are you going to do?" experience.
- Nothing is being timed yet.

### 2. When the Start button is pressed
- Create or open a new tracking session.
- Switch the mode from `planning` to `tracking`.
- Start the timer.
- Change the input experience from "planned task" to "what have you been doing since your last log?"
- The activities entered after this point are treated as actual logged work.

### 3. During tracking
- The timer continues running.
- The user can add activities as they work.
- Each activity should be stored with:
  - text
  - timestamp
  - session id

### 4. When the user stops or pauses
- Stop the timer.
- Mark the session as `completed` or `paused`.
- Keep the activity log as the actual record of what happened during the session.

## Suggested UI Switch
- Before Start: show planned activities / next actions.
- After Start: show a live tracker and an activity entry field with text like:
  - "What have you been doing since your last log?"

## Pseudocode
```ts
if (mode === 'planning' && startClicked) {
  mode = 'tracking';
  startTimer();
  openSession();
}

if (mode === 'tracking' && activitySubmitted) {
  saveActivity({
    text: activityText,
    timestamp: Date.now(),
    sessionId: activeSessionId,
  });
}

if (stopClicked) {
  stopTimer();
  mode = 'completed';
}
```

## Recommended Mental Model
The app should behave like this:
- Planning mode = "what I intend to do"
- Tracking mode = "what I actually did"

That means the Start button is the switch from intention to live logging.
