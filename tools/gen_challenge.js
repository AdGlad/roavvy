#!/usr/bin/env node
/**
 * Generate the daily challenge document for a given date by calling the
 * deployed Cloud Function. The function handles site selection, AI clue
 * generation, and Firestore writes with the correct GCP service account.
 *
 * Usage:
 *   node tools/gen_challenge.js                          # today (local date)
 *   node tools/gen_challenge.js 2026-06-01               # specific date
 *   node tools/gen_challenge.js 2026-06-01 2026-06-07   # date range
 *   node tools/gen_challenge.js --regen 2026-06-01       # delete + regenerate
 *   node tools/gen_challenge.js --delete 2026-06-01      # delete only
 *
 * Requires:
 *   gcloud auth login (for identity token)
 *   Firebase Admin SDK (bundled in apps/functions/node_modules) for --delete
 */

'use strict';

const path = require('path');
const fs   = require('fs');

// ── Firebase Admin init (used only for --delete) ───────────────────────────
const admin = require(path.join(__dirname, '../apps/functions/node_modules/firebase-admin'));

const firebaserc = JSON.parse(
  fs.readFileSync(path.join(__dirname, '../.firebaserc'), 'utf-8')
);
// Default to prod; override with FIREBASE_PROJECT=roavvy-dev for dev testing.
const project =
  process.env.GCLOUD_PROJECT ||
  process.env.FIREBASE_PROJECT ||
  firebaserc.projects?.default ||
  firebaserc.projects?.dev;

if (!project) {
  console.error('❌  Could not determine Firebase project. Set FIREBASE_PROJECT env var.');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId: project });
}
const db = admin.firestore();

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

// ── Core operations ────────────────────────────────────────────────────────
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
  // Check if already exists (skip unless --regen)
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

  // Call the Cloud Function via HTTPS (allUsers invoker set on Cloud Run service)
  const CF_URL = `https://us-central1-${project}.cloudfunctions.net/getDailyChallenge`;
  console.log(`  ⏳ ${date} — calling Cloud Function…`);

  const res = await fetch(CF_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ data: { date } }),
  });

  if (!res.ok) {
    const body = await res.text();
    console.error(`  ❌ ${date} — Cloud Function error ${res.status}: ${body}`);
    return;
  }

  const json = await res.json();
  const result = json.result ?? json;
  const siteId = result?.siteId ?? '?';
  const firstClue = result?.clues?.[0]?.text ?? '';
  console.log(`  ✅ ${date} — written (siteId=${siteId}, ${firstClue.slice(0, 60)}…)`);
}

// ── Main ───────────────────────────────────────────────────────────────────
async function main() {
  const args = process.argv.slice(2);

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

  console.log(`Project: ${project}\n`);

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
