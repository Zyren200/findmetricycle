import axios from "axios";

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

apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    const skipAuthRedirect = error?.config?.skipAuthRedirect;
    if (error?.response?.status === 401 && !skipAuthRedirect) {
      localStorage.removeItem("fmt_admin_token");
      localStorage.removeItem("fmt_admin_user");
      sessionStorage.removeItem("fmt_admin_token");
      sessionStorage.removeItem("fmt_admin_user");
      setAuthToken(null);
      if (typeof window !== "undefined") {
        window.location.href = "/";
      }
    }
    return Promise.reject(error);
  }
);
