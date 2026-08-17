#!/usr/bin/env bash
# Roavvy Design Studio — one-cycle experiment runner.
# Drives: GENERATE (batch) -> SCORE/REGRESS (arbiter) -> CAPTURE (before/after).
# It does NOT edit the generator (the Engineer does that first) and it NEVER
# accepts a new baseline automatically (keep/revert is the Director's call).
#
# Usage:   design_studio/tools/run_experiment.sh <experiment-id> <label>
# Example: design_studio/tools/run_experiment.sh E-001 small-multi-hierarchy
#
# Env passthrough: EXPERIMENT_ID/EXPERIMENT_LABEL are exported to the batch
# harness so batch.json + the batch dir carry the experiment provenance.
set -euo pipefail

EXP_ID="${1:?usage: run_experiment.sh <experiment-id> <label>}"
LABEL="${2:?usage: run_experiment.sh <experiment-id> <label>}"

# Resolve repo root from this script's location (design_studio/tools/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STUDIO="$REPO_ROOT/design_studio"
FLUTTER_APP="$REPO_ROOT/apps/mobile_flutter"
BASELINE="$STUDIO/regression_tests/baselines/procedural_baseline.json"

EXP_DIR="$STUDIO/experiments/${EXP_ID}-${LABEL}"
mkdir -p "$EXP_DIR"
LOG="$EXP_DIR/cycle.log"

echo "=== Design Studio cycle: $EXP_ID ($LABEL) ===" | tee "$LOG"
command -v flutter >/dev/null 2>&1 || { echo "FLUTTER NOT FOUND — install/PATH flutter to run the loop." | tee -a "$LOG"; exit 2; }

# 0) Snapshot the current baseline as the 'before' (the arbiter's committed numbers).
if [ -f "$BASELINE" ]; then
  cp "$BASELINE" "$EXP_DIR/before_baseline.json"
  echo "[cycle] snapshotted baseline -> before_baseline.json" | tee -a "$LOG"
fi

# 1) GENERATE — deterministic batch under this experiment id/label.
echo "[cycle] generating batch (EXPERIMENT_ID=$EXP_ID label=$LABEL)…" | tee -a "$LOG"
( cd "$FLUTTER_APP" && EXPERIMENT_ID="$EXP_ID" EXPERIMENT_LABEL="$LABEL" \
    flutter test test/features/merch/design_engine/procedural/batch_generate.dart ) 2>&1 | tee -a "$LOG"

BATCH_DIR="$STUDIO/generated_batches/batch_v0.1.0_${LABEL}"
BATCH_JSON="$BATCH_DIR/batch.json"

# 2) SCORE/REGRESS — the official arbiter (compares current vs committed baseline).
echo "[cycle] running regression (arbiter)…" | tee -a "$LOG"
set +e
( cd "$FLUTTER_APP" && \
    flutter test test/features/merch/design_engine/procedural/regression_test.dart ) 2>&1 | tee "$EXP_DIR/regression.log" | tee -a "$LOG"
REGRESSION_STATUS=${PIPESTATUS[0]}
set -e
echo "[cycle] regression exit status: $REGRESSION_STATUS (0 = within tolerance)" | tee -a "$LOG"

# 3) CAPTURE — extract the per-context Δ table and compute batch metrics.
grep -E 'base=.*cur=.*Δ=|improvements:|regressions' "$EXP_DIR/regression.log" \
    > "$EXP_DIR/delta_table.txt" 2>/dev/null || true

if [ -f "$BATCH_JSON" ]; then
  python3 - "$BATCH_JSON" "$EXP_DIR/batch_metrics.json" <<'PY' 2>>"$LOG" || true
import json, sys, statistics
batch = json.load(open(sys.argv[1]))
by = {}
for d in batch.get('designs', []):
    by.setdefault(d['context'], []).append(d['quality'])
per = {c: {'meanQuality': round(statistics.mean(v), 4),
           'topQuality': round(max(v), 4),
           'count': len(v)} for c, v in by.items()}
out = {'batchId': batch.get('batchId'), 'experimentId': batch.get('experimentId'),
       'engineVersion': batch.get('engineVersion'), 'grammarVersion': batch.get('grammarVersion'),
       'designCount': batch.get('designCount'),
       'aggregateMeanQuality': round(statistics.mean([q for v in by.values() for q in v]), 4),
       'perContext': per}
json.dump(out, open(sys.argv[2], 'w'), indent=2)
print('[cycle] batch metrics -> batch_metrics.json  aggregate=%.4f' % out['aggregateMeanQuality'])
PY
fi

# 4) RESULT stub — the Director/Reviewer fill decision + observations.
RESULT="$EXP_DIR/result.json"
if [ ! -f "$RESULT" ]; then
  cat > "$RESULT" <<JSON
{
  "experimentId": "$EXP_ID",
  "slug": "$LABEL",
  "status": "running",
  "batchId": "batch_v0.1.0_${LABEL}",
  "regressionExit": $REGRESSION_STATUS,
  "decision": null,
  "decisionReason": null,
  "note": "Fill hypothesis/expectedOutcome/variables/observations per experiment_record.schema.json; set status kept|reverted."
}
JSON
  echo "[cycle] wrote result stub -> result.json" | tee -a "$LOG"
fi

echo "=== cycle complete ===" | tee -a "$LOG"
echo "batch:        $BATCH_DIR" | tee -a "$LOG"
echo "contact sheet: $BATCH_DIR/index.html" | tee -a "$LOG"
echo "delta table:  $EXP_DIR/delta_table.txt" | tee -a "$LOG"
echo "regression:   exit $REGRESSION_STATUS (non-zero = a context regressed > tolerance)" | tee -a "$LOG"
echo "NEXT: Director reviews delta_table.txt + batch_metrics.json, invokes Critic/Analyst if needed, records keep/revert." | tee -a "$LOG"
exit 0
