# M148 — Flag Mosaic Wall

## Goal
Scrollable full-screen grid of every country's flag. Visited = full colour. Unvisited = greyscale + dimmed.
Launched from the Countries stat card. Tapping a visited flag shows a bottom sheet with visit dates and trip count.
Continent filter chips narrow the grid. Share button exports visited flags as PNG.

## Tasks

- [ ] T1 — `flag_mosaic_screen.dart` — full-screen scaffold, header, continent filter chips, flag GridView
- [ ] T2 — Flag tile widget — full-colour visited / greyscale unvisited with ColorFiltered shader
- [ ] T3 — Visit detail bottom sheet — country name, first/last seen, trip count
- [ ] T4 — Share CTA — RepaintBoundary → PNG → Share.shareXFiles (visited flags only)
- [ ] T5 — Wire entry point — tap Countries card in StatsGrid navigates to FlagMosaicScreen
- [ ] T6 — Widget test: given 3 visited countries, 3 coloured tiles and 192 dimmed tiles render
