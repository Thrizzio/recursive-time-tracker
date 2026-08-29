import { useState, useEffect } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { Dashboard } from './pages/Dashboard';
import { Settings } from './pages/Settings';
import { Activities } from './pages/Activities';

type User = {
  id: number;
  email: string;
  name: string;
  avatarUrl: string;
  trackingStartedAt: string | null;
  selectedTaskListId: string | null;
};

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3000";

export function App() {
  const [user, setUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true);

  const customFetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    return fetch(input, {
      ...init,
      credentials: "include",
    });
  };

  async function checkAuth() {
    try {
      const res = await customFetch(`${apiUrl}/auth/me`);
      if (res.ok) {
        setUser(await res.json());
      }
    } catch {
      // ignore
    } finally {
      setAuthLoading(false);
    }
  }

  async function logout() {
    await customFetch(`${apiUrl}/auth/logout`, { method: "POST" });
    setUser(null);
  }

  useEffect(() => {
    checkAuth();
  }, []);

  if (authLoading) {
    return (
      <main className="min-h-screen bg-zinc-950 flex items-center justify-center text-zinc-50">
        <div className="animate-pulse flex flex-col items-center gap-4">
          <div className="h-8 w-8 rounded-full border-2 border-cyan-400 border-t-transparent animate-spin" />
        </div>
      </main>
    );
  }

  if (!user) {
    return (
      <main className="min-h-screen bg-zinc-950 flex items-center justify-center text-zinc-50 px-5">
        <div className="w-full max-w-sm rounded-2xl border border-zinc-800 bg-zinc-900 p-8 text-center space-y-6 shadow-xl">
          <div className="space-y-2">
            <h1 className="text-2xl font-bold text-zinc-50">Log in to Chronolog</h1>
            <p className="text-sm text-zinc-400">Track your time with seamless multi-device sync.</p>
          </div>
          <a
            href={`${apiUrl}/auth/google`}
            className="flex w-full items-center justify-center gap-3 rounded-lg bg-zinc-50 px-4 py-3 text-sm font-semibold text-zinc-900 hover:bg-zinc-200 transition-colors"
          >
            <svg className="h-5 w-5" viewBox="0 0 24 24">
              <path
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                fill="#4285F4"
              />
              <path
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                fill="#34A853"
              />
              <path
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                fill="#FBBC05"
              />
              <path
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                fill="#EA4335"
              />
            </svg>
            Continue with Google
          </a>
        </div>
      </main>
    );
  }

  return (
    <Routes>
      {/* Legacy root path — redirect to /dashboard */}
      <Route path="/" element={<Navigate to="/dashboard" replace />} />

      <Route
        path="/dashboard"
        element={
          <Dashboard
            user={user}
            onUserUpdate={checkAuth}
            onLogout={logout}
          />
        }
      />
      <Route
        path="/activities"
        element={<Activities onLogout={logout} />}
      />
      <Route
        path="/settings"
        element={
          <Settings
            user={user}
            onUserUpdate={checkAuth}
          />
        }
      />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}

