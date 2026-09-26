import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { apiClient, setAuthToken } from "../api/client";

const AuthContext = createContext(null);

const TOKEN_KEY = "fmt_admin_token";
const USER_KEY = "fmt_admin_user";
const REMEMBER_KEY = "fmt_admin_remember";

const initialToken = localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY);
if (initialToken) {
  setAuthToken(initialToken);
}

function getAuthErrorMessage(err) {
  const responseData = err?.response?.data;
  const backendMessage =
    responseData && typeof responseData === "object" ? responseData.message : null;

  if (backendMessage) {
    return backendMessage;
  }

  if (err?.response?.status === 500) {
    return "Cannot reach the backend API on port 5000. Start the backend with `cd backend` and `npm run start`, then try again.";
  }

  if (err?.code === "ERR_NETWORK") {
    return "Cannot connect to the server. Make sure the frontend and backend are both running.";
  }

  return err?.message || "Login failed.";
}

export function AuthProvider({ children }) {
  const [token, setToken] = useState(localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY));
  const [rememberMe, setRememberMe] = useState(localStorage.getItem(REMEMBER_KEY) === "true");
  const [user, setUser] = useState(() => {
    try {
      const raw = localStorage.getItem(USER_KEY) || sessionStorage.getItem(USER_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (_) {
      return null;
    }
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    setAuthToken(token);
  }, [token]);

  async function login({ identifier, email, phone, password, remember = false }) {
    setLoading(true);
    setError(null);
    try {
      const loginValue = String(identifier || email || phone || "").trim();
      const payload = loginValue.includes("@")
        ? { email: loginValue, password }
        : { phone: loginValue, password };

      const { data } = await apiClient.post(
        "/auth/login",
        payload,
        { skipAuthRedirect: true }
      );
      const authData = data?.data || {};
      const adminUser = authData.user;
      const jwt = authData.token;

      if (!adminUser || adminUser.role !== "admin") {
        throw new Error("Account is not an admin user.");
      }

      if (remember) {
        localStorage.setItem(TOKEN_KEY, jwt);
        localStorage.setItem(USER_KEY, JSON.stringify(adminUser));
        localStorage.setItem(REMEMBER_KEY, "true");
      } else {
        sessionStorage.setItem(TOKEN_KEY, jwt);
        sessionStorage.setItem(USER_KEY, JSON.stringify(adminUser));
        localStorage.removeItem(TOKEN_KEY);
        localStorage.removeItem(USER_KEY);
        localStorage.setItem(REMEMBER_KEY, "false");
      }
      setToken(jwt);
      setUser(adminUser);
      setRememberMe(Boolean(remember));
      setAuthToken(jwt);
      return true;
    } catch (err) {
      setError(getAuthErrorMessage(err));
      return false;
    } finally {
      setLoading(false);
    }
  }

  async function sendAdminOtp({ email }) {
    setLoading(true);
    setError(null);
    try {
      await apiClient.post("/auth/admin/send-otp", { email }, { skipAuthRedirect: true });
      return true;
    } catch (err) {
      setError(getAuthErrorMessage(err));
      return false;
    } finally {
      setLoading(false);
    }
  }

  async function verifyAdminOtp({ email, code }) {
    setLoading(true);
    setError(null);
    try {
      await apiClient.post("/auth/admin/verify-otp", { email, code }, { skipAuthRedirect: true });
      return true;
    } catch (err) {
      setError(getAuthErrorMessage(err));
      return false;
    } finally {
      setLoading(false);
    }
  }

  async function registerAdmin({ fullName, phone, email, password }) {
    setLoading(true);
    setError(null);
    try {
      const { data } = await apiClient.post(
        "/auth/admin/register",
        { fullName, phone, email, password },
        { skipAuthRedirect: true }
      );
      const authData = data?.data || {};
      const adminUser = authData.user;
      const jwt = authData.token;

      sessionStorage.setItem(TOKEN_KEY, jwt);
      sessionStorage.setItem(USER_KEY, JSON.stringify(adminUser));
      setToken(jwt);
      setUser(adminUser);
      setAuthToken(jwt);
      return true;
    } catch (err) {
      setError(getAuthErrorMessage(err));
      return false;
    } finally {
      setLoading(false);
    }
  }

  function logout() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    localStorage.removeItem(REMEMBER_KEY);
    sessionStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(USER_KEY);
    setToken(null);
    setUser(null);
    setRememberMe(false);
    setError(null);
    setAuthToken(null);
  }

  const value = useMemo(
    () => ({
      token,
      user,
      rememberMe,
      loading,
      error,
      isAuthenticated: Boolean(token),
      login,
      sendAdminOtp,
      verifyAdminOtp,
      registerAdmin,
      logout,
    }),
    [token, user, loading, error]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider.");
  return ctx;
}
