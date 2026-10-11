import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  BarChart3,
  Bell,
  BookOpen,
  ChevronDown,
  ClipboardList,
  FileText,
  History,
  LayoutDashboard,
  LogOut,
  Mail,
  Map as MapIcon,
  MapPin,
  Megaphone,
  Menu,
  MessageSquareWarning,
  PhilippinePeso,
  ScrollText,
  Search,
  Settings as SettingsIcon,
  Siren,
  UserCheck,
  UserCog,
  Users,
  Wifi,
  Wrench,
  X,
} from "lucide-react";
import { apiClient } from "../api/client";
import { FRESH_LOGIN_KEY, useAuth } from "../context/AuthContext";
import { useSocket } from "../hooks/useSocket";
import ConfirmDialog from "../components/ConfirmDialog";
import LiveMapCard from "../components/LiveMapCard";
import NoAccessPage from "../components/NoAccessPage";
import ServiceAreaMap from "../components/ServiceAreaMap";
import NotificationsInbox from "../components/NotificationsInbox";
import NotificationsPanel from "../components/NotificationsPanel";
import ReportsInbox from "../components/ReportsInbox";
import SupportInbox from "../components/SupportInbox";
import SummaryCards from "../components/SummaryCards";
import PageHero from "../components/PageHero";
import ThemeToggle from "../components/ThemeToggle";
import { asText, formatDateTime, formatMoney, statusTone, formatPlace } from "../utils/admin-formatters";
import { PERMISSIONS as P, canOpenSection } from "../utils/admin-access";
import { isOutsideServiceArea, useServiceArea } from "../utils/service-area";
import {
  browserAlertPermission,
  installAlarmUnlock,
  playSosAlarm,
  requestBrowserAlerts,
  showBrowserAlert,
} from "../utils/sos-alerts";
import { useToasts } from "../context/ToastContext";
import ActivityLogsPage from "./ActivityLogsPage";
import AdminAccountsPage from "./AdminAccountsPage";
import AnalyticsPage from "./AnalyticsPage";
import BarangayManagerPage from "./BarangayManagerPage";
import EarningsPage from "./EarningsPage";
import SettingsPage from "./SettingsPage";
import FareSettingsPage from "./FareSettingsPage";
import PendingPage from "./PendingPage";
import DriversPage from "./DriversPage";
import RidesPage from "./RidesPage";
import AnnouncementsPage from "./AnnouncementsPage";

// A booking in any of these can be force-closed from its detail modal.
const ACTIVE_RIDE_STATUSES = ["pending", "searching", "accepted", "assigned", "arriving", "ongoing", "on_ride"];

const sections = [
  { key: "dashboard", title: "Dashboard", icon: LayoutDashboard, group: "Main" },
  { key: "live", title: "Live Map", icon: MapIcon, group: "Main" },
  { key: "users", title: "Users", icon: Users, group: "Operations" },
  { key: "applications", title: "Driver Applications", icon: ClipboardList, group: "Operations" },
  { key: "drivers", title: "Approved Drivers", icon: UserCheck, group: "Operations" },
  { key: "bookings", title: "Bookings", icon: BookOpen, group: "Operations" },
  { key: "rides", title: "Ride History", icon: History, group: "Operations" },
  { key: "sos", title: "SOS", icon: Siren, group: "Operations" },
  { key: "complaints", title: "Complaints", icon: MessageSquareWarning, group: "Operations" },
  { key: "support", title: "Contact Support", icon: Mail, group: "Operations" },
  { key: "notifications", title: "Notifications", icon: Bell, group: "Operations" },
  { key: "announcements", title: "Announcements", icon: Megaphone, group: "Operations" },
  { key: "reports", title: "Reports", icon: BarChart3, group: "Insights" },
  { key: "earnings", title: "Earnings", icon: PhilippinePeso, group: "Insights" },
  { key: "activity", title: "Activity Logs", icon: ScrollText, group: "System" },
  { key: "barangays", title: "Barangay Coverage", icon: MapPin, group: "System" },
  { key: "fares", title: "Fare Settings", icon: FileText, group: "System" },
  { key: "settings", title: "Settings", icon: Wrench, group: "System" },
  { key: "admins", title: "Admin Accounts", icon: UserCog, group: "System" },
];

const SECTION_KEYS = sections.map((s) => s.key);
// The page last opened in this browser, reopened after signing in when the
// admin may still use it.
const LAST_SECTION_KEY = "fmt_admin_last_section";
// Set once the admin has answered the "turn on SOS alerts" prompt.
const SOS_ALERTS_ASKED_KEY = "fmt_admin_sos_alerts_asked";

const SOS_STATUS_LABEL = {
  active: ["open", "danger"],
  acknowledged: ["acknowledged", "warning"],
  resolved: ["resolved", "success"],
};

// An SOS alert's status, with who is handling it or who resolved it.
function SosStatus({ alert, compact = false }) {
  const [label, tone] = SOS_STATUS_LABEL[alert.status] || [alert.status, "neutral"];
  return (
    <div>
      <span className={`status-pill status-${tone}`}>{label}</span>
      {alert.status === "active" && alert.escalatedAt ? (
        <span className="status-pill status-danger" style={{ marginLeft: 4 }} title="Sent to the Super Admins">
          escalated
        </span>
      ) : null}
      {alert.status === "acknowledged" && alert.acknowledgedBy ? (
        <small className="sos-handler">
          Handled by <b>{alert.acknowledgedBy.name}</b>
          {compact ? null : ` · ${formatDateTime(alert.acknowledgedAt)}`}
        </small>
      ) : null}
      {alert.status === "resolved" && alert.resolvedBy && !compact ? (
        <small className="sos-handler">
          By <b>{alert.resolvedBy.name}</b> · {formatDateTime(alert.resolvedAt)}
          {alert.resolutionNote ? <span className="sos-note">“{alert.resolutionNote}”</span> : null}
        </small>
      ) : null}
    </div>
  );
}

// Pages live in the URL (#/bookings), so a refresh or a shared link opens
// the same page and Back/Forward move between pages.
function sectionFromHash() {
  const key = window.location.hash.replace(/^#\/?/, "").split(/[/?]/)[0];
  return SECTION_KEYS.includes(key) ? key : null;
}

function readLastSection() {
  try {
    return localStorage.getItem(LAST_SECTION_KEY);
  } catch (_) {
    return null;
  }
}

const BOOKING_STATUSES = ["pending", "accepted", "arriving", "ongoing", "completed", "cancelled"];


function SectionCard({ title, children, action }) {
  return (
    <section className="panel">
      <div className="section-header">
        <h3 className="section-title">{title}</h3>
        {action || null}
      </div>
      {children}
    </section>
  );
}

function SearchField({ value, onChange, placeholder }) {
  return (
    <div className="adm-search">
      <Search size={14} />
      <input type="search" value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder || "Search…"} />
    </div>
  );
}

function Pill({ value }) {
  return <span className={`status-pill status-${statusTone(value)}`}>{value}</span>;
}

function SimpleTable({ columns, rows, renderRow, emptyLabel = "No records found." }) {
  return (
    <div className="table-wrap">
      <table className="compact-table">
        <thead>
          <tr>{columns.map((col) => <th key={col}>{col}</th>)}</tr>
        </thead>
        <tbody>
          {rows.length === 0 ? (
            <tr><td colSpan={columns.length}>{emptyLabel}</td></tr>
          ) : rows.map(renderRow)}
        </tbody>
      </table>
    </div>
  );
}

