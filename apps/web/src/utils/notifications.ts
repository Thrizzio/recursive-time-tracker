/**
 * Browser notification and audio utility for Chronolog.
 *
 * Three exported functions:
 *   requestNotificationPermission() — ask the user once (call from explicit gesture only)
 *   showNotification(title, body)   — fire a native browser notification if permitted
 *   playNotificationSound()         — short Web Audio API beep; never throws
 */

// ─── Permission ──────────────────────────────────────────────────────────────

/**
 * Request notification permission from the browser.
 * Safe to call only when `Notification.permission === 'default'`;
 * the caller is responsible for gating on that check.
 *
 * Returns the resulting permission string, or 'unsupported' if the
 * Notification API is unavailable in this browser.
 */
export async function requestNotificationPermission(): Promise<
  NotificationPermission | 'unsupported'
> {
  if (typeof Notification === 'undefined') return 'unsupported';
  if (Notification.permission !== 'default') return Notification.permission;

  try {
    return await Notification.requestPermission();
  } catch {
    return 'denied';
  }
}

// ─── Show notification ────────────────────────────────────────────────────────

/**
 * Show a native browser notification.
 * No-ops silently when:
 *   - the Notification API is unavailable
 *   - permission has not been granted
 */
export function showNotification(title: string, body: string): void {
  if (typeof Notification === 'undefined') return;
  if (Notification.permission !== 'granted') return;

  try {
    new Notification(title, { body, icon: '/favicon.ico' });
  } catch {
    // Some environments (e.g. insecure context) throw — ignore.
  }
}

// ─── Audio ───────────────────────────────────────────────────────────────────

/**
 * Play a short, pleasant notification beep using the Web Audio API.
 *
 * Generates a 880 Hz sine wave for 200 ms with a quick fade-out.
 * Uses the Web Audio API so no external file is required and autoplay
 * restrictions do not apply when called from a user-gesture context.
 *
 * Any failure is caught and logged; the beep never breaks notification flow.
 */
export function playNotificationSound(): void {
  try {
    const AudioCtx =
      window.AudioContext ??
      (window as unknown as { webkitAudioContext: typeof AudioContext })
        .webkitAudioContext;

    if (!AudioCtx) return;

    const ctx = new AudioCtx();

    // Oscillator — 880 Hz sine wave
    const oscillator = ctx.createOscillator();
    oscillator.type = 'sine';
    oscillator.frequency.setValueAtTime(880, ctx.currentTime);

    // Gain envelope: full volume → silent over 200 ms
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.25, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 0.2);

    oscillator.connect(gain);
    gain.connect(ctx.destination);

    oscillator.start(ctx.currentTime);
    oscillator.stop(ctx.currentTime + 0.2);

    // Clean up the AudioContext after the sound finishes
    oscillator.onended = () => {
      ctx.close().catch(() => {/* ignore */});
    };
  } catch (err) {
    console.warn('[Chronolog] Could not play notification sound:', err);
  }
}

