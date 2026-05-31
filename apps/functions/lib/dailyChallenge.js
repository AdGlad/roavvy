"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDailyChallenge = exports.scheduleDailyChallenge = void 0;
exports.buildClues = buildClues;
exports.buildCluesWithAI = buildCluesWithAI;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const firestore_1 = require("firebase-admin/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const https_1 = require("firebase-functions/v2/https");
const genai_1 = require("@google/genai");
// ── Dataset ───────────────────────────────────────────────────────────────────
/**
 * Loads the bundled whs_sites.json and deduplicates by siteId (transboundary
 * sites appear once per member country; we keep the first occurrence after
 * lexicographic sort so the selection is stable).
 */
function loadUniqueSites() {
    const jsonPath = path.join(__dirname, 'assets', 'whs_sites.json');
    const raw = fs.readFileSync(jsonPath, 'utf-8');
    const all = JSON.parse(raw);
    // Deduplicate by siteId — keep first occurrence per id.
    const seen = new Set();
    const unique = [];
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
function toFlagEmoji(countryCode) {
    const code = countryCode.toUpperCase();
    return (String.fromCodePoint(0x1f1e6 + (code.charCodeAt(0) - 65)) +
        String.fromCodePoint(0x1f1e6 + (code.charCodeAt(1) - 65)));
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
function buildClues(site) {
    const categoryLabel = site.category === 'cultural'
        ? 'Cultural'
        : site.category === 'natural'
            ? 'Natural'
            : 'Mixed Cultural and Natural';
    const hemisphere = site.latitude >= 0 ? 'Northern Hemisphere' : 'Southern Hemisphere';
    const flag = toFlagEmoji(site.countryCode);
    // Clue 3 (index 3): age milestone or category flavour.
    let clue3Type;
    let clue3Text;
    if (site.inscriptionYear <= 1980) {
        clue3Type = 'historical';
        clue3Text = `One of the very first sites ever inscribed on the UNESCO World Heritage List (${site.inscriptionYear}).`;
    }
    else if (site.inscriptionYear <= 1990) {
        clue3Type = 'historical';
        clue3Text = `Inscribed in the early years of the UNESCO World Heritage List (${site.inscriptionYear}).`;
    }
    else if (site.category === 'natural') {
        clue3Type = 'natural';
        clue3Text = 'A place of exceptional natural beauty or ecological importance.';
    }
    else if (site.category === 'mixed') {
        clue3Type = 'natural';
        clue3Text = 'A site recognised for both its cultural heritage and its natural landscape.';
    }
    else {
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
function countryName(code) {
    const names = {
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
async function buildCluesWithAI(site, _projectId) {
    try {
        const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? _projectId;
        const ai = new genai_1.GoogleGenAI({ vertexai: true, project: projectId, location: 'us-central1' });
        const flag = toFlagEmoji(site.countryCode);
        const country = countryName(site.countryCode);
        const firstWord = site.name.split(/[\s,()–-]/)[0];
        const descriptionLine = site.shortDescription
            ? `Description: ${site.shortDescription}`
            : '';
        const criteriaLine = site.criteria?.length
            ? `UNESCO criteria: (${site.criteria.join(')(')})`
            : '';
        const prompt = `You are writing clues for Roavvy — a daily Wordle-style game where players guess a UNESCO World Heritage Site from 5 progressive clues. Each clue reveals a little more. Your goal is a smooth difficulty gradient, not a fixed category structure.

TARGET DIFFICULTY (think: what % of players guess correctly after seeing this clue alone):
  Clue 1 → ~20%  Name the broad geographic region (e.g. Western Europe, Scandinavia, the Mediterranean, South America, East Asia, Sub-Saharan Africa, the Middle East, Central Asia, the Pacific) AND the type of site (e.g. ancient city, cathedral, natural wonder, temple complex, fortified castle, rock art site, national park, historic town centre). End with one brief, evocative sensory detail. No country name, no specific sub-region, no civilisation name, no time period.
  Clue 2 → ~40%  Nearly half of players should be able to guess. A memorable pop culture connection (film, novel, game, song) OR a single record-breaking physical stat. No country name, no civilisation name.
  Clue 3 → ~60%  Most players should guess correctly by now. Historical/cultural context: which civilisation built it and roughly when. No country name.
  Clue 4 → ~80%  The vast majority should get it. Geographic reveal: continent + sub-region + terrain. No country name yet.
  Clue 5 → ~95%  Full reveal: country flag, country name, first word of site name.

STRICT RULES FOR EACH CLUE:
  Clue 1: Must state the broad region AND the type of site. One sensory detail allowed. NO country name, NO specific sub-region, NO civilisation name, NO time period, NO proper nouns.
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
${criteriaLine}

EXAMPLE (Colosseum, Rome — do not copy the style, just the structure and difficulty calibration):
[
  {"type":"geography","text":"Southern Europe. An ancient amphitheatre — the largest ever built — its tiered stone arches open to a blazing sky, worn travertine warm underfoot."},
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
        const parsed = JSON.parse(cleaned);
        if (!Array.isArray(parsed) || parsed.length !== 5) {
            throw new Error(`Unexpected clue array length: ${parsed.length}`);
        }
        console.log(`[dailyChallenge] AI clues generated for ${site.name} (${site.siteId})`);
        return parsed;
    }
    catch (err) {
        console.error(`[dailyChallenge] AI clue generation failed, falling back to templates:`, err);
        return buildClues(site);
    }
}
// ── Site picker ───────────────────────────────────────────────────────────────
/** Returns the UTC date string for today in `YYYY-MM-DD` format. */
function todayUtc() {
    return new Date().toISOString().slice(0, 10);
}
/** Adds [n] days to a YYYY-MM-DD string and returns the result. */
function addDays(date, n) {
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
async function pickSite(sites, date, db) {
    const epochDay = Math.floor(Date.parse(date + 'T00:00:00Z') / 86_400_000);
    // Fetch siteIds used in the ±COLLISION_WINDOW day window.
    const windowStart = addDays(date, -COLLISION_WINDOW);
    const windowEnd = addDays(date, COLLISION_WINDOW);
    const snap = await db.collection('daily_challenge')
        .where('__name__', '>=', windowStart)
        .where('__name__', '<=', windowEnd)
        .select('siteId')
        .get();
    const usedIds = new Set(snap.docs.map(d => d.data().siteId));
    // Walk forward from deterministic index until an unused site is found.
    for (let offset = 0; offset < sites.length; offset++) {
        const candidate = sites[(epochDay + offset) % sites.length];
        if (!usedIds.has(candidate.siteId))
            return candidate;
    }
    // Exhausted — shouldn't happen (1246 sites, 600-day window).
    console.warn(`[dailyChallenge] All sites used in window — falling back to deterministic pick`);
    return sites[epochDay % sites.length];
}
// ── Firestore writer ──────────────────────────────────────────────────────────
async function writeDailyChallenge(date) {
    const db = (0, firestore_1.getFirestore)();
    const ref = db.collection('daily_challenge').doc(date);
    const existing = await ref.get();
    if (existing.exists) {
        return { siteId: existing.data().siteId, alreadyExisted: true };
    }
    const site = await pickSite(WHS_SITES, date, db);
    const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? '';
    const clues = await buildCluesWithAI(site, projectId);
    const doc = {
        siteId: site.siteId,
        clues,
        generatedAt: firestore_1.Timestamp.now(),
    };
    await ref.set(doc);
    return { siteId: site.siteId, alreadyExisted: false };
}
// ── Exported Cloud Functions ──────────────────────────────────────────────────
/**
 * Runs every day at 00:00 UTC and writes the daily challenge document to
 * Firestore. Idempotent — skips if the document already exists.
 */
exports.scheduleDailyChallenge = (0, scheduler_1.onSchedule)({ schedule: 'every day 00:00', timeZone: 'UTC' }, async (_event) => {
    const date = todayUtc();
    const result = await writeDailyChallenge(date);
    if (result.alreadyExisted) {
        console.log(`[dailyChallenge] ${date} already exists (siteId=${result.siteId}), skipping.`);
    }
    else {
        console.log(`[dailyChallenge] ${date} written: siteId=${result.siteId}`);
    }
});
/**
 * onCall function for manual triggering and local testing.
 * Accepts an optional `date` string (YYYY-MM-DD); defaults to today UTC.
 * Returns the siteId and clues written (or already existing).
 */
exports.getDailyChallenge = (0, https_1.onCall)({}, async (request) => {
    const date = typeof request.data?.date === 'string' && request.data.date.match(/^\d{4}-\d{2}-\d{2}$/)
        ? request.data.date
        : todayUtc();
    const result = await writeDailyChallenge(date);
    const doc = await (0, firestore_1.getFirestore)().collection('daily_challenge').doc(date).get();
    return { date, ...doc.data(), alreadyExisted: result.alreadyExisted };
});
//# sourceMappingURL=dailyChallenge.js.map