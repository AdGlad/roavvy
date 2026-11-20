#!/usr/bin/env bash
# M189 / ADR-180: build the App Store IPA for the free (commerce-off) app.
#
# Usage: scripts/build_ios_release.sh [--dry-run] [--build-number N] [extra flutter args]
#
# Refuses to build if any argument or environment variable would turn on
# commerce or a dev tool, or if the entrypoint is anything but lib/main.dart.
set -euo pipefail

FORBIDDEN=(ROAVVY_COMMERCE STUDIO_V2 STUDIO_V2_TRACE)
DRY_RUN=0
ARGS=()

fail() { echo "build_ios_release: REFUSED: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --build-number) ARGS+=("--build-number=$2"); shift ;;
    -t|--target) [[ "$2" == "lib/main.dart" ]] || fail "target must be lib/main.dart (got $2)"; shift ;;
    --target=*) [[ "${1#--target=}" == "lib/main.dart" ]] || fail "target must be lib/main.dart (got ${1#--target=})" ;;
    --dart-define-from-file*) fail "--dart-define-from-file is not allowed; pass defines explicitly" ;;
    --debug|--profile) fail "$1: only release builds are allowed" ;;
    *)
      for key in "${FORBIDDEN[@]}"; do
        [[ "$1" == *"$key="* ]] && fail "$key must not be set in a release build"
        [[ "$1" == "--dart-define" && "${2:-}" == "$key="* ]] && fail "$key must not be set in a release build"
      done
      ARGS+=("$1") ;;
  esac
  shift
done

# Defines can also leak in through the environment of some CI wrappers.
for key in "${FORBIDDEN[@]}"; do
  [[ -z "${!key:-}" ]] || fail "environment variable $key is set"
done
[[ -z "${DART_DEFINES:-}" ]] || fail "DART_DEFINES is set in the environment"

CMD=(flutter build ipa --release -t lib/main.dart ${ARGS[@]+"${ARGS[@]}"})
echo "build_ios_release: ${CMD[*]}"
[[ $DRY_RUN -eq 1 ]] && exit 0

cd "$(dirname "$0")/../apps/mobile_flutter"
"${CMD[@]}"
