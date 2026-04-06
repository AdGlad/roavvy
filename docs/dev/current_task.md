# Current Task: Milestone 61 — Passport Card Refinement

**Status:** 🔄 In Progress
**Started:** 2026-04-06

## Goal
Refine and correct the Passport-style card generation and preview so that the design is consistent, visually strong, and reusable across screens.

---

## Task 169: Safe Zones & Layout
**Objective:** Ensure stamps avoid the top (title) and bottom-left (branding) zones in `PassportLayoutEngine`.

### Sub-tasks
1. [ ] Analyze `PassportLayoutEngine.layout` for current exclusion zones.
2. [ ] Define top safe zone (for title text).
3. [ ] Define bottom-left safe zone (for Roavvy branding).
4. [ ] Update layout algorithm to prevent stamp placement within these zones.
5. [ ] Verify that stamps still overlap naturally and fill the remaining space.

### Acceptance Criteria
- [ ] Stamps never overlap the title area (top center).
- [ ] Stamps never overlap the branding area (bottom-left).
- [ ] Density remains high (stamps overlap each other).
