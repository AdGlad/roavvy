# Milestone 61 — Passport Card Refinement

**Goal:** Refine and correct the Passport-style card generation and preview so that the design is consistent, visually strong, and reusable across screens.

---

## 🎯 Goal

Ensure the card:
- Looks correct on the Create Card screen
- Scales consistently when shown on confirmation screens
- Maintains visual density and quality
- Supports user customization of text and colors
- Is suitable for printing (tee shirts / posters)

---

## 🧩 Tasks

| Task | Description | Deliverable | Acceptance Criteria |
|---|---|---|---|
| 169 | **Safe Zones & Layout** | `PassportLayoutEngine` update | Stamps avoid top (title) and bottom-left (branding) zones. |
| 170 | **Density & Consistency** | `PassportStampsCard` update | Identical layout algorithm across all screens; large, overlapping stamps. |
| 171 | **Color Configuration** | `CardGeneratorScreen` UI | User can toggle stamp/date colors and multi-color mode. |
| 172 | **Text & Background Fix** | `PassportStampsCard` / `PaperTexturePainter` | No green tint (pure white/transparent); title centered top; Roavvy bottom-left; no underlines. |
| 173 | **Editable Title** | `CardGeneratorScreen` + `shared_models` | User can override auto-generated title; text remains centered in safe zone. |
| 174 | **Single-Image Rendering** | `CardImageRenderer` / `MerchVariantScreen` | Use SAME generated image across all screens; scale only; no re-render. |

---

## ⚠️ Non-Negotiable Rules
- DO NOT regenerate layout between screens.
- DO NOT reposition text dynamically per screen.
- DO NOT overlay text separately.
- ALWAYS use same generated image.
- ALWAYS maintain spacing zones.
