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
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const firestore_1 = require("firebase-admin/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const https_1 = require("firebase-functions/v2/https");
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
// ── Site picker ───────────────────────────────────────────────────────────────
/** Returns the UTC date string for today in `YYYY-MM-DD` format. */
function todayUtc() {
    return new Date().toISOString().slice(0, 10);
}
/**
 * Picks a site deterministically from [sites] based on the current UTC date.
 * The epoch-day index cycles through all sites before repeating, ensuring no
 * two consecutive days share the same site (for lists longer than 1 day).
 */
function pickSite(sites, date) {
    const epochDay = Math.floor(Date.parse(date + 'T00:00:00Z') / 86_400_000);
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
    const site = pickSite(WHS_SITES, date);
    const clues = buildClues(site);
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
exports.getDailyChallenge = (0, https_1.onCall)(async (request) => {
    const date = typeof request.data?.date === 'string' && request.data.date.match(/^\d{4}-\d{2}-\d{2}$/)
        ? request.data.date
        : todayUtc();
    const result = await writeDailyChallenge(date);
    const doc = await (0, firestore_1.getFirestore)().collection('daily_challenge').doc(date).get();
    return { date, ...doc.data(), alreadyExisted: result.alreadyExisted };
});
//# sourceMappingURL=dailyChallenge.js.map