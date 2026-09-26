import axios from "axios";

const TOKEN_KEY = "fmt_driverapply_token";

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "/api",
  timeout: 30000,
});

export function getToken() {
  return localStorage.getItem(TOKEN_KEY) || "";
}

export function setToken(token) {
  if (!token) {
    localStorage.removeItem(TOKEN_KEY);
    delete apiClient.defaults.headers.common.Authorization;
    return;
  }
  localStorage.setItem(TOKEN_KEY, token);
  apiClient.defaults.headers.common.Authorization = `Bearer ${token}`;
}

// Re-attach the token on page reload.
const existingToken = getToken();
if (existingToken) {
  apiClient.defaults.headers.common.Authorization = `Bearer ${existingToken}`;
}

export { TOKEN_KEY };
