const complaintModel = require("../models/complaint.model");
const bookingModel = require("../models/booking.model");
const notificationService = require("./notification.service");
const ApiError = require("../utils/api-error");
const { REPORT_CATEGORIES: CATEGORIES } = require("../constants/report-categories");

// Driver and passenger reports both funnel through here — the booking (if
// any) tells us who the "other side" of the report is, so the reporter
// never has to specify a user id directly.
async function createComplaint({ reporterId, bookingId, category, description }) {
  if (!CATEGORIES.includes(category)) {
    throw new ApiError(400, `category must be one of: ${CATEGORIES.join(", ")}.`);
  }
  if (!description || !description.trim()) {
    throw new ApiError(400, "description is required.");
  }

  let reportedUserId = null;

  if (bookingId) {
    const booking = await bookingModel.findById(bookingId);
    if (!booking) {
      throw new ApiError(404, "Booking not found.");
    }

    const isPassenger = Number(booking.passenger_id) === Number(reporterId);
    const isDriver = Number(booking.driver_user_id) === Number(reporterId);
    if (!isPassenger && !isDriver) {
      throw new ApiError(403, "You can only report a booking you were part of.");
    }

    reportedUserId = isPassenger ? booking.driver_user_id || null : booking.passenger_id;
  }

  const complaint = await complaintModel.createComplaint({
    reporterId,
    reportedUserId,
    bookingId: bookingId || null,
    category,
    description: description.trim(),
  });

  await notificationService.createNotification({
    type: "driver_report",
    title: "New report submitted",
    body: `${category.replace(/_/g, " ")}: ${description.trim().slice(0, 120)}`,
    recipientRole: "admin",
    metadataJson: { complaintId: complaint.id, bookingId: bookingId || null },
  }).catch(() => {});

  return complaint;
}

async function listForAdmin(filters) {
  return complaintModel.listForAdmin(filters);
}

async function resolveForAdmin(id, adminUserId, options) {
  const complaint = await complaintModel.findById(id);
  if (!complaint) {
    throw new ApiError(404, "Report not found.");
  }
  return complaintModel.resolveComplaint(id, adminUserId, options);
}

module.exports = {
  CATEGORIES,
  createComplaint,
  listForAdmin,
  resolveForAdmin,
};
