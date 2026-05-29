#!/usr/bin/env node
/**
 * dev-challenge.js — DEV ONLY
 *
 * Deletes today's daily_challenge Firestore doc and regenerates it using a
 * different site (picked by offset), so you can test the challenge UI against
 * multiple UNESCO sites without waiting for the scheduler.
 *
 * Usage:
 *   node scripts/dev-challenge.js [--offset N] [--project PROJECT_ID] [--date YYYY-MM-DD]
 *
 * Options:
 *   --offset N          Shift the site index by N (default: 1, range: any integer)
 *   --project ID        Firebase project ID (default: roavvy-dev)
 *   --date YYYY-MM-DD   Target date to reset (default: today UTC)
 *
 * Examples:
 *   node scripts/dev-challenge.js                   # next site from today's index
 *   node scripts/dev-challenge.js --offset 42       # site 42 slots ahead
 *   node scripts/dev-challenge.js --offset -1       # previous site
 *   node scripts/dev-challenge.js --project roavvy-prod --offset 5
 *
 * Prerequisites:
 *   gcloud auth application-default login
 *   (or set GOOGLE_APPLICATION_CREDENTIALS to a service account key)
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ── Parse args ────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
function getArg(flag, defaultValue) {
  const i = args.indexOf(flag);
  if (i === -1 || i + 1 >= args.length) return defaultValue;
  return args[i + 1];
}

const offset = parseInt(getArg('--offset', '1'), 10);
const projectId = getArg('--project', 'roavvy-prod');
const targetDate = getArg('--date', new Date().toISOString().slice(0, 10));

// ── Load sites ────────────────────────────────────────────────────────────────

const sitesPath = path.join(__dirname, '..', 'apps', 'functions', 'src', 'assets', 'whs_sites.json');
const allSites = JSON.parse(fs.readFileSync(sitesPath, 'utf-8'));

// Deduplicate + stable sort (mirrors loadUniqueSites() in dailyChallenge.ts).
const seen = new Set();
const unique = [];
for (const site of allSites) {
  if (!seen.has(site.siteId)) {
    seen.add(site.siteId);
    unique.push(site);
  }
}
unique.sort((a, b) => a.siteId.localeCompare(b.siteId));

// ── Pick site ─────────────────────────────────────────────────────────────────

const epochDay = Math.floor(Date.parse(targetDate + 'T00:00:00Z') / 86_400_000);
const baseIndex = epochDay % unique.length;
const newIndex = ((baseIndex + offset) % unique.length + unique.length) % unique.length;
const site = unique[newIndex];

// ── Build template clues (mirrors buildClues() in dailyChallenge.ts) ──────────

function toFlagEmoji(code) {
  const c = code.toUpperCase();
  return (
    String.fromCodePoint(0x1f1e6 + (c.charCodeAt(0) - 65)) +
    String.fromCodePoint(0x1f1e6 + (c.charCodeAt(1) - 65))
  );
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

function buildClues(s) {
  const catLabel = s.category === 'cultural' ? 'Cultural'
    : s.category === 'natural' ? 'Natural' : 'Mixed Cultural and Natural';
  const hemi = s.latitude >= 0 ? 'Northern Hemisphere' : 'Southern Hemisphere';
  const flag = toFlagEmoji(s.countryCode);
  const country = COUNTRY_NAMES[s.countryCode] ?? s.countryCode;
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

// ── Write to Firestore ────────────────────────────────────────────────────────

async function main() {
  const admin = require(path.join(__dirname, '..', 'apps', 'functions', 'node_modules', 'firebase-admin'));

  admin.initializeApp({ projectId });
  const db = admin.firestore();

  const ref = db.collection('daily_challenge').doc(targetDate);

  console.log(`Project : ${projectId}`);
  console.log(`Date    : ${targetDate}`);
  console.log(`Site    : [${newIndex}] ${site.siteId} — ${site.name} (${site.countryCode})`);
  console.log(`Original: [${baseIndex}] (offset ${offset >= 0 ? '+' : ''}${offset})`);
  console.log('');

  // Delete existing doc.
  await ref.delete();
  console.log(`Deleted existing doc for ${targetDate}`);

  // Write new challenge.
  const clues = buildClues(site);
  await ref.set({
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
  console.log('Pull-to-refresh the app or reopen the challenge screen to load the new site.');

  process.exit(0);
}

main().catch(err => {
  console.error('Error:', err.message ?? err);
  process.exit(1);
});
