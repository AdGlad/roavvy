# M188 — Copy, legal and App Store listing for a free app

**Phase:** Free Launch (M184–M189)
**Depends on:** M186 (so the final UI is known)
**Status:** In progress (drafts done; awaiting owner sign-off and website deploy)
**Primary target:** in-app copy · `legal/terms_screen.dart` · App Store Connect · `apps/web_marketing`

---

## 1. Why this exists

App Review checks that the app, its listing and its legal text describe the same product. A
free app whose Terms describe print-on-demand purchases, or whose screenshots show T-shirts,
invites a rejection under 2.3 (accurate metadata), and it is also misleading.

## 2. Tasks

- **T1 In-app copy sweep.** Change any string that *promises* merch to a commerce-neutral
  version when commerce is off. Includes onboarding, achievement descriptions and celebration
  copy. Use `grep -riE "t-shirt|tee|merch|poster|shop|order|print"` across `lib/` outside the
  merch features.
- **T2 Terms of Service.** §6 "Merchandise & Print-on-Demand" and the promo-code and
  fulfilment clauses are shown only when commerce is on. Mirror this in the hosted Terms and
  Privacy Policy on roavvy.com, or reword them as "may offer in future". The owner chooses the
  wording, and legal text needs owner sign-off.
- **T3 App Store Connect** (owner-operated; we prepare the content):
  - description, keywords and promo text with no merch;
  - screenshots from a commerce-off build;
  - age rating;
  - privacy nutrition labels with no Purchases category;
  - review notes saying "All features are free; no purchases in this version".
- **T4 Website.** roavvy.com mentions t-shirts and merch (about 8 references in
  `apps/web_marketing`). Align it to "coming later" or remove. Deploy only from
  `apps/web_marketing`.

## 3. Acceptance

- [ ] No in-app, Terms, listing or website text promises a purchase in v1.0.
- [ ] Owner has signed off on the legal and listing copy.

## As built (2026-11-20)

- **T1 in-app copy.** Swept `lib/` outside the commerce folders. Every string that offers merch
  was already behind `CommerceEntry`/`CommerceGate` after M186, including the "exclusive design
  unlocked" notification (only scheduled when commerce is on, `scan_screen.dart`). No changes.
  `features/web/landing_page.dart` still mentions merch, but it is the Flutter web landing page
  and never ships on iOS.
- **T2 Terms, in-app.** `TermsScreen(commerce:)` defaults to `kCommerceBuild`, the build flag
  rather than the remote switch, so the legal text can't change mid-session. The free Terms
  replace §6 Merchandise, §7 Subscriptions and §8 Promotions with one §6 "Free Service" ("may
  offer paid products in future; we will update these Terms first"). They also drop Printful and
  Shopify from §Third-party and merchandise fulfilment from §Liability, and number sections
  automatically. `kCurrentTermsVersion` is `1.2` for free builds and `1.1` for commerce builds,
  so existing testers re-accept. Test: `test/features/legal/terms_screen_test.dart`.
- **T2 Terms, hosted.** `apps/web_marketing` Terms §7–8 rewritten ("A Free App", "Payments and
  Refunds"), Privacy has no order data, Refund has a "nothing to refund today" overview and the
  subscription sections removed (Roavvy never had subscriptions). All dated 20 November 2026.
- **T3 App Store Connect.** Content pack in `docs/product/app_store_listing_v1.md`: subtitle,
  promo text, description, keywords, screenshot rules, age rating, privacy labels and review
  notes. Items marked "owner to verify" need checking against the build.
- **T4 Website.** Merch removed from Home, Download, Support, Footer (payment badges) and the
  meta/JSON-LD in `index.html`. Features and Home describe it as "coming later"; About and
  Investors say "planned". The merch testimonial was removed. `npm run build` OK. **Not deployed.**

### Open for the owner

- Sign off the legal wording (in-app Terms, hosted Terms, Privacy, Refund) and the listing.
- Home "Travellers love it" testimonials: the app isn't live yet. Unless these are real quotes
  from testers, remove the section, since invented reviews break the ACL and App Review rules.
- In-app Terms §10 "Social Features" describes following, likes and comments. Confirm v1.0 has
  them, or remove the section.
- Deploy the website from `apps/web_marketing` once signed off.
