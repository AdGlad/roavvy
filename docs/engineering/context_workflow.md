# Context Workflow

How to decide what to load for each coding task. Default: load nothing until you need it.

---

## The single deciding question

> "What would fail if I didn't read this?"

If the answer is "nothing" — don't load it.

---

## Load matrix

| Task type | Always load | Load if needed | Never load |
|---|---|---|---|
| Bug fix | Affected source file(s) | `current_state.md` (to locate code), `decisions/_index.md` (if pattern is unclear) | Backlog, roadmap, vision, persona files |
| New feature — planning | `backlog_active.md`, `current_state.md` | `roadmap.md`, `vision.md` (if scope is ambiguous) | ADR archive, persona files |
| New feature — architecture | `decisions/_index.md` | Specific ADR entries, `package_boundaries.md` | Backlog, roadmap, vision |
| New feature — implementation | `current_task.md` + relevant `CLAUDE.md` | `decisions/_index.md` (to check constraints) | Backlog, roadmap, ADR archive |
| New feature — review | `reviewer.md` | `decisions/_index.md` (if boundary violation suspected) | All other context |
| Refactor | Affected source file(s), `decisions/_index.md` | `current_state.md` (if scope is unclear), `package_boundaries.md` | Backlog, roadmap, vision, persona files |
| Cross-cutting change | `decisions/_index.md`, `package_boundaries.md` | Specific recent ADRs | ADR archive (unless debugging old behaviour) |

---

## Decision rules

**Start with the code, not the docs.**
Read the file you're about to change first. Only load context docs when the code alone is insufficient.

**`current_state.md` is a map, not a spec.**
Load it to find what exists and where. Don't load it to understand *how* something works — read the source.

**`decisions/_index.md` replaces the full ADR file for 95% of tasks.**
Scan the one-line summaries. Only open `adr-recent.md` or `adr-archive.md` if you need the full reasoning of a specific ADR.

**Persona files are invoked, not pre-loaded.**
Load `planner.md` when planning, `reviewer.md` when reviewing. Never load all four at once.

**CLAUDE.md is always active — don't re-read it mid-task.**
Its constraints apply globally. The only reason to re-read it is if you're unsure whether a constraint applies.

---

## Example: fixing a bug

**Scenario:** Stamp shuffle button not working after navigating away and back.

```
1. Read the bug report / reproduce mentally
2. Grep for the shuffle handler → finds card_editor_screen.dart:_shuffleStampLayout
3. Read card_editor_screen.dart (the affected file)
4. Fix is apparent: _stampLayoutSeed is reset in initState
5. Write fix + test
```

**Loaded:** 1 source file.
**Not loaded:** current_state.md, backlog, any persona, any ADR.

**When to escalate:** If the fix touches package boundaries or contradicts an ADR pattern → scan `decisions/_index.md` before proceeding.

---

## Example: building a new feature (M61 — Grid Card SVG upgrade)

### Step 1 — Planning (act as Planner)

```
Load: backlog_active.md         → read M61 goal + scope
Load: current_state.md          → confirm GridFlagsCard is emoji-based (lib/features/cards/card_templates.dart)
Load: planner.md                → output format + constraints checklist
Write: current_task.md          → task list (not in chat)
```

**Not loaded:** roadmap (scope is clear), vision (no direction ambiguity), any ADR.

### Step 2 — Architecture (act as Architect)

```
Load: decisions/_index.md       → scan for existing SVG/flag/card ADRs
  → ADR-098 (HeartFlagsCard SVG layout) is directly relevant → load that entry from adr-recent.md
Load: package_boundaries.md     → confirm SVG assets stay in app layer
Load: architect.md              → ADR output format
Write: new ADR entry            → append to adr-recent.md
```

**Not loaded:** full adr-archive.md, backlog, roadmap, planner/builder/reviewer personas.

### Step 3 — Implementation (act as Builder)

```
Load: current_task.md           → task list + acceptance criteria
Load: apps/mobile_flutter/CLAUDE.md  → conventions for this directory
Read: lib/features/cards/card_templates.dart   → existing GridFlagsCard code
Read: lib/features/cards/heart_layout_engine.dart  → SVG pattern to follow (ADR-098)
```

**Not loaded:** current_state.md (already know the file), backlog, any ADR beyond what was noted in Step 2.

### Step 4 — Review (act as Reviewer)

```
Load: reviewer.md               → run the checklist
```

**Not loaded:** anything else — the reviewer works from the diff, not from planning docs.

---

## Example: refactoring code

**Scenario:** Extract title generation logic from `card_editor_screen.dart` into a dedicated service.

```
1. Read card_editor_screen.dart  → understand current structure
2. Scan decisions/_index.md      → check ADR-125 (title generation) for constraints
   → confirms: year must not appear in titles; region-aware prompts required
3. Read rule_based_title_generator.dart + AiTitlePlugin.swift  → understand full scope
4. Refactor: extract TitleGenerationService
5. Update tests
```

**Loaded:** 3 source files + `_index.md` one-pass scan.
**Not loaded:** backlog, persona files, current_state.md (files already known from code search), roadmap.

**Key rule for refactors:** If the refactor changes a public API that other features depend on → load `current_state.md` to find all call sites before starting.

---

## Section retrieval — reading only what you need

For large files (`adr-recent.md`, `adr-archive.md`), retrieve specific sections rather than the whole file:

**Step 1 — find relevant ADRs by topic:**
```
Grep docs/_index.md for keyword → returns ADR numbers + source files
```

**Step 2 — confirm relevance from one-liner:**
```
Scan docs/architecture/decisions/_index.md for those ADR numbers
```

**Step 3 — read only that ADR section:**
```
grep -n "## ADR-125" docs/architecture/decisions/adr-recent.md
# → 812: ## ADR-125 — …
# Then Read(adr-recent.md, offset=812, limit=50)
```

ADR sections average 30–60 lines. Use `limit=80` when unsure of length.

---

## What never gets loaded mid-task

| File | Why |
|---|---|
| `backlog_active.md` | Irrelevant once a task is underway |
| `roadmap.md` / `vision.md` | Only relevant when scoping a new milestone |
| `adr-archive.md` | ADR-001–099 are rarely relevant; scan `_index.md` first |
| All 4 persona files at once | Each persona is stage-specific |
| `project_index.md` | Use Glob/Grep to find files directly |
