import {
  FormEvent,
  useCallback,
  useEffect,
  useRef,
  useState,
} from "react";

// ─── Types ────────────────────────────────────────────────────────────────────

type User = {
  id: number;
  email: string;
  name: string;
  avatarUrl: string;
};

type GoogleTask = {
  id: string; // "listId|taskId"
  title: string;
  notes?: string;
  taskListName: string;
};

type Activity = {
  id: number;
  name: string;
  color: string;
  createdAt: string;
};

type Allocation = {
  activityId: number;
  percentage: number; // integer 0–100; all allocations sum to exactly 100
};

/** One allocation row inside a TimeBlockFull (from GET or POST /time-blocks) */
type BlockAllocation = {
  id: number;
  activityId: number;
  percentage: number;
  durationSeconds: number;
  activity: { id: number; name: string; color: string };
};

/** Full time block with nested allocations — returned by both GET and POST /time-blocks */
type TimeBlockFull = {
  id: number;
  startTime: string;
  endTime: string;
  createdAt: string;
  elapsedSeconds: number;
  allocations: BlockAllocation[];
};

// ─── Constants ────────────────────────────────────────────────────────────────

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3000";
const trackingStartedAtStorageKey = "chronolog.trackingStartedAt";
const MIN_SEGMENT_PCT = 2;

// ─── Pure helpers ─────────────────────────────────────────────────────────────

function formatTime(date: Date) {
  return date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

function formatElapsedClock(start: Date, end: Date) {
  const totalSeconds = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 1000));
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  return [h, m, s].map((v) => v.toString().padStart(2, "0")).join(":");
}

function formatMinutes(totalMinutes: number) {
  const mins = Math.round(totalMinutes);
  if (mins <= 0) return "0m";
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h ${m}m`;
}

/** Format a raw second count as "3h 20m", "45m", "1h", etc. */
function formatSeconds(totalSeconds: number) {
  return formatMinutes(totalSeconds / 60);
}

function formatElapsedHumanShort(start: Date, end: Date) {
  const totalSeconds = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 1000));
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  if (h === 0 && m === 0) return "less than a minute";
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h ${m}m`;
}

function buildEqualAllocations(activityIds: number[]): Allocation[] {
  const n = activityIds.length;
  if (n === 0) return [];
  const base = Math.floor(100 / n);
  const remainder = 100 - base * n;
  return activityIds.map((id, i) => ({
    activityId: id,
    percentage: base + (i === 0 ? remainder : 0),
  }));
}

function moveDivider(
  allocations: Allocation[],
  dividerIndex: number,
  deltaPct: number,
): Allocation[] {
  const left = allocations[dividerIndex];
  const right = allocations[dividerIndex + 1];
  if (!left || !right) return allocations;

  const maxIncrease = right.percentage - MIN_SEGMENT_PCT;
  const maxDecrease = left.percentage - MIN_SEGMENT_PCT;
  const actualDelta = Math.max(-maxDecrease, Math.min(maxIncrease, deltaPct));

  if (actualDelta === 0) return allocations;

  return allocations.map((a, i) => {
    if (i === dividerIndex) return { ...a, percentage: a.percentage + actualDelta };
    if (i === dividerIndex + 1) return { ...a, percentage: a.percentage - actualDelta };
    return a;
  });
}

// ─── App ─────────────────────────────────────────────────────────────────────

type ModalView = "select" | "allocate" | "tasks";

