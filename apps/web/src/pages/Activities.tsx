import { FormEvent, useState, useEffect } from "react";
import { Sidebar, MenuButton } from "../components/Sidebar";

// ─── Types ────────────────────────────────────────────────────────────────────

type Activity = {
  id: number;
  name: string;
  color: string;
  createdAt: string;
};

type ActivitiesProps = {
  onLogout: () => Promise<void>;
};

// ─── Constants ────────────────────────────────────────────────────────────────

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3000";

// ─── Activities Page ──────────────────────────────────────────────────────────

export function Activities({ onLogout }: ActivitiesProps) {
  const [activities, setActivities] = useState<Activity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Create form
  const [name, setName] = useState("");
  const [color, setColor] = useState("#38bdf8");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [feedback, setFeedback] = useState("");
  const [formError, setFormError] = useState("");

  // Sidebar
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const customFetch = (input: RequestInfo | URL, init?: RequestInit) =>
    fetch(input, { ...init, credentials: "include" });

  // ── Fetch ────────────────────────────────────────────────────────────────────

  useEffect(() => {
    setLoading(true);
    customFetch(`${apiUrl}/activities`)
      .then((res) => {
        if (!res.ok) throw new Error("Server error");
        return res.json() as Promise<Activity[]>;
      })
      .then(setActivities)
      .catch(() => setError("Could not load activities."))
      .finally(() => setLoading(false));
  }, []);

  // ── Create ───────────────────────────────────────────────────────────────────

  async function handleCreate(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!name.trim()) return;
    setIsSubmitting(true);
    setFormError("");
    setFeedback("");

    try {
      const res = await customFetch(`${apiUrl}/activities`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: name.trim(), color }),
      });
      const data = await res.json();
      if (!res.ok) {
        setFormError(data.error ?? "Could not create activity.");
        return;
      }
      setActivities((prev) => [...prev, data]);
      setName("");
      setFeedback(`"${data.name}" added.`);
    } catch {
      setFormError("Network error. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  }

  // ── Render ───────────────────────────────────────────────────────────────────

  return (
    <main className="min-h-screen bg-zinc-950 px-5 py-8 text-zinc-50 pb-20">
      <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      <div className="mx-auto max-w-lg space-y-8">

        {/* ── Header ────────────────────────────────────────────────────────── */}
        <header className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <MenuButton onClick={() => setSidebarOpen(true)} />
            <div className="space-y-0.5">
              <p className="text-xs font-semibold uppercase tracking-wide text-cyan-400">
                Chronolog
              </p>
              <h1 className="text-2xl font-bold leading-tight">Activities</h1>
            </div>
          </div>
          <button
            onClick={onLogout}
            className="text-xs font-medium text-zinc-400 hover:text-zinc-200 transition-colors"
          >
            Sign out
          </button>
        </header>

        {/* ── Tagline ───────────────────────────────────────────────────────── */}
        <p className="text-sm text-zinc-400">
          What are you spending your time on? Create the activities you want to
          track, then log time against them from the Dashboard.
        </p>

        {/* ── Create form ───────────────────────────────────────────────────── */}
        <section className="rounded-lg border border-zinc-800 bg-zinc-900 p-5 space-y-4">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-zinc-400">
            Add activity
          </h2>

          <form onSubmit={handleCreate} className="space-y-4">
            <div className="flex gap-3 items-end">
              <label className="flex-1 space-y-1.5">
                <span className="text-xs font-medium text-zinc-400">Name</span>
                <input
                  className="w-full rounded-md border border-zinc-700 bg-zinc-950 px-3 py-2.5 text-sm text-zinc-50 outline-none focus:border-cyan-400 transition-colors"
                  maxLength={100}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Coding, Reading, Exercise…"
                  value={name}
                  required
                />
              </label>
              <label className="space-y-1.5">
                <span className="text-xs font-medium text-zinc-400">Color</span>
                <input
                  className="block h-10 w-14 rounded-md border border-zinc-700 bg-zinc-950 p-1 cursor-pointer"
                  type="color"
                  value={color}
                  onChange={(e) => setColor(e.target.value)}
                />
              </label>
            </div>

            {formError && (
              <p className="text-sm text-red-400">{formError}</p>
            )}
            {feedback && (
              <p className="text-sm text-emerald-400">{feedback}</p>
            )}

            <button
              type="submit"
              disabled={isSubmitting || !name.trim()}
              className="w-full rounded-md bg-cyan-300 px-4 py-2.5 text-sm font-semibold text-zinc-950 hover:bg-cyan-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {isSubmitting ? "Adding…" : "+ Add activity"}
            </button>
          </form>
        </section>

        {/* ── Activity list ─────────────────────────────────────────────────── */}
        <section className="space-y-3">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-zinc-400">
            Your activities
          </h2>

          {loading ? (
            <div className="space-y-2">
              {[1, 2, 3].map((i) => (
                <div
                  key={i}
                  className="h-12 animate-pulse rounded-lg border border-zinc-800 bg-zinc-800/50"
                />
              ))}
            </div>
          ) : error ? (
            <p className="rounded-lg border border-red-900 bg-red-950/40 px-4 py-3 text-sm text-red-300">
              {error}
            </p>
          ) : activities.length === 0 ? (
            <div className="rounded-lg border border-dashed border-zinc-700 px-5 py-10 text-center">
              <p className="text-sm font-medium text-zinc-400">
                No activities yet.
              </p>
              <p className="mt-1 text-xs text-zinc-500">
                Add your first activity above to start tracking.
              </p>
            </div>
          ) : (
            <ul className="space-y-2">
              {activities.map((activity) => (
                <li
                  key={activity.id}
                  className="flex items-center gap-3 rounded-lg border border-zinc-800 bg-zinc-900 px-4 py-3"
                >
                  <span
                    className="h-3 w-3 flex-none rounded-full"
                    style={{ backgroundColor: activity.color }}
                  />
                  <span className="flex-1 truncate text-sm font-medium text-zinc-200">
                    {activity.name}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </main>
  );
}
