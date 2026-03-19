# Current Task — Task 59: Fix trip inference: geographic sequence model

**Milestone:** 19A
**Phase:** Quality fix

## Why

The current trip inference algorithm clusters photos within a single country by a 30-day time gap. This is wrong: a user who visits Japan three times with less than 30 days between visits gets a single trip. The correct model follows the traveller's actual movement through the chronological photo stream. A trip starts at the first photo for a country and ends at the last photo before the next photo from a *different* country appears.

## Algorithm

1. Sort all `PhotoDateRecord`s by `capturedAt` across all countries.
2. Walk the sorted list; when the country code changes, close the current trip and open a new one.
3. Trip `startedOn` = first photo's `capturedAt` in the run; `endedOn` = last photo's `capturedAt` in the run.
4. Manual trips (`isManual: true`) are never touched by re-inference.

## Acceptance criteria

- [ ] `TripInference.inferTrips()` uses geographic sequence model: sort all records by date, run-length encode by country code, each run = one `TripRecord`
- [ ] `startedOn` = first photo's `capturedAt` in the run; `endedOn` = last photo's `capturedAt` in the run
- [ ] A sequence JP → US → JP produces two separate JP trips and one US trip (not one JP trip)
- [ ] Existing manual trips (`isManual: true`) are not touched by re-inference
- [ ] Unit tests cover: single country, two countries alternating, same country non-adjacent, manual trip preservation
- [ ] `dart analyze` reports zero issues
- [ ] All existing `shared_models` tests continue to pass

## Files to change

- `packages/shared_models/lib/src/trip_inference.dart` — replace 30-day gap algorithm with geographic sequence model
- `packages/shared_models/test/trip_inference_test.dart` — update and extend tests

## Dependencies

None.

## Status: AWAITING ARCHITECT
