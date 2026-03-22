# M14 — Phase 4: Web Sign-Up

**Milestone:** 14
**Phase:** 4 — Web Map
**Goal:** Users can create a Roavvy account on the web with email/password at a dedicated `/sign-up` route.

---

## Planner Output

**Goal:** A visitor can navigate to `/sign-up`, create an account with email + password, and land on their travel map.

**Scope — included:**
- `/sign-up` page as a standalone Next.js route
- Email + password fields; `createUserWithEmailAndPassword`; client-side validation (password ≥ 8 chars)
- Error states: "email already in use", "weak password" (corrected to 8 chars), "network error"
- "Already have an account? Sign in" link → `/sign-in`
- Update `/sign-in`: replace mode toggle with "Don't have an account? Sign up" link → `/sign-up`
- Redirect to `/map` on successful sign-up

**Scope — excluded:**
- Email verification
- Password reset
- Social sign-in on web

**Context:** `/sign-in/page.tsx` already implements a combined sign-in/sign-up toggle. Task 100 extracts sign-up into its own route and cleans up the toggle.

---

## Task List

| Task | Description | Status |
|---|---|---|
| 100 | Create `/sign-up` page + update `/sign-in` links | 🔄 In Progress |

---

### Task 100 — `/sign-up` page + `/sign-in` link update

**Deliverable:**
- `apps/web_nextjs/src/app/sign-up/page.tsx` — standalone sign-up page
- `apps/web_nextjs/src/app/sign-in/page.tsx` — mode toggle removed; "Don't have an account? Sign up" link navigates to `/sign-up`

**Acceptance criteria:**
1. `GET /sign-up` renders a form with email and password fields and a "Create account" submit button.
2. Submitting valid credentials calls `createUserWithEmailAndPassword` and redirects to `/map`.
3. Submitting a password shorter than 8 characters shows "Password must be at least 8 characters." (client-side, before API call).
4. Firebase error `auth/email-already-in-use` shows "An account with this email already exists."
5. Firebase error `auth/weak-password` shows "Password must be at least 8 characters."
6. Any other Firebase error shows "Something went wrong. Please try again."
7. An "Already have an account? Sign in" link navigates to `/sign-in`.
8. Authenticated users visiting `/sign-up` are redirected to `/map`.
9. `/sign-in` page no longer has a mode toggle — it has a "Don't have an account? Sign up" link to `/sign-up`.
10. `npm run build` in `apps/web_nextjs` succeeds with no TypeScript errors.

**Dependencies:** None — `/sign-in` and Firebase auth SDK already exist.

**Risks:** None. This is a straightforward extraction of existing code.
