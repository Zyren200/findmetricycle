import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  BarChart3,
  Bell,
  BookOpen,
  ChevronDown,
  ClipboardList,
  DollarSign,
  FileText,
  History,
  LayoutDashboard,
  LogOut,
  Map as MapIcon,
  MapPin,
  Megaphone,
  Menu,
  MessageSquareWarning,
  ScrollText,
  Search,
  Settings as SettingsIcon,
  Shield,
  Siren,
  UserCheck,
  Users,
  Wifi,
  Wrench,
  X,
} from "lucide-react";
import { apiClient } from "../api/client";
import { useAuth } from "../context/AuthContext";
import { useSocket } from "../hooks/useSocket";
import ConfirmDialog from "../components/ConfirmDialog";
import LiveMapCard from "../components/LiveMapCard";
import NotificationsPanel from "../components/NotificationsPanel";
import SummaryCards from "../components/SummaryCards";
import PageHero from "../components/PageHero";
import { asText, formatDateTime, formatMoney, statusTone, formatPlace } from "../utils/admin-formatters";
import ActivityLogsPage from "./ActivityLogsPage";
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
  { key: "notifications", title: "Notifications", icon: Bell, group: "Operations" },
  { key: "announcements", title: "Announcements", icon: Megaphone, group: "Operations" },
  { key: "reports", title: "Reports", icon: BarChart3, group: "Insights" },
  { key: "earnings", title: "Earnings", icon: DollarSign, group: "Insights" },
  { key: "activity", title: "Activity Logs", icon: ScrollText, group: "System" },
  { key: "barangays", title: "Barangay Coverage", icon: MapPin, group: "System" },
  { key: "fares", title: "Fare Settings", icon: FileText, group: "System" },
  { key: "settings", title: "Settings", icon: Wrench, group: "System" },
];

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
  const { user, logout, token } = useAuth();
  const [activeSectionKey, setActiveSectionKey] = useState("dashboard");
  const [navOpen, setNavOpen] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
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
  const [passengers, setPassengers] = useState([]);
  const [userSearch, setUserSearch] = useState("");
  const [userStatusFilter, setUserStatusFilter] = useState("all");
  const [driverList, setDriverList] = useState([]);
  const [fare, setFare] = useState(null);
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
  const [complaintSearch, setComplaintSearch] = useState("");
  const [complaintStatus, setComplaintStatus] = useState("all");
  const [sosFilter, setSosFilter] = useState("all");

  useEffect(() => {
    apiClient
      .get("/admin/barangays")
      .then(({ data }) => {
        const list = Array.isArray(data?.data) ? data.data : [];
        setBarangaysCovered(list.filter((b) => b.is_enabled === true || b.is_enabled === 1).length);
      })
      .catch(() => {});
  }, []);

  const loadData = useCallback(async () => {
    try {
      setError(null);
      const [summaryRes, mapRes, pendingRes, bookingsRes, sosRes, complaintsRes, notifRes, driversRes, passengersRes, fareRes] =
        await Promise.all([
          apiClient.get("/admin/dashboard"),
          apiClient.get("/admin/live-map"),
          apiClient.get("/admin/drivers/pending"),
          apiClient.get("/admin/bookings"),
          apiClient.get("/admin/sos"),
          apiClient.get("/admin/complaints"),
          apiClient.get("/admin/notifications"),
          apiClient.get("/admin/drivers"),
          apiClient.get("/admin/passengers"),
          apiClient.get("/admin/fare"),
        ]);

      setSummary(summaryRes.data?.data || {});
      setOnlineDrivers(mapRes.data?.data?.onlineDrivers || []);
      setActiveRides(mapRes.data?.data?.activeRides || []);
      setPendingDrivers(pendingRes.data?.data || []);
      setBookings(bookingsRes.data?.data || []);
      setSosAlerts(sosRes.data?.data || []);
      setComplaints(complaintsRes.data?.data || []);
      const notificationList = notifRes.data?.data || [];
      setNotifications(notificationList);
      setUnreadCount(notifRes.data?.meta?.unread ?? notificationList.filter((n) => !n.isRead).length);
      setDriverList(driversRes.data?.data || []);
      setPassengers(passengersRes.data?.data || []);
      setFare(fareRes.data?.data || null);
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to load dashboard.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
    const timer = setInterval(loadData, 15000);
    return () => clearInterval(timer);
  }, [loadData]);

  const onSosAlert = useCallback((alert) => {
    setSosAlerts((prev) => [alert, ...prev.filter((item) => item.id !== alert.id)]);
  }, []);

  // New admin notifications arrive live instead of on the next 15s poll.
  const onNotification = useCallback((notification) => {
    if (!notification?.id) return;
    setNotifications((prev) => [notification, ...prev.filter((item) => item.id !== notification.id)]);
    if (!notification.isRead) setUnreadCount((count) => count + 1);
  }, []);

  useSocket({ token, onSosAlert, onNotification });

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

  // Clicking a notification opens the page where it can be acted on.
  const NOTIFICATION_SECTIONS = {
    driver_application: "applications",
    driver_document_resubmission: "applications",
    driver_documents_flagged: "applications",
    sos_alert: "sos",
    driver_report: "complaints",
    new_booking: "bookings",
    booking_cancelled: "bookings",
  };

  function openNotification(notification) {
    markNotificationRead(notification.id);
    const section = NOTIFICATION_SECTIONS[notification.type];
    if (section) {
      setActiveSectionKey(section);
      setShowNotifications(false);
    }
  }

  // Top-bar search: pages, users, drivers and bookings already loaded by
  // the dashboard. Picking a result opens the right page.
  const searchResults = useMemo(() => {
    const term = searchTerm.trim().toLowerCase();
    if (!term) return [];
    const has = (...values) => values.some((v) => String(v ?? "").toLowerCase().includes(term));
    const results = [];
    sections
      .filter((s) => has(s.title))
      .forEach((s) => results.push({ id: `page-${s.key}`, kind: "Page", label: s.title, action: { type: "section", key: s.key } }));
    passengers
      .filter((p) => has(p.full_name, p.phone, p.email))
      .slice(0, 5)
      .forEach((p) =>
        results.push({ id: `user-${p.id}`, kind: "User", label: p.full_name, sub: p.phone || p.email, action: { type: "user", term: p.full_name } })
      );
    driverList
      .filter((d) => has(d.full_name, d.phone, d.tricycle_number))
      .slice(0, 5)
      .forEach((d) =>
        results.push({ id: `driver-${d.id}`, kind: "Driver", label: d.full_name, sub: d.tricycle_number, action: { type: "section", key: "drivers" } })
      );
    bookings
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
  }, [searchTerm, passengers, driverList, bookings]);

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
    sosAlerts: sosAlerts.filter((alert) => alert.status !== "resolved").length || summary.sosAlerts,
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

  async function resolveSos(id) {
    setOperationsBusyId(`sos-${id}`);
    try {
      await apiClient.post(`/admin/sos/${id}/resolve`);
      await loadData();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to resolve SOS.");
    } finally {
      setOperationsBusyId(null);
    }
  }

  async function resolveComplaint(id) {
    setOperationsBusyId(`complaint-${id}`);
    try {
      await apiClient.post(`/admin/complaints/${id}/resolve`);
      await loadData();
    } catch (err) {
      setError(err?.response?.data?.message || "Failed to resolve complaint.");
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
          />

          <div className="adm-grid-3">
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
                        <b>{alert.passengerName || alert.driverName || asText(alert.title) || "SOS Alert"}</b>
                        <p>{alert.body}</p>
                        <small>{formatDateTime(alert.createdAt)}</small>
                      </div>
                      <i />
                    </div>
                  ))}
                </div>
              )}
            </section>

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
          </div>

          <LiveMapCard onlineDrivers={onlineDrivers} activeRides={activeRides} />

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
          <LiveMapCard onlineDrivers={onlineDrivers} activeRides={activeRides} />
        </div>
      );
    }

    if (activeSectionKey === "users") {
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
            columns={["User", "Phone", "Joined", "Rides", "Spent", "Status", "Actions"]}
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
      const openCount = sosAlerts.filter((a) => a.status !== "resolved").length;
      const visibleSos = sosAlerts.filter((a) =>
        sosFilter === "all" ? true : sosFilter === "resolved" ? a.status === "resolved" : a.status !== "resolved"
      );
      return (
        <div className="page-stack">
          <PageHero title="SOS Emergency Center" description="Emergency alerts from passengers and drivers" />
          {openCount > 0 ? (
            <div className="error-banner" style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <Siren size={16} /> <b>{openCount} active SOS alert{openCount > 1 ? "s" : ""}</b> — respond immediately.
            </div>
          ) : null}
          <div className="filter-bar" style={{ marginBottom: 0 }}>
            <select className="input" value={sosFilter} onChange={(e) => setSosFilter(e.target.value)}>
              <option value="all">All alerts</option>
              <option value="active">Active</option>
              <option value="resolved">Resolved</option>
            </select>
            <span className="adm-count">{visibleSos.length} alerts</span>
          </div>
          <section className="panel" style={{ padding: 0 }}>
            <SimpleTable
              columns={["Passenger", "Driver", "Ride ID", "Contact", "Timestamp", "Status", "Action"]}
              rows={visibleSos}
              emptyLabel="No SOS alerts."
              renderRow={(row) => (
                <tr key={row.id} style={row.status !== "resolved" ? { background: "rgba(239,68,68,0.05)" } : undefined}>
                  <td style={{ fontWeight: 500, color: "var(--text)" }}>{row.passengerName || "-"}</td>
                  <td>{row.driverName || "-"}</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontSize: 12 }}>{row.bookingId ? `#${row.bookingId}` : "-"}</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontSize: 12 }}>{row.contact || "-"}</td>
                  <td style={{ fontFamily: "var(--font-mono)", fontSize: 12 }}>{formatDateTime(row.createdAt)}</td>
                  <td><Pill value={row.status} /></td>
                  <td>
                    <button type="button" className="btn btn-success btn-sm" disabled={operationsBusyId === `sos-${row.id}` || row.status === "resolved"} onClick={() => resolveSos(row.id)}>
                      {operationsBusyId === `sos-${row.id}` ? "..." : row.status === "resolved" ? "Resolved" : "Resolve"}
                    </button>
                  </td>
                </tr>
              )}
            />
          </section>
        </div>
      );
    }

    if (activeSectionKey === "complaints") {
      const term = complaintSearch.trim().toLowerCase();
      const visibleComplaints = complaints.filter((c) => {
        const resolved = c.status === "resolved";
        if (complaintStatus === "open" && resolved) return false;
        if (complaintStatus === "resolved" && !resolved) return false;
        if (!term) return true;
        return [c.reporter, c.reportedUser, c.category, c.description].some((v) => String(v ?? "").toLowerCase().includes(term));
      });
      return (
        <div className="page-stack">
          <PageHero title="Complaint Center" description="Passenger and driver reports and dispute resolution" />
          <div className="filter-bar" style={{ marginBottom: 0 }}>
            <SearchField value={complaintSearch} onChange={setComplaintSearch} placeholder="Reporter, category or details…" />
            <select className="input" value={complaintStatus} onChange={(e) => setComplaintStatus(e.target.value)}>
              <option value="all">All</option>
              <option value="open">Open</option>
              <option value="resolved">Resolved</option>
            </select>
            <span className="adm-count">{visibleComplaints.length} complaints</span>
          </div>
          {visibleComplaints.length === 0 ? (
            <div className="state-block">
              <MessageSquareWarning size={32} style={{ opacity: 0.3, marginBottom: 8 }} />
              <div>No complaints found</div>
            </div>
          ) : (
            <div className="adm-list" style={{ gap: 12 }}>
              {visibleComplaints.map((c) => {
                const resolved = c.status === "resolved";
                const busy = operationsBusyId === `complaint-${c.id}`;
                return (
                  <article key={c.id} className="adm-card" style={{ padding: 20, opacity: resolved ? 0.7 : 1 }}>
                    <div style={{ display: "flex", gap: 16, alignItems: "flex-start" }}>
                      <span className="adm-metric-ico" style={{ padding: 8, borderRadius: 8, background: "rgba(139,92,246,0.2)", color: "var(--purple)", display: "grid" }}>
                        <MessageSquareWarning size={16} />
                      </span>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap", marginBottom: 4 }}>
                          <b style={{ color: "var(--text-strong)", fontSize: 14 }}>{c.reporter}</b>
                          {c.category ? <span className="status-pill status-neutral">{String(c.category).replace(/_/g, " ")}</span> : null}
                          <Pill value={c.status} />
                        </div>
                        {c.description ? <p style={{ fontSize: 14, color: "#cbd5e1", margin: 0 }}>{c.description}</p> : null}
                        <div style={{ display: "flex", gap: 12, marginTop: 8, fontSize: 12, color: "var(--muted2)", fontFamily: "var(--font-mono)", flexWrap: "wrap" }}>
                          {c.reportedUser ? <span>Reported: {c.reportedUser}</span> : null}
                          {c.rideId ? <span>Booking: #{c.rideId}</span> : null}
                          {c.createdAt ? <span>{formatDateTime(c.createdAt)}</span> : null}
                        </div>
                      </div>
                      {!resolved ? (
                        <button type="button" className="btn btn-success btn-sm" disabled={busy} onClick={() => resolveComplaint(c.id)}>
                          {busy ? "..." : "Resolve"}
                        </button>
                      ) : null}
                    </div>
                  </article>
                );
              })}
            </div>
          )}
        </div>
      );
    }

    if (activeSectionKey === "notifications") {
      return (
        <div className="page-stack">
        <PageHero
          title="Notifications"
          description={unreadCount ? `${unreadCount} unread` : "You're all caught up"}
          actions={
            unreadCount ? (
              <button type="button" className="btn btn-ghost btn-sm" onClick={markAllNotificationsRead}>
                Mark all as read
              </button>
            ) : null
          }
        />
        <section className="panel" style={{ padding: 0 }}>
          <SimpleTable
            columns={["Title", "Message", "Date", "Status", "Actions"]}
            rows={notifications}
            renderRow={(row) => (
              <tr key={row.id} style={row.isRead ? { opacity: 0.7 } : { fontWeight: 600 }}>
                <td>{row.title}</td>
                <td>{row.body}</td>
                <td>{formatDateTime(row.createdAt)}</td>
                <td><Pill value={row.isRead ? "read" : "unread"} /></td>
                <td style={{ whiteSpace: "nowrap" }}>
                  {NOTIFICATION_SECTIONS[row.type] ? (
                    <button type="button" className="btn btn-ghost btn-sm" onClick={() => openNotification(row)}>Open</button>
                  ) : null}
                  {!row.isRead ? (
                    <button type="button" className="btn btn-ghost btn-sm" style={{ marginLeft: 6 }} onClick={() => markNotificationRead(row.id)}>Mark read</button>
                  ) : null}
                </td>
              </tr>
            )}
          />
        </section>
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
      return <SettingsPage onOpenFares={() => setActiveSectionKey("fares")} />;
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
    sos: sosAlerts.filter((a) => a.status !== "resolved").length,
    notifications: unreadCount,
  };
  const initials = (user?.full_name || "Admin")
    .split(" ")
    .filter(Boolean)
    .map((n) => n[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();

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
          <div className="adm-brand-mark"><Shield size={16} /></div>
          <div>
            <p className="adm-brand-name">FindMeTricycle</p>
            <p className="adm-brand-sub">ADMIN PORTAL</p>
          </div>
        </div>

        <nav className="adm-nav">
          {["Main", "Operations", "Insights", "System"].map((group) => (
            <div className="adm-nav-group" key={group}>
              <p className="adm-nav-label">{group}</p>
              {sections.filter((s) => s.group === group).map((section) => {
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
                placeholder="Search pages, users, drivers, bookings…"
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

            <span className="adm-live"><i /> LIVE</span>

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
                <span className="nm">{user?.full_name || "Admin"}</span>
                <ChevronDown size={14} color="var(--muted2)" />
              </button>
              {adminMenuOpen ? (
                <div className="adm-dropdown" style={{ width: 180 }}>
                  <button type="button" className="item" onClick={() => go("settings")}>
                    <SettingsIcon size={14} /> Settings
                  </button>
                  <div className="sep" />
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
          />
        ) : null}

        <main
          className="adm-content"
          onClick={() => {
            setAdminMenuOpen(false);
          }}
        >
          <div className="page-stack">
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
                  {ACTIVE_RIDE_STATUSES.includes(selectedBooking.status) ? (
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
              {!selectedBookingLoading && ACTIVE_RIDE_STATUSES.includes(selectedBooking.status) ? (
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
