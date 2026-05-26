import * as fs from 'fs';
import * as path from 'path';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall } from 'firebase-functions/v2/https';

// ── Types ─────────────────────────────────────────────────────────────────────

interface WhsSite {
  siteId: string;
  name: string;
  countryCode: string;
  latitude: number;
  longitude: number;
  category: 'cultural' | 'natural' | 'mixed';
  region: string;
  inscriptionYear: number;
}

interface DailyChallenge {
  siteId: string;
  clues: [string, string, string, string, string];
  generatedAt: Timestamp;
}

// ── Dataset ───────────────────────────────────────────────────────────────────

/**
 * Loads the bundled whs_sites.json and deduplicates by siteId (transboundary
 * sites appear once per member country; we keep the first occurrence after
 * lexicographic sort so the selection is stable).
 */
function loadUniqueSites(): WhsSite[] {
  const jsonPath = path.join(__dirname, 'assets', 'whs_sites.json');
  const raw = fs.readFileSync(jsonPath, 'utf-8');
  const all: WhsSite[] = JSON.parse(raw);

  // Deduplicate by siteId — keep first occurrence per id.
  const seen = new Set<string>();
  const unique: WhsSite[] = [];
  for (const site of all) {
    if (!seen.has(site.siteId)) {
      seen.add(site.siteId);
      unique.push(site);
    }
  }

  // Stable lexicographic order ensures the same index maps to the same site
  // regardless of source file ordering changes.
  unique.sort((a, b) => a.siteId.localeCompare(b.siteId));
  return unique;
}

// Loaded once at cold start.
const WHS_SITES = loadUniqueSites();

// ── Clue builder ──────────────────────────────────────────────────────────────

/** Converts a 2-letter ISO country code to a flag emoji. */
function toFlagEmoji(countryCode: string): string {
  const code = countryCode.toUpperCase();
  return (
    String.fromCodePoint(0x1f1e6 + (code.charCodeAt(0) - 65)) +
    String.fromCodePoint(0x1f1e6 + (code.charCodeAt(1) - 65))
  );
}

/**
 * Builds five progressive clues for a WHS site, from vaguest (index 0) to
 * most specific (index 4). All content is derived from site fields — no
 * external API needed.
 */
export function buildClues(site: WhsSite): [string, string, string, string, string] {
  const categoryLabel =
    site.category === 'cultural'
      ? 'Cultural'
      : site.category === 'natural'
        ? 'Natural'
        : 'Mixed Cultural and Natural';

  const hemisphere = site.latitude >= 0 ? 'Northern Hemisphere' : 'Southern Hemisphere';

  const flag = toFlagEmoji(site.countryCode);

  // Clue 4: age-based hint if early inscription, otherwise category flavour.
  let clue4: string;
  if (site.inscriptionYear <= 1980) {
    clue4 = `One of the very first sites ever inscribed on the UNESCO World Heritage List (${site.inscriptionYear}).`;
  } else if (site.inscriptionYear <= 1990) {
    clue4 = `Inscribed in the early years of the UNESCO World Heritage List (${site.inscriptionYear}).`;
  } else if (site.category === 'natural') {
    clue4 = 'A place of exceptional natural beauty or ecological importance.';
  } else if (site.category === 'mixed') {
    clue4 = 'A site recognised for both its cultural heritage and its natural landscape.';
  } else {
    clue4 = 'A place of outstanding historical, artistic, or archaeological significance.';
  }

  // Clue 5: first word of the site name (stripped of leading articles).
  const firstWord = site.name.split(/[\s,()–-]/)[0];

  return [
    `A ${categoryLabel} site in ${site.region}.`,
    `Inscribed in ${site.inscriptionYear}. Located in the ${hemisphere}.`,
    `${flag} Found in ${countryName(site.countryCode)}.`,
    clue4,
    `The site name begins with "${firstWord}".`,
  ];
}

/**
 * Maps ISO 3166-1 alpha-2 codes to English country names for the 50 most
 * common WHS countries. Falls back to the raw code for unlisted codes.
 */
