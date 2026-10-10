const bookingModel = require("../models/booking.model");
const driverModel = require("../models/driver.model");
const ratingModel = require("../models/rating.model");
const userModel = require("../models/user.model");
const bookingRouteService = require("./booking-route.service");
const ApiError = require("../utils/api-error");
const { haversineKm } = require("../utils/haversine");
const { classifyExpiry } = require("./license-validation.service");

// Below this movement, a location broadcast to passengers/admin would just
// be noise (GPS jitter while stopped at a light, etc) — the DB still gets
// the fresh coordinate/timestamp, but sockets/index.js skips the emit.
const MIN_BROADCAST_MOVEMENT_KM = 0.015;

async function getDriverByUserIdOrFail(userId) {
  const driver = await driverModel.findByUserId(userId);
  if (!driver) {
    throw new ApiError(404, "Driver profile not found.");
  }
  return driver;
}

// A driver whose license or business permit has expired can't go online
// until an updated document is approved (Phase 8 "Expiration Protection")
// — going offline is always allowed regardless of document state.
function assertDocumentsCurrent(driver) {
  if (driver.license_expires_at && classifyExpiry(new Date(driver.license_expires_at)) === "expired") {
    throw new ApiError(403, "Your driver's license has expired. Submit an updated license to go online.");
  }
  if (
    driver.business_permit_expires_at &&
    classifyExpiry(new Date(driver.business_permit_expires_at)) === "expired"
  ) {
    throw new ApiError(403, "Your business permit has expired. Submit an updated permit to go online.");
  }
}

async function updateOnlineStatus(userId, isOnline) {
  const driver = await getDriverByUserIdOrFail(userId);
  if (driver.approval_status !== "approved") {
    throw new ApiError(403, "Driver is not approved by admin yet.");
  }

  if (isOnline) {
    assertDocumentsCurrent(driver);
  }

  await driverModel.setOnlineStatus(driver.id, Boolean(isOnline));
  return { ...driver, is_online: isOnline ? 1 : 0 };
}

async function updateLocation(userId, lat, lng) {
  const driver = await getDriverByUserIdOrFail(userId);
  if (driver.approval_status !== "approved") {
    throw new ApiError(403, "Driver is not approved by admin yet.");
  }

  const numLat = Number(lat);
  const numLng = Number(lng);
  // If location is missing or invalid, just return current driver state instead of failing the app.
  if (!Number.isFinite(numLat) || !Number.isFinite(numLng)) {
    return { ...driver, movedSignificantly: false };
  }

  if (numLat < -90 || numLat > 90 || numLng < -180 || numLng > 180) {
    return { ...driver, movedSignificantly: false };
  }

  const previousLat = Number(driver.current_lat);
  const previousLng = Number(driver.current_lng);
  const movedSignificantly =
    !Number.isFinite(previousLat) ||
    !Number.isFinite(previousLng) ||
    haversineKm(previousLat, previousLng, numLat, numLng) >= MIN_BROADCAST_MOVEMENT_KM;

  await driverModel.updateLocation(driver.id, numLat, numLng);
  const updated = await driverModel.findById(driver.id);

  // A rider remains visible while heading to the pickup, but route history
  // starts only after the passenger's PIN has started the trip.
  try {
    const activeBooking = await bookingModel.findActiveByDriver(driver.id);
    if (activeBooking && ["ongoing", "on_ride"].includes(activeBooking.status)) {
      await bookingRouteService.recordPoint({
        bookingId: activeBooking.id,
        lat: numLat,
        lng: numLng,
      });
    }
  } catch (error) {
    // A route-history write must never interrupt the existing live-location
    // and booking flow. The next GPS update will retry it.
    console.warn("Could not record booking route point:", error.message);
  }

  return { ...updated, movedSignificantly };
}

async function getDriverEarnings(userId) {
  const driver = await getDriverByUserIdOrFail(userId);
  const summary = await driverModel.getEarningsSummary(driver.id);
  return summary;
}

async function getDriverPerformance(userId) {
  const driver = await getDriverByUserIdOrFail(userId);
  return driverModel.getPerformanceStats(driver.id);
}

async function getDriverProfile(userId) {
  const profile = await driverModel.getProfileByUserId(userId);
  if (!profile) {
    throw new ApiError(404, "Driver profile not found.");
  }

  return {
    ...profile,
    license_expiry_status: profile.license_expires_at
      ? classifyExpiry(new Date(profile.license_expires_at))
      : "unable_to_determine",
    business_permit_expiry_status: profile.business_permit_expires_at
      ? classifyExpiry(new Date(profile.business_permit_expires_at))
      : "unable_to_determine",
  };
}

async function updateDriverProfile(userId, payload) {
  const driver = await getDriverByUserIdOrFail(userId);
  const currentUser = await userModel.findById(userId);

  if (!currentUser) {
    throw new ApiError(404, "Driver profile not found.");
  }

  if (payload.phone && payload.phone !== currentUser.phone) {
    const existingByPhone = await userModel.findByPhone(payload.phone);
    if (existingByPhone && Number(existingByPhone.id) !== Number(userId)) {
      throw new ApiError(409, "Phone number is already registered.");
    }
  }

  if (Object.prototype.hasOwnProperty.call(payload, "email")) {
    const nextEmail = payload.email;
    if (nextEmail && nextEmail !== currentUser.email) {
      const existingByEmail = await userModel.findByEmail(nextEmail);
      if (existingByEmail && Number(existingByEmail.id) !== Number(userId)) {
        throw new ApiError(409, "Email is already registered.");
      }
    }
  }

  if (payload.tricycleNumber && payload.tricycleNumber !== driver.tricycle_number) {
    const existingDriver = await driverModel.findByTricycleNumber(payload.tricycleNumber);
    if (existingDriver && Number(existingDriver.id) !== Number(driver.id)) {
      throw new ApiError(409, "Tricycle number is already registered.");
    }
  }

  await userModel.updateProfile(userId, {
    ...(payload.fullName ? { fullName: payload.fullName } : {}),
    ...(payload.phone ? { phone: payload.phone } : {}),
    ...(Object.prototype.hasOwnProperty.call(payload, "email") ? { email: payload.email } : {}),
    ...(payload.profileImageUrl ? { profileImageUrl: payload.profileImageUrl } : {}),
  });

  await driverModel.updateProfile(driver.id, {
    ...(payload.tricycleNumber ? { tricycleNumber: payload.tricycleNumber } : {}),
  });

  return getDriverProfile(userId);
}

async function getDriverRatings(userId) {
  const driver = await getDriverByUserIdOrFail(userId);
  return ratingModel.listRatingsByDriver(driver.id, 100);
}

async function getCompletedHistory(userId) {
  const driver = await getDriverByUserIdOrFail(userId);
  return bookingModel.listCompletedByDriver(driver.id, 100);
}

async function getActiveBooking(userId) {
  const driver = await getDriverByUserIdOrFail(userId);
  return bookingModel.findActiveByDriver(driver.id);
}

module.exports = {
  getDriverByUserIdOrFail,
  updateOnlineStatus,
  updateLocation,
  getDriverEarnings,
  getDriverPerformance,
  getDriverProfile,
  updateDriverProfile,
  getDriverRatings,
  getCompletedHistory,
  getActiveBooking,
};
