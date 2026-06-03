# T4 — Widget Tests: Task List

## Already covered (no work needed)
- T4.4 — merch_variant_screen_test.dart (13 tests)
- T4.6 — scan_summary_screen_test.dart (25 tests)
- T4.9 — onboarding_flow_test.dart (10 tests; covers all 4 T4.9 scenarios)
- T4.10 — sign_in_screen_test.dart (3 tests; Apple + anonymous + fields)
- T4.11 — main_shell_test.dart (6 tests; nav bar + tab switching)
- T4.12 — map_screen_test.dart (30 tests)

## Tasks to build

### T4.1 — NEW: test/features/merch/merch_cart_screen_test.dart
- Unsigned user sees "Sign in" message
- Loading state shows CircularProgressIndicator
- Empty cart shows empty state message
- Non-empty cart shows item tiles
- Item tile shows title
- Item tile shows delete button

### T4.2 — NEW: test/features/merch/merch_customisation_sheet_test.dart
- Sheet renders colour picker chips
- Tapping a chip updates the selection
- Sheet renders layout toggle
- Apply/confirm CTA is visible and tappable

### T4.3 — NEW: test/features/merch/merch_country_selection_screen_test.dart
- List renders country names from fixture
- Tapping a country toggles its selection
- "Continue" is disabled when no countries selected
- "Continue" enabled after selecting one country
- Deselecting all disables "Continue"

### T4.5 — NEW: test/features/scan/scan_screen_test.dart
- Scan button is present before scan starts
- Progress area is absent before scan starts
- (Platform channel is stubbed so scan doesn't fire)

### T4.7 — NEW: test/features/challenge/daily_challenge_screen_test.dart
- Loading state shows CircularProgressIndicator
- First clue is visible when state is data
- "Reveal next clue" button present when clues remain
- Guess input field accepts text
- Solved state shows success message

### T4.8 — NEW: test/features/stats/achievements_screen_test.dart
- Screen renders 'Achievements' app bar
- With zero unlocked achievements, no unlock dates shown
- Unlocked achievements show badge/name
