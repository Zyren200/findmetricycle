require("./setup-env");

const { formatAddress, isCoordinateAddress } = require("../src/services/geocoding.service");

// Trimmed from real Nominatim answers for points in Guiuan.
const guiuan = (data) => formatAddress(data, { fallbackTown: "Guiuan" });

describe("formatAddress", () => {
  test("landmark, street, purok, barangay, town and province", () => {
    expect(
      guiuan({
        category: "amenity",
        addresstype: "amenity",
        name: "Guiuan National High School",
        address: {
          amenity: "Guiuan National High School",
          road: "Borongan – Guiuan Road",
          neighbourhood: "Purok 2",
          quarter: "Poblacion Ward 10",
          suburb: "Poblacion Ward",
          town: "Guiuan",
          state: "Eastern Samar",
        },
      })
    ).toBe(
      "Guiuan National High School, Borongan – Guiuan Road, Purok 2, Brgy. Poblacion Ward 10, Guiuan, Eastern Samar"
    );
  });

  test("a rural barangay gets its town and its sitio", () => {
    expect(
      guiuan({
        category: "highway",
        addresstype: "road",
        name: "",
        address: { quarter: "Hollywood", suburb: "Poblacion Ward", village: "Salug", state: "Eastern Samar" },
      })
    ).toBe("Hollywood, Brgy. Salug, Guiuan, Eastern Samar");
  });

  test("a barangay itself isn't repeated as a landmark", () => {
    expect(
      guiuan({
        category: "place",
        addresstype: "village",
        name: "Sulangan",
        address: { village: "Sulangan", state: "Eastern Samar" },
      })
    ).toBe("Brgy. Sulangan, Guiuan, Eastern Samar");
  });

  test("outside Guiuan there's no fallback town, and no doubled Barangay", () => {
    expect(
      formatAddress({
        category: "building",
        addresstype: "building",
        name: "JG Plaza",
        address: { house_number: "718", road: "P. Paterno Street", quarter: "Barangay 307", city: "Manila" },
      })
    ).toBe("JG Plaza, 718 P. Paterno Street, Barangay 307, Manila");
  });

  test("no address means no place", () => {
    expect(formatAddress({ error: "Unable to geocode" })).toBeNull();
  });

  test("named places aren't mistaken for coordinates", () => {
    expect(isCoordinateAddress("11.03520, 125.72450")).toBe(true);
    expect(isCoordinateAddress("Brgy. Salug, Guiuan, Eastern Samar")).toBe(false);
  });
});
