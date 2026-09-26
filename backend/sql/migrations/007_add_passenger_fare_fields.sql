-- Adds configurable additional-passenger fee to fare_settings, and records
-- the passenger count + fare breakdown used on each booking so historical
-- bookings are never retroactively recalculated when fare settings change.

ALTER TABLE fare_settings
  ADD COLUMN additional_passenger_fee DECIMAL(10, 2) NOT NULL DEFAULT 0.00 AFTER night_fee;

ALTER TABLE bookings
  ADD COLUMN passenger_count TINYINT UNSIGNED NOT NULL DEFAULT 1 AFTER dropoff_lng,
  ADD COLUMN fare_breakdown_json JSON NULL AFTER final_fare;
