import { useEffect, useRef } from "react";
import { io } from "socket.io-client";

export function useSocket({ token, onDriverLocation, onRideUpdate, onSosAlert, onNotification }) {
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

    socket.on("admin:notification_created", (payload) => {
      if (onNotification) onNotification(payload);
    });

    socketRef.current = socket;

    return () => {
      socket.disconnect();
      socketRef.current = null;
    };
  }, [token, onDriverLocation, onRideUpdate, onSosAlert, onNotification]);

  return socketRef;
}
