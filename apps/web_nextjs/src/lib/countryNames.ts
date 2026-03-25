/**
 * Country name resolution for ISO 3166-1 alpha-2 codes.
 *
 * Uses Intl.DisplayNames when available (browser + Node ≥13); falls back to
 * the static COUNTRY_NAMES record; ultimately falls back to the code itself.
 * No network calls — pure static data.
 */

/** Partial static map — covers the most common codes as a fallback. */
export const COUNTRY_NAMES: Record<string, string> = {
  AE: "United Arab Emirates",
  AR: "Argentina",
  AT: "Austria",
  AU: "Australia",
  BD: "Bangladesh",
  BE: "Belgium",
  BG: "Bulgaria",
  BR: "Brazil",
  CA: "Canada",
  CH: "Switzerland",
  CL: "Chile",
  CN: "China",
  CO: "Colombia",
  CZ: "Czech Republic",
  DE: "Germany",
  DK: "Denmark",
  EG: "Egypt",
  ES: "Spain",
  ET: "Ethiopia",
  FI: "Finland",
  FR: "France",
  GB: "United Kingdom",
  GH: "Ghana",
  GR: "Greece",
  HR: "Croatia",
  HU: "Hungary",
  ID: "Indonesia",
  IE: "Ireland",
  IL: "Israel",
  IN: "India",
  IT: "Italy",
  JO: "Jordan",
  JP: "Japan",
  KE: "Kenya",
  KR: "South Korea",
  KW: "Kuwait",
  LK: "Sri Lanka",
  MA: "Morocco",
  MX: "Mexico",
  MY: "Malaysia",
  NG: "Nigeria",
  NL: "Netherlands",
  NO: "Norway",
  NP: "Nepal",
  NZ: "New Zealand",
  PE: "Peru",
  PH: "Philippines",
  PK: "Pakistan",
  PL: "Poland",
  PT: "Portugal",
  QA: "Qatar",
  RO: "Romania",
  RS: "Serbia",
  RU: "Russia",
  SA: "Saudi Arabia",
  SE: "Sweden",
  SG: "Singapore",
  SI: "Slovenia",
  SK: "Slovakia",
  TH: "Thailand",
  TR: "Turkey",
  TZ: "Tanzania",
  UA: "Ukraine",
  UG: "Uganda",
  US: "United States",
  VE: "Venezuela",
  VN: "Vietnam",
  ZA: "South Africa",
};

let _displayNames: Intl.DisplayNames | null | undefined = undefined;

function getDisplayNames(): Intl.DisplayNames | null {
  if (_displayNames !== undefined) return _displayNames;
  try {
    _displayNames = new Intl.DisplayNames(["en"], { type: "region" });
    return _displayNames;
  } catch {
    _displayNames = null;
    return null;
  }
}

/**
 * Returns the English display name for an ISO 3166-1 alpha-2 country code.
 * Falls back to the static COUNTRY_NAMES map, then to the code itself.
 */
export function countryName(code: string): string {
  const dn = getDisplayNames();
  if (dn) {
    try {
      const name = dn.of(code);
      // Intl returns "Unknown Region" for unrecognised codes in some runtimes
      if (name && name !== code && name !== "Unknown Region") return name;
    } catch {
      // Unknown or invalid code — fall through
    }
  }
  return COUNTRY_NAMES[code] ?? code;
}
