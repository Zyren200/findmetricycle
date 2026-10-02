-- Admins can force-close a stuck ride (e.g. the driver's phone died
-- mid-trip): the booking records that the admin closed it and why.
ALTER TABLE bookings MODIFY COLUMN cancelled_by ENUM('passenger', 'driver', 'admin', 'system') NULL;
ALTER TABLE bookings ADD COLUMN cancel_reason VARCHAR(255) NULL;
