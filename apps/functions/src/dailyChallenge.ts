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
  criteria?: string[];
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
const GEMINI_MODEL = 'gemini-2.5-flash';

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
  _projectId = '',
): Promise<ChallengeClue[]> {
  try {
    const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? _projectId;
    const ai = new GoogleGenAI({ vertexai: true, project: projectId, location: 'us-central1' });

    const flag = toFlagEmoji(site.countryCode);
    const country = countryName(site.countryCode);
    const firstWord = site.name.split(/[\s,()–-]/)[0];
    const descriptionLine = site.shortDescription
      ? `Description: ${site.shortDescription}`
      : '';
    const criteriaLine = site.criteria?.length
      ? `UNESCO criteria: (${site.criteria.join(')(')})`
      : '';

    const prompt = `You are writing clues for Roavvy — a daily mobile game where players guess a UNESCO World Heritage Site from 5 progressive clues. Roavvy is a daily retention game, not an expert geography quiz. Clues should be player-friendly, exciting, and useful. Every clue must add a new piece of information — never repeat the same fact in different wording.

TARGET DIFFICULTY (% of casual players who guess correctly after seeing only this clue):
  Clue 1 → ~30%  Broad geographic region + type of site + one distinctive physical feature or recognisable characteristic. One brief sensory detail allowed. Should immediately help casual players narrow their search.
  Clue 2 → ~50%  A memorable fact, famous characteristic, record-breaking feature, or well-known cultural/pop-culture association. Should be genuinely useful, not obscure.
  Clue 3 → ~70%  Civilisation or culture + approximate historical era. Who built it, used it, worshipped there, or why it mattered. Should make the answer clear to most players.
  Clue 4 → ~90%  Reveal the country name plus useful local geography: nearest major city, river, mountain range, or coastline. Should make the answer obvious.
  Clue 5 → ~99%  Full reveal: country flag, country name, first word of site name.

RULES FOR EACH CLUE:
  Clue 1: State the broad region AND the type of site AND one distinctive feature. One sensory detail allowed. NO country name. NO specific sub-region. NO civilisation name. NO time period. NO proper nouns.
  Clue 2: NO country name. NO site name. NO civilisation name unless unavoidable. One memorable fact or association — make it count.
  Clue 3: Civilisation/culture + era allowed. NO country name.
  Clue 4: Country name ALLOWED. Add nearest city, river, coast, or mountain. Do NOT reveal the exact site name.
  Clue 5: Must start exactly with "${flag} ${country}." and end with: The site name starts with "${firstWord}".

QUALITY RULES (apply to every clue):
  - Avoid generic phrases like "ancient ruins", "historic city", or "beautiful landscape" unless paired with a distinctive feature.
  - Prefer recognisable, famous characteristics over obscure academic facts.
  - Use natural, exciting language suited to a daily mobile game.
  - Keep each clue concise: 1–2 sentences maximum.
  - Every clue must add new information not already given.

For the "type" field choose the best fit from: atmosphere, pop_culture, historical, cultural, natural, geography, direct.

SITE TO WRITE CLUES FOR:
- Name: ${site.name}
- Country: ${country}
- Category: ${site.category}
- Inscription year: ${site.inscriptionYear}
- Region: ${site.region}
${descriptionLine}
${criteriaLine}

EXAMPLE (Colosseum, Rome — do not copy the style, just the structure and difficulty curve):
[
  {"type":"geography","text":"Southern Europe. A vast ancient amphitheatre — the largest ever built — with tiered stone arches you can see from across the city."},
  {"type":"pop_culture","text":"Russell Crowe fought for his life here in Ridley Scott's 2000 epic, and it's one of the most photographed structures on Earth."},
  {"type":"historical","text":"Built by the Roman Empire under Emperor Vespasian, completed in 80 AD, and used for gladiatorial combat and public spectacles for four centuries."},
  {"type":"geography","text":"Located in Italy, in the centre of Rome — a short walk from the Roman Forum and the Palatine Hill."},
  {"type":"direct","text":"🇮🇹 Italy. The site name starts with \\"Colosseum\\"."}
]

Return ONLY a valid JSON array for the target site — no markdown, no explanation, nothing else:
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

/** Adds [n] days to a YYYY-MM-DD string and returns the result. */
function addDays(date: string, n: number): string {
  const d = new Date(date + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/**
 * Number of days on each side of [date] to check for collisions.
 * With 1246 unique sites the full cycle is 1246 days, so no natural repeats
 * occur. This check guards against dataset changes or manual overrides.
 */
const COLLISION_WINDOW = 300;

/**
 * Picks the site for [date] using the deterministic epoch-day index, then
 * walks forward until a site not used in the ±300-day window is found.
 *
 * The base algorithm cycles through all 1246 sites before repeating, so
 * no collision is expected in normal operation. This is a safety net only.
 */
async function pickSite(sites: WhsSite[], date: string, db: ReturnType<typeof getFirestore>): Promise<WhsSite> {
  const epochDay = Math.floor(Date.parse(date + 'T00:00:00Z') / 86_400_000);

  // Fetch siteIds used in the ±COLLISION_WINDOW day window.
  const windowStart = addDays(date, -COLLISION_WINDOW);
  const windowEnd   = addDays(date,  COLLISION_WINDOW);
  const snap = await db.collection('daily_challenge')
    .where('__name__', '>=', windowStart)
    .where('__name__', '<=', windowEnd)
    .select('siteId')
    .get();
  const usedIds = new Set(snap.docs.map(d => d.data().siteId as string));

  // Walk forward from deterministic index until an unused site is found.
  for (let offset = 0; offset < sites.length; offset++) {
    const candidate = sites[(epochDay + offset) % sites.length];
    if (!usedIds.has(candidate.siteId)) return candidate;
  }

  // Exhausted — shouldn't happen (1246 sites, 600-day window).
  console.warn(`[dailyChallenge] All sites used in window — falling back to deterministic pick`);
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

  const site = await pickSite(WHS_SITES, date, db);
  const clues = await buildCluesWithAI(site);

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
export const getDailyChallenge = onCall({}, async (request) => {
  const date: string =
    typeof request.data?.date === 'string' && request.data.date.match(/^\d{4}-\d{2}-\d{2}$/)
      ? request.data.date
      : todayUtc();

  const result = await writeDailyChallenge(date);
  const doc = await getFirestore().collection('daily_challenge').doc(date).get();
  return { date, ...doc.data(), alreadyExisted: result.alreadyExisted };
});
