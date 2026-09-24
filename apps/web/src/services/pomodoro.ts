import { PomodoroPlan, PomodoroStartParams } from '../types/pomodoro';

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3000";

async function fetchWithCredentials(url: string, options?: RequestInit) {
  return fetch(url, {
    ...options,
    credentials: 'include',
  });
}

export async function getCurrentPlan(): Promise<PomodoroPlan | null> {
  const res = await fetchWithCredentials(`${apiUrl}/pomodoro/current`);
  if (!res.ok) throw new Error('Failed to fetch pomodoro plan');
  const data = await res.json();
  return data.plan ?? null;
}

export async function startPlan(params: PomodoroStartParams): Promise<PomodoroPlan> {
  const res = await fetchWithCredentials(`${apiUrl}/pomodoro/start`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(params),
  });
  if (!res.ok) throw new Error('Failed to start pomodoro plan');
  const data = await res.json();
  return data.plan;
}

export async function pausePlan(planId?: number): Promise<PomodoroPlan> {
  const res = await fetchWithCredentials(`${apiUrl}/pomodoro/pause`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ planId }),
  });
  if (!res.ok) throw new Error('Failed to pause pomodoro plan');
  const data = await res.json();
  return data.plan;
}

export async function resumePlan(planId?: number): Promise<PomodoroPlan> {
  const res = await fetchWithCredentials(`${apiUrl}/pomodoro/resume`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ planId }),
  });
  if (!res.ok) throw new Error('Failed to resume pomodoro plan');
  const data = await res.json();
  return data.plan;
}

export async function nextPhase(planId?: number): Promise<PomodoroPlan> {
  const res = await fetchWithCredentials(`${apiUrl}/pomodoro/next`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ planId }),
  });
  if (!res.ok) throw new Error('Failed to advance pomodoro phase');
  const data = await res.json();
  return data.plan;
}

export async function skipPhase(planId?: number): Promise<PomodoroPlan> {
  const res = await fetchWithCredentials(`${apiUrl}/pomodoro/skip`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ planId }),
  });
  if (!res.ok) throw new Error('Failed to skip pomodoro phase');
  const data = await res.json();
  return data.plan;
}

export async function cancelPlan(planId?: number): Promise<PomodoroPlan> {
  const res = await fetchWithCredentials(`${apiUrl}/pomodoro/cancel`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ planId }),
  });
  if (!res.ok) throw new Error('Failed to cancel pomodoro plan');
  const data = await res.json();
  return data.plan;
}
