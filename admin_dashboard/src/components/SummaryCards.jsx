import {
  BookOpen,
  Car,
  CheckCircle,
  ClipboardList,
  MapPin,
  Siren,
  TrendingUp,
  UserCheck,
  Users,
  Wifi,
  XCircle,
} from "lucide-react";
import { PERMISSIONS as P } from "../utils/admin-access";

export function MetricCard({ label, value, sub, icon: Icon, accent = false, alert = false, onClick }) {
  const Tag = onClick ? "button" : "div";
  return (
    <Tag
      type={onClick ? "button" : undefined}
      className={`adm-metric ${alert ? "alert" : accent ? "accent" : ""}`}
      onClick={onClick}
    >
      <div>
        <p className="lbl">{label}</p>
        <p className="val">{value}</p>
        {sub ? <p className="sub">{sub}</p> : null}
      </div>
      {Icon ? (
        <span className="ico">
          <Icon size={18} />
        </span>
      ) : null}
    </Tag>
  );
}

const peso = (value) => `₱${Number(value || 0).toLocaleString("en-PH", { maximumFractionDigits: 2 })}`;

/// The dashboard's metrics: only the cards backed by data the admin may
/// see ([can] checks a permission). [onNavigate] opens the related page when
/// a card is clicked, if [canOpen] says the admin may open it.
export default function SummaryCards({ summary, barangaysCovered, onNavigate, can = () => true, canOpen = () => true }) {
  const s = summary || {};
  const pending = s.pendingApplications ?? 0;
  const sos = s.sosAlerts ?? 0;
  const go = (key) => (onNavigate && canOpen(key) ? () => onNavigate(key) : undefined);
  const canRides = can(P.BOOKINGS_VIEW) || can(P.RIDES_VIEW);

  const first = [
    can(P.USERS_VIEW) && (
      <MetricCard key="passengers" label="Total Passengers" value={s.totalPassengers ?? 0} icon={Users} sub="All registered" onClick={go("users")} />
    ),
    can(P.DRIVERS_VIEW) && (
      <MetricCard key="drivers" label="Total Drivers" value={s.totalDrivers ?? 0} icon={Car} sub="All fleet accounts" onClick={go("drivers")} />
    ),
    can(P.DRIVERS_VIEW) && (
      <MetricCard key="approved" label="Approved Drivers" value={s.approvedDrivers ?? 0} icon={UserCheck} accent sub="Eligible to drive" onClick={go("drivers")} />
    ),
    can(P.LIVE_MAP_VIEW) && (
      <MetricCard key="online" label="Online Drivers" value={s.onlineDrivers ?? 0} icon={Wifi} accent sub="Currently active" onClick={go("live")} />
    ),
    can(P.DRIVER_APPLICATIONS_VIEW) && (
      <MetricCard
        key="pending"
        label="Pending Applications"
        value={pending}
        icon={ClipboardList}
        alert={pending > 0}
        sub="Awaiting review"
        onClick={go("applications")}
      />
    ),
    (canRides || can(P.LIVE_MAP_VIEW)) && (
      <MetricCard
        key="ongoing"
        label="Ongoing Rides"
        value={s.ongoingRides ?? 0}
        icon={BookOpen}
        sub="In progress now"
        onClick={go("bookings") || go("live")}
      />
    ),
    canRides && (
      <MetricCard key="completed" label="Completed Today" value={s.completedRidesToday ?? 0} icon={CheckCircle} sub={`${s.todaysBookings ?? 0} bookings today`} />
    ),
    canRides && <MetricCard key="cancelled" label="Cancelled Today" value={s.cancelledRidesToday ?? 0} icon={XCircle} sub="Dropped bookings" />,
  ].filter(Boolean);

  const second = [
    can(P.SOS_VIEW) && (
      <MetricCard
        key="sos"
        label="SOS Alerts"
        value={sos}
        icon={Siren}
        alert={sos > 0}
        sub={sos > 0 ? "Requires attention!" : "No active alerts"}
        onClick={go("sos")}
      />
    ),
    can(P.EARNINGS_VIEW) && (
      <MetricCard key="earnings" label="Today's Earnings" value={peso(s.dailyEarnings)} icon={TrendingUp} accent sub="Cash from completed rides" onClick={go("earnings")} />
    ),
    canRides && <MetricCard key="rides" label="Total Rides" value={s.totalRides ?? 0} icon={BookOpen} sub="All time" onClick={go("rides")} />,
    can(P.BARANGAYS_MANAGE) && (
      <MetricCard
        key="barangays"
        label="Barangays Covered"
        value={barangaysCovered ?? "—"}
        icon={MapPin}
        sub="Active coverage"
        onClick={go("barangays")}
      />
    ),
  ].filter(Boolean);

  return (
    <>
      {first.length ? <section className="adm-metrics">{first}</section> : null}
      {second.length ? <section className="adm-metrics">{second}</section> : null}
    </>
  );
}
