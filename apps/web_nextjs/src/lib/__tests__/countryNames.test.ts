import { countryName, COUNTRY_NAMES } from "../countryNames";

const REQUIRED_CODES = [
  "US", "GB", "FR", "DE", "JP", "AU", "BR", "CA",
  "IN", "ZA", "NG", "CN", "MX", "IT", "ES", "NL",
  "RU", "TR", "SA", "AR",
];

describe("COUNTRY_NAMES", () => {
  test.each(REQUIRED_CODES)("has entry for %s", (code) => {
    expect(COUNTRY_NAMES[code]).toBeTruthy();
    expect(typeof COUNTRY_NAMES[code]).toBe("string");
  });
});

describe("countryName", () => {
  it("returns a non-empty display name for known codes", () => {
    for (const code of REQUIRED_CODES) {
      const name = countryName(code);
      expect(name.length).toBeGreaterThan(0);
      expect(name).not.toBe("");
    }
  });

  it("falls back to the code itself for unknown codes", () => {
    expect(countryName("XX")).toBe("XX");
    expect(countryName("ZZ")).toBe("ZZ");
  });

  it("never returns an empty string", () => {
    expect(countryName("US")).toBeTruthy();
    expect(countryName("UNKNOWN_CODE")).toBe("UNKNOWN_CODE");
  });

  it("returns a string different from the code for well-known countries", () => {
    // Either Intl or static map should resolve these to a real name
    const name = countryName("GB");
    expect(name).not.toBe("GB");
    expect(name.length).toBeGreaterThan(2);
  });
});
