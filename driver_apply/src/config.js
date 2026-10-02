// Website settings — override with VITE_* variables in driver_apply/.env.
const env = import.meta.env;

export const config = {
  // Where "Download Android APK" points. By default the APK is served by
  // this site itself: put the file at public/downloads/findmetricycle-latest.apk.
  apkUrl: env.VITE_APP_DOWNLOAD_URL || "/downloads/findmetricycle-latest.apk",

  // The QR code points to the download page (not the raw APK).
  downloadPageUrl:
    env.VITE_DOWNLOAD_PAGE_URL || `${window.location.origin}/download`,

  contactEmail: env.VITE_CONTACT_EMAIL || "support@findmetricycle.com",

  appVersion: env.VITE_APP_VERSION || "1.0.0",
  appSize: env.VITE_APP_SIZE || "24.5 MB",
  appUpdated: env.VITE_APP_UPDATED || "2026",
  minAndroid: "Android 7.0 (Nougat) or higher",
};
