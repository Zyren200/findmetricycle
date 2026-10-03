import { formatDateTime, formatMoney, formatPlace } from "../utils/admin-formatters";
import { Field, RelatedCard } from "./InboxLayout";

/** Booking summary shown in the Notifications and Reports readers. */
export default function BookingCard({ booking }) {
  return (
    <RelatedCard title={`Booking #${booking.id}`}>
      <Field label="Status" value={booking.status} />
      <Field label="Passenger" value={booking.passengerName} />
      <Field label="Driver" value={booking.driverName} />
      <Field label="Pickup" value={formatPlace(booking.pickupAddress)} />
      <Field label="Drop-off" value={formatPlace(booking.dropoffAddress)} />
      <Field label="Fare" value={formatMoney(booking.finalFare || booking.estimatedFare || 0)} />
      <Field label="Requested" value={formatDateTime(booking.requestedAt)} />
      <Field label="Reason" value={booking.cancelReason} />
    </RelatedCard>
  );
}
