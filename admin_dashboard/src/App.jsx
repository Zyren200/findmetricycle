import { useEffect, useState } from "react";
import DashboardShell from "./pages/DashboardShell";
import LoginPage from "./pages/LoginPage";
import SignupPage from "./pages/SignupPage";
import { useAuth } from "./context/AuthContext";
import { ToastProvider } from "./context/ToastContext";
import { apiClient } from "./api/client";
import { useModalDismiss } from "./hooks/useModalDismiss";

export default function App() {
  const { isAuthenticated } = useAuth();
  // Esc / backdrop click closes any open dialog.
  useModalDismiss();
  const [adminExists, setAdminExists] = useState(null);

  useEffect(() => {
    if (isAuthenticated) return;
    let cancelled = false;
    apiClient
      .get("/auth/admin/exists", { skipAuthRedirect: true })
      .then(({ data }) => {
        if (!cancelled) setAdminExists(Boolean(data?.data?.exists));
      })
      .catch(() => {
        if (!cancelled) setAdminExists(true);
      });
    return () => {
      cancelled = true;
    };
  }, [isAuthenticated]);

  function renderUnauthenticated() {
    if (adminExists === null) return null;
    return adminExists ? <LoginPage /> : <SignupPage />;
  }

  return (
    <ToastProvider>
      {isAuthenticated ? <DashboardShell /> : renderUnauthenticated()}
    </ToastProvider>
  );
}
