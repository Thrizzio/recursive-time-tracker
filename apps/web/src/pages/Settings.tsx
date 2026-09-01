import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { GoogleTaskList } from '../types/tasks';
import * as tasksService from '../services/tasks';
import { clearTaskCache } from '../hooks/useTasks';
import { requestNotificationPermission } from '../utils/notifications';
import {
  getNotificationPrefs,
  setNotificationPrefs,
  type NotificationPrefs,
} from '../utils/notificationPrefs';

type User = {
  id: number;
  email: string;
  name: string;
  avatarUrl: string;
  trackingStartedAt: string | null;
  selectedTaskListId: string | null;
};

type SettingsProps = {
  user: User;
  onUserUpdate: () => Promise<void>;
};

export function Settings({ user, onUserUpdate }: SettingsProps) {
  const [lists, setLists] = useState<GoogleTaskList[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // ── Notification permission ──────────────────────────────────────────────────

  const [permission, setPermission] = useState<NotificationPermission | 'unsupported'>(() => {
    if (typeof Notification === 'undefined') return 'unsupported';
    return Notification.permission;
  });
  const [requestingPermission, setRequestingPermission] = useState(false);

  async function handleEnableNotifications() {
    setRequestingPermission(true);
    try {
      const result = await requestNotificationPermission();
      setPermission(result === 'unsupported' ? 'unsupported' : result);
    } finally {
      setRequestingPermission(false);
    }
  }

  // ── Notification preferences (app-level toggles) ───────────────────────────

  const [prefs, setPrefs] = useState<NotificationPrefs>(() => getNotificationPrefs());

  function handlePrefChange(key: keyof NotificationPrefs, value: boolean) {
    const next = { ...prefs, [key]: value };
    setPrefs(next);
    setNotificationPrefs(next); // persists to localStorage + notifies Dashboard
  }

  // ── Task list ────────────────────────────────────────────────────────────────

  useEffect(() => {
    async function loadLists() {
      try {
        const data = await tasksService.getTaskLists();
        setLists(data);
      } catch (err) {
        setError('Could not load task lists.');
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    loadLists();
  }, []);

  const handleSelectList = async (listId: string) => {
    setSaving(true);
    setError('');
    setSuccess('');

    try {
      await tasksService.saveSelectedTaskList(listId);
      clearTaskCache();
      await onUserUpdate();
      setSuccess('Task list preference saved!');
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError('Could not save preference. Please try again.');
      console.error(err);
    } finally {
      setSaving(false);
    }
  };

  // ── Toggle row helper ────────────────────────────────────────────────────────

  function ToggleRow({
    label,
    description,
    checked,
    onChange,
    disabled,
  }: {
    label: string;
    description: string;
    checked: boolean;
    onChange: (v: boolean) => void;
    disabled?: boolean;
  }) {
    return (
      <div className={`flex items-start justify-between gap-4 ${disabled ? 'opacity-40 pointer-events-none select-none' : ''}`}>
        <div className="space-y-0.5">
          <p className="text-sm font-medium text-zinc-200">{label}</p>
          <p className="text-xs text-zinc-400">{description}</p>
        </div>
        <button
          role="switch"
          aria-checked={checked}
          onClick={() => onChange(!checked)}
          className={`relative flex-none h-6 w-10 rounded-full transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-cyan-400 ${
            checked ? 'bg-cyan-500' : 'bg-zinc-600'
          }`}
        >
          <span
            className={`absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white shadow transition-transform ${
              checked ? 'translate-x-4' : 'translate-x-0'
            }`}
          />
        </button>
      </div>
    );
  }

  // ── Render ───────────────────────────────────────────────────────────────────

  return (
    <main className="min-h-screen bg-zinc-950 px-5 py-8 text-zinc-50">
      <div className="mx-auto max-w-2xl space-y-8">

        {/* Header */}
        <header className="flex items-center justify-between">
          <div className="space-y-1">
            <p className="text-xs font-semibold uppercase tracking-wide text-cyan-400">Settings</p>
            <h1 className="text-2xl font-bold leading-tight">Configure Chronolog</h1>
          </div>
          <Link
            to="/dashboard"
            className="rounded-lg border border-zinc-700 bg-zinc-900 px-4 py-2 text-sm font-medium text-zinc-300 hover:bg-zinc-800 hover:text-zinc-50 transition-colors"
          >
            Back to Dashboard
          </Link>
        </header>

        {/* Task List Selection */}
        <section className="rounded-lg border border-zinc-800 bg-zinc-900 p-6 space-y-4">
          <div>
            <h2 className="text-lg font-semibold text-zinc-200">Default Task List</h2>
            <p className="text-sm text-zinc-400 mt-1">
              Select which Google Task List to display on your dashboard.
            </p>
          </div>

          {loading && (
            <div className="space-y-2">
              <div className="h-12 bg-zinc-800 rounded animate-pulse" />
              <div className="h-12 bg-zinc-800 rounded animate-pulse" />
            </div>
          )}

          {error && (
            <p className="text-sm text-red-400">{error}</p>
          )}

          {success && (
            <p className="text-sm text-emerald-400">{success}</p>
          )}

          {!loading && lists.length === 0 && (
            <div className="rounded-lg border border-dashed border-zinc-700 px-4 py-6 text-center">
              <p className="text-sm text-zinc-400">
                No task lists found. Create one in{' '}
                <a
                  href="https://tasks.google.com"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-cyan-400 hover:underline"
                >
                  Google Tasks
                </a>
              </p>
            </div>
          )}

          {!loading && lists.length > 0 && (
            <div className="space-y-2">
              {lists.map(list => (
                <button
                  key={list.id}
                  onClick={() => handleSelectList(list.id)}
                  disabled={saving}
                  className={`w-full text-left px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                    user?.selectedTaskListId === list.id
                      ? 'bg-cyan-700 text-zinc-50 border-2 border-cyan-500'
                      : 'bg-zinc-800 text-zinc-300 border border-zinc-700 hover:bg-zinc-700 hover:text-zinc-50'
                  } ${saving ? 'opacity-50 cursor-not-allowed' : ''}`}
                >
                  <div className="flex items-center justify-between">
                    <span>{list.title}</span>
                    {user?.selectedTaskListId === list.id && (
                      <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                      </svg>
                    )}
                  </div>
                </button>
              ))}
            </div>
          )}
        </section>

        {/* Notifications */}
        <section className="rounded-lg border border-zinc-800 bg-zinc-900 p-6 space-y-6">
          <div>
            <h2 className="text-lg font-semibold text-zinc-200">Notifications</h2>
            <p className="text-sm text-zinc-400 mt-1">
              Control how Chronolog notifies you while you work.
            </p>
          </div>

          {/* ── Browser permission status ── */}
          <div className="space-y-3">
            <p className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
              Browser permission
            </p>

            {permission === 'unsupported' && (
              <p className="text-sm text-zinc-400">
                Browser notifications are not supported in this browser.
              </p>
            )}

            {permission === 'granted' && (
              <div className="flex items-center gap-2 text-sm text-emerald-400">
                <svg className="h-4 w-4 flex-none" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                </svg>
                Browser notifications enabled
              </div>
            )}

            {permission === 'denied' && (
              <div className="space-y-1.5">
                <p className="text-sm text-red-400">Notifications are blocked in your browser.</p>
                <p className="text-xs text-zinc-400">
                  To enable them, open your browser's site settings for this page and allow
                  notifications, then reload.
                </p>
              </div>
            )}

            {permission === 'default' && (
              <div className="flex items-center gap-4">
                <p className="text-sm text-zinc-400">
                  Chronolog hasn't been given permission to send notifications yet.
                </p>
                <button
                  onClick={handleEnableNotifications}
                  disabled={requestingPermission}
                  className="flex-none rounded-md bg-cyan-300 px-3 py-1.5 text-xs font-semibold text-zinc-950 hover:bg-cyan-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {requestingPermission ? 'Requesting…' : 'Enable'}
                </button>
              </div>
            )}
          </div>

          <div className="border-t border-zinc-800" />

          {/* ── App-level toggles ── */}
          <div className="space-y-5">
            <p className="text-xs font-semibold uppercase tracking-wide text-zinc-500">
              Notification preferences
            </p>

            <ToggleRow
              label="Tracking reminders"
              description="Get reminded every 2 hours to log how you spent your time."
              checked={prefs.trackingRemindersEnabled}
              onChange={(v) => handlePrefChange('trackingRemindersEnabled', v)}
              disabled={permission !== 'granted'}
            />

            <ToggleRow
              label="Timer notifications"
              description="Get notified when your focus timer finishes."
              checked={prefs.timerNotificationsEnabled}
              onChange={(v) => handlePrefChange('timerNotificationsEnabled', v)}
              disabled={permission !== 'granted'}
            />

            {permission !== 'granted' && (
              <p className="text-xs text-zinc-500">
                Enable browser notifications above to use these settings.
              </p>
            )}
          </div>
        </section>

        {/* Work Hours placeholder */}
        <section className="rounded-lg border border-zinc-800 bg-zinc-900 p-6 space-y-4 opacity-50">
          <div>
            <h2 className="text-lg font-semibold text-zinc-200">Work Hours</h2>
            <p className="text-sm text-zinc-400 mt-1">
              Define your typical work schedule (coming soon)
            </p>
          </div>
        </section>
      </div>
    </main>
  );
}
