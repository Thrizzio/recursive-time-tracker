import { db } from "../../db/client.js";
import { users } from "../../db/schema.js";
import { eq } from "drizzle-orm";
import { refreshGoogleTokens } from "../../auth/google.js";

async function getValidAccessToken(userId: number) {
    const [user] = await db.select().from(users).where(eq(users.id, userId));
    if (!user || !user.googleAccessToken) {
        throw new Error("No Google access token found for user");
    }

    if (user.googleTokenExpiresAt && user.googleTokenExpiresAt.getTime() < Date.now() + 60000) {
        if (!user.googleRefreshToken) {
            throw new Error("Google access token expired and no refresh token available");
        }
        const newTokens = await refreshGoogleTokens(user.googleRefreshToken);
        const expiresAt = new Date(Date.now() + newTokens.expires_in * 1000);

        await db.update(users).set({
            googleAccessToken: newTokens.access_token,
            googleTokenExpiresAt: expiresAt,
        }).where(eq(users.id, userId));

        return newTokens.access_token;
    }

    return user.googleAccessToken;
}

export type GoogleTask = {
    id: string; // Composite ID: `${taskListId}|${taskId}`
    title: string;
    notes?: string;
    taskListName: string;
};

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
                        id: `${list.id}|${t.id}`,
                        title: t.title,
                        notes: t.notes,
                        taskListName: list.title,
                    });
                }
            }
        }
    }

    return allTasks;
}

export async function completeTasks(userId: number, compositeTaskIds: string[]) {
    if (compositeTaskIds.length === 0) return;
    const token = await getValidAccessToken(userId);

    const results = await Promise.allSettled(compositeTaskIds.map(async (compositeId) => {
        const [taskListId, taskId] = compositeId.split("|");
        if (!taskListId || !taskId) throw new Error(`Invalid task ID format: ${compositeId}`);

        const res = await fetch(`https://tasks.googleapis.com/tasks/v1/lists/${taskListId}/tasks/${taskId}`, {
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
