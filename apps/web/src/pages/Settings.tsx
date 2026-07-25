import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { GoogleTaskList } from '../types/tasks';
import * as tasksService from '../services/tasks';
import { clearTaskCache } from '../hooks/useTasks';

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
            to="/"
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

        {/* Future Settings Sections (Placeholders) */}
        <section className="rounded-lg border border-zinc-800 bg-zinc-900 p-6 space-y-4 opacity-50">
          <div>
            <h2 className="text-lg font-semibold text-zinc-200">Notifications</h2>
            <p className="text-sm text-zinc-400 mt-1">
              Configure notification preferences (coming soon)
            </p>
          </div>
        </section>

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
