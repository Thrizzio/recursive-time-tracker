import { db } from "../../db/client.js";
import { users } from "../../db/schema.js";
import { eq } from "drizzle-orm";
import { getValidAccessToken } from "../../auth/google.js";

export type GoogleTask = {
    id: string;
    title: string;
    notes?: string;
    due?: string;
    status: string;
};

export type GoogleTaskList = {
    id: string;
    title: string;
};

/**
 * Fetch all available Google Task Lists for a user
 */
export async function getTaskLists(userId: number): Promise<GoogleTaskList[]> {
    const token = await getValidAccessToken(userId);

    const listsRes = await fetch("https://tasks.googleapis.com/tasks/v1/users/@me/lists", {
        headers: { Authorization: `Bearer ${token}` }
    });
    if (!listsRes.ok) throw new Error("Failed to fetch task lists");
    const listsData = (await listsRes.json()) as { items?: any[] };
    const taskLists = listsData.items || [];

    return taskLists.map((list) => ({
        id: list.id,
        title: list.title,
    }));
}

/**
 * Fetch incomplete tasks from a specific task list
 */
export async function getTasksFromList(userId: number, taskListId: string): Promise<GoogleTask[]> {
    const token = await getValidAccessToken(userId);

    const tasksRes = await fetch(
        `https://tasks.googleapis.com/tasks/v1/lists/${taskListId}/tasks?showCompleted=false`,
        {
            headers: { Authorization: `Bearer ${token}` }
        }
    );
    
    if (!tasksRes.ok) {
        throw new Error("Failed to fetch tasks from list");
    }
    
    const tasksData = (await tasksRes.json()) as { items?: any[] };
    const tasks = tasksData.items || [];

    return tasks.map((t) => ({
        id: t.id,
        title: t.title,
        notes: t.notes,
        due: t.due,
        status: t.status,
    }));
}

/**
 * Legacy function - fetches tasks from all lists
 * @deprecated Use getTasksFromList with user's selectedTaskListId instead
 */
export async function getIncompleteTasks(userId: number): Promise<GoogleTask[]> {
    const token = await getValidAccessToken(userId);

    const listsRes = await fetch("https://tasks.googleapis.com/tasks/v1/users/@me/lists", {
        headers: { Authorization: `Bearer ${token}` }
    });
    if (!listsRes.ok) throw new Error("Failed to fetch task lists");
    const listsData = (await listsRes.json()) as { items?: any[] };
    const taskLists = listsData.items || [];

    const allTasks: GoogleTask[] = [];

    for (const list of taskLists) {
        const tasksRes = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${list.id}/tasks?showCompleted=false`, {
            headers: { Authorization: `Bearer ${token}` }
        });
        if (tasksRes.ok) {
            const tasksData = (await tasksRes.json()) as { items?: any[] };
            if (tasksData.items) {
                for (const t of tasksData.items) {
                    allTasks.push({
                        id: t.id,
                        title: t.title,
                        notes: t.notes,
                        due: t.due,
                        status: t.status,
                    });
                }
            }
        }
    }

    return allTasks;
}

export async function completeTasks(userId: number, taskIds: string[]) {
    if (taskIds.length === 0) return;
    
    // Get user's selected task list
    const [user] = await db.select().from(users).where(eq(users.id, userId));
    if (!user.selectedTaskListId) {
        throw new Error("No task list selected");
    }
    
    const token = await getValidAccessToken(userId);

    const results = await Promise.allSettled(taskIds.map(async (taskId) => {
        const res = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${user.selectedTaskListId}/tasks/${taskId}`, {
            method: "PATCH",
            headers: {
                Authorization: `Bearer ${token}`,
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ status: "completed" })
        });
        if (!res.ok) {
            throw new Error(`Task ${taskId} completion failed: ${await res.text()}`);
        }
    }));

    const failures = results.filter((r) => r.status === "rejected");
    if (failures.length > 0) {
        throw new Error(`${failures.length} tasks failed to update.`);
    }
}
