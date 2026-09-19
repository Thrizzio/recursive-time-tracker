import { WebSocketServer, WebSocket } from "ws";
import type { Server } from "node:http";
import type { IncomingMessage } from "node:http";
import { getSessionUserId } from "./auth/session.js";

export interface AuthenticatedWebSocket extends WebSocket {
  userId?: number;
  isAlive?: boolean;
}

function parseCookies(cookieHeader?: string): Record<string, string> {
  const list: Record<string, string> = {};
  if (!cookieHeader) return list;
  for (const cookie of cookieHeader.split(";")) {
    const parts = cookie.split("=");
    if (parts.length >= 2) {
      const key = parts[0].trim();
      const val = parts.slice(1).join("=").trim();
      list[key] = decodeURIComponent(val);
    }
  }
  return list;
}

let wssInstance: WebSocketServer | null = null;

/**
 * Initializes WebSocket server attached to the shared HTTP server.
 * Authenticates the upgrade request using the 'chronolog_session' cookie.
 */
export function setupWebSocketServer(server: Server): WebSocketServer {
  const wss = new WebSocketServer({ noServer: true });
  wssInstance = wss;

  server.on("upgrade", async (request: IncomingMessage, socket, head) => {
    try {
      const host = request.headers.host || "localhost";
      const url = new URL(request.url || "", `http://${host}`);
      if (url.pathname !== "/ws") {
        return;
      }

      const cookies = parseCookies(request.headers.cookie);
      const sessionId = cookies.chronolog_session;

      if (!sessionId) {
        socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
        socket.destroy();
        return;
      }

      const userId = await getSessionUserId(sessionId);
      if (!userId) {
        socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
        socket.destroy();
        return;
      }

      wss.handleUpgrade(request, socket, head, (ws) => {
        const authWs = ws as AuthenticatedWebSocket;
        authWs.userId = userId;
        authWs.isAlive = true;
        wss.emit("connection", authWs, request);
      });
    } catch (err) {
      console.error("[WS] Error during upgrade authentication:", err);
      socket.write("HTTP/1.1 500 Internal Server Error\r\n\r\n");
      socket.destroy();
    }
  });

  wss.on("connection", (ws: AuthenticatedWebSocket) => {
    ws.isAlive = true;
    ws.on("pong", () => {
      ws.isAlive = true;
    });

    // Send acknowledgement to client
    ws.send(JSON.stringify({ event: "connected", data: { userId: ws.userId } }));

    ws.on("error", (err) => {
      console.error(`[WS] Client error (userId=${ws.userId}):`, err);
    });
  });

  // Keep-alive heartbeat interval
  const interval = setInterval(() => {
    for (const client of wss.clients) {
      const authWs = client as AuthenticatedWebSocket;
      if (authWs.isAlive === false) {
        authWs.terminate();
      } else {
        authWs.isAlive = false;
        authWs.ping();
      }
    }
  }, 30000);

  wss.on("close", () => {
    clearInterval(interval);
  });

  return wss;
}

/**
 * Broadcasts an event strictly to connected sockets authenticated as the specified userId.
 * Events are never broadcast globally across different users.
 */
export function broadcastToUser(userId: number, event: string, data: any): void {
  if (!wssInstance) return;

  const payload = JSON.stringify({ event, data });
  for (const client of wssInstance.clients) {
    const authWs = client as AuthenticatedWebSocket;
    if (authWs.readyState === WebSocket.OPEN && authWs.userId === userId) {
      authWs.send(payload);
    }
  }
}

