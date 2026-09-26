const { classifyDocument } = require("../src/utils/document-classifier");

// OCR output of the two photos a real applicant submitted (names removed):
// an electrical inspection certificate in the license slot, and an old
// graduation photo in the permit slot. Both were accepted before.
const ELECTRICAL_CERTIFICATE = `Republic of the Philippines /AZREaes
Province of Eastern Samar s{@Rz=13
Municipality of Guiuan AMET 5
CERTIFICATE OF FINAL ELECTRICAL INSPECTION
JUAN D. CRUZ
NAME OF OWNER/LESSEE
BARANGAY SULANGAN, GUIUAN EASTERN SAMAR
LOCATION AT/ALONG
COMMERCIAL E
USE OR CHARACTER OF OCCUPANCY GROUP`;

const GRADUATION_PHOTO = `amd 9 2" ~~" \\
a Some : > A 7
Ree GPS ii 1
Banga Be 1g 2 » TO [ Sa PROMOTIONAL & . gE
Fd 1 - | u Ye : /, n P o 0 9 8 a : El] t N Vv - o Py E 4 Pp}
a wae ivi Nh GN FTA`;

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

const TRICYCLE_FRANCHISE = `Republic of the Philippines
Province of Eastern Samar
Municipality of Guiuan
OFFICE OF THE MUNICIPAL MAYOR
MOTORIZED TRICYCLE OPERATOR'S PERMIT (MTOP)
FRANCHISE NO. 2025-0142
Operator: JUAN S. DELA CRUZ
TODA: GUIUAN CENTRAL TODA
Body No. 142 Plate No. AAJ-5974
Motor No. KC12E-1234567 Chassis No. MH1KC1234567`;

describe("document classifier", () => {
  it("rejects an electrical certificate uploaded as a driver's license", () => {
    const result = classifyDocument(ELECTRICAL_CERTIFICATE, "license");
    expect(result.status).toBe("suspicious");
    expect(result.otherDocument).toMatch(/ELECTRICAL/);
  });

  it("rejects a photo with no document text as a permit", () => {
    expect(classifyDocument(GRADUATION_PHOTO, "permit").status).not.toBe("verified");
  });

  it("treats empty OCR output as unreadable", () => {
    expect(classifyDocument("", "license").status).toBe("unreadable");
    expect(classifyDocument("  ~~ | ", "permit").status).toBe("unreadable");
  });

  it("accepts a real LTO driver's license", () => {
    const result = classifyDocument(LTO_LICENSE, "license");
    expect(result.status).toBe("verified");
    expect(result.matched).toContain("LTO license number");
  });

  it("accepts a tricycle franchise / MTOP permit", () => {
    expect(classifyDocument(TRICYCLE_FRANCHISE, "permit").status).toBe("verified");
  });

  it("doesn't accept a license in the permit slot or vice versa", () => {
    expect(classifyDocument(LTO_LICENSE, "permit").status).not.toBe("verified");
    expect(classifyDocument(TRICYCLE_FRANCHISE, "license").status).not.toBe("verified");
  });

  it("is not fooled by 'PHILIPPINES' alone", () => {
    expect(classifyDocument("REPUBLIC OF THE PHILIPPINES CERTIFICATE OF EMPLOYMENT THIS IS TO CERTIFY THAT", "license").status)
      .not.toBe("verified");
  });
});

describe("website copy of the classifier", () => {
  it("matches the server's rules", () => {
    const fs = require("fs");
    const path = require("path");
    const source = fs
      .readFileSync(path.resolve(__dirname, "../../driver_apply/src/utils/documentClassifier.js"), "utf8")
      .replace(/^export \{[^}]*\};?\s*$/m, "");
    const webClassify = new Function(`${source}; return classifyDocument;`)();
    for (const [text, kind] of [
      [ELECTRICAL_CERTIFICATE, "license"],
      [GRADUATION_PHOTO, "permit"],
      [LTO_LICENSE, "license"],
      [TRICYCLE_FRANCHISE, "permit"],
      [LTO_LICENSE, "permit"],
    ]) {
      expect(webClassify(text, kind)).toEqual(classifyDocument(text, kind));
    }
  });
});
