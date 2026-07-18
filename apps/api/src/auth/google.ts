// Replace lines 1-3 in apps/api/src/auth/google.ts

export function getGoogleConfig() {
    const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
    const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
    const GOOGLE_CALLBACK_URL = process.env.GOOGLE_CALLBACK_URL ?? "http://localhost:3000/auth/google/callback";

    if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
        throw new Error("Missing Google OAuth credentials. Please set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in the .env file.");
    }

    return { GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_CALLBACK_URL };
}

export function getGoogleAuthUrl() {
    const { GOOGLE_CLIENT_ID, GOOGLE_CALLBACK_URL } = getGoogleConfig();

    const rootUrl = "https://accounts.google.com/o/oauth2/v2/auth";
    const options = {
        redirect_uri: GOOGLE_CALLBACK_URL,
        client_id: GOOGLE_CLIENT_ID,
        access_type: "offline",
        response_type: "code",
        prompt: "consent",
        scope: [
            "https://www.googleapis.com/auth/userinfo.profile",
            "https://www.googleapis.com/auth/userinfo.email",
            "https://www.googleapis.com/auth/tasks",
        ].join(" "),
    };

    const qs = new URLSearchParams(options);
    return `${rootUrl}?${qs.toString()}`;
}

export async function getGoogleTokens(code: string) {
    const { GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_CALLBACK_URL } = getGoogleConfig();

    const url = "https://oauth2.googleapis.com/token";
    const values = {
        code,
        client_id: GOOGLE_CLIENT_ID,
        client_secret: GOOGLE_CLIENT_SECRET,
        redirect_uri: GOOGLE_CALLBACK_URL,
        grant_type: "authorization_code",
    };

    const res = await fetch(url, {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams(values).toString(),
    });

    if (!res.ok) {
        throw new Error(`Failed to fetch Google tokens: ${await res.text()}`);
    }

    return res.json() as Promise<{
        access_token: string;
        id_token: string;
        expires_in: number;
        refresh_token: string;
        scope: string;
    }>;
}

export async function refreshGoogleTokens(refresh_token: string) {
    const { GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET } = getGoogleConfig();
    const url = "https://oauth2.googleapis.com/token";
    const values = {
        client_id: GOOGLE_CLIENT_ID,
        client_secret: GOOGLE_CLIENT_SECRET,
        refresh_token,
        grant_type: "refresh_token",
    };

    const res = await fetch(url, {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams(values).toString(),
    });

    if (!res.ok) {
        throw new Error(`Failed to refresh Google tokens: ${await res.text()}`);
    }

    return res.json() as Promise<{
        access_token: string;
        expires_in: number;
        scope: string;
        token_type: string;
    }>;
}

export async function getGoogleUser(id_token: string, access_token: string) {
    const res = await fetch(`https://www.googleapis.com/oauth2/v1/userinfo?alt=json&access_token=${access_token}`, {
        headers: {
            Authorization: `Bearer ${id_token}`,
        },
    });

    if (!res.ok) {
        throw new Error(`Failed to fetch Google user profile: ${await res.text()}`);
    }

    return res.json() as Promise<{
        id: string;
        email: string;
        verified_email: boolean;
        name: string;
        given_name: string;
        family_name: string;
        picture: string;
        locale: string;
    }>;
}
