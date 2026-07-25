import { GoogleTaskList, GoogleTask } from '../types/tasks';

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3000";

async function fetchWithCredentials(url: string, options?: RequestInit) {
  return fetch(url, {
    ...options,
    credentials: 'include',
  });
}

/**
 * Fetch all available Google Task Lists for the current user
 */
export async function getTaskLists(): Promise<GoogleTaskList[]> {
  const res = await fetchWithCredentials(`${apiUrl}/tasks/lists`);
  if (!res.ok) throw new Error('Failed to fetch task lists');
  return res.json();
}

/**
 * Fetch tasks from the user's selected task list
 * Returns empty array if no list is selected
 */
export async function getTasks(): Promise<GoogleTask[]> {
  const res = await fetchWithCredentials(`${apiUrl}/tasks`);
  if (!res.ok) throw new Error('Failed to fetch tasks');
  return res.json();
}

/**
 * Save the user's selected task list preference
 */
export async function saveSelectedTaskList(taskListId: string): Promise<void> {
  const res = await fetchWithCredentials(`${apiUrl}/settings/task-list`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ taskListId }),
  });
  if (!res.ok) throw new Error('Failed to save task list preference');
}
