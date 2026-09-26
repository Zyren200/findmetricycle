// The subset of a driver row a passenger may see when choosing or tracking a
// rider. The full `drivers` row also carries license numbers/images, OCR
// text and earnings, which must never reach another user's device.
function toPublicDriver(driver) {
  if (!driver) return null;
  const distance = driver.distanceToPickupKm;
  return {
    id: driver.id,
    full_name: driver.full_name || driver.driver_name || null,
    tricycle_number: driver.tricycle_number || null,
    rating: Number(driver.rating_avg ?? driver.rating ?? 0),
    total_rides: Number(driver.total_rides || 0),
    current_lat: driver.current_lat != null ? Number(driver.current_lat) : null,
    current_lng: driver.current_lng != null ? Number(driver.current_lng) : null,
    distanceToPickupKm: distance != null ? Number(Number(distance).toFixed(3)) : null,
  };
}

module.exports = { toPublicDriver };
