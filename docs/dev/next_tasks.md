# M130 — Scan: Cinematic Pacing & Orchestration Engine

## Tasks

### T1 — Event infrastructure (sealed classes + priority queue)
Add before `_ScanningView` in `scan_screen.dart`:
- `_EventPriority` enum (p1, p2, p3, p4)
- `_ScanPhase` enum (early, building, revealing)
- `_DiscoveryEvent` sealed class + 5 subclasses
- `_PriorityQueue` (sorted list, enqueue/dequeue/length)

### T2 — Wire buffer into _ScanningViewState + drain timer
- Replace direct toast calls in `didUpdateWidget` with `_buffer.enqueue()`
- Add drain timer (100ms periodic), presentation lock, _ScanPhase tracking
- Remove old rate-limit timer + heritage delay timer

### T3 — Cinematic presentation engine (_drainQueue + _presentX)
- `_drainQueue()` checks lock, dequeues, dispatches
- `_presentCountryDiscovery`, `_presentHeritageDiscovery`, `_presentAchievement`,
  `_presentContinent`, `_presentMajorMilestone` — each async with timing + audio

### T4 — Mute toggle + queue depth indicator
- `_muted: bool` state + speaker IconButton
- Queue depth pill (AnimatedSwitcher, shows when 3+ queued)

### T5 — UNESCO site type chip + _ScanPhase modulation
- `siteType` param on `_HeritageToastBanner` → Cultural/Natural chip
- Phase modulates toast richness and audio category

### T6 — Docs + validation
- Mark M130 complete, update backlog + current_task
- flutter analyze + index_docs
