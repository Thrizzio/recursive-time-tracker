import { FormEvent, useEffect, useState } from "react";

type Activity = {
  id: number;
  name: string;
  color: string;
  createdAt: string;
};

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3000";

export function App() {
  const [activities, setActivities] = useState<Activity[]>([]);
  const [name, setName] = useState("");
  const [color, setColor] = useState("#38bdf8");
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isLoggingId, setIsLoggingId] = useState<number | null>(null);

  useEffect(() => {
    async function loadActivities() {
      const response = await fetch(`${apiUrl}/activities`);
      const data = (await response.json()) as Activity[];

      setActivities(data);
    }

    loadActivities().catch(() => {
      setError("Could not load activities.");
    });
  }, []);

  async function createActivity(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setFeedback("");
    setIsSubmitting(true);

    try {
      const response = await fetch(`${apiUrl}/activities`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ name, color }),
      });

      const data = await response.json();

      if (!response.ok) {
        setError(data.error ?? "Could not create activity.");
        return;
      }

      setActivities((currentActivities) => [...currentActivities, data]);
      setName("");
      setFeedback(`Created ${data.name}.`);
    } catch {
      setError("Could not create activity.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function logActivity(activityId: number, activityName: string) {
    setError("");
    setFeedback("");
    setIsLoggingId(activityId);

    try {
      const response = await fetch(`${apiUrl}/time-logs`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ activityId }),
      });

      const data = await response.json();

      if (!response.ok) {
        setError(data.error ?? "Could not log activity.");
        return;
      }

      const loggedAt = new Date(data.loggedAt).toLocaleTimeString([], {
        hour: "numeric",
        minute: "2-digit",
      });

      setFeedback(`Logged ${activityName} at ${loggedAt}.`);
    } catch {
      setError("Could not log activity.");
    } finally {
      setIsLoggingId(null);
    }
  }

  return (
    <main className="min-h-screen bg-zinc-950 px-5 py-8 text-zinc-50">
      <section className="mx-auto flex max-w-md flex-col gap-7">
        <header className="space-y-3">
          <p className="text-sm font-medium uppercase tracking-wide text-cyan-300">
            Chronolog
          </p>
          <div className="space-y-2">
            <h1 className="text-3xl font-semibold leading-tight">Activities</h1>
            <p className="text-base leading-7 text-zinc-300">
              Create the activities you want to track before logging time.
            </p>
          </div>
        </header>

        <form className="space-y-4" onSubmit={createActivity}>
          <label className="block space-y-2">
            <span className="text-sm font-medium text-zinc-200">Name</span>
            <input
              className="w-full rounded-md border border-zinc-700 bg-zinc-900 px-3 py-3 text-base text-zinc-50 outline-none focus:border-cyan-300"
              maxLength={100}
              onChange={(event) => setName(event.target.value)}
              placeholder="Study"
              value={name}
            />
          </label>

          <label className="block space-y-2">
            <span className="text-sm font-medium text-zinc-200">Color</span>
            <input
              className="h-12 w-20 rounded-md border border-zinc-700 bg-zinc-900 p-1"
              onChange={(event) => setColor(event.target.value)}
              type="color"
              value={color}
            />
          </label>

          {error ? <p className="text-sm text-red-300">{error}</p> : null}
          {feedback ? (
            <p className="text-sm text-emerald-300">{feedback}</p>
          ) : null}

          <button
            className="w-full rounded-md bg-cyan-300 px-4 py-3 text-base font-semibold text-zinc-950 disabled:cursor-not-allowed disabled:opacity-60"
            disabled={isSubmitting}
            type="submit"
          >
            {isSubmitting ? "Adding..." : "Add activity"}
          </button>
        </form>

        <section className="space-y-3">
          <h2 className="text-lg font-semibold">Saved activities</h2>

          {activities.length === 0 ? (
            <p className="rounded-md border border-dashed border-zinc-700 px-4 py-5 text-sm text-zinc-400">
              No activities yet.
            </p>
          ) : (
            <ul className="space-y-3">
              {activities.map((activity) => (
                <li
                  className="flex items-center justify-between gap-3 rounded-md border border-zinc-800 bg-zinc-900 px-4 py-3"
                  key={activity.id}
                >
                  <div className="flex items-center gap-3">
                    <span
                      className="h-4 w-4 rounded-full"
                      style={{ backgroundColor: activity.color }}
                    />
                    <span className="font-medium">{activity.name}</span>
                  </div>

                  <button
                    className="rounded-md bg-zinc-800 px-3 py-2 text-sm font-medium text-zinc-100 disabled:cursor-not-allowed disabled:opacity-60"
                    disabled={isLoggingId === activity.id}
                    onClick={() => logActivity(activity.id, activity.name)}
                    type="button"
                  >
                    {isLoggingId === activity.id ? "Logging..." : "Log"}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </section>
      </section>
    </main>
  );
}
