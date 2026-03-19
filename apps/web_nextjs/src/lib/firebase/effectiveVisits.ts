/**
 * Computes the effective set of visited country codes from the three Firestore
 * subcollections (ADR-029, ADR-046).
 *
 * Logic: (inferred ∪ added) − removed
 *
 * This is the TypeScript counterpart of effectiveVisitedCountries() in
 * packages/shared_models (Dart). Semantics must remain identical (ADR-007).
 */
export function effectiveVisits(
  inferred: string[],
  added: string[],
  removed: string[]
): string[] {
  const removedSet = new Set(removed);
  const combined = new Set([...inferred, ...added]);
  return Array.from(combined).filter((code) => !removedSet.has(code));
}
