# Current Task

**Milestone:** M130 — Scan: Cinematic Pacing & Orchestration Engine
**Status:** Complete (2026-05-25)

All tasks implemented:
- T1: `_DiscoveryEvent` sealed class hierarchy + `_PriorityQueue`
- T2: `_ScanningViewState` wired to buffer; drain timer; `_ScanPhase` tracking
- T3: `_drainQueue()` + `_presentX()` cinematic presentation methods
- T4: Mute toggle + `_muted` guard on audio calls
- T5: Queue depth indicator (AnimatedSwitcher pill, shows when 3+ queued)
- T6: UNESCO `siteType` chip on `_HeritageToastBanner` (Cultural/Natural)
- T7: `_ScanPhase` progressive intensity (early/building/revealing)

See: `docs/dev/milestones/m130-scan-cinematic-pacing-orchestration.md`

Next milestone: see `backlog_active.md`.
