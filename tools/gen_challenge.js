#!/usr/bin/env node
/**
 * Generate the daily challenge document for a given date and write it to
 * Firestore. Requires ADC (application default credentials) — run
 * `gcloud auth application-default login` first if needed.
 *
 * Usage:
 *   node tools/gen_challenge.js                 # today (local date)
 *   node tools/gen_challenge.js 2026-06-01      # specific date
 *   node tools/gen_challenge.js 2026-06-01 2026-06-07  # date range
 *
 * Run from the repo root. The functions package must be built first:
 *   cd apps/functions && npm run build && cd ../..
 */

'use strict';

const path = require('path');

// ── Verify the functions lib is built ──────────────────────────────────────
const libDir = path.join(__dirname, '../apps/functions/lib');
let buildCluesWithAI, buildClues;
try {
  const mod = require(path.join(libDir, 'dailyChallenge'));
  buildCluesWithAI = mod.buildCluesWithAI;
  buildClues = mod.buildClues;
} catch (e) {
  console.error('❌  Could not load apps/functions/lib/dailyChallenge.js');
  console.error('   Build first: cd apps/functions && npm run build');
  process.exit(1);
}

// ── Firebase Admin init ────────────────────────────────────────────────────
const admin = require(path.join(__dirname, '../apps/functions/node_modules/firebase-admin'));

// Determine project from .firebaserc
const firebaserc = require(path.join(__dirname, '../.firebaserc'));
const project = process.env.GCLOUD_PROJECT
  || process.env.FIREBASE_PROJECT
  || firebaserc.projects?.dev
  || firebaserc.projects?.default;

if (!project) {
  console.error('❌  Could not determine Firebase project. Set FIREBASE_PROJECT env var.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId: project });
}
const db = admin.firestore();

// ── WHS sites (from functions asset) ──────────────────────────────────────
const fs = require('fs');
const sitesPath = path.join(libDir, 'assets/whs_sites.json');
const allSites = JSON.parse(fs.readFileSync(sitesPath, 'utf-8'));

// Deduplicate + sort (same logic as Cloud Function)
const seen = new Set();
const uniqueSites = [];
for (const s of allSites) {
  if (!seen.has(s.siteId)) { seen.add(s.siteId); uniqueSites.push(s); }
}
uniqueSites.sort((a, b) => a.siteId.localeCompare(b.siteId));

// ── Helpers ────────────────────────────────────────────────────────────────
function todayLocal() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function dateRange(from, to) {
  const dates = [];
  const cur = new Date(from + 'T00:00:00Z');
  const end = new Date(to + 'T00:00:00Z');
  while (cur <= end) {
    const y = cur.getUTCFullYear();
    const m = String(cur.getUTCMonth() + 1).padStart(2, '0');
    const d = String(cur.getUTCDate()).padStart(2, '0');
    dates.push(`${y}-${m}-${d}`);
    cur.setUTCDate(cur.getUTCDate() + 1);
  }
  return dates;
}

function pickSite(date) {
  const epochDay = Math.floor(Date.parse(date + 'T00:00:00Z') / 86_400_000);
  return uniqueSites[epochDay % uniqueSites.length];
}

// ── Main ───────────────────────────────────────────────────────────────────
async function generateDate(date) {
  const ref = db.collection('daily_challenge').doc(date);
  const existing = await ref.get();
  if (existing.exists) {
    console.log(`  ✓ ${date} — already exists (siteId=${existing.data().siteId}), skipping`);
    return;
  }

  const site = pickSite(date);
  console.log(`  ⏳ ${date} — generating clues for: ${site.name} (${site.siteId})`);

  const clues = await buildCluesWithAI(site, project).catch(() => {
    console.warn('     AI failed, using templates');
    return buildClues(site);
  });

  await ref.set({
    siteId: site.siteId,
    clues,
    generatedAt: admin.firestore.Timestamp.now(),
  });

  console.log(`  ✅ ${date} — written (${clues[0]?.text?.slice(0, 60)}…)`);
}

async function main() {
  const args = process.argv.slice(2);
  let dates;

  if (args.length === 0) {
    dates = [todayLocal()];
  } else if (args.length === 1) {
    dates = [args[0]];
  } else {
    dates = dateRange(args[0], args[1]);
  }

  console.log(`Project: ${project}`);
  console.log(`Generating ${dates.length} date(s)…\n`);

  for (const date of dates) {
    await generateDate(date);
  }

  console.log('\nDone.');
  process.exit(0);
}

main().catch(err => {
  console.error('❌ ', err);
  process.exit(1);
});
