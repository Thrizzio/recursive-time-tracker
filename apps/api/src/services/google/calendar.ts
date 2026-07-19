import { getValidAccessToken } from "../../auth/google.js";

export type GoogleEvent = {
    id: string;
    title: string;
    start: string;
    end: string;
    location?: string;
    allDay: boolean;
};

export async function listEvents(userId: number, start: string, end: string): Promise<GoogleEvent[]> {
    const token = await getValidAccessToken(userId);

    // Time format required by Google API is RFC3339 timestamp (ISO 8601)
    const query = new URLSearchParams({
        timeMin: start,
        timeMax: end,
        singleEvents: "true",
        orderBy: "startTime",
    });

    const res = await fetch(`https://www.googleapis.com/calendar/v3/calendars/primary/events?${query.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
    });

    if (!res.ok) {
        throw new Error(`Failed to fetch calendar events: ${await res.text()}`);
    }

    const data = (await res.json()) as any;
    const items = data.items || [];

    return items.map((e: any) => {
        const allDay = e.start?.date !== undefined;

        return {
            id: e.id,
            title: e.summary || "Untitled Event",
            start: e.start?.dateTime || e.start?.date,
            end: e.end?.dateTime || e.end?.date,
            location: e.location,
            allDay,
        };
    });
}
