-- Keep the plain 4-digit pickup PIN so the passenger can see it again after
-- an app restart (it was previously only ever sent once, at creation). The
-- API only returns it to the booking's own passenger and clears it once the
-- driver has verified it.
ALTER TABLE bookings
  ADD COLUMN pickup_pin VARCHAR(6) NULL AFTER pickup_pin_hash;
