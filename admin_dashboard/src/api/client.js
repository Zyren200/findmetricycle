import axios from "axios";

export const TOKEN_KEY = "fmt_admin_token";
export const REFRESH_TOKEN_KEY = "fmt_admin_refresh_token";
export const USER_KEY = "fmt_admin_user";
// Fired on window whenever the interceptor swaps in a fresh access token,
// so AuthContext (and the socket that depends on it) can follow along.
export const TOKEN_REFRESHED_EVENT = "fmt:admin-token-refreshed";
// Shown once on the sign-in page after the admin was signed out on purpose
// (account disabled, role changed).
export const SIGN_OUT_NOTICE_KEY = "fmt_admin_signout_notice";

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "/api",
  timeout: 20000,
});

export function setAuthToken(token) {
  if (!token) {
    delete apiClient.defaults.headers.common.Authorization;
    return;
  }
  apiClient.defaults.headers.common.Authorization = `Bearer ${token}`;
}

// Tokens live in localStorage for "remember me" sessions and in
// sessionStorage otherwise; refreshed tokens go back where they came from.
function sessionStore() {
  return localStorage.getItem(REFRESH_TOKEN_KEY) ? localStorage : sessionStorage;
}

export function clearStoredSession() {
  for (const store of [localStorage, sessionStorage]) {
    store.removeItem(TOKEN_KEY);
    store.removeItem(REFRESH_TOKEN_KEY);
    store.removeItem(USER_KEY);
  }
}

let refreshInFlight = null;

// Exchanges the stored refresh token for a new pair. Concurrent 401s share
// one request, since the backend rotates (revokes) the refresh token on use.
function refreshAccessToken() {
  if (!refreshInFlight) {
    const store = sessionStore();
    const refreshToken = store.getItem(REFRESH_TOKEN_KEY);
    refreshInFlight = (async () => {
      if (!refreshToken) throw new Error("No refresh token.");
      const { data } = await apiClient.post(
        "/auth/refresh",
        { refreshToken },
        { skipAuthRedirect: true, skipAuthRefresh: true }
      );
      const authData = data?.data || {};
      if (!authData.token || !authData.refreshToken) throw new Error("Refresh failed.");
      store.setItem(TOKEN_KEY, authData.token);
      store.setItem(REFRESH_TOKEN_KEY, authData.refreshToken);
      setAuthToken(authData.token);
      window.dispatchEvent(new CustomEvent(TOKEN_REFRESHED_EVENT, { detail: authData.token }));
      return authData.token;
    })().finally(() => {
      refreshInFlight = null;
    });
  }
  return refreshInFlight;
}

apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const config = error?.config || {};
    if (error?.response?.status !== 401 || config.skipAuthRedirect) {
      return Promise.reject(error);
    }

    // Access tokens are short-lived (15m) — try one silent refresh and
    // replay the request before giving up and sending the admin to login.
    if (!config.skipAuthRefresh && !config._retriedAfterRefresh) {
      try {
        const newToken = await refreshAccessToken();
        config._retriedAfterRefresh = true;
        config.headers = { ...config.headers, Authorization: `Bearer ${newToken}` };
        return apiClient(config);
      } catch (refreshError) {
        // fall through to logout — and say why when a Super Admin disabled
        // this account.
        const reason = refreshError?.response?.data?.message || "";
        if (/disabled/i.test(reason)) sessionStorage.setItem(SIGN_OUT_NOTICE_KEY, reason);
      }
    }

    clearStoredSession();
    setAuthToken(null);
    if (typeof window !== "undefined") {
      // Reload in place; with no stored token the app renders the login
      // screen, wherever the dashboard is mounted.
      window.location.reload();
    }
    return Promise.reject(error);
  }
);
