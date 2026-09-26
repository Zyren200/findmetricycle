export default function SummaryCards({ summary }) {
  const cards = [
    { label: "Total Passengers", icon: "👥", value: summary?.totalPassengers ?? 0, sub: "Registered accounts" },
    { label: "Total Drivers", icon: "🧑‍✈️", value: summary?.totalDrivers ?? 0, sub: "All fleet accounts" },
    { label: "Approved Drivers", icon: "🛡️", value: summary?.approvedDrivers ?? 0, sub: "Cleared to operate" },
    { label: "Online Drivers", icon: "🟢", value: summary?.onlineDrivers ?? 0, sub: "Available right now" },
    { label: "Pending Applications", icon: "📥", value: summary?.pendingApplications ?? 0, sub: "Awaiting review", attn: (summary?.pendingApplications ?? 0) > 0 },
    { label: "Ongoing Rides", icon: "🛣️", value: summary?.ongoingRides ?? 0, sub: "In progress" },
    { label: "Today's Bookings", icon: "📋", value: summary?.todaysBookings ?? 0, sub: "Since midnight" },
    { label: "Completed Today", icon: "✅", value: summary?.completedRidesToday ?? 0, sub: "Finished rides" },
    { label: "Cancelled Today", icon: "🚫", value: summary?.cancelledRidesToday ?? 0, sub: "Dropped bookings" },
    { label: "SOS Alerts", icon: "🚨", value: summary?.sosAlerts ?? 0, sub: "Needs attention", attn: (summary?.sosAlerts ?? 0) > 0 },
  ];

  return (
    <section className="kpis">
      {cards.map((card) => (
        <article key={card.label} className={`kpi ${card.attn ? "attn" : ""}`}>
          <p className="lbl">
            <span aria-hidden="true">{card.icon}</span> {card.label}
          </p>
          <p className="val">{card.value}</p>
          <p className="delta muted">{card.sub}</p>
        </article>
      ))}
    </section>
  );
}
