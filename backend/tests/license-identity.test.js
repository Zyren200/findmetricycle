const { checkLicenseIdentity, findLicenseNumber } = require("../src/utils/license-identity");

const LTO_LICENSE = `REPUBLIC OF THE PHILIPPINES
DEPARTMENT OF TRANSPORTATION
LAND TRANSPORTATION OFFICE
NON-PROFESSIONAL DRIVER'S LICENSE
Last Name, First Name, Middle Name
DELA CRUZ, JUAN SANTOS
Nationality Sex Date of Birth Weight (kg) Height(m)
PHL M 1990/01/15 65 1.70
License No. Expiration Date Agency Code
H04-23-001476 2030/01/15 H04
Blood Type Eyes Color DL Codes Conditions
O+ BROWN A, A1, B NONE`;

// Same card, typical OCR noise: O for 0, spaces instead of dashes, one
// letter misread in the surname.
const NOISY_LICENSE = LTO_LICENSE.replace("H04-23-001476", "H O4 23 OO1476").replace("DELA CRUZ", "DELA CRUS");

const BLURRY = "a7 ;; LI 0 ~~ .. ee";

describe("license identity check", () => {
  it("accepts the applicant's own LTO license", () => {
    const r = checkLicenseIdentity(LTO_LICENSE, "Juan Dela Cruz");
    expect(r).toMatchObject({ licenseNumber: "H04-23-001476", readable: true, nameStatus: "match" });
  });

  it("tolerates common OCR misreads", () => {
    expect(findLicenseNumber(NOISY_LICENSE)).toBe("H04-23-001476");
    expect(checkLicenseIdentity(NOISY_LICENSE, "Juan Dela Cruz").nameStatus).toBe("match");
  });

  it("ignores suffixes, initials and a missing middle name", () => {
    expect(checkLicenseIdentity(LTO_LICENSE, "Juan S. Dela Cruz Jr.").nameStatus).toBe("match");
  });

  it("rejects someone else's license", () => {
    const r = checkLicenseIdentity(LTO_LICENSE, "Maria Lopez");
    expect(r.nameStatus).toBe("mismatch");
    expect(r.missingNames).toEqual(["MARIA", "LOPEZ"]);
  });

  it("rejects a license sharing only the first name", () => {
    expect(checkLicenseIdentity(LTO_LICENSE, "Juan Reyes").nameStatus).toBe("mismatch");
  });

  it("reports an unreadable photo instead of a mismatch", () => {
    expect(checkLicenseIdentity(BLURRY, "Juan Dela Cruz")).toMatchObject({ readable: false, nameStatus: "unreadable" });
  });

  it("finds no LTO number on a non-Philippine card", () => {
    expect(findLicenseNumber("DRIVER LICENSE STATE OF CALIFORNIA DL 12345678 JUAN DELA CRUZ")).toBeNull();
  });
});

describe("website copy of the license identity check", () => {
  it("matches the server's rules", () => {
    const fs = require("fs");
    const path = require("path");
    const source = fs
      .readFileSync(path.resolve(__dirname, "../../driver_apply/src/utils/licenseIdentity.js"), "utf8")
      .replace(/^export \{[^}]*\};?\s*$/m, "");
    const webCheck = new Function(`${source}; return checkLicenseIdentity;`)();
    for (const [text, name] of [
      [LTO_LICENSE, "Juan Dela Cruz"],
      [NOISY_LICENSE, "Juan Dela Cruz"],
      [LTO_LICENSE, "Maria Lopez"],
      [BLURRY, "Juan Dela Cruz"],
    ]) {
      expect(webCheck(text, name)).toEqual(checkLicenseIdentity(text, name));
    }
  });
});
