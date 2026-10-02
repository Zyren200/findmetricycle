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

/// The dashboard's two rows of metrics. [onNavigate] opens the related
/// page when a card is clicked.
export default function SummaryCards({ summary, barangaysCovered, onNavigate }) {
  const s = summary || {};
  const pending = s.pendingApplications ?? 0;
  const sos = s.sosAlerts ?? 0;
  const go = (key) => (onNavigate ? () => onNavigate(key) : undefined);

  return (
    <>
      <section className="adm-metrics">
        <MetricCard label="Total Passengers" value={s.totalPassengers ?? 0} icon={Users} sub="All registered" onClick={go("users")} />
        <MetricCard label="Total Drivers" value={s.totalDrivers ?? 0} icon={Car} sub="All fleet accounts" onClick={go("drivers")} />
        <MetricCard label="Approved Drivers" value={s.approvedDrivers ?? 0} icon={UserCheck} accent sub="Eligible to drive" onClick={go("drivers")} />
        <MetricCard label="Online Drivers" value={s.onlineDrivers ?? 0} icon={Wifi} accent sub="Currently active" onClick={go("live")} />
        <MetricCard
          label="Pending Applications"
          value={pending}
          icon={ClipboardList}
          alert={pending > 0}
          sub="Awaiting review"
          onClick={go("applications")}
        />
        <MetricCard label="Ongoing Rides" value={s.ongoingRides ?? 0} icon={BookOpen} sub="In progress now" onClick={go("bookings")} />
        <MetricCard label="Completed Today" value={s.completedRidesToday ?? 0} icon={CheckCircle} sub={`${s.todaysBookings ?? 0} bookings today`} />
        <MetricCard label="Cancelled Today" value={s.cancelledRidesToday ?? 0} icon={XCircle} sub="Dropped bookings" />
      </section>

      <section className="adm-metrics">
        <MetricCard
          label="SOS Alerts"
          value={sos}
          icon={Siren}
          alert={sos > 0}
          sub={sos > 0 ? "Requires attention!" : "No active alerts"}
          onClick={go("sos")}
        />
        <MetricCard label="Today's Earnings" value={peso(s.dailyEarnings)} icon={TrendingUp} accent sub="Cash from completed rides" onClick={go("earnings")} />
        <MetricCard label="Total Rides" value={s.totalRides ?? 0} icon={BookOpen} sub="All time" onClick={go("rides")} />
        <MetricCard
          label="Barangays Covered"
          value={barangaysCovered ?? "—"}
          icon={MapPin}
          sub="Active coverage"
          onClick={go("barangays")}
        />
      </section>
    </>
  );
}