export function App() {
  // Auth state
  const [user, setUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true);

  // Core data
  const [activities, setActivities] = useState<Activity[]>([]);
  const [timeBlocks, setTimeBlocks] = useState<TimeBlockFull[]>([]);
  const [timeBlocksLoading, setTimeBlocksLoading] = useState(true);
  const [timeBlocksError, setTimeBlocksError] = useState("");
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState("");

  // Activity creation form
  const [name, setName] = useState("");
  const [color, setColor] = useState("#38bdf8");
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Session / timer
  const [trackingStartedAt, setTrackingStartedAt] = useState<string | null>(() =>
    localStorage.getItem(trackingStartedAtStorageKey),
  );
  const [now, setNow] = useState(() => new Date());

  // Log dialog — Step 1: select activities
  const [modalView, setModalView] = useState<ModalView>("select");
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalElapsedText, setModalElapsedText] = useState("");
  const [modalTotalMinutes, setModalTotalMinutes] = useState(0);
  const [selectedActivityIds, setSelectedActivityIds] = useState<number[]>([]);

  // Log dialog — Step 2: allocate percentages
  const [allocations, setAllocations] = useState<Allocation[]>([]);
  const [isSaving, setIsSaving] = useState(false);
  const [modalError, setModalError] = useState("");

  // Log dialog — Step 3: Google Tasks
  const [incompleteTasks, setIncompleteTasks] = useState<GoogleTask[]>([]);
  const [tasksLoading, setTasksLoading] = useState(false);
  const [tasksError, setTasksError] = useState("");
  const [completedTaskIds, setCompletedTaskIds] = useState<string[]>([]);

  // Derived
  const hasTrackingStarted = trackingStartedAt !== null;
  const boundary = trackingStartedAt ? new Date(trackingStartedAt) : null;
  const timeSinceBoundary = boundary ? formatElapsedClock(boundary, now) : "00:00:00";
  const boundaryLabel = boundary ? `Started ${formatTime(boundary)}` : "Waiting to start";

  // ── Fetch helpers ─────────────────────────────────────────────────────────

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

  async function fetchActivities() {
    const res = await customFetch(`${apiUrl}/activities`);
    if (!res.ok) throw new Error("Server error");
    const data = (await res.json()) as Activity[];
    setActivities(data);
  }

  async function fetchTimeBlocks() {
    setTimeBlocksLoading(true);
    setTimeBlocksError("");
    try {
      const res = await customFetch(`${apiUrl}/time-blocks`);
      if (!res.ok) throw new Error("Server error");
      const data = (await res.json()) as TimeBlockFull[];
      setTimeBlocks(data);
    } catch {
      setTimeBlocksError("Could not load time blocks.");
    } finally {
      setTimeBlocksLoading(false);
    }
  }

  // ── Effects ───────────────────────────────────────────────────────────────

  useEffect(() => {
    checkAuth();
  }, []);

  useEffect(() => {
    if (user) {
      fetchActivities().catch(() => setError("Could not load activities."));
      fetchTimeBlocks();
    }
  }, [user]);

  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(id);
  }, []);

  // ── Activity creation ─────────────────────────────────────────────────────

  async function createActivity(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setFeedback("");
    setIsSubmitting(true);
    try {
      const response = await customFetch(`${apiUrl}/activities`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, color }),
      });
      const data = await response.json();
      if (!response.ok) {
        setError(data.error ?? "Could not create activity.");
        return;
      }
      setActivities((prev) => [...prev, data]);
      setName("");
      setFeedback(`Created ${data.name}.`);
    } catch {
      setError("Could not create activity.");
    } finally {
      setIsSubmitting(false);
    }
  }

  // ── Start tracking ────────────────────────────────────────────────────────

  function startTracking() {
    const startedAt = new Date().toISOString();
    localStorage.setItem(trackingStartedAtStorageKey, startedAt);
    setTrackingStartedAt(startedAt);
    setNow(new Date(startedAt));
    setFeedback(`Tracking started at ${formatTime(new Date(startedAt))}.`);
    setError("");
  }

  // ── Log dialog — Step 1 (select) ──────────────────────────────────────────

  function openModal() {
    if (!boundary) return;
    setModalElapsedText(formatElapsedHumanShort(boundary, now));
    setModalTotalMinutes(Math.max(0, (now.getTime() - boundary.getTime()) / 60000));
    setSelectedActivityIds([]);
    setAllocations([]);
    setModalError("");
    setModalView("select");
    setIsModalOpen(true);
  }

  function closeModal() {
    setIsModalOpen(false);
    setSelectedActivityIds([]);
    setAllocations([]);
    setModalError("");
    setIsSaving(false);
    setCompletedTaskIds([]);
  }

  function toggleActivity(activityId: number) {
    setSelectedActivityIds((prev) =>
      prev.includes(activityId) ? prev.filter((id) => id !== activityId) : [...prev, activityId],
    );
  }

  function proceedToAllocate() {
    setAllocations(buildEqualAllocations(selectedActivityIds));
    setModalError("");
    setModalView("allocate");
  }

  function toggleTask(id: string) {
    setCompletedTaskIds((prev) =>
      prev.includes(id) ? prev.filter((t) => t !== id) : [...prev, id]
    );
  }

  async function loadTasks() {
    setTasksLoading(true);
    setTasksError("");
    setModalView("tasks");
    try {
      const res = await customFetch(`${apiUrl}/tasks`);
      if (res.ok) {
        setIncompleteTasks(await res.json());
      } else {
        setTasksError("Could not load tasks from Google.");
      }
    } catch {
      setTasksError("Network error while loading tasks.");
    } finally {
      setTasksLoading(false);
    }
  }

  // ── Log dialog — Step 2/3 (allocate/tasks) ───────────────────────────────────────

  async function handleSave() {
    if (isSaving) return;
    setIsSaving(true);
    setModalError("");

    try {
      const response = await customFetch(`${apiUrl}/log-session`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          allocations: allocations.map((a) => ({
            activityId: a.activityId,
            percentage: a.percentage,
          })),
          completedTaskIds,
        }),
      });

      const data = (await response.json()) as any;

      if (!response.ok) {
        setModalError(data.error ?? "Could not save. Please try again.");
        return;
      }

      const block = data.block;

      // Advance tracking boundary to the server's authoritative end_time
      localStorage.setItem(trackingStartedAtStorageKey, block.endTime);
      setTrackingStartedAt(block.endTime);
      setNow(new Date(block.endTime));

      // Refresh timeline — prepend the new block (it's the newest)
      setTimeBlocks((prev) => [block, ...prev]);

      closeModal();
      setFeedback(
        `Saved — ${formatSeconds(block.elapsedSeconds)} logged across ${block.allocations.length} activit${block.allocations.length === 1 ? "y" : "ies"}.${data.warning ? " (Note: " + data.warning + ")" : ""}`
      );
      setError("");
    } catch {
      setModalError("Network error. Check your connection and try again.");
    } finally {
      setIsSaving(false);
    }
  }

  // ── Derived for AllocateView ───────────────────────────────────────────────

  const selectedActivities = allocations
    .map((a) => activities.find((act) => act.id === a.activityId))
    .filter((a): a is Activity => a !== undefined);

  // ─── Render ────────────────────────────────────────────────────────────────

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
    <main className="min-h-screen bg-zinc-950 px-5 py-8 text-zinc-50 pb-20">
      <section className="mx-auto flex max-w-md flex-col gap-8">

        {/* ── Header ─────────────────────────────────────────────────────── */}
        <header className="flex items-center justify-between">
          <div className="space-y-1">
            <p className="text-xs font-semibold uppercase tracking-wide text-cyan-400">Chronolog</p>
            <h1 className="text-2xl font-bold leading-tight">Time Tracker</h1>
          </div>
          <div className="flex items-center gap-3">
            <div className="flex flex-col items-end hidden sm:flex">
              <span className="text-sm font-semibold">{user.name}</span>
              <button onClick={logout} className="text-xs text-zinc-400 hover:text-zinc-200">Sign out</button>
            </div>
            {user.avatarUrl ? (
              <img src={user.avatarUrl} alt={user.name} className="h-10 w-10 rounded-full border border-zinc-700 bg-zinc-800" />
            ) : (
              <div className="h-10 w-10 rounded-full border border-zinc-700 bg-zinc-800 flex items-center justify-center font-bold text-zinc-400">
                {user.name.charAt(0)}
              </div>
            )}
            <button onClick={logout} className="sm:hidden text-xs font-medium text-zinc-400 hover:text-zinc-200 bg-zinc-900 px-2 py-1 rounded">Logout</button>
          </div>
        </header>

        {/* ── Start tracking CTA ─────────────────────────────────────────── */}
        {!hasTrackingStarted ? (
          <section className="space-y-3 rounded-md border border-cyan-700 bg-cyan-950/40 px-4 py-4">
            <div className="space-y-1">
              <h2 className="text-lg font-semibold">Start tracking</h2>
              <p className="text-sm leading-6 text-cyan-100">
                Press this once when you want Chronolog to begin counting time.
              </p>
            </div>
            <button
              className="w-full rounded-md bg-cyan-300 px-4 py-3 text-base font-semibold text-zinc-950 hover:bg-cyan-200 transition-colors"
              onClick={startTracking}
              type="button"
            >
              Start tracking
            </button>
          </section>
        ) : null}

        {/* ── Live timer + Log Activity ────────────────────────────────────── */}
        {hasTrackingStarted ? (
          <section className="rounded-md border border-zinc-800 bg-zinc-900 px-4 py-4">
            <div className="flex items-end justify-between gap-4">
              <div className="space-y-1">
                <h2 className="text-sm font-medium uppercase tracking-wide text-zinc-400">
                  Since last log
                </h2>
                <p className="text-4xl font-semibold tabular-nums text-zinc-50">
                  {timeSinceBoundary}
                </p>
              </div>
              <p className="pb-1 text-right text-sm text-zinc-400">{boundaryLabel}</p>
            </div>
            <button
              className="mt-4 w-full rounded-md bg-cyan-300 px-4 py-3 text-base font-semibold text-zinc-950 hover:bg-cyan-200 transition-colors duration-150 active:scale-[0.98]"
              onClick={openModal}
              type="button"
            >
              Log Activity
            </button>
          </section>
        ) : null}

        {/* ── Timeline ────────────────────────────────────────────────────── */}
        <section className="space-y-3">
          <h2 className="text-lg font-semibold">Today's blocks</h2>
          <Timeline
            blocks={timeBlocks}
            loading={timeBlocksLoading}
            error={timeBlocksError}
          />
        </section>

        {/* ── Create activity form ────────────────────────────────────────── */}
        <section className="space-y-4">
          <h2 className="text-lg font-semibold">Activities</h2>
          <p className="text-sm text-zinc-400">
            Create the activities you want to track before logging time.
          </p>
          <form className="space-y-4" onSubmit={createActivity}>
            <label className="block space-y-2">
              <span className="text-sm font-medium text-zinc-200">Name</span>
              <input
                className="w-full rounded-md border border-zinc-700 bg-zinc-900 px-3 py-3 text-base text-zinc-50 outline-none focus:border-cyan-300"
                maxLength={100}
                onChange={(e) => setName(e.target.value)}
                placeholder="Study"
                value={name}
              />
            </label>
            <label className="block space-y-2">
              <span className="text-sm font-medium text-zinc-200">Color</span>
              <input
                className="h-12 w-20 rounded-md border border-zinc-700 bg-zinc-900 p-1"
                onChange={(e) => setColor(e.target.value)}
                type="color"
                value={color}
              />
            </label>

            {error ? <p className="text-sm text-red-300">{error}</p> : null}
            {feedback ? <p className="text-sm text-emerald-300">{feedback}</p> : null}

            <button
              className="w-full rounded-md bg-cyan-300 px-4 py-3 text-base font-semibold text-zinc-950 disabled:cursor-not-allowed disabled:opacity-60"
              disabled={isSubmitting}
              type="submit"
            >
              {isSubmitting ? "Adding…" : "Add activity"}
            </button>
          </form>

          {/* Saved activities list */}
          {activities.length === 0 ? (
            <p className="rounded-md border border-dashed border-zinc-700 px-4 py-5 text-sm text-zinc-400">
              No activities yet.
            </p>
          ) : (
            <ul className="space-y-2">
              {activities.map((activity) => (
                <li
                  className="flex items-center gap-3 rounded-md border border-zinc-800 bg-zinc-900 px-4 py-3"
                  key={activity.id}
                >
                  <span
                    className="h-4 w-4 flex-none rounded-full"
                    style={{ backgroundColor: activity.color }}
                  />
                  <span className="truncate font-medium">{activity.name}</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </section>

      {/* ── Modal overlay ────────────────────────────────────────────────────── */}
      {isModalOpen ? (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-zinc-950/80 backdrop-blur-sm p-4 sm:items-center"
          onClick={(e) => { if (e.target === e.currentTarget) closeModal(); }}
        >
          <div className="w-full max-w-md rounded-2xl border border-zinc-800 bg-zinc-900 shadow-2xl">
            {modalView === "select" ? (
              <SelectView
                activities={activities}
                elapsedText={modalElapsedText}
                selectedActivityIds={selectedActivityIds}
                onToggle={toggleActivity}
                onCancel={closeModal}
                onContinue={proceedToAllocate}
              />
            ) : modalView === "allocate" ? (
              <AllocateView
                activities={selectedActivities}
                allocations={allocations}
                elapsedText={modalElapsedText}
                totalMinutes={modalTotalMinutes}
                onAllocationsChange={setAllocations}
                onBack={() => setModalView("select")}
                onNext={loadTasks}
                isSaving={tasksLoading}
                saveError={modalError}
              />
            ) : modalView === "tasks" ? (
              <CompletedTasksView
                incompleteTasks={incompleteTasks}
                tasksLoading={tasksLoading}
                tasksError={tasksError}
                completedTaskIds={completedTaskIds}
                onToggleTask={toggleTask}
                onBack={() => setModalView("allocate")}
                onSkip={() => { setCompletedTaskIds([]); handleSave(); }}
                onSave={handleSave}
                isSaving={isSaving}
                saveError={modalError}
              />
            ) : null}
          </div>
        </div>
      ) : null}
    </main>
  );
}

// ─── Timeline ─────────────────────────────────────────────────────────────────

type TimelineProps = {
  blocks: TimeBlockFull[];
  loading: boolean;
  error: string;
};

function Timeline({ blocks, loading, error }: TimelineProps) {
  if (loading) {
    return (
      <div className="space-y-3">
        {[1, 2].map((i) => (
          <div
            key={i}
            className="h-16 animate-pulse rounded-xl border border-zinc-800 bg-zinc-800/50"
          />
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <p className="rounded-xl border border-red-900 bg-red-950/40 px-4 py-4 text-sm text-red-300">
        {error}
      </p>
    );
  }

  if (blocks.length === 0) {
    return (
      <div className="rounded-xl border border-dashed border-zinc-700 px-5 py-8 text-center">
        <p className="text-sm font-medium text-zinc-300">No time blocks yet.</p>
        <p className="mt-1 text-sm text-zinc-500">
          Log your first retrospective block to begin tracking your day.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {blocks.map((block, index) => (
        <TimeBlockCard
          key={block.id}
          block={block}
          defaultExpanded={index === 0}
        />
      ))}
    </div>
  );
}

// ─── TimeBlockCard ────────────────────────────────────────────────────────────

type TimeBlockCardProps = {
  block: TimeBlockFull;
  defaultExpanded: boolean;
};

function TimeBlockCard({ block, defaultExpanded }: TimeBlockCardProps) {
  const [expanded, setExpanded] = useState(defaultExpanded);

  const start = new Date(block.startTime);
  const end = new Date(block.endTime);
  const timeRange = `${formatTime(start)} → ${formatTime(end)}`;
  const duration = formatSeconds(block.elapsedSeconds);

  return (
    <div className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900">
      {/* ── Header row (always visible) ────────────────────────────────── */}
      <button
        type="button"
        onClick={() => setExpanded((v) => !v)}
        className="flex w-full items-center justify-between gap-3 px-4 py-3.5 text-left hover:bg-zinc-800/60 transition-colors"
      >
        <div className="flex items-center gap-2 min-w-0">
          {/* Chevron */}
          <span
            className={`flex-none text-zinc-500 transition-transform duration-200 ${expanded ? "rotate-180" : ""}`}
            aria-hidden
          >
            <ChevronDownIcon />
          </span>

          <span className="truncate text-sm font-semibold text-zinc-100">
            {timeRange}
          </span>
        </div>

        {/* Duration badge */}
        <span className="shrink-0 rounded-md bg-zinc-800 px-2.5 py-1 text-xs font-semibold tabular-nums text-zinc-300">
          {duration}
        </span>
      </button>

      {/* ── Expanded body ───────────────────────────────────────────────── */}
      {expanded ? (
        <div className="border-t border-zinc-800 px-4 pb-4 pt-3 space-y-1">
          {block.allocations.length === 0 ? (
            <p className="text-xs text-zinc-500">No allocations recorded.</p>
          ) : (
            block.allocations.map((alloc) => (
              <ActivityAllocationRow key={alloc.id} allocation={alloc} />
            ))
          )}
        </div>
      ) : null}
    </div>
  );
}

// ─── ActivityAllocationRow ────────────────────────────────────────────────────

type ActivityAllocationRowProps = {
  allocation: BlockAllocation;
};

function ActivityAllocationRow({ allocation }: ActivityAllocationRowProps) {
  const { activity, durationSeconds, percentage } = allocation;

  return (
    <div className="flex items-center justify-between gap-3 rounded-lg px-3 py-2.5 hover:bg-zinc-800/50 transition-colors">
      {/* Color swatch + name */}
      <div className="flex items-center gap-2.5 min-w-0">
        <span
          className="h-2.5 w-2.5 flex-none rounded-full"
          style={{ backgroundColor: activity.color }}
        />
        <span className="truncate text-sm font-medium text-zinc-200">
          {activity.name}
        </span>
      </div>

      {/* Duration + percentage */}
      <div className="flex items-baseline gap-2.5 shrink-0 tabular-nums">
        <span className="text-sm font-semibold text-zinc-100">
          {formatSeconds(durationSeconds)}
        </span>
        <span className="text-xs text-zinc-500 w-8 text-right">
          {percentage}%
        </span>
      </div>
    </div>
  );
}

// ─── ChevronDownIcon ──────────────────────────────────────────────────────────

function ChevronDownIcon() {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 14 14"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <polyline points="2 5 7 10 12 5" />
    </svg>
  );
}

// ─── SelectView ───────────────────────────────────────────────────────────────

type SelectViewProps = {
  activities: Activity[];
  elapsedText: string;
  selectedActivityIds: number[];
  onToggle: (id: number) => void;
  onCancel: () => void;
  onContinue: () => void;
};

function SelectView({
  activities, elapsedText, selectedActivityIds, onToggle, onCancel, onContinue,
}: SelectViewProps) {
  return (
    <div className="flex flex-col">
      <div className="px-6 pt-6 pb-4">
        <p className="text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-1">
          How was the last
        </p>
        <p className="text-3xl font-bold text-zinc-50">{elapsedText}</p>
        <p className="text-xs font-semibold uppercase tracking-wider text-zinc-500 mt-1">spent?</p>
      </div>

      <div className="h-px bg-zinc-800" />

      <div className="overflow-y-auto max-h-72 px-3 py-3 space-y-1">
        {activities.length === 0 ? (
          <p className="px-3 py-6 text-center text-sm text-zinc-500">No activities saved yet.</p>
        ) : (
          activities.map((activity) => {
            const checked = selectedActivityIds.includes(activity.id);
            return (
              <label
                key={activity.id}
                className={`flex items-center justify-between gap-3 rounded-xl px-4 py-3 cursor-pointer select-none transition-all duration-100 ${checked
                  ? "bg-zinc-800 border border-zinc-700"
                  : "bg-zinc-900/40 border border-transparent hover:bg-zinc-800/50"
                  }`}
              >
                <div className="flex items-center gap-3 min-w-0">
                  <span
                    className="h-3 w-3 flex-none rounded-full"
                    style={{ backgroundColor: activity.color }}
                  />
                  <span className="truncate text-sm font-medium text-zinc-200">{activity.name}</span>
                </div>
                <input
                  type="checkbox"
                  checked={checked}
                  onChange={() => onToggle(activity.id)}
                  className="h-4 w-4 rounded accent-cyan-400 cursor-pointer"
                />
              </label>
            );
          })
        )}
      </div>

      <div className="h-px bg-zinc-800" />

      <div className="flex gap-3 px-6 py-4">
        <button
          type="button"
          onClick={onCancel}
          className="flex-1 rounded-xl border border-zinc-700 bg-zinc-900 py-3 text-sm font-semibold text-zinc-300 hover:bg-zinc-800 hover:text-zinc-50 transition-colors"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={onContinue}
          disabled={selectedActivityIds.length === 0}
          className="flex-1 rounded-xl bg-cyan-300 py-3 text-sm font-bold text-zinc-950 hover:bg-cyan-200 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          Continue
        </button>
      </div>
    </div>
  );
}

// ─── AllocateView ─────────────────────────────────────────────────────────────

type AllocateViewProps = {
  activities: Activity[];
  allocations: Allocation[];
  elapsedText: string;
  totalMinutes: number;
  onAllocationsChange: (updated: Allocation[]) => void;
  onBack: () => void;
  onNext: () => void;
  isSaving: boolean;
  saveError: string;
};

function AllocateView({
  activities, allocations, elapsedText, totalMinutes,
  onAllocationsChange, onBack, onNext, isSaving, saveError,
}: AllocateViewProps) {
  return (
    <div className="flex flex-col">
      <div className="px-6 pt-6 pb-4">
        <p className="text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-1">
          How was the last
        </p>
        <p className="text-3xl font-bold text-zinc-50">{elapsedText}</p>
        <p className="text-xs font-semibold uppercase tracking-wider text-zinc-500 mt-1">spent?</p>
      </div>

      <div className="h-px bg-zinc-800" />

      {/* Allocation bar */}
      <div className="px-6 pt-5 pb-2">
        <AllocationBar
          activities={activities}
          allocations={allocations}
          onChange={onAllocationsChange}
        />
      </div>

      {/* Legend */}
      <div className="divide-y divide-zinc-800/60 px-6 pb-2">
        {allocations.map((alloc) => {
          const activity = activities.find((a) => a.id === alloc.activityId);
          if (!activity) return null;
          const mins = formatMinutes((alloc.percentage / 100) * totalMinutes);
          return (
            <div key={alloc.activityId} className="flex items-center justify-between gap-4 py-3">
              <div className="flex items-center gap-2.5 min-w-0">
                <span
                  className="h-3 w-3 flex-none rounded-full"
                  style={{ backgroundColor: activity.color }}
                />
                <span className="truncate text-sm font-semibold text-zinc-200">
                  {activity.name}
                </span>
              </div>
              <div className="flex items-baseline gap-3 shrink-0 tabular-nums">
                <span className="text-sm font-medium text-zinc-200">{mins}</span>
                <span className="text-xs font-semibold text-zinc-500 w-10 text-right">
                  {alloc.percentage}%
                </span>
              </div>
            </div>
          );
        })}
      </div>

      <div className="h-px bg-zinc-800" />

      {/* Inline error */}
      {saveError ? (
        <p className="mx-6 mt-3 rounded-lg bg-red-950/60 border border-red-800 px-4 py-2.5 text-sm text-red-300">
          {saveError}
        </p>
      ) : null}

      {/* Footer */}
      <div className="flex gap-3 px-6 py-4">
        <button
          type="button"
          onClick={onBack}
          disabled={isSaving}
          className="flex-1 rounded-xl border border-zinc-700 bg-zinc-900 py-3 text-sm font-semibold text-zinc-300 hover:bg-zinc-800 hover:text-zinc-50 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          Back
        </button>
        <button
          type="button"
          onClick={onNext}
          disabled={isSaving}
          className="flex-1 rounded-xl bg-cyan-300 py-3 text-sm font-bold text-zinc-950 hover:bg-cyan-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {isSaving ? "Loading…" : "Next"}
        </button>
      </div>
    </div>
  );
}

// ─── AllocationBar ────────────────────────────────────────────────────────────

type AllocationBarProps = {
  activities: Activity[];
  allocations: Allocation[];
  onChange: (updated: Allocation[]) => void;
};

export function AllocationBar({ activities, allocations, onChange }: AllocationBarProps) {
  const barRef = useRef<HTMLDivElement>(null);
  const dragging = useRef<{
    dividerIndex: number;
    startX: number;
    startAllocations: Allocation[];
  } | null>(null);

  const activityMap = Object.fromEntries(activities.map((a) => [a.id, a]));

  function pctFromPixelDelta(deltaX: number): number {
    const bar = barRef.current;
    if (!bar) return 0;
    const width = bar.getBoundingClientRect().width;
    return (deltaX / width) * 100;
  }

  const onPointerDown = useCallback(
    (dividerIndex: number) => (e: React.PointerEvent<HTMLDivElement>) => {
      e.preventDefault();
      e.stopPropagation();
      (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
      dragging.current = { dividerIndex, startX: e.clientX, startAllocations: allocations };
    },
    [allocations],
  );

  const onPointerMove = useCallback(
    (e: React.PointerEvent<HTMLDivElement>) => {
      if (!dragging.current) return;
      const { dividerIndex, startX, startAllocations } = dragging.current;
      const deltaPct = pctFromPixelDelta(e.clientX - startX);
      const rounded = Math.round(deltaPct);
      if (rounded === 0) return;
      const updated = moveDivider(startAllocations, dividerIndex, rounded);
      onChange(updated);
      dragging.current = { dividerIndex, startX: e.clientX, startAllocations: updated };
    },
    [onChange],
  );

  const onPointerUp = useCallback(() => { dragging.current = null; }, []);

  return (
    <div
      ref={barRef}
      className="relative flex h-10 w-full overflow-hidden rounded-xl touch-none select-none"
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
    >
      {allocations.map((alloc, i) => {
        const activity = activityMap[alloc.activityId];
        if (!activity) return null;
        const isLast = i === allocations.length - 1;

        return (
          <div
            key={alloc.activityId}
            className="relative h-full transition-none"
            style={{ width: `${alloc.percentage}%`, backgroundColor: activity.color }}
          >
            {!isLast ? (
              <div
                className="absolute right-0 top-0 bottom-0 z-10 flex items-center justify-center"
                style={{ width: "18px", transform: "translateX(50%)", cursor: "col-resize" }}
                onPointerDown={onPointerDown(i)}
              >
                <div className="h-6 w-1.5 rounded-full bg-zinc-900/70 shadow-sm" />
              </div>
            ) : null}
          </div>
        );
      })}
    </div>
  );
}
// ─── CompletedTasksView ─────────────────────────────────────────────────────────────

type CompletedTasksViewProps = {
  incompleteTasks: GoogleTask[];
  tasksLoading: boolean;
  tasksError: string;
  completedTaskIds: string[];
  onToggleTask: (id: string) => void;
  onBack: () => void;
  onSkip: () => void;
  onSave: () => void;
  isSaving: boolean;
  saveError: string;
};

export function CompletedTasksView({
  incompleteTasks, tasksLoading, tasksError, completedTaskIds,
  onToggleTask, onBack, onSkip, onSave, isSaving, saveError
}: CompletedTasksViewProps) {
  return (
    <div className="flex flex-col">
      <div className="px-6 pt-6 pb-4 space-y-1">
        <h2 className="text-xl font-bold text-zinc-50">Did you complete any tasks during this time?</h2>
        <p className="text-sm text-zinc-400">Select any Google Tasks you finished.</p>
      </div>

      <div className="h-px bg-zinc-800" />

      <div className="overflow-y-auto max-h-72 px-3 py-3 space-y-1 custom-scrollbar">
        {tasksLoading ? (
          <div className="flex justify-center py-10">
            <div className="h-8 w-8 rounded-full border-2 border-cyan-400 border-t-transparent animate-spin" />
          </div>
        ) : tasksError ? (
          <p className="px-3 py-6 text-center text-sm text-red-400">{tasksError}</p>
        ) : incompleteTasks.length === 0 ? (
          <p className="px-3 py-6 text-center text-sm text-zinc-500">No incomplete tasks found.</p>
        ) : (
          incompleteTasks.map((task) => {
            const checked = completedTaskIds.includes(task.id);
            return (
              <label
                key={task.id}
                className={`flex items-start gap-3 rounded-xl px-4 py-3 cursor-pointer select-none transition-all duration-100 ${checked ? "bg-zinc-800 border border-zinc-700" : "bg-zinc-900/40 border border-transparent hover:bg-zinc-800/50"
                  }`}
              >
                <input
                  type="checkbox"
                  checked={checked}
                  onChange={() => onToggleTask(task.id)}
                  className="mt-0.5 h-4 w-4 rounded accent-cyan-400 cursor-pointer flex-shrink-0"
                />
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-zinc-200">{task.title}</p>
                  <p className="truncate text-xs font-semibold text-zinc-500 uppercase tracking-wider mt-0.5">{task.taskListName}</p>
                </div>
              </label>
            );
          })
        )}
      </div>

      <div className="h-px bg-zinc-800" />

      {saveError ? (
        <p className="mx-6 mt-3 rounded-lg bg-red-950/60 border border-red-800 px-4 py-2.5 text-sm text-red-300">
          {saveError}
        </p>
      ) : null}

      <div className="flex gap-3 px-6 py-4">
        <button
          type="button"
          onClick={onBack}
          disabled={isSaving}
          className="flex-[0.5] rounded-xl border border-zinc-700 bg-zinc-900 py-3 text-sm font-semibold text-zinc-300 hover:bg-zinc-800 hover:text-zinc-50 transition-colors shrink-0"
        >
          Back
        </button>
        <div className="flex-1 flex gap-3">
          <button
            type="button"
            onClick={onSkip}
            disabled={isSaving || tasksLoading}
            className="flex-1 rounded-xl bg-zinc-800 py-3 text-sm font-semibold text-zinc-300 hover:bg-zinc-700 transition-colors"
          >
            Skip
          </button>
          <button
            type="button"
            onClick={onSave}
            disabled={isSaving || tasksLoading}
            className="flex-1 rounded-xl bg-cyan-300 py-3 text-sm font-bold text-zinc-950 hover:bg-cyan-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors shrink-0"
          >
            {isSaving ? "Saving…" : "Save"}
          </button>
        </div>
      </div>
    </div>
  );
}
