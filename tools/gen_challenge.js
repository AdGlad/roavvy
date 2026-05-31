#!/usr/bin/env node
/**
 * Generate the daily challenge document for a given date and write it to
 * Firestore. Requires ADC (application default credentials) — run
 * `gcloud auth application-default login` first if needed.
 *
 * Usage:
 *   node tools/gen_challenge.js                          # today (local date)
 *   node tools/gen_challenge.js 2026-06-01               # specific date
 *   node tools/gen_challenge.js 2026-06-01 2026-06-07   # date range
 *   node tools/gen_challenge.js --regen 2026-06-01       # delete + regenerate
 *   node tools/gen_challenge.js --delete 2026-06-01      # delete only
 *
 * Run from the repo root. The functions package must be built first:
 *   cd apps/functions && npm run build && cd ../..
 */

'use strict';

const path = require('path');
const fs = require('fs');

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
const firebaserc = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../.firebaserc'), 'utf-8')
);
// Default to prod — daily challenge documents live in roavvy-prod.
// Override with FIREBASE_PROJECT=roavvy-dev for local dev testing.
const project = process.env.GCLOUD_PROJECT
  || process.env.FIREBASE_PROJECT
  || firebaserc.projects?.default
  || firebaserc.projects?.dev;

if (!project) {
  console.error('❌  Could not determine Firebase project. Set FIREBASE_PROJECT env var.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId: project });
}
const db = admin.firestore();

// ── WHS sites (from functions asset) ──────────────────────────────────────
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

const COLLISION_WINDOW = 300; // days

function epochDay(date) {
  return Math.floor(Date.parse(date + 'T00:00:00Z') / 86_400_000);
}

function addDays(date, n) {
  const d = new Date(date + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** Picks a site for [date], skipping any already used in the prior/next 300 days. */
async function pickSite(date) {
  const day = epochDay(date);
  // Fetch recent siteIds from Firestore (±COLLISION_WINDOW days)
  const windowStart = addDays(date, -COLLISION_WINDOW);
  const windowEnd   = addDays(date, COLLISION_WINDOW);
  const snap = await db.collection('daily_challenge')
    .where(admin.firestore.FieldPath.documentId(), '>=', windowStart)
    .where(admin.firestore.FieldPath.documentId(), '<=', windowEnd)
    .select('siteId')
    .get();
  const usedSiteIds = new Set(snap.docs.map(d => d.data().siteId));

  // Walk forward from deterministic start until we find an unused site.
  let offset = 0;
  while (offset < uniqueSites.length) {
    const candidate = uniqueSites[(day + offset) % uniqueSites.length];
    if (!usedSiteIds.has(candidate.siteId)) return candidate;
    offset++;
  }
  // Exhausted (shouldn't happen with 1246 sites and a 600-day window)
  return uniqueSites[day % uniqueSites.length];
}

// ── Main ───────────────────────────────────────────────────────────────────
async function deleteDate(date) {
  const ref = db.collection('daily_challenge').doc(date);
  const existing = await ref.get();
  if (!existing.exists) {
    console.log(`  ✗ ${date} — no document found, nothing to delete`);
    return;
  }
  await ref.delete();
  console.log(`  🗑️  ${date} — deleted (was siteId=${existing.data().siteId})`);
}

async function generateDate(date, { force = false } = {}) {
  const ref = db.collection('daily_challenge').doc(date);
  const existing = await ref.get();
  if (existing.exists && !force) {
    console.log(`  ✓ ${date} — already exists (siteId=${existing.data().siteId}), skipping`);
    return;
  }
  if (existing.exists && force) {
    await ref.delete();
    console.log(`  🗑️  ${date} — deleted existing (siteId=${existing.data().siteId})`);
  }

  const site = await pickSite(date);
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

  // Parse flags
  const deleteOnly = args.includes('--delete');
  const regen      = args.includes('--regen');
  const dateArgs   = args.filter(a => !a.startsWith('--'));

  let dates;
  if (dateArgs.length === 0) {
    dates = [todayLocal()];
  } else if (dateArgs.length === 1) {
    dates = [dateArgs[0]];
  } else {
    dates = dateRange(dateArgs[0], dateArgs[1]);
  }

  console.log(`Project: ${project}`);

  if (deleteOnly) {
    console.log(`Deleting ${dates.length} date(s)…\n`);
    for (const date of dates) await deleteDate(date);
  } else {
    console.log(`Generating ${dates.length} date(s)${regen ? ' (--regen: delete first)' : ''}…\n`);
    for (const date of dates) await generateDate(date, { force: regen });
  }

  console.log('\nDone.');
  process.exit(0);
}

main().catch(err => {
  console.error('❌ ', err);
  process.exit(1);
});
