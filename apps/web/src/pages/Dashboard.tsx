import {
  FormEvent,
  useCallback,
  useEffect,
  useRef,
  useState,
} from "react";
import { Link } from "react-router-dom";
import { TimerPanel } from "../components/timer/TimerPanel";
import { TaskPanel } from "../components/tasks/TaskPanel";
import { Sidebar, MenuButton } from "../components/Sidebar";
import { useTasks } from "../hooks/useTasks";
import * as tasksService from "../services/tasks";
import type { GoogleTask } from "../types/tasks";
import {
  requestNotificationPermission,
  showNotification,
} from "../utils/notifications";

// ─── Types ────────────────────────────────────────────────────────────────────

type User = {
  id: number;
  email: string;
  name: string;
  avatarUrl: string;
  trackingStartedAt: string | null;
  selectedTaskListId: string | null;
};

// type GoogleTask = {
//   id: string; // "listId|taskId"
//   title: string;
//   notes?: string;
//   taskListName: string;
// };

type GoogleEvent = {
  id: string;
  title: string;
  start: string;
  end: string;
  location?: string;
  allDay: boolean;
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
const MIN_SEGMENT_PCT = 2;
/** 2 hours in milliseconds — used for tracking reminder boundaries */
const TWO_HOURS_MS = 2 * 60 * 60 * 1000;

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

type DashboardProps = {
  user: User;
  onUserUpdate: () => Promise<void>;
  onLogout: () => Promise<void>;
};

export function Dashboard({ user, onUserUpdate, onLogout }: DashboardProps) {
  // Core data
  const [activities, setActivities] = useState<Activity[]>([]);
  const [timeBlocks, setTimeBlocks] = useState<TimeBlockFull[]>([]);
  const [timeBlocksLoading, setTimeBlocksLoading] = useState(true);
  const [timeBlocksError, setTimeBlocksError] = useState("");
  // Tracking-level error/feedback (not activity form — that moved to Activities page)
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState("");

  // Tasks integration
  const { tasks, loading: tasksLoading, error: tasksError, refreshTasks } = useTasks({
    selectedListId: user?.selectedTaskListId ?? null,
    enabled: !!user
  });

  // Sidebar navigation
  const [sidebarOpen, setSidebarOpen] = useState(false);

  // Session / timer
  const trackingStartedAt = user?.trackingStartedAt ?? null;
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
  // const [incompleteTasks, setIncompleteTasks] = useState<GoogleTask[]>([]);
  // const [tasksLoading, setTasksLoading] = useState(false);
  // const [tasksError, setTasksError] = useState("");
  // const [completedTaskIds, setCompletedTaskIds] = useState<string[]>([]);

  // Log dialog — Step 3: Google Tasks
const [completedTaskIds, setCompletedTaskIds] = useState<string[]>([]);

  // Dashboard Agenda
  const [todayEvents, setTodayEvents] = useState<GoogleEvent[]>([]);
  const [todayEventsLoading, setTodayEventsLoading] = useState(false);
  const [todayEventsError, setTodayEventsError] = useState("");

  // Log dialog — Step (context): Google Calendar
  const [retroEvents, setRetroEvents] = useState<GoogleEvent[]>([]);
  const [retroEventsLoading, setRetroEventsLoading] = useState(false);
  const [retroEventsError, setRetroEventsError] = useState("");

  // Browser notification permission state
  const [notifPermission, setNotifPermission] = useState<
    NotificationPermission | "unsupported"
  >(() => {
    if (typeof Notification === "undefined") return "unsupported";
    return Notification.permission;
  });

  // Ref for the 2-hour reminder timeout — cleaned up on tracking change/unmount
  const reminderTimeoutRef = useRef<number | null>(null);

  // Which boundary index has already produced a notification for the CURRENT
  // tracking session. Lives in a ref so it survives Dashboard rerenders and
  // React StrictMode's deliberate setup→cleanup→setup double-invocation
  // without resetting to -1. Only reset when trackingStartedAt changes to a
  // genuinely new value (new session).
  const lastFiredBoundaryIdxRef = useRef<number>(-1);

  // The value of trackingStartedAt that lastFiredBoundaryIdxRef was last reset
  // for. Used to detect a real session change vs. a mere re-render.
  const lastResetForSessionRef = useRef<string | null>(null);

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

  async function fetchCalendarEvents(start: string, end: string) {
    const params = new URLSearchParams({ start, end });
    const res = await customFetch(`${apiUrl}/google/calendar?${params.toString()}`);
    if (!res.ok) throw new Error("Could not load events");
    return (await res.json()) as GoogleEvent[];
  }

  async function fetchTodayEvents() {
    setTodayEventsLoading(true);
    setTodayEventsError("");
    try {
      const start = new Date();
      start.setHours(0, 0, 0, 0);
      const end = new Date();
      end.setHours(23, 59, 59, 999);

      const events = await fetchCalendarEvents(start.toISOString(), end.toISOString());
      setTodayEvents(events);
    } catch {
      setTodayEventsError("Could not load calendar events.");
    } finally {
      setTodayEventsLoading(false);
    }
  }

  // ── Effects ───────────────────────────────────────────────────────────────

  useEffect(() => {
    fetchActivities().catch(() => setError("Could not load activities."));
    fetchTimeBlocks();
    fetchTodayEvents();
  }, []);

  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(id);
  }, []);

  // ── 2-hour tracking reminder ───────────────────────────────────────────────
  //
  // Algorithm (no fixed setInterval — everything is derived from timestamps):
  //
  //   1. When trackingStartedAt changes (new session / reset), cancel any
  //      pending timeout and restart the scheduler.
  //   2. Compute elapsed = now - startedAt.
  //   3. Find the index of the LAST boundary that should have fired:
  //        lastBoundaryIdx = floor(elapsed / TWO_HOURS_MS)
  //   4. If lastBoundaryIdx > lastFiredBoundaryIdxRef.current (boundary not yet
  //      notified this session), emit exactly ONE notification and record it.
  //   5. Schedule a timeout for the NEXT boundary:
  //        delay = (lastBoundaryIdx + 1) * TWO_HOURS_MS - elapsed
  //   6. When the timeout fires, re-run steps 2-5.
  //
  // Deduplication survives rerenders because lastFiredBoundaryIdxRef is a ref
  // (not a local variable). It is only reset when trackingStartedAt is a new
  // value, detected via lastResetForSessionRef — so React StrictMode's
  // deliberate setup→cleanup→setup cycle does NOT wipe the counter.

  useEffect(() => {
    if (!trackingStartedAt) {
      // Tracking is off — cancel any pending reminder.
      if (reminderTimeoutRef.current !== null) {
        window.clearTimeout(reminderTimeoutRef.current);
        reminderTimeoutRef.current = null;
      }
      return;
    }

    // Reset deduplication counter ONLY when this is a genuinely new session,
    // not merely a re-execution of the effect for the same trackingStartedAt
    // value (e.g. StrictMode double-invoke, or future React re-runs).
    if (lastResetForSessionRef.current !== trackingStartedAt) {
      lastFiredBoundaryIdxRef.current = -1;
      lastResetForSessionRef.current = trackingStartedAt;
    }

    const startMs = new Date(trackingStartedAt).getTime();

    function scheduleNextReminder() {
      const elapsed = Date.now() - startMs;
      if (elapsed < 0) return; // clock skew guard

      const lastBoundaryIdx = Math.floor(elapsed / TWO_HOURS_MS);

      // Only notify if this boundary hasn't already been notified this session.
      // lastFiredBoundaryIdxRef.current persists across effect re-executions,
      // so a second scheduler spawned by StrictMode or a rerender cannot
      // fire for a boundary that the first scheduler already handled.
      if (lastBoundaryIdx > lastFiredBoundaryIdxRef.current) {
        showNotification(
          "How was the last 2 hours spent?",
          "Take a moment to log your time."
        );
        lastFiredBoundaryIdxRef.current = lastBoundaryIdx;
      }

      // Schedule a timeout for the NEXT future boundary.
      const nextBoundaryMs = (lastBoundaryIdx + 1) * TWO_HOURS_MS;
      const delay = nextBoundaryMs - elapsed;

      reminderTimeoutRef.current = window.setTimeout(() => {
        scheduleNextReminder();
      }, delay);
    }

    scheduleNextReminder();

    return () => {
      // Cancel the pending timeout on cleanup (tracking reset, new session,
      // or unmount). The deduplication ref is NOT reset here — that only
      // happens above when trackingStartedAt itself changes to a new value.
      if (reminderTimeoutRef.current !== null) {
        window.clearTimeout(reminderTimeoutRef.current);
        reminderTimeoutRef.current = null;
      }
    };
  }, [trackingStartedAt]); // Re-run only when the tracking session changes

  // ── Enable notifications handler ──────────────────────────────────────────

  const handleEnableNotifications = useCallback(async () => {
    const result = await requestNotificationPermission();
    setNotifPermission(result === "unsupported" ? "unsupported" : result);
  }, []);
  // ── Start tracking ────────────────────────────────────────────────────────


  async function startTracking() {
    try {
      const res = await customFetch(`${apiUrl}/tracking/start`, { method: "POST" });
      if (res.ok) {
        await onUserUpdate(); // Refresh user state
        const data = await res.json();
        setNow(new Date(data.trackingStartedAt));
        setFeedback(`Tracking started at ${formatTime(new Date(data.trackingStartedAt))}.`);
        setError("");
      }
    } catch {
      setError("Could not start tracking.");
    }
  }

  async function resetTracking() {
    try {
      const res = await customFetch(`${apiUrl}/tracking/reset`, { method: "POST" });
      if (res.ok) {
        await onUserUpdate(); // Refresh user state
        setFeedback("Tracking reset successfully.");
      }
    } catch {
      setError("Could not reset tracking.");
    }
  }

  // ── Log dialog — Step 1 (select) ──────────────────────────────────────────

  function openModal() {
    if (!boundary) return;
    setModalElapsedText(formatElapsedHumanShort(boundary, now));
    setModalTotalMinutes(Math.max(0, (now.getTime() - boundary.getTime()) / 60000));
    setSelectedActivityIds([]);
    setAllocations([]);
    setModalError("");
    setCompletedTaskIds([]);
    setModalView("select");
    setIsModalOpen(true);

    // Fetch retrospective events for context
    setRetroEventsLoading(true);
    setRetroEventsError("");
    fetchCalendarEvents(boundary.toISOString(), now.toISOString())
      .then((events) => setRetroEvents(events))
      .catch(() => setRetroEventsError("Failed to fetch context events."))
      .finally(() => setRetroEventsLoading(false));
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

  function loadTasks() {
  setModalView("tasks");
}

  // ── Log dialog — Step 2/3 (allocate/tasks) ───────────────────────────────────────

  async function handleSave() {
    if (isSaving) return;
    setIsSaving(true);
    setModalError("");

    try {
      // 1. Save time block first (this should never fail due to task issues)
      const response = await customFetch(`${apiUrl}/log-session`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          allocations: allocations.map((a) => ({
            activityId: a.activityId,
            percentage: a.percentage,
          })),
        }),
      });

      const data = (await response.json()) as any;

      if (!response.ok) {
        setModalError(data.error ?? "Could not save. Please try again.");
        return;
      }

      const block = data.block;

      // 2. Try to complete Google Tasks separately
      let taskWarning = "";
      if (completedTaskIds.length > 0) {
        try {
          await tasksService.completeTasks(completedTaskIds);
          // Refresh task cache to show updated tasks
          await refreshTasks();
        } catch (taskError) {
          console.error("Failed to complete Google Tasks:", taskError);
          taskWarning = " (Note: Tasks could not be marked complete in Google Tasks)";
        }
      }

      // 3. Update UI state
      await onUserUpdate();
      setNow(new Date(block.endTime));
      setTimeBlocks((prev) => [block, ...prev]);

      closeModal();
      setFeedback(
        `Saved — ${formatSeconds(block.elapsedSeconds)} logged across ${block.allocations.length} activit${block.allocations.length === 1 ? "y" : "ies"}.${taskWarning}`
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

  return (
    <main className="min-h-screen bg-zinc-950 px-5 py-8 text-zinc-50 pb-20">
      <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      {/* Desktop: Three-column layout with Tasks Panel, Mobile: Stacked layout */}
      <div className="mx-auto flex max-w-7xl gap-8">
        {/* Left Sidebar: Tasks Panel */}
        <TaskPanel
          tasks={tasks}
          loading={tasksLoading}
          error={tasksError}
          hasSelectedList={!!user?.selectedTaskListId}
        />

        {/* Main content */}
        <section className="flex-1 max-w-md flex flex-col gap-8">

          {/* ── Header ─────────────────────────────────────────────────────── */}
          <header className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <MenuButton onClick={() => setSidebarOpen(true)} />
              <div className="space-y-0.5">
                <p className="text-xs font-semibold uppercase tracking-wide text-cyan-400">Chronolog</p>
                <h1 className="text-2xl font-bold leading-tight">Time Tracker</h1>
              </div>
            </div>
            <div className="flex items-center gap-3">
              {/* Enable notifications — only shown when permission not yet decided */}
              {notifPermission === "default" && (
                <button
                  onClick={handleEnableNotifications}
                  className="text-xs font-medium text-zinc-400 hover:text-zinc-200 underline underline-offset-2"
                  title="Get reminded every 2 hours to log your time"
                >
                  Enable notifications
                </button>
              )}
              <button
                onClick={refreshTasks}
                disabled={tasksLoading || !user?.selectedTaskListId}
                className="text-xs font-medium text-zinc-400 hover:text-zinc-200 disabled:opacity-50 disabled:cursor-not-allowed underline underline-offset-2"
                title="Refresh tasks"
              >
                {tasksLoading ? "Refreshing..." : "Refresh Tasks"}
              </button>
              <Link
                to="/settings"
                className="text-xs font-medium text-zinc-400 hover:text-zinc-200 underline underline-offset-2"
              >
                Settings
              </Link>
              <div className="flex flex-col items-end hidden sm:flex">
                <span className="text-sm font-semibold">{user.name}</span>
                <button onClick={onLogout} className="text-xs text-zinc-400 hover:text-zinc-200">Sign out</button>
              </div>
              {user.avatarUrl ? (
                <img src={user.avatarUrl} alt={user.name} className="h-10 w-10 rounded-full border border-zinc-700 bg-zinc-800" />
              ) : (
                <div className="h-10 w-10 rounded-full border border-zinc-700 bg-zinc-800 flex items-center justify-center font-bold text-zinc-400">
                  {user.name.charAt(0)}
                </div>
              )}
              <button onClick={onLogout} className="sm:hidden text-xs font-medium text-zinc-400 hover:text-zinc-200 bg-zinc-900 px-2 py-1 rounded">Logout</button>
            </div>
          </header>

          {/* ── Timer Panel (Mobile only) ──────────────────────────────────── */}
          <div className="lg:hidden">
            <TimerPanel />
          </div>

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
                <div className="flex flex-col items-end gap-1 pb-1">
                  <p className="text-right text-sm text-zinc-400">{boundaryLabel}</p>
                  <button
                    type="button"
                    onClick={resetTracking}
                    className="text-xs text-zinc-500 hover:text-zinc-300 underline underline-offset-2 decoration-zinc-700 hover:decoration-zinc-400 transition-colors"
                  >
                    Reset tracking
                  </button>
                </div>
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
          <div className="space-y-8">
            <Agenda
              title="Today's Schedule"
              events={todayEvents}
              loading={todayEventsLoading}
              error={todayEventsError}
            />
            <section className="space-y-3">
              <h2 className="text-lg font-semibold">Today's blocks</h2>
              <Timeline
                blocks={timeBlocks}
                loading={timeBlocksLoading}
                error={timeBlocksError}
              />
            </section>
          </div>

        </section>

        {/* Timer Panel (Desktop only) */}
        <aside className="hidden lg:block w-80 flex-shrink-0">
          <TimerPanel />
        </aside>
      </div>

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
                retroEvents={retroEvents}
                retroEventsLoading={retroEventsLoading}
                retroEventsError={retroEventsError}
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
                incompleteTasks={tasks}
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
  retroEvents: GoogleEvent[];
  retroEventsLoading: boolean;
  retroEventsError: string;
  onToggle: (id: number) => void;
  onCancel: () => void;
  onContinue: () => void;
};

function SelectView({
  activities, elapsedText, selectedActivityIds, retroEvents, retroEventsLoading, retroEventsError, onToggle, onCancel, onContinue,
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

      <div className="px-6 py-4 border-b border-zinc-800 bg-zinc-900/30">
        <Agenda
          title="Events during this block"
          events={retroEvents}
          loading={retroEventsLoading}
          error={retroEventsError}
          emptyMessage="No overlapping calendar events."
        />
      </div>

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
// ─── Agenda ───────────────────────────────────────────────────────────────────

type AgendaProps = {
  events: GoogleEvent[];
  loading: boolean;
  error: string;
  title: string;
  emptyMessage?: string;
};

export function Agenda({ events, loading, error, title, emptyMessage = "No events scheduled." }: AgendaProps) {
  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold">{title}</h2>
      <div className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900 px-4 py-3">
        {loading ? (
          <div className="flex justify-center py-4">
            <div className="h-6 w-6 rounded-full border-2 border-cyan-400 border-t-transparent animate-spin" />
          </div>
        ) : error ? (
          <p className="py-4 text-center text-sm text-red-400">{error}</p>
        ) : events.length === 0 ? (
          <p className="py-4 text-center text-sm text-zinc-500">{emptyMessage}</p>
        ) : (
          <div className="divide-y divide-zinc-800/60">
            {events.map((evt) => {
              const dateStart = new Date(evt.start);
              const dateEnd = new Date(evt.end);
              return (
                <div key={evt.id} className="flex flex-col gap-1 py-3 first:pt-1 last:pb-1">
                  <div className="flex items-start justify-between gap-3">
                    <p className="text-sm font-medium text-zinc-200">{evt.title}</p>
                    <p className="text-xs font-medium tabular-nums text-zinc-400 shrink-0">
                      {evt.allDay ? "All day" : `${formatTime(dateStart)} - ${formatTime(dateEnd)}`}
                    </p>
                  </div>
                  {evt.location && (
                    <p className="text-xs text-zinc-500 truncate">{evt.location}</p>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </section>
  );
}
