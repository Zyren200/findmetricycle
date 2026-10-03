import { useEffect, useRef } from "react";
import { io } from "socket.io-client";

export function useSocket({
  token,
  onDriverLocation,
  onRideUpdate,
  onSosAlert,
  onSosUpdated,
  onSosEscalation,
  onNotification,
  onAccessChanged,
  onServerDisconnect,
}) {
  const socketRef = useRef(null);

  useEffect(() => {
    if (!token) return undefined;

    const socket = io(
      import.meta.env.VITE_SOCKET_URL ||
        (typeof window !== "undefined" ? window.location.origin : "http://localhost:5000"),
      {
        transports: ["websocket"],
        auth: { token },
      }
    );

    socket.on("admin:driver_location", (payload) => {
      if (onDriverLocation) {
        onDriverLocation(payload);
      }
    });

    socket.on("admin:ride_update", (payload) => {
      if (onRideUpdate) onRideUpdate(payload);
    });

    socket.on("admin:sos_alert", (payload) => {
      if (onSosAlert) onSosAlert(payload);
    });

    // An alert was acknowledged, resolved or escalated (by anyone).
    socket.on("admin:sos_updated", (payload) => {
      if (onSosUpdated) onSosUpdated(payload);
    });

    // Nobody acknowledged an SOS in time (Super Admins).
    socket.on("admin:sos_escalation", (payload) => {
      if (onSosEscalation) onSosEscalation(payload);
    });

    socket.on("admin:notification_created", (payload) => {
      if (onNotification) onNotification(payload);
    });

    // A Super Admin disabled this account or changed its role.
    socket.on("admin:access_changed", (payload) => {
      if (onAccessChanged) onAccessChanged(payload);
    });

    // The server only drops a connection on purpose when this admin's
    // access changed (or their password was reset). Socket.IO doesn't
    // reconnect by itself then: re-check access, and reconnect if this
    // session is still allowed (the server refuses a disabled admin).
    let reconnectTimer = null;
    socket.on("disconnect", (reason) => {
      if (reason !== "io server disconnect") return;
      Promise.resolve(onServerDisconnect ? onServerDisconnect() : null)
        .catch(() => null)
        .finally(() => {
          reconnectTimer = setTimeout(() => socket.connect(), 1000);
        });
    });

    socketRef.current = socket;

    return () => {
      clearTimeout(reconnectTimer);
      socket.disconnect();
      socketRef.current = null;
    };
  }, [
    token,
    onDriverLocation,
    onRideUpdate,
    onSosAlert,
    onSosUpdated,
    onSosEscalation,
    onNotification,
    onAccessChanged,
    onServerDisconnect,
  ]);

  return socketRef;
}
