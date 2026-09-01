/**
 * Chronolog notification preferences.
 *
 * Persisted to localStorage so they survive page refreshes and browser restarts.
 * Read synchronously by the Dashboard scheduler and useTimer — no React context
 * or prop-drilling required.
 *
 * Listening for changes: call `subscribeToPrefs(listener)` so that Dashboard
 * can react immediately when the user changes a toggle in Settings (e.g. to
 * cancel a pending timeout when tracking reminders are disabled mid-session).
 */

const STORAGE_KEY = 'chronolog_notification_prefs';

export type NotificationPrefs = {
  trackingRemindersEnabled: boolean;
  timerNotificationsEnabled: boolean;
};

const DEFAULT_PREFS: NotificationPrefs = {
  trackingRemindersEnabled: true,
  timerNotificationsEnabled: true,
};

// ── Read ──────────────────────────────────────────────────────────────────────

export function getNotificationPrefs(): NotificationPrefs {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { ...DEFAULT_PREFS };
    const parsed = JSON.parse(raw) as Partial<NotificationPrefs>;
    return {
      trackingRemindersEnabled: parsed.trackingRemindersEnabled ?? DEFAULT_PREFS.trackingRemindersEnabled,
      timerNotificationsEnabled: parsed.timerNotificationsEnabled ?? DEFAULT_PREFS.timerNotificationsEnabled,
    };
  } catch {
    return { ...DEFAULT_PREFS };
  }
}

// ── Write ─────────────────────────────────────────────────────────────────────

export function setNotificationPrefs(prefs: NotificationPrefs): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
  } catch {
    // Ignore write failures (private browsing, storage quota)
  }
  // Notify all in-page subscribers synchronously so the scheduler can
  // react immediately (e.g. cancel a pending timeout when reminders are
  // disabled while a session is active).
  for (const listener of listeners) {
    listener(prefs);
  }
}

// ── Subscribe ─────────────────────────────────────────────────────────────────

type PrefsListener = (prefs: NotificationPrefs) => void;
const listeners = new Set<PrefsListener>();

/**
 * Subscribe to preference changes. Returns an unsubscribe function.
 * Useful for the Dashboard scheduler useEffect.
 */
export function subscribeToPrefs(listener: PrefsListener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

