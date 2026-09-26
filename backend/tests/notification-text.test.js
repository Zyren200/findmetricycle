const { replaceCoordinates } = require("../src/services/notification-text.service");

describe("coordinates in notification text", () => {
  const places = [
    { lat: 11.10853, lng: 125.3881, name: "Buenavista-Lawaan Road, Bantayao Village" },
    { lat: 11.11009, lng: 125.38123, name: null }, // no name found yet
  ];

  it("swaps a matching coordinate pair for the place name", () => {
    expect(replaceCoordinates("Booking #7 requested from 11.10853, 125.38810.", places)).toBe(
      "Booking #7 requested from Buenavista-Lawaan Road, Bantayao Village."
    );
  });

  it("leaves pairs it can't name, and other numbers, untouched", () => {
    expect(replaceCoordinates("Drop-off 11.11009, 125.38123", places)).toBe("Drop-off 11.11009, 125.38123");
    expect(replaceCoordinates("Total fare: PHP 45.50", places)).toBe("Total fare: PHP 45.50");
    expect(replaceCoordinates("From 14.59950, 120.98420", places)).toBe("From 14.59950, 120.98420");
  });
});
