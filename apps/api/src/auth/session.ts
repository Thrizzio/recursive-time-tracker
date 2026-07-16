import { db } from "../db/client.js";
import { sessions } from "../db/schema.js";
import { eq } from "drizzle-orm";
import crypto from "crypto";

export async function createSession(userId: number): Promise<string> {
    const sessionId = crypto.randomBytes(32).toString("hex");
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

    await db.insert(sessions).values({
        id: sessionId,
        userId,
        expiresAt,
    });

    return sessionId;
}

export async function getSessionUserId(sessionId: string): Promise<number | null> {
    const [session] = await db.select().from(sessions).where(eq(sessions.id, sessionId));

    if (!session) return null;

    if (session.expiresAt.getTime() < Date.now()) {
        await deleteSession(sessionId);
        return null;
    }

    return session.userId;
}

export async function deleteSession(sessionId: string) {
    await db.delete(sessions).where(eq(sessions.id, sessionId));
}
