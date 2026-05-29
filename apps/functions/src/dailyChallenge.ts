import * as fs from 'fs';
import * as path from 'path';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall } from 'firebase-functions/v2/https';
import { GoogleGenAI } from '@google/genai';

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
  shortDescription?: string;
  imageUrl?: string;
}

type ClueType = 'geography' | 'historical' | 'location' | 'natural' | 'direct' | 'atmosphere' | 'pop_culture';

interface ChallengeClue {
  type: ClueType;
  text: string;
}

interface DailyChallenge {
  siteId: string;
  clues: ChallengeClue[];
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
 * Builds five progressive typed clues for a WHS site, from vaguest (index 0)
 * to most specific (index 4). All content is derived from site fields — no
 * external API needed.
 *
 * Clue types:
 *   0 — geography  (region / category)
 *   1 — historical (inscription year + hemisphere)
 *   2 — location   (country flag + name)
 *   3 — historical | natural (age milestone or category flavour)
 *   4 — direct     (first word of site name)
 */
export function buildClues(site: WhsSite): ChallengeClue[] {
  const categoryLabel =
    site.category === 'cultural'
      ? 'Cultural'
      : site.category === 'natural'
        ? 'Natural'
        : 'Mixed Cultural and Natural';

  const hemisphere = site.latitude >= 0 ? 'Northern Hemisphere' : 'Southern Hemisphere';

  const flag = toFlagEmoji(site.countryCode);

  // Clue 3 (index 3): age milestone or category flavour.
  let clue3Type: ClueType;
  let clue3Text: string;
  if (site.inscriptionYear <= 1980) {
    clue3Type = 'historical';
    clue3Text = `One of the very first sites ever inscribed on the UNESCO World Heritage List (${site.inscriptionYear}).`;
  } else if (site.inscriptionYear <= 1990) {
    clue3Type = 'historical';
    clue3Text = `Inscribed in the early years of the UNESCO World Heritage List (${site.inscriptionYear}).`;
  } else if (site.category === 'natural') {
    clue3Type = 'natural';
    clue3Text = 'A place of exceptional natural beauty or ecological importance.';
  } else if (site.category === 'mixed') {
    clue3Type = 'natural';
    clue3Text = 'A site recognised for both its cultural heritage and its natural landscape.';
  } else {
    clue3Type = 'historical';
    clue3Text = 'A place of outstanding historical, artistic, or archaeological significance.';
  }

  // Clue 4 (index 4): first word of the site name (stripped of leading articles).
  const firstWord = site.name.split(/[\s,()–-]/)[0];

  return [
    { type: 'geography', text: `A ${categoryLabel} site in ${site.region}.` },
    { type: 'historical', text: `Inscribed in ${site.inscriptionYear}. Located in the ${hemisphere}.` },
    { type: 'location', text: `${flag} Found in ${countryName(site.countryCode)}.` },
    { type: clue3Type, text: clue3Text },
    { type: 'direct', text: `The site name begins with "${firstWord}".` },
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

// ── AI clue builder ───────────────────────────────────────────────────────────

/**
 * Gemini model to use. gemini-2.0-flash gives excellent creative writing at
 * minimal cost (~$0.0003 per day for one challenge).
 */
const GEMINI_MODEL = 'gemini-2.0-flash';

/**
 * Builds five progressive typed clues using Gemini via Vertex AI.
 *
 * Clues go from most abstract (atmosphere / physical feeling) to most direct
 * (country + first letter). Gemini is given the site's metadata and
 * description and asked to write engaging, culturally-aware clues that may
 * reference pop culture, physical characteristics, or history.
 *
 * Falls back to [buildClues] if the API call fails or returns malformed JSON.
 */
export async function buildCluesWithAI(
  site: WhsSite,
  _projectId: string,
): Promise<ChallengeClue[]> {
  try {
    const apiKey = process.env.GEMINI_API_KEY ?? '';
    const ai = new GoogleGenAI({ apiKey });

    const flag = toFlagEmoji(site.countryCode);
    const country = countryName(site.countryCode);
    const firstWord = site.name.split(/[\s,()–-]/)[0];
    const descriptionLine = site.shortDescription
      ? `Description: ${site.shortDescription}`
      : '';

    const prompt = `You are writing clues for Roavvy — a daily Wordle-style game where players guess a UNESCO World Heritage Site from 5 progressive clues. Each clue reveals a little more. Your goal is a smooth difficulty gradient, not a fixed category structure.

TARGET DIFFICULTY (think: what % of players guess correctly after seeing this clue alone):
  Clue 1 →  ~5%  Almost nobody gets it. Pure sensory — what it feels like to stand there.
  Clue 2 → ~15%  One surprising fact: a genuine pop culture connection (film, novel, game, song) OR a single record-breaking physical stat. Still no location or civilisation name.
  Clue 3 → ~35%  Historical/cultural context: which civilisation built it and roughly when. No country name.
  Clue 4 → ~65%  Geographic reveal: continent + sub-region + terrain. No country name yet.
  Clue 5 → ~90%  Full reveal: country flag, country name, first word of site name.

STRICT RULES FOR EACH CLUE:
  Clue 1: NO country, continent, civilisation, time period, or proper nouns. Sensory only.
  Clue 2: NO country or site name. One fact or pop culture ref that is genuinely interesting.
  Clue 3: Civilisation/culture + time period allowed. NO country or sub-region name.
  Clue 4: Continent + sub-region + terrain allowed. NO country name.
  Clue 5: Must start with "${flag} ${country}." and end with: The site name starts with "${firstWord}".

For the "type" field choose the best fit from: atmosphere, pop_culture, historical, cultural, natural, geography, direct.

SITE TO WRITE CLUES FOR:
- Name: ${site.name}
- Country: ${country}
- Category: ${site.category}
- Inscription year: ${site.inscriptionYear}
- Region: ${site.region}
${descriptionLine}

EXAMPLE (Colosseum, Rome — do not copy the style, just the structure and difficulty calibration):
[
  {"type":"atmosphere","text":"An oval of tiered stone arches open to a blazing sky — the scale is overwhelming, the silence eerie, the worn travertine warm underfoot. You can almost hear the roar."},
  {"type":"pop_culture","text":"Russell Crowe fought for his life here in Ridley Scott's 2000 epic — and the establishing shot has become one of cinema's most recognisable images."},
  {"type":"historical","text":"Commissioned by Emperor Vespasian of the Roman Empire and completed in 80 AD, funded by the spoils of war and built to entertain up to 80,000 citizens with gladiatorial combat."},
  {"type":"geography","text":"In the heart of southern Europe, on the Italian peninsula, in a city that gave its name to one of history's greatest empires."},
  {"type":"direct","text":"🇮🇹 Italy. The site name starts with \\"Colosseum\\"."}
]

Return ONLY a valid JSON array for the target site, no markdown, no explanation:
[
  {"type":"...","text":"..."},
  {"type":"...","text":"..."},
  {"type":"...","text":"..."},
  {"type":"...","text":"..."},
  {"type":"direct","text":"${flag} ${country}. The site name starts with \\"${firstWord}\\"."}
]`;

    const response = await ai.models.generateContent({
      model: GEMINI_MODEL,
      contents: prompt,
    });
    const text = response.text ?? '';

    // Strip markdown code fences if present.
    const cleaned = text.replace(/^```(?:json)?\n?/m, '').replace(/\n?```$/m, '').trim();
    const parsed = JSON.parse(cleaned) as ChallengeClue[];

    if (!Array.isArray(parsed) || parsed.length !== 5) {
      throw new Error(`Unexpected clue array length: ${parsed.length}`);
    }

    console.log(`[dailyChallenge] AI clues generated for ${site.name} (${site.siteId})`);
    return parsed;
  } catch (err) {
    console.error(`[dailyChallenge] AI clue generation failed, falling back to templates:`, err);
    return buildClues(site);
  }
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
  const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? '';
  const clues = await buildCluesWithAI(site, projectId);

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
  { schedule: 'every day 00:00', timeZone: 'UTC', secrets: ['GEMINI_API_KEY'] },
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
export const getDailyChallenge = onCall({ secrets: ['GEMINI_API_KEY'] }, async (request) => {
  const date: string =
    typeof request.data?.date === 'string' && request.data.date.match(/^\d{4}-\d{2}-\d{2}$/)
      ? request.data.date
      : todayUtc();

  const result = await writeDailyChallenge(date);
  const doc = await getFirestore().collection('daily_challenge').doc(date).get();
  return { date, ...doc.data(), alreadyExisted: result.alreadyExisted };
});