function countryName(code: string): string {
  const names: Record<string, string> = {
    AF: 'Afghanistan', AL: 'Albania', DZ: 'Algeria', AD: 'Andorra', AO: 'Angola',
    AR: 'Argentina', AM: 'Armenia', AU: 'Australia', AT: 'Austria', AZ: 'Azerbaijan',
    BH: 'Bahrain', BD: 'Bangladesh', BY: 'Belarus', BE: 'Belgium', BZ: 'Belize',
    BJ: 'Benin', BO: 'Bolivia', BA: 'Bosnia and Herzegovina', BW: 'Botswana',
    BR: 'Brazil', BG: 'Bulgaria', KH: 'Cambodia', CM: 'Cameroon', CA: 'Canada',
    CF: 'Central African Republic', CL: 'Chile', CN: 'China', CO: 'Colombia',
    CG: 'Congo', CR: 'Costa Rica', HR: 'Croatia', CU: 'Cuba', CY: 'Cyprus',
    CZ: 'Czech Republic', DK: 'Denmark', EC: 'Ecuador', EG: 'Egypt',
    SV: 'El Salvador', EE: 'Estonia', ET: 'Ethiopia', FI: 'Finland', FR: 'France',
    GA: 'Gabon', GM: 'Gambia', GE: 'Georgia', DE: 'Germany', GH: 'Ghana',
    GR: 'Greece', GT: 'Guatemala', GN: 'Guinea', HN: 'Honduras', HU: 'Hungary',
    IN: 'India', ID: 'Indonesia', IR: 'Iran', IQ: 'Iraq', IE: 'Ireland',
    IL: 'Israel', IT: 'Italy', JM: 'Jamaica', JP: 'Japan', JO: 'Jordan',
    KZ: 'Kazakhstan', KE: 'Kenya', KR: 'South Korea', KG: 'Kyrgyzstan',
    LA: 'Laos', LV: 'Latvia', LB: 'Lebanon', LS: 'Lesotho', LT: 'Lithuania',
    LU: 'Luxembourg', MK: 'North Macedonia', MG: 'Madagascar', MW: 'Malawi',
    MY: 'Malaysia', ML: 'Mali', MT: 'Malta', MR: 'Mauritania', MX: 'Mexico',
    MD: 'Moldova', MC: 'Monaco', MN: 'Mongolia', ME: 'Montenegro', MA: 'Morocco',
    MZ: 'Mozambique', NA: 'Namibia', NP: 'Nepal', NL: 'Netherlands', NZ: 'New Zealand',
    NI: 'Nicaragua', NE: 'Niger', NG: 'Nigeria', NO: 'Norway', OM: 'Oman',
    PK: 'Pakistan', PA: 'Panama', PY: 'Paraguay', PE: 'Peru', PH: 'Philippines',
    PL: 'Poland', PT: 'Portugal', QA: 'Qatar', RO: 'Romania', RU: 'Russia',
    RW: 'Rwanda', SA: 'Saudi Arabia', SN: 'Senegal', RS: 'Serbia', SL: 'Sierra Leone',
    SK: 'Slovakia', SI: 'Slovenia', SO: 'Somalia', ZA: 'South Africa', ES: 'Spain',
    LK: 'Sri Lanka', SD: 'Sudan', SE: 'Sweden', CH: 'Switzerland', SY: 'Syria',
    TJ: 'Tajikistan', TZ: 'Tanzania', TH: 'Thailand', TG: 'Togo', TN: 'Tunisia',
    TR: 'Turkey', TM: 'Turkmenistan', UG: 'Uganda', UA: 'Ukraine',
    GB: 'United Kingdom', US: 'United States', UY: 'Uruguay', UZ: 'Uzbekistan',
    VE: 'Venezuela', VN: 'Vietnam', YE: 'Yemen', ZM: 'Zambia', ZW: 'Zimbabwe',
  };
  return names[code] ?? code;
}

// ── Site picker ───────────────────────────────────────────────────────────────

/** Returns the UTC date string for today in `YYYY-MM-DD` format. */
function todayUtc(): string {
  return new Date().toISOString().slice(0, 10);
}

/**
 * Picks a site deterministically from [sites] based on the current UTC date.
 * The epoch-day index cycles through all sites before repeating, ensuring no
 * two consecutive days share the same site (for lists longer than 1 day).
 */
function pickSite(sites: WhsSite[], date: string): WhsSite {
  const epochDay = Math.floor(Date.parse(date + 'T00:00:00Z') / 86_400_000);
  return sites[epochDay % sites.length];
}

// ── Firestore writer ──────────────────────────────────────────────────────────

async function writeDailyChallenge(date: string): Promise<{ siteId: string; alreadyExisted: boolean }> {
  const db = getFirestore();
  const ref = db.collection('daily_challenge').doc(date);

  const existing = await ref.get();
  if (existing.exists) {
    return { siteId: existing.data()!.siteId as string, alreadyExisted: true };
  }

  const site = pickSite(WHS_SITES, date);
  const clues = buildClues(site);

  const doc: DailyChallenge = {
    siteId: site.siteId,
    clues,
    generatedAt: Timestamp.now(),
  };

  await ref.set(doc);
  return { siteId: site.siteId, alreadyExisted: false };
}

// ── Exported Cloud Functions ──────────────────────────────────────────────────

/**
 * Runs every day at 00:00 UTC and writes the daily challenge document to
 * Firestore. Idempotent — skips if the document already exists.
 */
export const scheduleDailyChallenge = onSchedule(
  { schedule: 'every day 00:00', timeZone: 'UTC' },
  async (_event) => {
    const date = todayUtc();
    const result = await writeDailyChallenge(date);
    if (result.alreadyExisted) {
      console.log(`[dailyChallenge] ${date} already exists (siteId=${result.siteId}), skipping.`);
    } else {
      console.log(`[dailyChallenge] ${date} written: siteId=${result.siteId}`);
    }
  },
);

/**
 * onCall function for manual triggering and local testing.
 * Accepts an optional `date` string (YYYY-MM-DD); defaults to today UTC.
 * Returns the siteId and clues written (or already existing).
 */
export const getDailyChallenge = onCall(async (request) => {
  const date: string =
    typeof request.data?.date === 'string' && request.data.date.match(/^\d{4}-\d{2}-\d{2}$/)
      ? request.data.date
      : todayUtc();

  const result = await writeDailyChallenge(date);
  const doc = await getFirestore().collection('daily_challenge').doc(date).get();
  return { date, ...doc.data(), alreadyExisted: result.alreadyExisted };
});
