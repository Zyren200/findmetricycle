import { createContext, useCallback, useContext, useEffect, useState } from "react";
import { apiClient, getToken, setToken } from "../api/client";

const AuthContext = createContext(null);

const CAPTCHA_KEY = "fmt_driverapply_captcha";
const USER_KEY = "fmt_driverapply_user";

export function AuthProvider({ children }) {
  const [token, setTokenState] = useState(getToken());
  const [user, setUser] = useState(() => {
    try {
      const raw = localStorage.getItem(USER_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  });
  const [captchaSessionToken, setCaptchaSessionTokenState] = useState(
    () => sessionStorage.getItem(CAPTCHA_KEY) || ""
  );

  useEffect(() => {
    setToken(token || null);
  }, [token]);

  const login = useCallback((jwt, userData) => {
    setToken(jwt);
    setTokenState(jwt);
    setUser(userData);
    localStorage.setItem(USER_KEY, JSON.stringify(userData || {}));
  }, []);

  const logout = useCallback(() => {
    setToken(null);
    setTokenState("");
    setUser(null);
    localStorage.removeItem(USER_KEY);
  }, []);

  // A stored token that has expired (or was revoked) can never recover —
  // drop it so the user lands back on login instead of a dead Retry loop.
  useEffect(() => {
    const id = apiClient.interceptors.response.use(undefined, (error) => {
      const isAuthEndpoint = /\/auth\/(v2\/)?(login|verify|otp|register)/.test(
        error?.config?.url || ""
      );
      if (error?.response?.status === 401 && !isAuthEndpoint) {
        logout();
      }
      return Promise.reject(error);
    });
    return () => apiClient.interceptors.response.eject(id);
  }, [logout]);

  const setCaptchaSessionToken =useCallback((value) => {
    sessionStorage.setItem(CAPTCHA_KEY, value);
    setCaptchaSessionTokenState(value);
  }, []);

  const value = {
    token,
    user,
    isAuthenticated: Boolean(token),
    login,
    logout,
    captchaSessionToken,
    isCaptchaVerified: Boolean(captchaSessionToken),
    setCaptchaSessionToken,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

export { apiClient };
