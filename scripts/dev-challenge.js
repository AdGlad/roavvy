#!/usr/bin/env node
/**
 * dev-challenge.js — DEV ONLY
 *
 * Deletes a daily_challenge Firestore doc and regenerates it with AI clues
 * (Gemini via Vertex AI — same path as the Cloud Function) for a different
 * site, so you can test the challenge UI without waiting for the scheduler.
 *
 * Usage:
 *   node scripts/dev-challenge.js [--offset N] [--project PROJECT_ID] [--date YYYY-MM-DD]
 *
 * Options:
 *   --offset N          Shift the site index by N (default: 1, range: any integer)
 *   --project ID        Firebase project ID (default: roavvy-prod)
 *   --date YYYY-MM-DD   Target date to reset (default: today UTC)
 *
 * Examples:
 *   node scripts/dev-challenge.js                   # next site from today's index
 *   node scripts/dev-challenge.js --offset 42       # site 42 slots ahead
 *   node scripts/dev-challenge.js --offset -1       # previous site
 *   node scripts/dev-challenge.js --date 2026-05-30 --offset 0
 *
 * Prerequisites:
 *   gcloud auth application-default login
 */

'use strict';

const fs   = require('fs');
const path = require('path');

// ── Parse args ────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
function getArg(flag, defaultValue) {
  const i = args.indexOf(flag);
  if (i === -1 || i + 1 >= args.length) return defaultValue;
  return args[i + 1];
}

const offset     = parseInt(getArg('--offset', '1'), 10);
const projectId  = getArg('--project', 'roavvy-prod');
const targetDate = getArg('--date', new Date().toISOString().slice(0, 10));

// ── Load + deduplicate sites ──────────────────────────────────────────────────

const sitesPath = path.join(__dirname, '..', 'apps', 'functions', 'src', 'assets', 'whs_sites.json');
const allSites  = JSON.parse(fs.readFileSync(sitesPath, 'utf-8'));

const seen   = new Set();
const unique = [];
for (const s of allSites) {
  if (!seen.has(s.siteId)) { seen.add(s.siteId); unique.push(s); }
}
unique.sort((a, b) => a.siteId.localeCompare(b.siteId));

// ── Pick site ─────────────────────────────────────────────────────────────────

const epochDay  = Math.floor(Date.parse(targetDate + 'T00:00:00Z') / 86_400_000);
const baseIndex = epochDay % unique.length;
const newIndex  = ((baseIndex + offset) % unique.length + unique.length) % unique.length;
const site      = unique[newIndex];

// ── Helpers (mirrors dailyChallenge.ts) ───────────────────────────────────────

function toFlagEmoji(code) {
  const c = code.toUpperCase();
  return String.fromCodePoint(0x1f1e6 + (c.charCodeAt(0) - 65)) +
         String.fromCodePoint(0x1f1e6 + (c.charCodeAt(1) - 65));
}

const COUNTRY_NAMES = {
  AF:'Afghanistan',AL:'Albania',DZ:'Algeria',AD:'Andorra',AO:'Angola',AR:'Argentina',
  AM:'Armenia',AU:'Australia',AT:'Austria',AZ:'Azerbaijan',BH:'Bahrain',BD:'Bangladesh',
  BY:'Belarus',BE:'Belgium',BZ:'Belize',BJ:'Benin',BO:'Bolivia',BA:'Bosnia and Herzegovina',
  BW:'Botswana',BR:'Brazil',BG:'Bulgaria',KH:'Cambodia',CM:'Cameroon',CA:'Canada',
  CF:'Central African Republic',CL:'Chile',CN:'China',CO:'Colombia',CG:'Congo',
  CR:'Costa Rica',HR:'Croatia',CU:'Cuba',CY:'Cyprus',CZ:'Czech Republic',DK:'Denmark',
  EC:'Ecuador',EG:'Egypt',SV:'El Salvador',EE:'Estonia',ET:'Ethiopia',FI:'Finland',
  FR:'France',GA:'Gabon',GM:'Gambia',GE:'Georgia',DE:'Germany',GH:'Ghana',GR:'Greece',
  GT:'Guatemala',GN:'Guinea',HN:'Honduras',HU:'Hungary',IN:'India',ID:'Indonesia',
  IR:'Iran',IQ:'Iraq',IE:'Ireland',IL:'Israel',IT:'Italy',JM:'Jamaica',JP:'Japan',
  JO:'Jordan',KZ:'Kazakhstan',KE:'Kenya',KR:'South Korea',KG:'Kyrgyzstan',LA:'Laos',
  LV:'Latvia',LB:'Lebanon',LS:'Lesotho',LT:'Lithuania',LU:'Luxembourg',MK:'North Macedonia',
  MG:'Madagascar',MW:'Malawi',MY:'Malaysia',ML:'Mali',MT:'Malta',MR:'Mauritania',
  MX:'Mexico',MD:'Moldova',MC:'Monaco',MN:'Mongolia',ME:'Montenegro',MA:'Morocco',
  MZ:'Mozambique',NA:'Namibia',NP:'Nepal',NL:'Netherlands',NZ:'New Zealand',NI:'Nicaragua',
  NE:'Niger',NG:'Nigeria',NO:'Norway',OM:'Oman',PK:'Pakistan',PA:'Panama',PY:'Paraguay',
  PE:'Peru',PH:'Philippines',PL:'Poland',PT:'Portugal',QA:'Qatar',RO:'Romania',RU:'Russia',
  RW:'Rwanda',SA:'Saudi Arabia',SN:'Senegal',RS:'Serbia',SL:'Sierra Leone',SK:'Slovakia',
  SI:'Slovenia',SO:'Somalia',ZA:'South Africa',ES:'Spain',LK:'Sri Lanka',SD:'Sudan',
  SE:'Sweden',CH:'Switzerland',SY:'Syria',TJ:'Tajikistan',TZ:'Tanzania',TH:'Thailand',
  TG:'Togo',TN:'Tunisia',TR:'Turkey',TM:'Turkmenistan',UG:'Uganda',UA:'Ukraine',
  GB:'United Kingdom',US:'United States',UY:'Uruguay',UZ:'Uzbekistan',VE:'Venezuela',
  VN:'Vietnam',YE:'Yemen',ZM:'Zambia',ZW:'Zimbabwe',
};

