# M27 — Web Shop: Public Landing Page + Entry Points

**Milestone:** 27
**Phase:** 12 — Commerce & Mobile Completion
**Goal:** Web visitors can discover the shop and be directed into the personalisation flow.

---

## Planner Output

**Goal:** A web visitor can navigate to `/shop`, see the products, and sign in to personalise their design; authenticated users on `/map` and visitors on any shared travel card can reach the shop in one tap.

**Scope — included:**
- `/shop` Next.js page (public, no auth required): two featured product cards (t-shirt + travel poster), tagline, "Sign in to personalise your design" CTA when signed out, "Create my design →" CTA when signed in
- "Shop" nav link added to `/map` header
- "Turn your travels into a poster" CTA block added to `/share/[token]` page, above the App Store section
- Redirect-after-login: `/sign-in` reads `?next` query parameter; on success redirects to `next` instead of `/map`

**Scope — excluded:**
- Country selection, product customisation, or checkout (M28)
- Live Printful/Printify mockup images (static placeholder product images)
- Any mobile changes

**Risks:**
- Redirect-after-login must sanitise `next` to prevent open redirect: only allow relative paths starting with `/`.

---

## Task List

| Task | Description | Status |
|---|---|---|
| 101 | `/shop` public landing page | 🔄 In Progress |
| 102 | Entry point wiring: `/map` nav link + `/share/[token]` CTA + `/sign-in` redirect-after-login | 🔲 Not started |

---

### Task 101 — `/shop` public landing page

**Deliverable:** `apps/web_nextjs/src/app/shop/page.tsx`

**Acceptance criteria:**
1. `GET /shop` renders without requiring authentication.
2. Page shows a headline, tagline, and two product cards: "Travel T-Shirt" and "Travel Poster".
3. Each product card has a name, brief description, and placeholder image area (can be a styled `div` or `next/image` with a static placeholder).
4. When user is **not** signed in: a single "Sign in to personalise your design" button links to `/sign-in?next=/shop`.
5. When user **is** signed in: the CTA changes to "Create my design →" (a link to `/shop/design` — which does not exist yet; render as a disabled button or placeholder for now with text "Country selection coming soon").
6. Page has a "Back to map" link for signed-in users.
7. `npm run build` passes with no TypeScript errors.

---

### Task 102 — Entry point wiring

**Deliverables:**
- `apps/web_nextjs/src/app/map/page.tsx` — "Shop" link in header
- `apps/web_nextjs/src/app/share/[token]/page.tsx` — poster CTA block
- `apps/web_nextjs/src/app/sign-in/page.tsx` — redirect-after-login via `?next` param

**Acceptance criteria:**
1. `/map` header contains a "Shop" link that navigates to `/shop`.
2. `/share/[token]` page shows a "Turn your travels into a poster →" block above the App Store CTA section; clicking links to `/shop`.
3. Navigating to `/sign-in?next=/shop` and signing in successfully redirects to `/shop` instead of `/map`.
4. `next` parameter is sanitised: only values starting with `/` and not containing `//` or a protocol (`http`, `https`) are honoured; all others fall back to `/map`.
5. `npm run build` passes with no TypeScript errors.
