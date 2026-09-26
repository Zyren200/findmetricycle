import React, { useCallback, useEffect, useMemo, useState } from "react";
import { apiClient } from "../api/client";
import { useAuth } from "../context/AuthContext";
import { useSocket } from "../hooks/useSocket";
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

const sections = [
  { key: "dashboard", title: "Dashboard", icon: "📊", group: "Main" },
  { key: "live", title: "Live Map", icon: "🗺️", group: "Main" },
  { key: "users", title: "Users", icon: "👥", group: "Operations" },
  { key: "applications", title: "Driver Applications", icon: "⏳", group: "Operations" },
  { key: "drivers", title: "Approved Drivers", icon: "🧑‍✈️", group: "Operations" },
  { key: "bookings", title: "Bookings", icon: "🛣️", group: "Operations" },
  { key: "sos", title: "SOS", icon: "🚨", group: "Operations" },
  { key: "complaints", title: "Complaints", icon: "📝", group: "Operations" },
  { key: "notifications", title: "Notifications", icon: "🔔", group: "Operations" },
  { key: "reports", title: "Reports", icon: "📈", group: "Insights" },
  { key: "earnings", title: "Earnings", icon: "💰", group: "Insights" },
  { key: "activity", title: "Activity Logs", icon: "📋", group: "System" },
  { key: "barangays", title: "Barangay Coverage", icon: "🗺️", group: "System" },
  { key: "fares", title: "Fare Settings", icon: "💵", group: "System" },
  { key: "settings", title: "Settings", icon: "⚙️", group: "System" },
];