export default function DashboardShell() {
  const { user, logout, token, can, refreshMe, signOutWithNotice } = useAuth();
  const [activeSectionKey, setSectionState] = useState(() => sectionFromHash() || "dashboard");
  // True once the admin's current role and permissions have been read from
  // the server (the stored copy may be stale or from before roles existed).
  const [accessReady, setAccessReady] = useState(false);
  const [navOpen, setNavOpen] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  // The notification open in the inbox (Notifications page).
  const [selectedNotificationId, setSelectedNotificationId] = useState(null);
  // Real numbers only — until the first load succeeds the cards show 0.
  const [summary, setSummary] = useState({});
  const [searchTerm, setSearchTerm] = useState("");
  const [searchOpen, setSearchOpen] = useState(false);
  const [onlineDrivers, setOnlineDrivers] = useState([]);
  const [activeRides, setActiveRides] = useState([]);
  const [pendingDrivers, setPendingDrivers] = useState([]);
  const [bookings, setBookings] = useState([]);
  const [sosAlerts, setSosAlerts] = useState([]);
  const [complaints, setComplaints] = useState([]);
  // Messages from the website's Contact page.
  const [contactMessages, setContactMessages] = useState([]);
  const [passengers, setPassengers] = useState([]);
  const [userSearch, setUserSearch] = useState("");
  const [userStatusFilter, setUserStatusFilter] = useState("all");
  const [driverList, setDriverList] = useState([]);
  const [selectedBooking, setSelectedBooking] = useState(null);
  const [selectedBookingLoading, setSelectedBookingLoading] = useState(false);
  // Force-closing a stuck ride from the booking modal: { outcome } while the
  // reason dialog is open.
  const [closeRideDialog, setCloseRideDialog] = useState(null);
  const [closeRideBusy, setCloseRideBusy] = useState(false);
  const [closeRideError, setCloseRideError] = useState(null);
  const [operationsBusyId, setOperationsBusyId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  // Design layout state: collapsible sidebar (desktop), admin menu.
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [adminMenuOpen, setAdminMenuOpen] = useState(false);
  const [barangaysCovered, setBarangaysCovered] = useState(null);
  const [bookingSearch, setBookingSearch] = useState("");
  const [bookingStatus, setBookingStatus] = useState("all");
  // The report open in the Complaints inbox.
  const [selectedComplaintId, setSelectedComplaintId] = useState(null);
  // The message open in the Contact Support inbox.
  const [selectedContactId, setSelectedContactId] = useState(null);
  const [sosFilter, setSosFilter] = useState("all");
  // The SOS alert whose "Resolve" note dialog is open.
  const [resolveSosTarget, setResolveSosTarget] = useState(null);
  // The SOS alert whose location map is open.
  const [sosMapTarget, setSosMapTarget] = useState(null);
  const serviceArea = useServiceArea();
  const { addToast } = useToasts();

  // Pages the signed-in admin may open, in sidebar order.
  const visibleSections = useMemo(() => sections.filter((s) => canOpenSection(can, s.key)), [can]);
  const homeSection = visibleSections[0] || null;

  const setActiveSectionKey = useCallback((key) => {
    if (!key) return;
    if (window.location.hash !== `#/${key}`) window.location.hash = `/${key}`;
    setSectionState(key);
  }, []);

  // Typing a page into the URL, or Back/Forward.
  useEffect(() => {
    const onHashChange = () => {
      const key = sectionFromHash();
      if (key) setSectionState(key);
    };
    window.addEventListener("hashchange", onHashChange);
    return () => window.removeEventListener("hashchange", onHashChange);
  }, []);

  useEffect(() => {
    if (accessReady && canOpenSection(can, activeSectionKey)) {
      try {
        localStorage.setItem(LAST_SECTION_KEY, activeSectionKey);
      } catch (_) {
        // Storage blocked — the page just isn't remembered.
      }
    }
  }, [accessReady, activeSectionKey, can]);

  // Current role and permissions first, then everything else.
  useEffect(() => {
    let cancelled = false;
    refreshMe()
      .catch(() => null)
      .finally(() => {
        if (!cancelled) setAccessReady(true);
      });
    return () => {
      cancelled = true;
    };
  }, [refreshMe]);

  // Which page to show once access is known. A page named in the URL opens
  // as is — a forbidden one shows "No access" — except right after signing
  // in, when the URL may be left over from another admin: then the last
  // page this admin may use, or their first page, opens instead.
  useEffect(() => {
    if (!accessReady) return;
    const freshLogin = sessionStorage.getItem(FRESH_LOGIN_KEY) === "1";
    sessionStorage.removeItem(FRESH_LOGIN_KEY);
    const fromHash = sectionFromHash();
    if (fromHash && (!freshLogin || canOpenSection(can, fromHash))) {
      setSectionState(fromHash);
      return;
    }
    const last = readLastSection();
    const target = last && canOpenSection(can, last) ? last : homeSection?.key;
    if (target) {
      window.history.replaceState(null, "", `#/${target}`);
      setSectionState(target);
    }
    // Decided once, when access first becomes known.
  }, [accessReady]);

  useEffect(() => {
    if (!accessReady || !can(P.BARANGAYS_MANAGE)) return;
    apiClient
      .get("/admin/barangays")
      .then(({ data }) => {
        const list = Array.isArray(data?.data) ? data.data : [];
        setBarangaysCovered(list.filter((b) => b.is_enabled === true || b.is_enabled === 1).length);
      })
      .catch(() => {});
  }, [accessReady, can]);

  // Only what this admin's permissions cover is requested; one failing
  // request no longer blanks the whole dashboard.
  const loadData = useCallback(async () => {
    const requests = [
      ["summary", P.DASHBOARD_VIEW, "/admin/dashboard"],
      ["map", P.LIVE_MAP_VIEW, "/admin/live-map"],
      ["pending", P.DRIVER_APPLICATIONS_VIEW, "/admin/drivers/pending"],
      ["bookings", P.BOOKINGS_VIEW, "/admin/bookings"],
      ["sos", P.SOS_VIEW, "/admin/sos"],
      ["complaints", P.COMPLAINTS_VIEW, "/admin/complaints"],
      ["support", P.SUPPORT_VIEW, "/admin/contact-messages"],
      ["notifications", P.NOTIFICATIONS_VIEW, "/admin/notifications"],
      ["drivers", P.DRIVERS_VIEW, "/admin/drivers"],
      ["passengers", P.USERS_VIEW, "/admin/passengers"],
    ].filter(([, permission]) => can(permission));

    try {
      setError(null);
      const settled = await Promise.allSettled(requests.map(([, , url]) => apiClient.get(url)));
      const got = {};
      let failure = null;
      settled.forEach((result, i) => {
        if (result.status === "fulfilled") got[requests[i][0]] = result.value.data;
        else failure = failure || result.reason;
      });

      if (got.summary) setSummary(got.summary.data || {});
      if (got.map) {
        setOnlineDrivers(got.map.data?.onlineDrivers || []);
        setActiveRides(got.map.data?.activeRides || []);
      }
      if (got.pending) setPendingDrivers(got.pending.data || []);
      if (got.bookings) setBookings(got.bookings.data || []);
      if (got.sos) setSosAlerts(got.sos.data || []);
      if (got.complaints) setComplaints(got.complaints.data || []);
      if (got.support) setContactMessages(got.support.data || []);
      if (got.notifications) {
        const notificationList = got.notifications.data || [];
        setNotifications(notificationList);
        setUnreadCount(got.notifications.meta?.unread ?? notificationList.filter((n) => !n.isRead).length);
      }
      if (got.drivers) setDriverList(got.drivers.data || []);
      if (got.passengers) setPassengers(got.passengers.data || []);
      if (failure) setError(failure?.response?.data?.message || "Failed to load dashboard.");
    } finally {
      setLoading(false);
    }

    // Catches a role change even if the live notice was missed.
    refreshMe().catch(() => null);
  }, [can, refreshMe]);

  useEffect(() => {
    if (!accessReady) return undefined;
    loadData();
    const timer = setInterval(loadData, 15000);
    return () => clearInterval(timer);
  }, [accessReady, loadData]);

  // A new emergency: alarm, desktop notification and an in-page notice.
  // (Only admins with SOS access receive these events.)
  const onSosAlert = useCallback(
    (alert) => {
      setSosAlerts((prev) => [alert, ...prev.filter((item) => item.id !== alert.id)]);
      const from = alert.senderName || alert.passengerName || "a passenger";
      playSosAlarm();
      showBrowserAlert({
        title: "🚨 SOS Alert",
        body: alert.body || `Emergency alert from ${from}.`,
        tag: `sos-${alert.id}`,
        onClick: () => setActiveSectionKey("sos"),
      });
      addToast(`🚨 SOS from ${from} — open SOS to respond.`, { type: "sos", duration: 12000 });
    },
    [addToast, setActiveSectionKey]
  );

  // Someone acknowledged, resolved or escalated an alert: everyone sees who
  // is handling it right away.
  const onSosUpdated = useCallback((alert) => {
    if (!alert?.id) return;
    setSosAlerts((prev) =>
      prev.some((item) => item.id === alert.id)
        ? prev.map((item) => (item.id === alert.id ? alert : item))
        : [alert, ...prev]
    );
  }, []);

  // Nobody acknowledged an SOS in time (sent to Super Admins).
  const onSosEscalation = useCallback(
    (alert) => {
      onSosUpdated(alert);
      const from = alert.senderName || alert.passengerName || "a passenger";
      playSosAlarm({ cycles: 5 });
      showBrowserAlert({
        title: "⏰ SOS not acknowledged",
        body: `No one is handling the SOS from ${from} yet.`,
        tag: `sos-escalation-${alert.id}`,
        onClick: () => setActiveSectionKey("sos"),
      });
      addToast(`⏰ No one is handling the SOS from ${from} yet.`, { type: "sos", duration: 15000 });
    },
    [addToast, onSosUpdated, setActiveSectionKey]
  );

  // Sound needs one click or key press on the page before it may play.
  useEffect(() => installAlarmUnlock(), []);

  // Asked once: desktop notifications for new SOS alerts.
  const [sosAlertsPromptOpen, setSosAlertsPromptOpen] = useState(() => {
    try {
      return browserAlertPermission() === "default" && !localStorage.getItem(SOS_ALERTS_ASKED_KEY);
    } catch (_) {
      return false;
    }
  });

  function closeSosAlertsPrompt() {
    setSosAlertsPromptOpen(false);
    try {
      localStorage.setItem(SOS_ALERTS_ASKED_KEY, "1");
    } catch (_) {
      // Storage blocked — the prompt may show again next time.
    }
  }

  async function enableSosAlerts() {
    closeSosAlertsPrompt();
    const permission = await requestBrowserAlerts();
    addToast(
      permission === "granted"
        ? "SOS alerts are on: you'll hear an alarm and get a desktop notification."
        : "Desktop notifications are blocked in this browser. The alarm still plays while this page is open.",
      { type: permission === "granted" ? "success" : "warning", duration: 7000 }
    );
  }

  // New admin notifications arrive live instead of on the next 15s poll.
  const onNotification = useCallback((notification) => {
    if (!notification?.id) return;
    setNotifications((prev) => [notification, ...prev.filter((item) => item.id !== notification.id)]);
    if (!notification.isRead) setUnreadCount((count) => count + 1);
  }, []);

  // A Super Admin disabled this account or changed its role: the server has
  // already ended the session, so sign out now and say why.
  const onAccessChanged = useCallback(
    async (payload) => {
      if (payload?.reason === "role_changed") {
        // refreshMe signs out itself, naming the new role (null = done).
        const me = await refreshMe().catch(() => null);
        if (me === null) return;
      }
      signOutWithNotice(
        payload?.reason === "disabled"
          ? "Your admin account was disabled by a Super Admin."
          : "A Super Admin changed your admin access. Please sign in again."
      );
    },
    [refreshMe, signOutWithNotice]
  );

  const onServerDisconnect = useCallback(() => refreshMe(), [refreshMe]);

  useSocket({
    token,
    onSosAlert,
    onSosUpdated,
    onSosEscalation,
    onNotification,
    onAccessChanged,
    onServerDisconnect,
  });

  // Read state is saved on the server (it used to only change in the
  // browser, so everything came back unread after a refresh).
  async function markNotificationRead(id) {
    const target = notifications.find((item) => item.id === id);
    if (!target || target.isRead) return;
    setNotifications((items) => items.map((item) => (item.id === id ? { ...item, isRead: true } : item)));
    setUnreadCount((count) => Math.max(0, count - 1));
    try {
      await apiClient.post(`/admin/notifications/${id}/read`);
    } catch (_err) {
      // The next refresh re-syncs from the server.
    }
  }

  async function markAllNotificationsRead() {
    setNotifications((items) => items.map((item) => ({ ...item, isRead: true })));
    setUnreadCount(0);
    try {
      await apiClient.post("/admin/notifications/mark_all_read");
    } catch (_err) {
      // The next refresh re-syncs from the server.
    }
  }

  // Opening a notification (from the bell or the inbox) shows it in full on
  // the Notifications page, Gmail-style, and marks it read; the page it's
  // about is one click away from there.
  function openNotification(notification) {
    if (!notification) {
      setSelectedNotificationId(null);
      return;
    }
    markNotificationRead(notification.id);
    setSelectedNotificationId(notification.id);
    setActiveSectionKey("notifications");
    setShowNotifications(false);
  }

  // Top-bar search: the pages, users, drivers and bookings this admin may
  // open, from what the dashboard already loaded. Picking a result opens the
  // right page.
  const canSearchUsers = can(P.USERS_VIEW);
  const canSearchDrivers = can(P.DRIVERS_VIEW);
  const canSearchBookings = can(P.BOOKINGS_VIEW);
  const searchResults = useMemo(() => {
    const term = searchTerm.trim().toLowerCase();
    if (!term) return [];
    const has = (...values) => values.some((v) => String(v ?? "").toLowerCase().includes(term));
    const results = [];
    visibleSections
      .filter((s) => has(s.title))
      .forEach((s) => results.push({ id: `page-${s.key}`, kind: "Page", label: s.title, action: { type: "section", key: s.key } }));
    (canSearchUsers ? passengers : [])
      .filter((p) => has(p.full_name, p.phone, p.email))
      .slice(0, 5)
      .forEach((p) =>
        results.push({ id: `user-${p.id}`, kind: "User", label: p.full_name, sub: p.phone || p.email, action: { type: "user", term: p.full_name } })
      );
    (canSearchDrivers ? driverList : [])
      .filter((d) => has(d.full_name, d.phone, d.tricycle_number))
      .slice(0, 5)
      .forEach((d) =>
        results.push({ id: `driver-${d.id}`, kind: "Driver", label: d.full_name, sub: d.tricycle_number, action: { type: "section", key: "drivers" } })
      );
    (canSearchBookings ? bookings : [])
      .filter((b) => has(`#${b.id}`, String(b.id), b.passengerName || b.passenger_name, b.driverName || b.driver_name))
      .slice(0, 5)
      .forEach((b) =>
        results.push({
          id: `booking-${b.id}`,
          kind: "Booking",
          label: `#${b.id} · ${b.passengerName || b.passenger_name || "Passenger"}`,
          sub: b.status,
          action: { type: "booking", id: b.id },
        })
      );
    return results.slice(0, 15);
  }, [searchTerm, visibleSections, canSearchUsers, canSearchDrivers, canSearchBookings, passengers, driverList, bookings]);

  const searchPlaceholder = `Search pages${[
    canSearchUsers ? "users" : null,
    canSearchDrivers ? "drivers" : null,
    canSearchBookings ? "bookings" : null,
  ]
    .filter(Boolean)
    .map((kind) => `, ${kind}`)
    .join("")}…`;

  function openSearchResult(result) {
    const { action } = result;
    if (action.type === "section") {
      setActiveSectionKey(action.key);
    } else if (action.type === "user") {
      setUserSearch(action.term);
      setUserStatusFilter("all");
      setActiveSectionKey("users");
    } else if (action.type === "booking") {
      setActiveSectionKey("bookings");
      openBookingDetail(action.id);
    }
    setSearchTerm("");
    setSearchOpen(false);
  }

  const pageTitle = useMemo(() => sections.find((s) => s.key === activeSectionKey)?.title || "Dashboard", [activeSectionKey]);

  const opsSummary = useMemo(() => ({
    pendingApplications: pendingDrivers.length || summary.pendingApplications,
    ongoingRides: activeRides.filter((ride) => ["pending", "accepted", "ongoing"].includes(String(ride.status || "").toLowerCase())).length || summary.ongoingRides,
    sosAlerts: sosAlerts.filter((alert) => alert.status === "active").length || summary.sosAlerts,
    totalPassengers: passengers.length || summary.totalPassengers,
  }), [activeRides, passengers.length, pendingDrivers.length, sosAlerts, summary]);

  async function closeRide(reason) {
    const outcome = closeRideDialog?.outcome;
    setCloseRideDialog(null);
    if (!selectedBooking || !outcome) return;
    setCloseRideBusy(true);
    setCloseRideError(null);
    try {
      const { data } = await apiClient.post(`/admin/bookings/${selectedBooking.id}/close`, { outcome, reason });
      if (data?.data) setSelectedBooking(data.data);
      await loadData();
    } catch (err) {
      setCloseRideError(
        err?.response?.data?.details?.issues?.[0]?.message ||
          err?.response?.data?.message ||
          "Failed to close the ride."
      );
    } finally {
      setCloseRideBusy(false);
    }
  }

  async function openBookingDetail(bookingId) {
    setCloseRideError(null);
    try {
      setSelectedBookingLoading(true);
      const { data } = await apiClient.get(`/admin/bookings/${bookingId}`);
      setSelectedBooking(data?.data || null);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load booking.");
    } finally {
      setSelectedBookingLoading(false);
    }
  }

  // "I'm handling this". If someone else got there first, the server says
  // who, and the list refreshes to show it.
  async function acknowledgeSos(alert) {
    setOperationsBusyId(`sos-${alert.id}`);
    try {
      const { data } = await apiClient.post(`/admin/sos/${alert.id}/acknowledge`);
      if (data?.data) onSosUpdated(data.data);
      addToast("You're handling this alert. Resolve it with a note when it's done.", { type: "success" });
    } catch (err) {
      addToast(err?.response?.data?.message || "Failed to acknowledge the alert.", { type: "error", duration: 7000 });
      await loadData();
    } finally {
      setOperationsBusyId(null);
    }
  }

  async function resolveSos(note) {
    const alert = resolveSosTarget;
    setResolveSosTarget(null);
    if (!alert) return;
    setOperationsBusyId(`sos-${alert.id}`);
    try {
      const { data } = await apiClient.post(`/admin/sos/${alert.id}/resolve`, { note });
      if (data?.data) onSosUpdated(data.data);
      addToast("SOS resolved.", { type: "success" });
    } catch (err) {
      addToast(
        err?.response?.data?.details?.issues?.[0]?.message || err?.response?.data?.message || "Failed to resolve SOS.",
        { type: "error", duration: 7000 }
      );
      await loadData();
    } finally {
      setOperationsBusyId(null);
    }
  }

  async function suspendPassenger(id) {
    const user = passengers.find((p) => p.id === id);
    const confirmed = window.confirm(
      `Suspend ${user?.full_name || "this user"}?\n\nThey will be logged out right away and can't book rides` +
        (user?.is_driver_account ? " or drive" : "") +
        " until you reinstate them."
    );
    if (!confirmed) return;
    setOperationsBusyId(`passenger-${id}`);
    try {
      await apiClient.post(`/admin/passengers/${id}/suspend`);
      await loadData();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to suspend passenger.");
    } finally {
      setOperationsBusyId(null);
    }
  }

  async function reinstatePassenger(id) {
    const user = passengers.find((p) => p.id === id);
    if (!window.confirm(`Reinstate ${user?.full_name || "this user"}? They'll be able to log in again.`)) return;
    setOperationsBusyId(`passenger-${id}`);
    try {
      await apiClient.post(`/admin/passengers/${id}/reinstate`);
      await loadData();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to reinstate passenger.");
    } finally {
      setOperationsBusyId(null);
    }
  }

  if (loading) {
    return <div className="state-block">Loading dashboard...</div>;
  }

  function renderSection() {
    if (!canOpenSection(can, activeSectionKey)) {
      return (
        <NoAccessPage
          pageTitle={sections.find((s) => s.key === activeSectionKey)?.title}
          roleLabel={user?.admin?.roleLabel}
          homeTitle={homeSection?.title}
          onGoHome={homeSection ? () => setActiveSectionKey(homeSection.key) : null}
        />
      );
    }

    if (activeSectionKey === "dashboard") {
      const hour = new Date().getHours();
      const greeting = hour < 12 ? "morning" : hour < 18 ? "afternoon" : "evening";
      const firstName = (user?.full_name || "").split(" ")[0];
      const openSos = sosAlerts.filter((alert) => alert.status !== "resolved");

      // Today's bookings per hour, 6 AM – 9 PM, from the loaded bookings.
      const today = new Date().toDateString();
      const hourly = Array.from({ length: 16 }, (_, i) => ({ hour: 6 + i, rides: 0 }));
      bookings.forEach((b) => {
        const when = new Date(b.requestedAt || b.requested_at || b.timestamp || "");
        if (Number.isNaN(when.getTime()) || when.toDateString() !== today) return;
        const slot = hourly.find((h) => h.hour === when.getHours());
        if (slot) slot.rides += 1;
      });
      const maxHourly = Math.max(1, ...hourly.map((h) => h.rides));

      return (
        <div className="page-stack">
          <PageHero
            title="Dashboard"
            description={`Good ${greeting}${firstName ? `, ${firstName}` : ""} — here's today's overview`}
          />
          <SummaryCards
            summary={{ ...summary, ...opsSummary }}
            barangaysCovered={barangaysCovered}
            onNavigate={setActiveSectionKey}
            can={can}
            canOpen={(key) => canOpenSection(can, key)}
          />

          {/* Each widget only when the admin may see its data. */}
          <div className="adm-grid-3">
            {can(P.BOOKINGS_VIEW) ? (
              <section className="adm-card adm-span-2">
                <div className="adm-card-head">
                  <h3>Today at a Glance</h3>
                  <small>Hourly bookings</small>
                </div>
                <div className="adm-hourly">
                  {hourly.map((h) => (
                    <div key={h.hour} title={`${String(h.hour).padStart(2, "0")}:00 — ${h.rides} bookings`}>
                      <div className="bar" style={{ height: `${(h.rides / maxHourly) * 100}%` }} />
                      <span>{String(h.hour).padStart(2, "0")}</span>
                    </div>
                  ))}
                </div>
              </section>
            ) : null}

            {can(P.SOS_VIEW) ? (
              <section className="adm-card">
                <div className="adm-card-head">
                  <h3><Siren size={14} color="var(--red)" /> SOS Alerts</h3>
                  <button type="button" className="adm-link" onClick={() => setActiveSectionKey("sos")}>View all</button>
                </div>
                {openSos.length === 0 ? (
                  <p className="adm-empty">No active SOS alerts</p>
                ) : (
                  <div className="adm-list">
                    {openSos.slice(0, 4).map((alert) => (
                      <div key={alert.id} className="adm-sos-item">
                        <div>
                          <b>{alert.senderName || alert.passengerName || alert.driverName || asText(alert.title) || "SOS Alert"}</b>
                          <p>{alert.body}</p>
                          <small>{formatDateTime(alert.createdAt)}</small>
                          <SosStatus alert={alert} compact />
                        </div>
                        {alert.status === "active" ? <i /> : null}
                      </div>
                    ))}
                  </div>
                )}
              </section>
            ) : null}

            {can(P.LIVE_MAP_VIEW) ? (
              <section className="adm-card">
                <div className="adm-card-head">
                  <h3><Wifi size={14} color="var(--accent)" /> Online Drivers</h3>
                  <button type="button" className="adm-link" onClick={() => setActiveSectionKey("live")}>Live map</button>
                </div>
                {onlineDrivers.length === 0 ? (
                  <p className="adm-empty">No drivers online right now</p>
                ) : (
                  <div className="adm-list">
                    {onlineDrivers.slice(0, 6).map((d) => (
                      <div key={d.id} className="adm-row">
                        <div className="adm-avatar">{(d.full_name || "?")[0]}</div>
                        <div className="grow">
                          <b>{d.full_name}</b>
                          <small>{d.tricycle_number || "—"}</small>
                        </div>
                        <small style={{ color: "var(--green)" }}>ONLINE</small>
                      </div>
                    ))}
                  </div>
                )}
              </section>
            ) : null}

            {can(P.DRIVER_APPLICATIONS_VIEW) ? (
              <section className="adm-card">
                <div className="adm-card-head">
                  <h3>Recent Registrations</h3>
                  <button type="button" className="adm-link" onClick={() => setActiveSectionKey("applications")}>Review all</button>
                </div>
                {pendingDrivers.length === 0 ? (
                  <p className="adm-empty">No applications waiting</p>
                ) : (
                  <div className="adm-list">
                    {pendingDrivers.slice(0, 4).map((d) => (
                      <div key={d.id} className="adm-row">
                        <div className="adm-avatar" style={{ background: "rgba(217,119,6,0.2)", color: "#fbbf24" }}>
                          {(d.name || d.full_name || "?")[0]}
                        </div>
                        <div className="grow">
                          <b>{d.name || d.full_name}</b>
                          <small>{formatDateTime(d.appliedDate || d.submitted_at)}</small>
                        </div>
                        <Pill value={d.status || "pending"} />
                      </div>
                    ))}
                  </div>
                )}
              </section>
            ) : null}

            {can(P.BOOKINGS_VIEW) ? (
              <section className="adm-card">
                <div className="adm-card-head">
                  <h3>Recent Bookings</h3>
                  <button type="button" className="adm-link" onClick={() => setActiveSectionKey("bookings")}>View all</button>
                </div>
                {bookings.length === 0 ? (
                  <p className="adm-empty">No bookings yet</p>
                ) : (
                  <div className="adm-list">
                    {bookings.slice(0, 5).map((b) => (
                      <button
                        type="button"
                        key={b.id}
                        className="adm-row"
                        style={{ background: "none", border: 0, padding: 0, cursor: "pointer", textAlign: "left", color: "inherit" }}
                        onClick={() => openBookingDetail(b.id)}
                      >
                        <div className="grow">
                          <b>
                            {b.passengerName || b.passenger_name} <Pill value={b.status} />
                          </b>
                          <small>
                            {formatPlace(b.pickupAddress || b.pickup)} → {formatPlace(b.dropoffAddress || b.destination)}
                          </small>
                        </div>
                        <small style={{ color: "var(--green)" }}>₱{b.finalFare || b.estimatedFare || b.fare || 0}</small>
                      </button>
                    ))}
                  </div>
                )}
              </section>
            ) : null}
          </div>

          {can(P.LIVE_MAP_VIEW) ? <LiveMapCard onlineDrivers={onlineDrivers} activeRides={activeRides} sosAlerts={sosAlerts} /> : null}

          {can(P.DRIVERS_VIEW) ? (
            <SectionCard
              title="Approved Drivers"
              action={<button type="button" className="adm-link" onClick={() => setActiveSectionKey("drivers")}>Manage</button>}
            >
              <SimpleTable
                columns={["Name", "Plate", "Rating", "License"]}
                rows={driverList}
                renderRow={(driver) => (
                  <tr key={driver.id}>
                    <td>{driver.full_name}</td>
                    <td style={{ fontFamily: "var(--font-mono)", fontSize: 12 }}>{driver.tricycle_number}</td>
                    <td>{Number(driver.rating_avg || driver.rating || 0).toFixed(1)}</td>
                    <td><Pill value={new Date(driver.license_expires_at) < new Date() ? "expired" : "active"} /></td>
                  </tr>
                )}
              />
            </SectionCard>
          ) : null}
        </div>
      );
    }

    if (activeSectionKey === "live") {
      return (
        <div className="page-stack">
          <PageHero
            title="Live Map"
            description={`${onlineDrivers.length} drivers online · ${activeRides.length} active rides`}
          />
          <LiveMapCard onlineDrivers={onlineDrivers} activeRides={activeRides} sosAlerts={sosAlerts} />
        </div>
      );
    }

    if (activeSectionKey === "users") {
      const canManageUsers = can(P.USERS_MANAGE);
      const term = userSearch.trim().toLowerCase();
      const visibleUsers = passengers.filter((row) => {
        if (userStatusFilter !== "all" && row.status !== userStatusFilter) return false;
        if (!term) return true;
        return [row.full_name, row.phone, row.email].some((v) => String(v || "").toLowerCase().includes(term));
      });
      const suspendedCount = passengers.filter((row) => row.status === "suspended").length;
      return (
        <div className="page-stack">
          <PageHero title="Users" description={`All passenger accounts — ${passengers.length} registered`} />
          <div className="filter-bar" style={{ marginBottom: 0 }}>
            <SearchField value={userSearch} onChange={setUserSearch} placeholder="Name, phone or email…" />
            <select className="input" value={userStatusFilter} onChange={(e) => setUserStatusFilter(e.target.value)}>
              <option value="all">All statuses</option>
              <option value="active">Active</option>
              <option value="suspended">Suspended ({suspendedCount})</option>
            </select>
            <span className="adm-count">{visibleUsers.length} users</span>
          </div>
        <section className="panel" style={{ padding: 0 }}>
          <SimpleTable
            columns={["User", "Phone", "Joined", "Rides", "Spent", "Status", ...(canManageUsers ? ["Actions"] : [])]}
            rows={visibleUsers}
            emptyLabel={passengers.length ? "No users match this search or filter." : "No users yet."}
            renderRow={(row) => {
              const isSuspended = row.status === "suspended";
              const busy = operationsBusyId === `passenger-${row.id}`;
              return (
                <tr key={row.id}>
                  <td>
                    <div className="adm-row">
                      <div className="adm-avatar">{(row.full_name || "?")[0]}</div>
                      <div className="grow">
                        <b style={{ fontSize: 13 }}>
                          {row.full_name}
                          {row.is_driver_account ? (
                            <span style={{ marginLeft: 6 }}><Pill value={`driver · ${row.driver_approval_status}`} /></span>
                          ) : null}
                        </b>
                        <small>{row.email || "-"}</small>
                      </div>
                    </div>
                  </td>
                  <td>{row.phone || "-"}</td>
                  <td>{formatDateTime(row.created_at)}</td>
                  <td title={`${row.total_bookings ?? 0} bookings in total`}>
                    {row.completed_rides ?? 0} completed
                    {Number(row.cancelled_rides) > 0 ? <div><small>{row.cancelled_rides} cancelled</small></div> : null}
                  </td>
                  <td>{formatMoney(row.total_spent || 0)}</td>
                  <td><Pill value={row.status} /></td>
                  {canManageUsers ? (
                    <td>
                      {isSuspended ? (
                        <button
                          type="button"
                          className="btn btn-success btn-sm"
                          disabled={busy}
                          onClick={() => reinstatePassenger(row.id)}
                        >
                          {busy ? "..." : "Reinstate"}
                        </button>
                      ) : (
                        <button
                          type="button"
                          className="btn btn-danger btn-sm"
                          disabled={busy}
                          onClick={() => suspendPassenger(row.id)}
                        >
                          {busy ? "..." : "Suspend"}
                        </button>
                      )}
                    </td>
                  ) : null}
                </tr>
              );
            }}
          />
        </section>
        </div>
      );
    }

    if (activeSectionKey === "applications") {
      return <PendingPage />;
    }

    if (activeSectionKey === "drivers") {
      return <DriversPage />;
    }

    if (activeSectionKey === "bookings") {
      const term = bookingSearch.trim().toLowerCase();
      const statusOf = (s) => {
        const v = String(s || "").toLowerCase();
        if (v === "searching") return "pending";
        if (v === "assigned") return "accepted";
        if (v === "on_ride") return "ongoing";
        return v;
      };
      const visibleBookings = bookings.filter((ride) => {
        if (bookingStatus !== "all" && statusOf(ride.status) !== bookingStatus) return false;
        if (!term) return true;
        return [`#${ride.id}`, ride.id, ride.passengerName || ride.passenger_name, ride.driverName || ride.driver_name].some((v) =>
          String(v ?? "").toLowerCase().includes(term)
        );
      });
      return (
        <div className="page-stack">
          <PageHero title="Bookings" description="All rides and booking history — click a row for its timeline" />
          <div className="filter-bar" style={{ marginBottom: 0 }}>
            <SearchField value={bookingSearch} onChange={setBookingSearch} placeholder="Passenger, driver, or booking ID…" />
            <select className="input" value={bookingStatus} onChange={(e) => setBookingStatus(e.target.value)}>
              <option value="all">All Status</option>
              {BOOKING_STATUSES.map((s) => (
                <option key={s} value={s}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>
              ))}
            </select>
            <span className="adm-count">{visibleBookings.length} bookings</span>
          </div>
          <section className="panel" style={{ padding: 0 }}>
            <SimpleTable
              columns={["Booking ID", "Passenger", "Driver", "Pickup", "Drop-off", "Fare", "Status", "Date", ""]}
              rows={visibleBookings}
              emptyLabel="No bookings found."
              renderRow={(ride) => (
                <tr key={ride.id} style={{ cursor: "pointer" }} onClick={() => openBookingDetail(ride.id)}>
                  <td style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--accent)" }}>#{ride.id}</td>
                  <td style={{ fontWeight: 500, color: "var(--text)" }}>{ride.passengerName || ride.passenger_name}</td>
                  <td>{ride.driverName || ride.driver_name || <i style={{ color: "var(--faint)" }}>Unassigned</i>}</td>
                  <td style={{ fontSize: 12, maxWidth: 180 }}>{formatPlace(ride.pickupAddress || ride.pickup)}</td>
                  <td style={{ fontSize: 12, maxWidth: 180 }}>{formatPlace(ride.dropoffAddress || ride.destination)}</td>
                  <td style={{ fontFamily: "var(--font-mono)", color: "var(--green)" }}>₱{ride.finalFare || ride.estimatedFare || ride.fare || 0}</td>
                  <td><Pill value={ride.status} /></td>
                  <td style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--muted2)" }}>
                    {formatDateTime(ride.completedAt || ride.requestedAt || ride.timestamp)}
                  </td>
                  <td>
                    <button type="button" className="btn btn-ghost btn-sm" onClick={(e) => { e.stopPropagation(); openBookingDetail(ride.id); }}>
                      View
                    </button>
                  </td>
                </tr>
              )}
            />
          </section>
        </div>
      );
    }

    if (activeSectionKey === "sos") {
      const canRespond = can(P.SOS_RESPOND);
      // Open = nobody has acknowledged it yet.
      const openCount = sosAlerts.filter((a) => a.status === "active").length;
      const handlingCount = sosAlerts.filter((a) => a.status === "acknowledged").length;
      const visibleSos = sosAlerts.filter((a) => sosFilter === "all" || a.status === sosFilter);
      return (
        <div className="page-stack">
          <PageHero
            title="SOS Emergency Center"
            description="Emergency alerts from passengers and drivers. Acknowledge one to show everyone you're handling it."
          />
          {openCount > 0 ? (
            <div className="error-banner" style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <Siren size={16} /> <b>{openCount} open SOS alert{openCount > 1 ? "s" : ""}</b> — no one is handling{" "}
              {openCount > 1 ? "them" : "it"} yet.
            </div>
          ) : null}
          <div className="filter-bar" style={{ marginBottom: 0 }}>
            <select className="input" value={sosFilter} onChange={(e) => setSosFilter(e.target.value)}>
              <option value="all">All alerts</option>
              <option value="active">Open ({openCount})</option>
              <option value="acknowledged">Being handled ({handlingCount})</option>
              <option value="resolved">Resolved</option>
            </select>
            <span className="adm-count">{visibleSos.length} alerts</span>
          </div>
          <section className="panel" style={{ padding: 0 }}>
            <SimpleTable
              columns={["Sent by", "Passenger", "Driver", "Ride ID", "Location", "Contact", "Timestamp", "Status", ...(canRespond ? ["Action"] : [])]}
              rows={visibleSos}
              emptyLabel="No SOS alerts."
              renderRow={(row) => (
                <tr
                  key={row.id}
                  style={
                    row.status === "active"
                      ? { background: "rgba(239,68,68,0.08)" }
                      : row.status === "acknowledged"
                        ? { background: "rgba(245,158,11,0.05)" }
                        : undefined
                  }
                >
                  <td style={{ fontWeight: 500, color: "var(--text)" }}>
                    {row.senderName || row.passengerName || "-"}
                    {row.sentBy ? <div><small className="muted">{row.sentBy}</small></div> : null}
                    {row.body ? <small className="sos-note" style={{ maxWidth: 260 }}>{row.body}</small> : null}
                  </td>
                  <td>{row.passengerName || "-"}</td>
                  <td>{row.driverName || "-"}</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontSize: 12 }}>
                    {row.bookingId ? (
                      // Anyone who sees SOS alerts may open the ride it was raised on.
                      <button type="button" className="adm-link" onClick={() => openBookingDetail(row.bookingId)}>
                        #{row.bookingId}
                      </button>
                    ) : "-"}
                  </td>
                  <td>
                    {row.lat != null && row.lng != null ? (
                      <>
                        <button type="button" className="adm-link" onClick={() => setSosMapTarget(row)}>
                          View map
                        </button>
                        {isOutsideServiceArea(serviceArea, row.lat, row.lng) ? (
                          <div><span className="status-pill status-warning">outside service area</span></div>
                        ) : null}
                      </>
                    ) : (
                      "-"
                    )}
                  </td>
                  <td style={{ fontFamily: "var(--font-mono)", fontSize: 12 }}>{row.contact || "-"}</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontSize: 12 }}>{formatDateTime(row.createdAt)}</td>
                  <td style={{ minWidth: 170 }}><SosStatus alert={row} /></td>
                  {canRespond ? (
                    <td>
                      {row.status === "active" ? (
                        <button
                          type="button"
                          className="btn btn-danger btn-sm"
                          disabled={operationsBusyId === `sos-${row.id}`}
                          onClick={() => acknowledgeSos(row)}
                        >
                          {operationsBusyId === `sos-${row.id}` ? "..." : "I'm handling this"}
                        </button>
                      ) : row.status === "acknowledged" ? (
                        <button
                          type="button"
                          className={row.acknowledgedBy?.id === user?.id ? "btn btn-success btn-sm" : "btn btn-ghost btn-sm"}
                          title={row.acknowledgedBy?.id === user?.id ? undefined : `${row.acknowledgedBy?.name || "Another admin"} is handling this`}
                          disabled={operationsBusyId === `sos-${row.id}`}
                          onClick={() => setResolveSosTarget(row)}
                        >
                          {operationsBusyId === `sos-${row.id}` ? "..." : "Resolve"}
                        </button>
                      ) : (
                        <small className="muted">Done</small>
                      )}
                    </td>
                  ) : null}
                </tr>
              )}
            />
          </section>
        </div>
      );
    }

    if (activeSectionKey === "complaints") {
      const openReports = complaints.filter((c) => c.status === "open").length;
      return (
        <div className="page-stack">
          <PageHero
            title="Complaint Center"
            description={openReports ? `${openReports} open report${openReports === 1 ? "" : "s"}` : "No open reports"}
          />
          <ReportsInbox
            complaints={complaints}
            selectedId={selectedComplaintId}
            onSelect={(report) => setSelectedComplaintId(report?.id ?? null)}
            onOpenBooking={can(P.BOOKINGS_VIEW) ? openBookingDetail : null}
            canResolve={can(P.COMPLAINTS_RESOLVE)}
            onChanged={loadData}
          />
        </div>
      );
    }

    if (activeSectionKey === "support") {
      const openMessages = contactMessages.filter((m) => m.status === "open").length;
      return (
        <div className="page-stack">
          <PageHero
            title="Contact Support"
            description={
              openMessages
                ? `${openMessages} message${openMessages === 1 ? "" : "s"} waiting for a reply`
                : "No messages waiting for a reply"
            }
          />
          <SupportInbox
            messages={contactMessages}
            selectedId={selectedContactId}
            onSelect={(message) => setSelectedContactId(message?.id ?? null)}
            canReply={can(P.SUPPORT_REPLY)}
            onChanged={loadData}
          />
        </div>
      );
    }

    if (activeSectionKey === "notifications") {
      return (
        <div className="page-stack">
        <PageHero
          title="Notifications"
          description={unreadCount ? `${unreadCount} unread` : "You're all caught up"}
        />
        <NotificationsInbox
          notifications={notifications}
          unreadCount={unreadCount}
          selectedId={selectedNotificationId}
          onSelect={openNotification}
          onMarkAllRead={markAllNotificationsRead}
          sosAlerts={sosAlerts}
          complaints={complaints}
          // An SOS responder's notifications only point at bookings an SOS
          // was raised on, which they may open.
          onOpenBooking={can(P.BOOKINGS_VIEW) || can(P.SOS_VIEW) ? openBookingDetail : null}
          onOpenReport={
            can(P.COMPLAINTS_VIEW)
              ? (complaintId) => {
                  setSelectedComplaintId(complaintId);
                  setActiveSectionKey("complaints");
                }
              : null
          }
          onOpenSection={(key, info) => {
            if (key === "support" && info?.contactMessageId) setSelectedContactId(info.contactMessageId);
            setActiveSectionKey(key);
          }}
          canOpenSection={(key) => canOpenSection(can, key)}
        />
        </div>
      );
    }

    if (activeSectionKey === "reports") {
      return <AnalyticsPage />;
    }

    if (activeSectionKey === "earnings") {
      return <EarningsPage />;
    }

    if (activeSectionKey === "activity") {
      return <ActivityLogsPage />;
    }

    if (activeSectionKey === "barangays") {
      return <BarangayManagerPage />;
    }

    if (activeSectionKey === "fares") {
      return <FareSettingsPage />;
    }

    if (activeSectionKey === "settings") {
      return <SettingsPage onOpenFares={can(P.FARES_MANAGE) ? () => setActiveSectionKey("fares") : null} />;
    }

    if (activeSectionKey === "admins") {
      return <AdminAccountsPage />;
    }

    if (activeSectionKey === "rides") {
      return <RidesPage />;
    }

    if (activeSectionKey === "announcements") {
      return <AnnouncementsPage />;
    }

    return (
      <SectionCard title="Dashboard">
        <div className="detail-list">
          <div className="detail-row"><span>Status</span><span>Ready</span></div>
        </div>
      </SectionCard>
    );
  }

  const badges = {
    applications: pendingDrivers.length,
    // Alerts nobody is handling yet.
    sos: sosAlerts.filter((a) => a.status === "active").length,
    support: contactMessages.filter((m) => m.status === "open").length,
    notifications: unreadCount,
  };
  const initials = (user?.full_name || "Admin")
    .split(" ")
    .filter(Boolean)
    .map((n) => n[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
  // Sidebar groups that have at least one page this admin may open.
  const navGroups = ["Main", "Operations", "Insights", "System"].filter((group) =>
    visibleSections.some((s) => s.group === group)
  );
  const roleChip = user?.admin ? (
    <span className={`adm-role-chip role-${user.admin.role}`}>{user.admin.roleLabel}</span>
  ) : null;

  function go(key) {
    setActiveSectionKey(key);
    setNavOpen(false);
    setAdminMenuOpen(false);
    setShowNotifications(false);
  }

  return (
    <div className="adm-frame">
      {/* Phone/tablet: the sidebar slides in over the page. */}
      <div className={navOpen ? "adm-backdrop open" : "adm-backdrop"} onClick={() => setNavOpen(false)} />
      <aside className={`adm-sidebar ${sidebarCollapsed ? "collapsed" : ""} ${navOpen ? "mobile-open" : ""}`}>
        <div className="adm-brand">
          <div className="adm-brand-mark has-img"><img src={`${import.meta.env.BASE_URL}app-icon.png`} alt="" /></div>
          <div>
            <p className="adm-brand-name">FindMeTricycle</p>
            <p className="adm-brand-sub">ADMIN PORTAL</p>
          </div>
        </div>

        <nav className="adm-nav">
          {navGroups.map((group) => (
            <div className="adm-nav-group" key={group}>
              <p className="adm-nav-label">{group}</p>
              {visibleSections.filter((s) => s.group === group).map((section) => {
                const Icon = section.icon;
                const badge = badges[section.key] || 0;
                return (
                  <button
                    key={section.key}
                    type="button"
                    className={activeSectionKey === section.key ? "adm-nav-item active" : "adm-nav-item"}
                    onClick={() => go(section.key)}
                  >
                    <Icon size={15} style={{ flexShrink: 0 }} />
                    <span className="lbl">{section.title}</span>
                    {badge > 0 ? (
                      <span className={`adm-nav-badge ${section.key === "sos" ? "alert" : ""}`}>{badge > 99 ? "99+" : badge}</span>
                    ) : null}
                  </button>
                );
              })}
            </div>
          ))}
        </nav>

        <div className="adm-sidebar-foot">
          <div className="adm-avatar">{initials}</div>
          <div className="adm-who">
            <b>{user?.full_name || "Admin"}</b>
            <small>{user?.email || "Administrator"}</small>
            {roleChip}
          </div>
        </div>
      </aside>

      <div className="adm-main">
        <header className="adm-topbar">
          <button
            type="button"
            className="adm-icon-btn"
            aria-label="Toggle menu"
            onClick={() => {
              if (window.matchMedia("(max-width: 900px)").matches) setNavOpen((o) => !o);
              else setSidebarCollapsed((c) => !c);
            }}
          >
            {sidebarCollapsed || !navOpen ? <Menu size={18} /> : <X size={18} />}
          </button>

          <div className="adm-crumb">
            <span>FindMeTricycle</span>
            <span className="sep">/</span>
            <span className="cur">{pageTitle}</span>
          </div>

          <div className="adm-top-right">
            <div className="adm-search" style={{ position: "relative" }}>
              <Search size={14} />
              <input
                type="search"
                placeholder={searchPlaceholder}
                value={searchTerm}
                onChange={(e) => {
                  setSearchTerm(e.target.value);
                  setSearchOpen(true);
                }}
                onFocus={() => setSearchOpen(true)}
                onBlur={() => setTimeout(() => setSearchOpen(false), 150)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && searchResults[0]) openSearchResult(searchResults[0]);
                  if (e.key === "Escape") setSearchOpen(false);
                }}
              />
              {searchOpen && searchTerm.trim() ? (
                <div className="adm-dropdown adm-search-results">
                  {searchResults.length === 0 ? (
                    <p className="adm-empty">No matches for “{searchTerm.trim()}”.</p>
                  ) : (
                    searchResults.map((result) => (
                      <button key={result.id} type="button" onMouseDown={(e) => e.preventDefault()} onClick={() => openSearchResult(result)}>
                        <span>
                          {result.label}
                          {result.sub ? <span style={{ color: "var(--muted2)", marginLeft: 6, fontSize: 12 }}>{result.sub}</span> : null}
                        </span>
                        <small>{result.kind}</small>
                      </button>
                    ))
                  )}
                </div>
              ) : null}
            </div>

            <ThemeToggle />
            <span className="adm-live"><i /> LIVE</span>

            {can(P.NOTIFICATIONS_VIEW) ? (
              <div style={{ position: "relative" }}>
                <button
                  type="button"
                  className="adm-icon-btn"
                  aria-label={unreadCount ? `Notifications (${unreadCount} unread)` : "Notifications"}
                  onClick={() => {
                    setShowNotifications((s) => !s);
                    setAdminMenuOpen(false);
                  }}
                >
                  <Bell size={16} />
                  {unreadCount > 0 ? <span className="adm-dot" /> : null}
                </button>
              </div>
            ) : null}

            <div style={{ position: "relative" }}>
              <button
                type="button"
                className="adm-user-btn"
                onClick={() => {
                  setAdminMenuOpen((o) => !o);
                  setShowNotifications(false);
                }}
              >
                <span className="adm-avatar sm">{initials}</span>
                <span className="who">
                  <span className="nm">{user?.full_name || "Admin"}</span>
                  {roleChip}
                </span>
                <ChevronDown size={14} color="var(--muted2)" />
              </button>
              {adminMenuOpen ? (
                <div className="adm-dropdown" style={{ width: 180 }}>
                  {can(P.SETTINGS_MANAGE) ? (
                    <>
                      <button type="button" className="item" onClick={() => go("settings")}>
                        <SettingsIcon size={14} /> Settings
                      </button>
                      <div className="sep" />
                    </>
                  ) : null}
                  <button type="button" className="item danger" onClick={logout}>
                    <LogOut size={14} /> Sign out
                  </button>
                </div>
              ) : null}
            </div>
          </div>
        </header>

        {showNotifications ? (
          <NotificationsPanel
            notifications={notifications}
            onClose={() => setShowNotifications(false)}
            unreadCount={unreadCount}
            onMarkAllRead={markAllNotificationsRead}
            onMarkRead={markNotificationRead}
            onOpen={openNotification}
            onOpenInbox={() => {
              setSelectedNotificationId(null);
              setActiveSectionKey("notifications");
              setShowNotifications(false);
            }}
          />
        ) : null}

        <main
          className="adm-content"
          onClick={() => {
            setAdminMenuOpen(false);
          }}
        >
          <div className="page-stack">
            {sosAlertsPromptOpen && can(P.SOS_VIEW) ? (
              <div className="sos-alerts-prompt" role="status">
                <Siren size={16} />
                <span>
                  Turn on SOS alerts to get a desktop notification (and hear an alarm) the moment an SOS comes in.
                </span>
                <button type="button" className="btn btn-primary btn-sm" onClick={enableSosAlerts}>
                  Turn on
                </button>
                <button type="button" className="btn btn-ghost btn-sm" onClick={closeSosAlertsPrompt}>
                  Not now
                </button>
              </div>
            ) : null}
            {error ? (
              <div className="error-banner">
                {error}{" "}
                <button type="button" className="btn btn-ghost btn-sm" onClick={loadData}>
                  Retry
                </button>
              </div>
            ) : null}
            {renderSection()}
          </div>
        </main>
      </div>

      {selectedBooking ? (
        <div className="modal-overlay open">
          <div className="modal">
            <div className="modal-header">
              <div className="modal-title">Booking Timeline</div>
              <button className="modal-close" type="button" onClick={() => setSelectedBooking(null)}>×</button>
            </div>
            <div className="modal-body">
              {selectedBookingLoading ? (
                <div className="state-block">Loading booking...</div>
              ) : (
                <>
                  <div className="detail-list">
                    <div className="detail-row"><span>Booking ID</span><strong>#{selectedBooking.id}</strong></div>
                    <div className="detail-row"><span>Status</span><strong>{selectedBooking.status}</strong></div>
                    <div className="detail-row"><span>Passenger</span><strong>{selectedBooking.passengerName || "-"}</strong></div>
                    <div className="detail-row"><span>Driver</span><strong>{selectedBooking.driverName || "-"}</strong></div>
                    <div className="detail-row"><span>Pickup</span><strong>{formatPlace(selectedBooking.pickupAddress)}</strong></div>
                    <div className="detail-row"><span>Drop-off</span><strong>{formatPlace(selectedBooking.dropoffAddress)}</strong></div>
                    <div className="detail-row"><span>Fare</span><strong>PHP {selectedBooking.finalFare || selectedBooking.estimatedFare || 0}</strong></div>
                    <div className="detail-row"><span>Billing</span><strong>Cash only</strong></div>
                    {selectedBooking.cancelledBy ? (
                      <div className="detail-row"><span>Cancelled by</span><strong>{selectedBooking.cancelledBy}</strong></div>
                    ) : null}
                    {selectedBooking.cancelReason ? (
                      <div className="detail-row"><span>Reason</span><strong>{selectedBooking.cancelReason}</strong></div>
                    ) : null}
                  </div>
                  {can(P.BOOKINGS_CLOSE) && ACTIVE_RIDE_STATUSES.includes(selectedBooking.status) ? (
                    <p className="muted" style={{ fontSize: "0.85rem", marginTop: 12 }}>
                      Stuck ride? Force-close it below — both the passenger and the driver are notified, and the
                      passenger can book again right away.
                    </p>
                  ) : null}
                  {closeRideError ? <div className="error-banner" style={{ marginTop: 12 }}>{closeRideError}</div> : null}
                  <div className="timeline" style={{ marginTop: 16 }}>
                    <div className="tl-item"><div className="tl-dot" style={{ background: "var(--green)" }} /><div className="tl-content"><div className="tl-title">Requested</div><div className="tl-time">{formatDateTime(selectedBooking.requestedAt)}</div></div></div>
                    <div className="tl-item"><div className="tl-dot" style={{ background: "var(--accent)" }} /><div className="tl-content"><div className="tl-title">Accepted</div><div className="tl-time">{formatDateTime(selectedBooking.acceptedAt)}</div></div></div>
                    <div className="tl-item"><div className="tl-dot" style={{ background: "var(--blue)" }} /><div className="tl-content"><div className="tl-title">Started</div><div className="tl-time">{formatDateTime(selectedBooking.startedAt)}</div></div></div>
                    <div className="tl-item"><div className="tl-dot" style={{ background: "var(--red)" }} /><div className="tl-content"><div className="tl-title">Completed / Cancelled</div><div className="tl-time">{formatDateTime(selectedBooking.completedAt || selectedBooking.cancelledAt)}</div></div></div>
                  </div>
                </>
              )}
            </div>
            <div className="modal-footer">
              {!selectedBookingLoading && can(P.BOOKINGS_CLOSE) && ACTIVE_RIDE_STATUSES.includes(selectedBooking.status) ? (
                <>
                  {["ongoing", "on_ride"].includes(selectedBooking.status) ? (
                    <button
                      className="btn btn-success"
                      type="button"
                      disabled={closeRideBusy}
                      onClick={() => setCloseRideDialog({ outcome: "completed" })}
                    >
                      Mark Completed
                    </button>
                  ) : null}
                  <button
                    className="btn btn-danger"
                    type="button"
                    disabled={closeRideBusy}
                    onClick={() => setCloseRideDialog({ outcome: "cancelled" })}
                  >
                    {closeRideBusy ? "Closing..." : "Force Cancel"}
                  </button>
                </>
              ) : null}
              <button className="btn btn-ghost" type="button" onClick={() => setSelectedBooking(null)}>Close</button>
            </div>
          </div>
        </div>
      ) : null}

      {sosMapTarget ? (
        <div className="modal-overlay open">
          <div className="modal" style={{ maxWidth: 640 }}>
            <div className="modal-header">
              <div className="modal-title">
                SOS location — {sosMapTarget.senderName || sosMapTarget.passengerName || "SOS"}
              </div>
              <button className="modal-close" type="button" onClick={() => setSosMapTarget(null)}>×</button>
            </div>
            <div className="modal-body">
              {isOutsideServiceArea(serviceArea, sosMapTarget.lat, sosMapTarget.lng) ? (
                <div className="warning-banner" style={{ marginBottom: 12 }}>
                  Outside service area — this alert came from outside Guiuan. It is shown anyway: an emergency is
                  never hidden or blocked because of where it is.
                </div>
              ) : null}
              <ServiceAreaMap
                points={[
                  {
                    id: sosMapTarget.id,
                    lat: sosMapTarget.lat,
                    lng: sosMapTarget.lng,
                    label: "SOS",
                    color: "#DC2626",
                    highlight: true,
                  },
                ]}
                focus={{ lat: sosMapTarget.lat, lng: sosMapTarget.lng }}
                height={360}
                ariaLabel="SOS location map"
              />
              <div className="detail-list" style={{ marginTop: 12 }}>
                <div className="detail-row">
                  <span>Coordinates</span>
                  <strong style={{ fontFamily: "var(--font-mono)" }}>
                    {Number(sosMapTarget.lat).toFixed(5)}, {Number(sosMapTarget.lng).toFixed(5)}
                  </strong>
                </div>
                <div className="detail-row"><span>Sent</span><strong>{formatDateTime(sosMapTarget.createdAt)}</strong></div>
                <div className="detail-row"><span>Contact</span><strong>{sosMapTarget.contact || "-"}</strong></div>
              </div>
            </div>
            <div className="modal-footer">
              <a
                className="btn btn-ghost"
                href={`https://www.openstreetmap.org/?mlat=${sosMapTarget.lat}&mlon=${sosMapTarget.lng}#map=17/${sosMapTarget.lat}/${sosMapTarget.lng}`}
                target="_blank"
                rel="noreferrer"
              >
                Open in OpenStreetMap ↗
              </a>
              <button className="btn btn-ghost" type="button" onClick={() => setSosMapTarget(null)}>Close</button>
            </div>
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        key={resolveSosTarget ? `resolve-sos-${resolveSosTarget.id}` : "resolve-sos"}
        open={Boolean(resolveSosTarget)}
        title={`Resolve SOS from ${resolveSosTarget?.senderName || resolveSosTarget?.passengerName || "passenger"}`}
        message={
          resolveSosTarget?.acknowledgedBy && resolveSosTarget.acknowledgedBy.id !== user?.id
            ? `${resolveSosTarget.acknowledgedBy.name} is handling this alert. Resolve it only if you know it's over.`
            : "Say briefly what happened and what was done. It's kept with the alert."
        }
        requireInput
        inputLabel="Resolution note"
        defaultValue=""
        confirmLabel="Resolve"
        onConfirm={resolveSos}
        onCancel={() => setResolveSosTarget(null)}
      />

      <ConfirmDialog
        key={closeRideDialog?.outcome || "closed"}
        open={Boolean(closeRideDialog)}
        title={
          closeRideDialog?.outcome === "completed"
            ? `Mark ride #${selectedBooking?.id} completed`
            : `Force cancel ride #${selectedBooking?.id}`
        }
        message={
          closeRideDialog?.outcome === "completed"
            ? `Use this when the trip did happen but couldn't be finished in the app. The driver is credited the estimated fare (PHP ${selectedBooking?.estimatedFare || 0}).`
            : "Use this when the ride can't continue in the app (e.g. the driver's phone died). The passenger and driver both see the reason."
        }
        requireInput
        inputLabel="Reason (shown to the passenger and driver)"
        defaultValue={
          closeRideDialog?.outcome === "completed"
            ? "Trip finished, but the driver's app couldn't complete it."
            : "The ride couldn't continue in the app."
        }
        confirmLabel={closeRideDialog?.outcome === "completed" ? "Mark completed" : "Force cancel"}
        danger={closeRideDialog?.outcome !== "completed"}
        onConfirm={closeRide}
        onCancel={() => setCloseRideDialog(null)}
      />
    </div>
  );
}