function buildCluesFallback(s) {
  const catLabel = s.category === 'cultural' ? 'Cultural'
    : s.category === 'natural' ? 'Natural' : 'Mixed Cultural and Natural';
  const hemi     = s.latitude >= 0 ? 'Northern Hemisphere' : 'Southern Hemisphere';
  const flag     = toFlagEmoji(s.countryCode);
  const country  = COUNTRY_NAMES[s.countryCode] ?? s.countryCode;
  const firstWord = s.name.split(/[\s,()–-]/)[0];

  let clue3Type, clue3Text;
  if (s.inscriptionYear <= 1980) {
    clue3Type = 'historical';
    clue3Text = `One of the very first sites ever inscribed on the UNESCO World Heritage List (${s.inscriptionYear}).`;
  } else if (s.inscriptionYear <= 1990) {
    clue3Type = 'historical';
    clue3Text = `Inscribed in the early years of the UNESCO World Heritage List (${s.inscriptionYear}).`;
  } else if (s.category === 'natural') {
    clue3Type = 'natural';
    clue3Text = 'A place of exceptional natural beauty or ecological importance.';
  } else if (s.category === 'mixed') {
    clue3Type = 'natural';
    clue3Text = 'A site recognised for both its cultural heritage and its natural landscape.';
  } else {
    clue3Type = 'historical';
    clue3Text = 'A place of outstanding historical, artistic, or archaeological significance.';
  }

  return [
    { type: 'geography',  text: `A ${catLabel} site in ${s.region}.` },
    { type: 'historical', text: `Inscribed in ${s.inscriptionYear}. Located in the ${hemi}.` },
    { type: 'location',   text: `${flag} Found in ${country}.` },
    { type: clue3Type,    text: clue3Text },
    { type: 'direct',     text: `The site name begins with "${firstWord}".` },
  ];
}

// ── AI clue generation (mirrors buildCluesWithAI in dailyChallenge.ts) ────────

async function buildCluesWithAI(s) {
  const { GoogleGenAI } = require(
    path.join(__dirname, '..', 'apps', 'functions', 'node_modules', '@google', 'genai')
  );

  // Prefer Google AI Studio API key (env) over Vertex AI — avoids project-level
  // model access configuration. Falls back to Vertex AI if no key is set.
  const apiKey = process.env.GOOGLE_API_KEY || process.env.GEMINI_API_KEY;
  const ai = apiKey
    ? new GoogleGenAI({ apiKey })
    : new GoogleGenAI({ vertexai: true, project: projectId, location: 'us-central1' });

  const flag       = toFlagEmoji(s.countryCode);
  const country    = COUNTRY_NAMES[s.countryCode] ?? s.countryCode;
  const firstWord  = s.name.split(/[\s,()–-]/)[0];
  const descLine   = s.shortDescription ? `Description: ${s.shortDescription}` : '';

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
- Name: ${s.name}
- Country: ${country}
- Category: ${s.category}
- Inscription year: ${s.inscriptionYear}
- Region: ${s.region}
${descLine}

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
    model: 'gemini-2.0-flash',
    contents: prompt,
  });
  const text    = response.text ?? '';
  const cleaned = text.replace(/^```(?:json)?\n?/m, '').replace(/\n?```$/m, '').trim();
  const parsed  = JSON.parse(cleaned);

  if (!Array.isArray(parsed) || parsed.length !== 5) {
    throw new Error(`Unexpected clue array length: ${parsed.length}`);
  }
  return parsed;
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  const admin = require(
    path.join(__dirname, '..', 'apps', 'functions', 'node_modules', 'firebase-admin')
  );
  admin.initializeApp({ projectId });
  const db = admin.firestore();

  console.log(`Project : ${projectId}`);
  console.log(`Date    : ${targetDate}`);
  console.log(`Site    : [${newIndex}] ${site.siteId} — ${site.name} (${site.countryCode})`);
  console.log(`Original: [${baseIndex}] (offset ${offset >= 0 ? '+' : ''}${offset})`);
  console.log('');

  // Delete existing doc.
  await db.collection('daily_challenge').doc(targetDate).delete();
  console.log(`Deleted doc for ${targetDate}`);

  // Generate AI clues, fall back to templates on error.
  let clues;
  try {
    console.log('Generating AI clues via Gemini...');
    clues = await buildCluesWithAI(site);
    console.log('AI clues generated.');
  } catch (err) {
    console.warn(`AI generation failed (${err.message}) — using template clues.`);
    clues = buildCluesFallback(site);
  }

  // Write to Firestore.
  await db.collection('daily_challenge').doc(targetDate).set({
    siteId: site.siteId,
    clues,
    generatedAt: admin.firestore.Timestamp.now(),
    _devOverride: true,
  });

  console.log(`Written: ${site.name}`);
  console.log('');
  console.log('Clues:');
  clues.forEach((c, i) => console.log(`  ${i + 1}. [${c.type}] ${c.text}`));
  console.log('');
  console.log('Reopen the challenge screen (or pull-to-refresh) to load the new site.');

  process.exit(0);
}

main().catch(err => {
  console.error('Error:', err.message ?? err);
  process.exit(1);
});