const mockSummary = {
  totalRides: 428,
  dailyEarnings: 680,
  activeDrivers: 42,
  totalPassengers: 1284,
  pendingApplications: 18,
  ongoingRides: 7,
  completedRidesToday: 96,
  sosAlerts: 2,
};

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
  const [summary, setSummary] = useState(mockSummary);
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
  const [operationsBusyId, setOperationsBusyId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

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

      setSummary(summaryRes.data?.data || mockSummary);
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

  const pageTitle = useMemo(() => sections.find((s) => s.key === activeSectionKey)?.title || "Dashboard", [activeSectionKey]);

  const opsSummary = useMemo(() => ({
    pendingApplications: pendingDrivers.length || summary.pendingApplications,
    ongoingRides: activeRides.filter((ride) => ["pending", "accepted", "ongoing"].includes(String(ride.status || "").toLowerCase())).length || summary.ongoingRides,
    sosAlerts: sosAlerts.filter((alert) => alert.status !== "resolved").length || summary.sosAlerts,
    totalPassengers: passengers.length || summary.totalPassengers,
  }), [activeRides, passengers.length, pendingDrivers.length, sosAlerts, summary]);

  async function openBookingDetail(bookingId) {
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
      return (
        <div className="page-stack">
          <SummaryCards summary={{ ...summary, ...opsSummary }} />
          <div className="layout-row">
            <div className="left-col">
              <LiveMapCard onlineDrivers={onlineDrivers} activeRides={activeRides} />
              <SectionCard title="SOS Alerts">
                <div className="timeline">
                  {sosAlerts.length === 0 ? (
                    <div className="state-block">No active SOS alerts.</div>
                  ) : sosAlerts.map((alert) => (
                    <div className="tl-item" key={alert.id}>
                      <div className={`tl-dot ${alert.status === "resolved" ? "" : "red"}`} />
                      <div className="tl-content">
                        <div className="tl-title">{asText(alert.title) || "SOS Alert"}</div>
                        <div className="tl-time">{formatDateTime(alert.createdAt)} · {alert.body}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </SectionCard>
            </div>
            <div className="right-col">
              <SectionCard title="Today at a glance">
                <div className="detail-grid">
                  <div className="mini-metric"><span>Pending Applications</span><strong>{opsSummary.pendingApplications}</strong></div>
                  <div className="mini-metric"><span>Ongoing Rides</span><strong>{opsSummary.ongoingRides}</strong></div>
                  <div className="mini-metric"><span>Completed Today</span><strong>{summary.completedRidesToday}</strong></div>
                </div>
              </SectionCard>
              <SectionCard title="Approved Drivers">
                <SimpleTable
                  columns={["Name", "Plate", "Rating", "License"]}
                  rows={driverList}
                  renderRow={(driver) => (
                    <tr key={driver.id}>
                      <td>{driver.full_name}</td>
                      <td>{driver.tricycle_number}</td>
                      <td>{Number(driver.rating_avg || driver.rating || 0).toFixed(1)}</td>
                      <td><Pill value={new Date(driver.license_expires_at) < new Date() ? "expired" : "active"} /></td>
                    </tr>
                  )}
                />
              </SectionCard>
            </div>
          </div>
        </div>
      );
    }

    if (activeSectionKey === "live") {
      return <LiveMapCard onlineDrivers={onlineDrivers} activeRides={activeRides} />;
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
        <SectionCard title={`User Accounts (${passengers.length})`}>
          <div className="toolbar-row" style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 12 }}>
            <input
              type="search"
              className="input"
              placeholder="Search name, phone or email"
              value={userSearch}
              onChange={(e) => setUserSearch(e.target.value)}
              style={{ flex: "1 1 220px", minWidth: 0 }}
            />
            <select className="input" value={userStatusFilter} onChange={(e) => setUserStatusFilter(e.target.value)}>
              <option value="all">All statuses</option>
              <option value="active">Active</option>
              <option value="suspended">Suspended ({suspendedCount})</option>
            </select>
          </div>
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
                    <b>{row.full_name}</b>
                    {row.is_driver_account ? (
                      <span style={{ marginLeft: 6 }}><Pill value={`driver · ${row.driver_approval_status}`} /></span>
                    ) : null}
                    <div><small>{row.email || "-"}</small></div>
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
        </SectionCard>
      );
    }

    if (activeSectionKey === "applications") {
      return <PendingPage />;
    }

    if (activeSectionKey === "drivers") {
      return <DriversPage />;
    }

    if (activeSectionKey === "bookings") {
      return (
        <SectionCard title="Bookings">
          <SimpleTable
            columns={["Booking ID", "Passenger", "Driver", "Pickup", "Destination", "Fare", "Status", "Date", "Actions"]}
            rows={bookings}
            renderRow={(ride) => (
              <tr key={ride.id}>
                <td>#{ride.id}</td>
                <td>{ride.passengerName || ride.passenger_name}</td>
                <td>{ride.driverName || ride.driver_name || "-"}</td>
                <td>{formatPlace(ride.pickupAddress || ride.pickup)}</td>
                <td>{formatPlace(ride.dropoffAddress || ride.destination)}</td>
                <td>PHP {ride.finalFare || ride.estimatedFare || ride.fare || 0}</td>
                <td><Pill value={ride.status} /></td>
                <td>{formatDateTime(ride.completedAt || ride.requestedAt || ride.timestamp)}</td>
                <td><button type="button" className="btn btn-ghost btn-sm" onClick={() => openBookingDetail(ride.id)}>View</button></td>
              </tr>
            )}
          />
        </SectionCard>
      );
    }

    if (activeSectionKey === "sos") {
      return (
        <SectionCard title="SOS Emergency Center">
          <div className="warning-banner">Highest priority alerts surface here first and can be resolved or escalated immediately.</div>
          <SimpleTable
            columns={["Passenger", "Driver", "Ride ID", "Contact", "Timestamp", "Status", "Action"]}
            rows={sosAlerts}
            renderRow={(row) => (
              <tr key={row.id}>
                <td>{row.passengerName || "-"}</td>
                <td>{row.driverName || "-"}</td>
                <td>{row.bookingId ? `#${row.bookingId}` : "-"}</td>
                <td>{row.contact || "-"}</td>
                <td>{formatDateTime(row.createdAt)}</td>
                <td><Pill value={row.status} /></td>
                <td>
                  <button type="button" className="btn btn-success btn-sm" disabled={operationsBusyId === `sos-${row.id}` || row.status === "resolved"} onClick={() => resolveSos(row.id)}>
                    {operationsBusyId === `sos-${row.id}` ? "..." : row.status === "resolved" ? "Resolved" : "Resolve"}
                  </button>
                </td>
              </tr>
            )}
          />
        </SectionCard>
      );
    }

    if (activeSectionKey === "complaints") {
      return (
        <SectionCard title="Complaint Center">
          <SimpleTable
            columns={["Reporter", "Reported", "Ride ID", "Category", "Status", "Action"]}
            rows={complaints}
            renderRow={(row) => (
              <tr key={row.id}>
                <td>{row.reporter}</td>
                <td>{row.reportedUser}</td>
                <td>{row.rideId ? `#${row.rideId}` : "-"}</td>
                <td>{row.category}</td>
                <td><Pill value={row.status} /></td>
                <td>
                  <button type="button" className="btn btn-success btn-sm" disabled={operationsBusyId === `complaint-${row.id}` || row.status === "resolved"} onClick={() => resolveComplaint(row.id)}>
                    {operationsBusyId === `complaint-${row.id}` ? "..." : row.status === "resolved" ? "Resolved" : "Resolve"}
                  </button>
                </td>
              </tr>
            )}
          />
        </SectionCard>
      );
    }

    if (activeSectionKey === "notifications") {
      return (
        <SectionCard
          title={unreadCount ? `Notification Center (${unreadCount} unread)` : "Notification Center"}
          action={
            unreadCount ? (
              <button type="button" className="btn btn-ghost btn-sm" onClick={markAllNotificationsRead}>
                Mark all as read
              </button>
            ) : null
          }
        >
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
        </SectionCard>
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
      return <SettingsPage />;
    }

    return (
      <SectionCard title="Dashboard">
        <div className="detail-list">
          <div className="detail-row"><span>Status</span><span>Ready</span></div>
        </div>
      </SectionCard>
    );
  }

  return (
    <div style={{ display: "flex", minHeight: "100vh", width: "100%" }}>
      {/* Phone/tablet: the sidebar slides in over the page; tapping the
          dimmed area or a menu item closes it. */}
      {navOpen ? <div className="sidebar-backdrop" onClick={() => setNavOpen(false)} /> : null}
      <aside className={navOpen ? "sidebar open" : "sidebar"}>
        <div className="logo">
          <div className="logo-title">🛺 FindMeTricycle</div>
          <div className="logo-sub">Admin Operations</div>
        </div>

        {["Main", "Operations", "Insights", "System"].map((group) => (
          <React.Fragment key={group}>
            <div className="nav-section">{group}</div>
            {sections.filter((s) => s.group === group).map((section) => (
              <button
                key={section.key}
                className={activeSectionKey === section.key ? "nav-item active" : "nav-item"}
                onClick={() => {
                  setActiveSectionKey(section.key);
                  setNavOpen(false);
                }}
                type="button"
              >
                <span className="icon">{section.icon}</span>
                {section.title}
              </button>
            ))}
          </React.Fragment>
        ))}

        <div className="sidebar-footer">
          <div className="admin-profile" onClick={logout}>
            <div className="avatar">{(user?.full_name || "SA").split(" ").map((n) => n[0]).join("")}</div>
            <div className="admin-info">
              <div className="admin-name">{user?.full_name || "System Admin"}</div>
              <div className="admin-role">{user?.email || "admin@findme.local"}</div>
            </div>
          </div>
        </div>
      </aside>

      <main className="main">
        <div className="topbar">
          <div className="topbar-title">
            <button
              type="button"
              className="menu-toggle"
              aria-label="Open menu"
              onClick={() => setNavOpen(true)}
            >
              ☰
            </button>
            {pageTitle}
          </div>
          <div className="topbar-actions">
            <input className="search-box" type="text" placeholder="Search operations..." />
            <div className="live-pill"><div className="live-dot"></div> Live</div>
            <button className="btn btn-ghost" type="button" onClick={logout}>Logout</button>
            <button
              className="notif-btn"
              type="button"
              aria-label={unreadCount ? `Notifications (${unreadCount} unread)` : "Notifications"}
              onClick={() => setShowNotifications((s) => !s)}
            >
              🔔
              {unreadCount > 0 ? <span className="notif-badge">{unreadCount > 99 ? "99+" : unreadCount}</span> : null}
            </button>
          </div>
        </div>

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

        <div className="content">{renderSection()}</div>
      </main>

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
                  </div>
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
              <button className="btn btn-ghost" type="button" onClick={() => setSelectedBooking(null)}>Close</button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
