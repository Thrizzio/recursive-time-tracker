import { useEffect, useRef } from "react";

const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3000";

function getWebSocketUrl(baseUrl: string): string {
  try {
    const url = new URL(baseUrl, window.location.href);
    const isSecure = url.protocol === "https:";
    url.protocol = isSecure ? "wss:" : "ws:";
    url.pathname = "/ws";
    return url.toString();
  } catch {
    const isSecure = window.location.protocol === "https:";
    const host = window.location.host;
    return `${isSecure ? "wss" : "ws"}://${host}/ws`;
  }
}

export type WebSocketSyncOptions = {
  enabled: boolean;
  onTrackingStarted?: (data: { trackingStartedAt: string }) => void;
  onTrackingReset?: () => void;
  onTimeBlockCreated?: (data: { block: any; trackingStartedAt: string }) => void;
  onTaskCompleted?: (data: { taskIds: string[] }) => void;
  onReconnect?: () => void;
};

/**
 * React hook that manages a WebSocket connection for user-scoped realtime sync.
 * Listens for tracking, time-block, and task events broadcast by the backend.
 * Automatically reconnects with exponential backoff on disconnect.
 */
export function useWebSocketSync({
  enabled,
  onTrackingStarted,
  onTrackingReset,
  onTimeBlockCreated,
  onTaskCompleted,
  onReconnect,
}: WebSocketSyncOptions) {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<number | null>(null);
  const backoffDelayRef = useRef<number>(1000);
  const wasConnectedRef = useRef<boolean>(false);

  // Keep latest callbacks in refs to avoid re-triggering effect on identity changes
  const callbacksRef = useRef({
    onTrackingStarted,
    onTrackingReset,
    onTimeBlockCreated,
    onTaskCompleted,
    onReconnect,
  });

  useEffect(() => {
    callbacksRef.current = {
      onTrackingStarted,
      onTrackingReset,
      onTimeBlockCreated,
      onTaskCompleted,
      onReconnect,
    };
  }, [onTrackingStarted, onTrackingReset, onTimeBlockCreated, onTaskCompleted, onReconnect]);

  useEffect(() => {
    if (!enabled) {
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
      if (reconnectTimeoutRef.current) {
        window.clearTimeout(reconnectTimeoutRef.current);
        reconnectTimeoutRef.current = null;
      }
      return;
    }

    let isDisposed = false;
    const wsUrl = getWebSocketUrl(apiUrl);

    function connect() {
      if (isDisposed) return;

      try {
        const ws = new WebSocket(wsUrl);
        wsRef.current = ws;

        ws.onopen = () => {
          if (isDisposed) {
            ws.close();
            return;
          }
          console.log("[WS] Connected to Chronolog sync server.");
          if (wasConnectedRef.current) {
            console.log("[WS] Reconnected. Triggering refresh...");
            callbacksRef.current.onReconnect?.();
          }
          wasConnectedRef.current = true;
          backoffDelayRef.current = 1000;
        };

        ws.onmessage = (event) => {
          try {
            const message = JSON.parse(event.data);
            const { event: eventName, data } = message;

            switch (eventName) {
              case "tracking.started":
                callbacksRef.current.onTrackingStarted?.(data);
                break;
              case "tracking.reset":
                callbacksRef.current.onTrackingReset?.();
                break;
              case "time-block.created":
                callbacksRef.current.onTimeBlockCreated?.(data);
                break;
              case "task.completed":
                callbacksRef.current.onTaskCompleted?.(data);
                break;
              case "connected":
                console.log("[WS] Handshake acknowledged for userId:", data?.userId);
                break;
              default:
                break;
            }
          } catch (err) {
            console.warn("[WS] Error parsing message:", err);
          }
        };

        ws.onclose = () => {
          if (isDisposed) return;
          scheduleReconnect();
        };

        ws.onerror = (err) => {
          console.warn("[WS] Socket error:", err);
          ws.close();
        };
      } catch (err) {
        console.warn("[WS] Failed to initiate connection:", err);
        scheduleReconnect();
      }
    }

    function scheduleReconnect() {
      if (isDisposed) return;
      if (reconnectTimeoutRef.current) {
        window.clearTimeout(reconnectTimeoutRef.current);
      }

      const delay = backoffDelayRef.current;
      console.log(`[WS] Reconnecting in ${delay}ms...`);
      reconnectTimeoutRef.current = window.setTimeout(() => {
        connect();
      }, delay);

      backoffDelayRef.current = Math.min(delay * 2, 30000);
    }

    connect();

    return () => {
      isDisposed = true;
      if (reconnectTimeoutRef.current) {
        window.clearTimeout(reconnectTimeoutRef.current);
      }
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
    };
  }, [enabled]);
}
