# Milestone 87 — Passport PDF Generation & Mobile Preview

**Option A: Softcover Passport Book**

## Goal
Design and implement a system to generate a multi-page, print-ready "Passport Book" PDF based on a user's travel history, including a premium mobile preview experience.

## Technical Context
- **Stamps:** Use procedural rendering logic from `StampPainter` and `PassportLayoutEngine`.
- **Assets:** Background patterns (SVG/PNG) for passport-style pages.
- **Platform:** Flutter (mobile-side PDF generation or via dedicated service).

## 🧩 Part 1 — PDF Generation System

### Output Format: `RoavvyPassport.pdf`
- **Structure:**
  - **Page 1: Cover**
    - Navy or Burgundy background.
    - Gold-style minimal text: "ROAVVY", "PASSPORT".
    - Quokka emblem (optional/future).
  - **Page 2+: Stamp Pages**
    - 6–10 stamps per page.
    - Deterministic random placement (jittered grid).
    - Subtle rotation (±20°).
    - Controlled overlapping.
  - **Final Page:**
    - Summary of countries visited.
    - Date range of travels.

## 🎨 Part 2 — Page Composition Layers
- **Layer 1: Background Pattern**
  - Subtle passport-style guilloche or watermark pattern (5–10% opacity).
- **Layer 2: Security Texture** (Optional)
- **Layer 3: Stamp Images**
  - Rendered using existing procedural `StampPainter`.
- **Layer 4: Date Overlays** (Part of stamp rendering).

## 📐 Part 3 — Print Specifications (CRITICAL)
- **Format:** A6 (105mm x 148mm) or equivalent small passport format.
- **Margins:**
  - **Inner (Binding):** 15mm (Safe zone for spine).
  - **Outer:** 10mm.
  - **Top/Bottom:** 12mm.
- **Bleed:** 3mm standard for all edges.
- **Resolution:** 300 DPI equivalent for all rendered elements.

## 🧠 Part 4 — Stamp Layout Logic
- **Adaptation:** Extend `PassportLayoutEngine` to handle multi-page splitting.
- **Allocation:** 
  - If 50 stamps → 8 per page → ~7 pages.
  - Ensure no stamps are clipped by margins or lost in the binding area.

## 📱 Part 5 — Mobile Preview
- **UI:** In-app PDF viewer.
- **UX:**
  - Horizontal swipe (book-like pagination).
  - High-resolution rendering on demand.
  - Smooth zoom/pan support.

## ⚡ Part 6 — Performance Strategy
- **Threading:** PDF generation must run in a background isolate.
- **Caching:** Store generated PDF in app cache; regenerate only if travel data changes.

## 🧾 Part 7 — Export / Print Readiness
- **Metadata:** Include correct PDF trim boxes and bleed boxes.
- **Compatibility:** Optimized for manual upload to Blurb, Lulu, or similar POD services.

---

## 📌 Tasks

### Phase 1: Foundation & Specs
- **[ ] T1: Define Print Layout Schema**
  Define `PassportPrintConfig` (A6 dimensions, margins, bleed, DPI-to-pixels conversion).
- **[ ] T2: Implementation of Background Pattern Renderer**
  Create a widget/painter for the subtle passport-style background pattern.

### Phase 2: PDF Engine
- **[ ] T3: Build PDF Generator Isolate**
  Set up a Flutter isolate using `pdf` package or native bridge to generate multi-page PDF documents.
- **[ ] T4: Implement Cover Page Generator**
  Render the premium softcover (Navy/Gold style).
- **[ ] T5: Multi-page Stamp Layout Logic**
  Adapt `PassportLayoutEngine` to distribute `StampData` across multiple pages while respecting binding safe zones.

### Phase 3: Mobile Experience
- **[ ] T6: Implement Mobile PDF Preview UI**
  Create a book-like preview screen with horizontal swiping and pinch-to-zoom.
- **[ ] T7: PDF Caching & State Management**
  Implement logic to detect data changes and trigger PDF background regeneration.

### Phase 4: Validation & QA
- **[ ] T8: Print-Safe Validation**
  Verify bleed, trim, and margin compliance with external print specs (Blurb/Lulu).
- **[ ] T9: Performance Benchmarking**
  Ensure generation handles 100+ stamps without blocking UI or exhausting memory.

## 🧪 Acceptance Criteria
1. PDF generates successfully with all user stamps.
2. Cover page renders with premium aesthetic.
3. Stamp pages respect 15mm binding margin (no overlapping into spine).
4. Background patterns are visible but subtle.
5. In-app preview allows smooth swiping between all book pages.
6. Output PDF is high-resolution (300 DPI) and correct physical dimensions (A6 + bleed).

## 🚀 Implementation Order
1. Define page specs (size, margins, bleed).
2. Build single page renderer.
3. Extend to multi-page generation.
4. Add cover page.
5. Generate PDF.
6. Implement preview UI.
7. Optimize performance.
8. QA print output.
