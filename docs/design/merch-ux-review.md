# Roavvy Merch UX Review

> Status: Discovery document — do not implement changes without referencing the roadmap.
> Reviewed against codebase as of M136 (2026-06-04).

---

## What This Document Covers

A first-principles critique of the entire merch experience: from the moment a user could
discover merchandise through to post-purchase. Every screen and flow has been read from
source code.

The core question throughout:

> If a user had visited 42 countries and opened Roavvy today — what would make them think
> "I want that shirt" rather than "maybe later"?

---

## Strengths

### 1. The emotional raw material is exceptional

The app already knows things about the user that no generic store could know:
- every country they have visited
- which year they visited
- how many trips
- which continents
- which UNESCO heritage sites
- their travel identity (13 variants: Globetrotter, Continental Drifter, etc.)
- unlocked achievements with real milestone significance

No competing product has this. This is the biggest untapped asset.

### 2. MerchStory generates genuinely good titles

The `MerchStory.forOption()` system produces emotionally resonant titles:
"Half the World", "The Grand Tour", "Global Citizen", "Every Entry, Every Exit",
"Where It Began". These are titles worth wearing. The wordbank is well-considered.

### 3. LocalMockupPreviewScreen is solid

The current primary commerce screen (M58+) is well-designed:
- Mockup fills ~80% of the screen — visual first
- DraggableScrollableSheet for options keeps context
- T-shirt front/back flip animation is premium
- Circle colour swatches instead of chips — modern
- Pinch-to-zoom on the mockup

### 4. The ranked recommendation system (MerchTemplateRanker) is smart

The "Best Match" featured card at the top of option lists — with a gold badge, larger
preview, and prominent CTA — is the right pattern. The density-aware auto-tuning of
stamp size and scatter produces designs appropriate for the user's travel history.

### 5. Achievement-driven merch with TravelIdentity is emotionally powerful

Entering the merch flow from an achievement unlock is the highest-intent moment in the
app. The `_CelebrationHeader` showing identity emoji + gold display name + italic tagline
(e.g. "Globetrotter — The world is your playground") before the shirt options is exactly
right. This is the emotional hook that differentiates Roavvy from any print-on-demand store.

### 6. Memory Pulse as a merch trigger is clever

An anniversary notification surfacing a photo from the user's Thailand trip in 2019 — then
offering to put it on a shirt — is a fundamentally better trigger than "have you considered
buying something?". It arrives at the right emotional moment.

### 7. MerchShareExporter already exists

`LocalMockupPreviewScreen` already has a share icon in the AppBar that exports the
design. The infrastructure is there — it is simply not being surfaced early enough.

---

## Weaknesses

### 1. The Shop tab is a dead end

The "Shop" navigation tab opens `MerchShopScreen`, which contains two tabs: Cart and
Orders. There is **no way to start a new design from the Shop tab**. A user who opens
the app specifically to create a shirt has nowhere to go.

The shop is a staging area for items already created elsewhere. It is not a shop.

A user who has not recently had a Memory Pulse, and does not navigate to their
Achievement list, cannot discover merch at all. This is the single biggest conversion
gap in the product.

### 2. The cart feels like a list of pending transactions

Cart items are rendered as `ListTile`s with a 56×56 thumbnail. The item title falls back
to "T-shirt · 3 countries" if no name is set. The status badge says "Generating…" or
"Ready to checkout" — functional states, not emotional ones.

There is nothing here that says "these are my travel memories waiting to become real".

### 3. Order history is named "My orders" and looks like a utility screen

`MerchOrdersScreen` renders orders as `ListTile`s. The product name is derived from a
hardcoded lookup: items are named **"Roavvy Test Tee"** (literally the string in the
code, never updated from the test phase) or "Travel Poster". There are no thumbnails.
The status is "Processing" or "In progress" — administrative language.

This screen has the potential to become a personal gallery of physical travel artefacts
the user has bought. Currently it does none of that.

### 4. No price transparency until deep in the funnel

Users see no pricing until they reach `LocalMockupPreviewScreen` (which shows a price)
or the old `MerchVariantScreen` ("From £X"). During the option selection phase —
`PulseMerchOptionScreen` / `AchievementMerchOptionScreen` — there is no price anywhere.
Users are choosing between ~15 design options without knowing what anything costs. This
creates an implicit anxiety that delays commitment.

### 5. Post-purchase celebration does not show the design

`MerchPostPurchaseScreen` shows a 🎉 emoji, confetti, and "Your order is on its way!".
It does **not** show the shirt they just bought. The first thing someone wants to see
after buying is confirmation that the product looks right. The second thing they want to
do is share it. Currently the share text is a generic string; the design is never shown.

### 6. The "Customise Design" sheet labels are abstract

The `MerchCustomisationSheet` offers: Layout, Scatter, Density, Stamps. These are
engineer labels. "Scatter" means nothing to a customer. "Dense" vs "Sparse" is
unappealing. These options need to be reframed as outcomes: "Tightly packed", "More
breathing room", "Every stamp counted", "Just the highlights".

### 7. Too many options, not enough curation

`PulseMerchOptionScreen` renders up to ~20 items: four scopes (trip / year / country /
all-time) × four or five template types, each with a "Customise" row below. Grouped by
template type with ALL-CAPS section headers.

This is a catalogue, not a recommendation. The user is presented with a decision matrix
rather than guided towards a purchase. The "Best Match" featured card at the top is
good, but the rest of the list works against it by offering equal weight to all options.

### 8. Merch discovery depends entirely on passive triggers

The only ways to reach merch are:
1. A Memory Pulse notification (passive, app-driven)
2. Tapping "Create" in the Merch Moments section of the Stats screen
3. Navigating to Achievements and finding the CTA

None of these are intent-driven. A user who opens the app thinking "I want a shirt for
my Europe trip this year" has no obvious path to find it. They will likely give up.

---

## Friction Points

### Approval checkbox before checkout

`CartItemCheckoutScreen` requires the user to tick a checkbox confirming they have
verified size, colour, design, and print positions — before the checkout button
activates. This is a legally motivated step (custom products cannot be returned), but
the current implementation creates anxiety. The checkbox wording reads like a legal
warning at the most emotionally positive moment of the purchase.

### Mockup generation delay

When the user first enters `LocalMockupPreviewScreen`, the Printful photorealistic
mockup has not been generated yet. The screen shows a local (device-rendered) mockup,
which is lower quality. There is no clear signal to the user that a better image is
loading. The transition from local preview to Printful mockup is technically correct
but not communicated as an upgrade moment.

### Re-rendering spinner

Changing the card template or colour in `LocalMockupPreviewScreen` triggers a
re-render. During this the screen enters `rerendering` state. There is no indication
to the user that what they are seeing is about to change, or that they should wait
before approving. This can lead to approving a stale design.

### Shop tab naming

The nav-bar tab is called "Shop" but contains no products to browse. New users will
open it expecting to browse and find only an empty cart. This creates a mismatch of
expectation vs. reality that undermines trust in the product.

### Cart items awaiting mockup are un-tappable

Items in status `mockupGenerating` are not tappable. The user sees them in the list
with a spinner badge but cannot interact with them. There is no indication of how long
the wait will be, or what happens next.

---

## Missed Opportunities

### 1. The travel identity is not central to the purchase

The `TravelIdentityInfo` system (13 variants, emoji, gold display name, tagline) is
only shown in the `_CelebrationHeader` on the achievement screen. It is not present
in the shop, the cart, the post-purchase screen, or the order history. The most
emotionally resonant feature of the merch system is buried behind an achievement gate.

A user who is a "Passport Collector" should see that identity reflected throughout the
purchase — on the option cards, in the mockup preview, in the post-purchase message, and
in their order history.

### 2. No shareable design before purchase

The `MerchShareExporter` is accessible after the user enters `LocalMockupPreviewScreen`.
But the best moment to share is earlier — when the user sees the "Best Match" card and
immediately thinks "this is it". If they can share the design concept before committing
to purchase, it creates organic marketing and social proof. Currently nothing is
shareable until the user has configured size and colour.

### 3. No collections or grouping of designs

All design options are presented as an undifferentiated list grouped by template type.
There are no:
- Year collections ("Your 2024 Travels")
- Continent collections ("Europe Collection")
- Achievement collections ("Unlocked for: Globetrotter")
- Seasonal / limited drops

The `MerchDrop` and `kCurrentMerchDrops` system exists in the code
(`merch_drop.dart`) but is not visibly surfaced to the user anywhere in the main
navigation.

### 4. Saved designs have no identity

Cart items that have been designed but not yet purchased are mixed with items actively
awaiting checkout. There is no concept of a "wishlist" or "saved designs" gallery —
designs you loved but did not buy today. A user cannot curate a collection of designs
they want to return to.

### 5. Order history has no visual gallery

Past orders are text-only list tiles with no thumbnail. This is the wrong framing
entirely. Past orders are physical objects the user has bought — they are part of their
travel identity. They should be shown as a gallery with the design image, the story
title, and the travel context.

### 6. No size guide at the point of selection

Size selection happens in the `LocalMockupPreviewScreen` bottom sheet. There is no size
guide accessible from that screen. Users who are uncertain about fit will abandon rather
than commit to a custom product they cannot return.

### 7. No upsell from single-country to collection

When a user is looking at a single-country design (e.g. "France Memories"), there is no
path to the "World Collection" option that includes France plus all their other countries.
The two options exist side by side in the list, but there is no narrative that says
"or go bigger — here is your full collection".

### 8. The Merch Moments section in Stats is weak

`MerchMomentsSection` shows up to 3 tiles with a trophy icon, "You unlocked X", and a
small "Create" button. The product label uses generic names: "Flag Grid Tee",
"Passport Stamp Tee". These are template names, not emotional descriptions. Compare
with the MerchStory titles that the option screen generates — the gap in ambition is
large.

---

## Conversion Killers

### 1. No entry point from the shop

A user who opens the Shop tab and wants to create a new design cannot do so. There is
no "Create New Design" or "Design a Shirt" CTA. The blank cart tells them to go to the
map — but for a user not currently scanning, this is a dead end.

**Impact:** Any user arriving at the shop with purchase intent has nowhere to go.

### 2. "Roavvy Test Tee" in order history

The order history shows product names derived from a hardcoded lookup that returns
"Roavvy Test Tee" for most T-shirt orders. This is a test-phase artifact that was
never cleaned up. Any user who sees this in their order history will question whether
the product is production-ready.

**Impact:** Immediately erodes trust in users who have already purchased.

### 3. Fifteen options, zero guidance

The option screen shows ~15–20 items with equal visual weight. The "Best Match" card
at the top is good but the remaining options form a wall of choice. A user looking at
"Tour Dates Customise", "Passport This Trip", "Passport Year", "Passport Country",
"Passport World Collection" all at once is unlikely to commit to any of them.

**Impact:** Choice paralysis. Users defer the decision and often do not return.

### 4. No pricing on the option selection screen

Users invest time exploring designs — rotating through options, seeing the shirts — with
no idea what they cost. When price is finally revealed in the bottom sheet, it can
trigger sticker shock that undoes the emotional momentum built by the design experience.

**Impact:** Late-funnel abandonment after emotional investment.

### 5. Checkbox gate at checkout

The mandatory confirmation checkbox activates legal anxiety at the peak emotional
moment. The wording "I confirm the size, colour, design, and print positions shown
above are correct" — with no visible refund policy context — reads as "if this is
wrong, you lose your money." Many users will hesitate and exit.

**Impact:** Last-stage drop-off from users who would have converted.

### 6. Post-purchase does not reinforce the purchase

After buying, the user sees confetti and a generic message. They cannot see their
design. They cannot add another item. They cannot share the specific design they just
bought. The share text is hard-coded and does not mention the title or travel context
of their order.

**Impact:** No viral moment. No repeat purchase prompt. Low emotional payoff for
completing the purchase.

---

## Emotional Gaps

### The purchase does not feel like "completing the story"

Roavvy's positioning is that merchandise turns memories into physical artefacts. But the
current purchase flow feels like buying a product. The user selects options, approves a
mockup, confirms in a checkbox, completes checkout — these are transactional steps, not
emotional ones. There is no moment where the product says: "You have been to 42
countries. This shirt is proof of that."

### Identity is not reinforced at the right moments

The travel identity system ("Globetrotter", "Passport Collector", "Weekend Wanderer")
is used once, briefly, in the achievement entry flow. It is not woven through the rest
of the purchase. A user whose identity is "Continental Drifter" should encounter that
label when designing their "Across Three Continents" shirt, when reviewing their cart,
and when they receive their post-purchase screen.

### The shop tab communicates scarcity and emptiness

An empty cart with the message "Your cart is empty. Head to the map, pick your countries,
and design your first personalised t-shirt" is not an inspiring discovery surface. It
tells the user there is nothing here for them yet. Compare with Airbnb's wishlist screen
(empty state shows beautiful destinations with "Save places you love") or Strava's trophy
case ("Your achievements will appear here"). The empty state should create aspiration, not
describe absence.

### The wait for a mockup is not framed as a reveal

When the Printful photorealistic mockup loads (replacing the local device-rendered version),
this should feel like a reveal — the first time the user sees exactly what their shirt will
look like. Currently it is a silent image replacement with no celebration. It should feel
like opening a package.

---

## Landmark Designs — Role in the Experience Hierarchy

### What the Landmark template currently is

The Landmark template generates an AI-produced collage of iconic landmarks for the
user's selected countries using Apple's Image Playground API (`LandmarkImageService`,
implemented in M116). When a user taps a Landmark option card, the app immediately
opens Image Playground — Apple's on-device generative AI — with a curated concept list
built from `_kLandmarkDescriptions` (24 countries with rich prompts such as "Shinto
torii gate at Fushimi Inari shrine, Kyoto, Japan"). The user can confirm or regenerate
the result; the image is then cached to disk and composed onto the shirt.

For multi-country selections the app generates a single collage (not a grid of
individual landmark icons), combining all available landmark descriptions into one
Image Playground concept.

This is technically distinct from every other template: it is the only one that
produces a unique, user-specific AI image rather than a deterministic render of
travel data.

### The device wall is the dominant problem

`LandmarkImageService.isAvailable()` returns `true` only on iOS 18.1+ with Apple
Intelligence. As of 2026 this is still a minority of the active device fleet — older
iPhones, iPhone SE, and users who have not enabled Apple Intelligence all get `false`.
When unavailable, the Landmark option is hidden entirely from both option screens and
the customisation sheet.

The consequence: the most premium, emotionally differentiated design in the catalogue
is invisible to the majority of users, with no indication that it exists. Users on older
devices have no awareness of what they are missing, and no aspiration to upgrade.

**What this means for positioning:** Landmark cannot be the default "Best Match"
recommendation because it fails silently for most users. But treating it as an
invisible conditional feature wastes its potential. The right approach is to make
Landmark visible to everyone — locked behind a device requirement — so it creates
aspiration for users who cannot yet access it.

### The ranking logic underserves the strongest use case

`MerchTemplateRanker` excludes Landmark for `solo` (1 country) and `small` (2–5
countries) density classes. For medium, large, and massive it ranks 4th–6th. The
achievment-context rankings follow a similar pattern.

This is the wrong call for `solo`. A single-country design is exactly when a landmark
image is most coherent and emotionally resonant. "I just returned from Japan" — a
torii gate collage on a shirt is far more personal than a flag grid showing one flag.
The exclusion of Landmark for 1–5 countries eliminates its most compelling use case.

The reasoning is likely technical: with only one or two landmark descriptions available,
Image Playground may not produce a strong collage. But this is a product decision
disguised as a ranking decision. A better approach: include Landmark for solo/small
density at a low priority (rank 5–6), let `MerchTemplateRanker` surface it, and let
the image quality speak for itself. Users who tap it and dislike the result can cancel.

### The flow interruption is a UX mismatch

Every other template renders a shirt preview thumbnail as the option card loads, giving
the user a visual basis for their decision before they tap. Landmark is different: when
the user taps a Landmark card, Image Playground opens immediately — before they have
seen any preview of what the shirt will look like.

This creates a jarring experience:

1. User sees a list of option cards loading.
2. User taps the Landmark card out of curiosity.
3. Image Playground sheet appears — a full-screen Apple UI — before the user has any
   context for why.
4. User generates or cancels. If they cancel, the card shows no preview. If they
   confirm, the card renders.
5. The user now has to understand that the generated image is going on the shirt.

The generation moment should feel like a premium creative act, not an unexpected modal.
The current flow does not frame it as special — it simply appears.

**A better flow:** When a Landmark card is loading, show a distinct "AI Generated"
placeholder (not the same spinner as other templates). On tap, show a brief in-app
explanation: "Your landmark design is unique — generated by Apple Intelligence from
your countries. Create it now." Then open Image Playground. This frames the interaction
as intentional and premium.

### Coverage is limited to 24 countries

`_kLandmarkDescriptions` contains curated prompts for 24 countries. For countries
outside this set, Image Playground receives no description — only the ISO code and
country name — and the output quality is unpredictable. For multi-country collages
where no countries have descriptions, `generateCollage()` returns `null` and the
Landmark template silently fails.

A user who has visited only countries outside the 24 (e.g. Senegal, Mongolia, Bolivia)
will get either no result or a low-quality generic image. The Landmark template will
frustrate rather than delight these users.

This coverage gap should be closed before Landmark is given a more prominent position
in the experience. Expanding `_kLandmarkDescriptions` to 80–100 countries with quality
prompts is a prerequisite for treating Landmark as a tier-one template.

### Where Landmark should sit in the hierarchy

Landmark should be treated as a **premium tier** — distinct from the standard template
gallery, not an equal among equals.

The correct hierarchy:

```
Standard designs (always available)
  Passport · Flags · Heart Flags · Tour Dates · Word Cloud · Badge · Typography

Premium AI design (device-gated)
  Landmark — Your AI-generated landmark collage
```

For users with Apple Intelligence:
- Surface Landmark as a distinct "Premium" card in the option screen — visually
  differentiated (gold border, "AI Generated" chip, distinct background).
- Position it after the featured standard recommendation, not buried in the middle
  of the standard list.
- The "Best Match" standard recommendation leads. Below it, Landmark is offered as
  a premium alternative: "Want something unique? Create your AI landmark design."

For users without Apple Intelligence:
- Show the Landmark card in a locked/greyed state with the label "Requires Apple
  Intelligence on iOS 18+" and the device upgrade message.
- Do not hide it. Visibility creates aspiration; absence creates ignorance.
- This also gives the feature marketing reach beyond its current user base.

### The emotional opportunity being missed

A shirt generated from an AI image of the Fushimi Inari shrine, the Eiffel Tower,
and Machu Picchu — representing a user's actual travels — is a fundamentally different
product from any printed flag grid. It is:

- Unique: no two users with different country sets will get the same shirt.
- Unreplicable: even the same user regenerating will get a different image.
- Cinematic: the Image Playground output is visually striking in a way that geometric
  flag grids are not.
- Conversation-starting: the shirt looks like art, not merchandise.

Currently none of this emotional value is communicated to the user. The Landmark option
appears as one item in a list, labelled "Landmark", with no explanation of what makes
it different or why it is worth the extra step of AI generation.

### Recommended positioning changes (no code changes required for most)

1. **Expand landmark descriptions to 80+ countries** — prerequisite for reliable quality.
2. **Include Landmark for solo/small density at low priority** — the strongest use case
   is currently excluded by the ranker.
3. **Visible lock for non-Apple-Intelligence users** — surface the feature rather than
   hiding it. Add it as a locked entry in the option list with a device requirement label.
4. **Frame the generation step as a premium moment** — in-app explanation before Image
   Playground opens: "Your AI landmark design — unique to your travels."
5. **Visual differentiation in the option list** — gold border, "AI Generated" chip,
   distinct card background to communicate premium status.
6. **Consider premium pricing** — an AI-generated, one-of-a-kind design could command
   a higher price point than standard templates. This is a future commercial lever, not
   an immediate requirement.

---

## Competitive Inspiration

### Spotify Wrapped

**What it does:** Annual data storytelling presented as a narrative arc. Stats are
revealed one at a time with animation and emotional framing. The result is shareable as
a set of visual cards.

**What Roavvy can adapt:**
- Design option screens should present a narrative: "In 2024 you visited 8 countries
  across 3 continents. Here is your year."
- The "Best Match" card should explain *why* it is the best match: "We chose this
  design because your 2024 travels covered Europe and Southeast Asia."
- The post-purchase screen should be a Wrapped-style moment: reveal the design,
  celebrate the stats, make it shareable.

**Avoid:** Roavvy is not annual. The Wrapped moment should be available whenever the
user has a new achievement, not once a year.

### Strava Achievements

**What it does:** Achievements are earned, not bought. Segment KOMs and personal
records feel like real-world accolades. Some achievements unlock physical medals.

**What Roavvy can adapt:**
- Achievement-unlocked exclusive designs are the right model. Not every user can get the
  "Globetrotter" shirt — only users who have visited 50+ countries.
- The visual language of "locked" vs "unlocked" merchandise creates aspiration. A user
  at 40 countries sees the 50-country design and it becomes a goal.
- The idea of a "PR" (personal record) maps well: first new continent, biggest year,
  longest journey.

**Avoid:** Do not gamify the merch purchase itself (e.g. points for buying). The
emotional driver should be the travel, not the shopping.

### Apple Photos Memories

**What it does:** Surprise nostalgia. "On This Day" surfaces a photo you took three
years ago with smooth music and title cards. The experience is not requested — it
arrives.

**What Roavvy can adapt:**
- Memory Pulse is already doing this. The opportunity is to make the path from pulse to
  purchase feel as smooth as Apple Photos → sharing.
- The memory should be *shown* prominently in the merch option screen. A full-bleed
  background image from the trip behind the option list would immediately set the
  emotional context.
- "Inspired by France · 2021" at the top of the option screen is good. It could go
  further: show the hero photo from that trip as the backdrop.

**Avoid:** Apple Photos is passive. The merch step requires active intent. Do not force
the user into a purchase flow from a memory — make the path available but let them choose.

### Airbnb

**What it does:** Discovery is the product. The homepage is travel inspiration, not a
search form. Wishlists allow saving aspirational places. Collections can be shared.

**What Roavvy can adapt:**
- The Shop tab should be a **discovery surface**, not a staging area.
- Wishlists for designs you love but have not purchased — saved, named, shareable.
- Visual collections: "My Europe Designs", "2024 Collection", "Asian Adventures".
- The empty cart state should show inspirational design suggestions based on the user's
  actual travel data — not just tell them to go to the map.

**Avoid:** Airbnb's discovery is location-browsable (browse by city/country). Roavvy's
discovery is personal — the user is exploring their own history, not a catalogue. Do not
create a generic browse-all-designs flow; keep it personalised.

### Artifact Uprising / Chatbooks (photobook products)

**What they do:** Frame the product as an heirloom, not merchandise. "A book of your
year." The order flow emphasises creation over purchase. The packaging is premium and
the unboxing is designed to be shared.

**What Roavvy can adapt:**
- Reframe the post-purchase moment as "You've created something permanent." Not "your
  order is on its way." Show the design. Tell the story of what it represents.
- Order history becomes "My Collection" — physical artefacts, each with a title and
  travel story.
- The confirmation email (if Roavvy controls it) should reinforce the narrative: "Your
  Globetrotter shirt — 42 countries — is being made."

**Avoid:** Photobook products are elaborate, multi-step creation flows. Roavvy's merch
flow is already complex enough. Do not add more creation steps — make the existing
steps feel more meaningful.

### Nike By You

**What it does:** The product is the canvas. You are the creator. Every choice (colour,
sole, lace, text) is shown in real time on a rotating 3D model. The emotional investment
in the design makes the purchase feel inevitable.

**What Roavvy can adapt:**
- The local mockup preview (already 80% screen) should feel like ownership the moment
  the user arrives. The shirt should load immediately with the best-match design.
- Small real-time changes (colour, front/back) should feel like sculpting, not
  form-filling.
- The moment the user settles on a design and looks at it for more than 3 seconds, the
  CTA should become more prominent — they are emotionally committed.

**Avoid:** Nike By You is feature-complete and highly polished. Do not over-engineer the
customisation. Roavvy's competitive edge is the personalisation of the *artwork* (your
countries, your story) — not the product options (colour, size).

---

## Future Vision — The Ideal Roavvy Merch Experience in 12 Months

### Discovery: The Shop becomes a Personal Gallery

When a user opens the Shop tab, they see their travel identity at the top — their travel
name, country count, continent count, years of travel. Below this, three to five
generated design previews: the "right now" recommendation for them. Not a catalogue.
Not a blank cart. A personal preview of what their shirt could look like today.

A user who has just returned from a trip to Japan sees a Passport design titled "Tokyo
Calling" front and centre. They tap it, see a full mockup, and can buy in two taps.

### Browsing: Collections Replace Lists

Designs are organised into collections, not template-type lists. Collections are
personal and dynamic:
- "Your 2024 Collection" (all countries visited in 2024)
- "Europe Series" (all European countries visited across all time)
- "Milestone: 25 Countries" (the achievement they recently unlocked)
- "World Collection" (everything, all time)

Each collection has a visual hero card — the recommended design for that set of
countries — and a count of available options.

### Design Selection: One Clear Recommendation

Instead of showing 15–20 options, the flow leads with the single best-match design,
full screen, with the mockup already rendered. Below it: "Not your style? See 4 other
options." This mirrors how Spotify auto-plays the best song — you can browse, but the
default is great.

The price is visible before the user commits to configuring.

### Customisation: Outcomes, Not Parameters

The customisation sheet uses outcome language:
- "Spread out" vs "Packed tight" (not "Scatter: Low/Medium/High")
- "Show every trip" vs "Just the highlights" (not "Density: Dense/Sparse")
- "Every entry and exit" vs "One stamp per country" (not "Stamps: Entry only / Entry + Exit")

### Cart: Saved Designs Gallery

The cart is renamed or restructured. Items are shown as a gallery with large mockup
images, their story title, and the travel context. Designs awaiting purchase are called
"Saved Designs" — not cart items. The checkout path is always available but never
urgently pushed.

Items that have been purchased move automatically to "My Collection".

### Post-Purchase: The Reveal

After payment, a full-screen reveal: the shirt, large, with its title — "The Grand Tour
· Roavvy: 42 countries". Confetti. The travel identity. A share card showing the design
and the achievement. Two paths: "Share my design" (which shares the design image, not a
generic text) and "Back to my adventures".

Three days later: a push notification with a mockup image — "Your Globetrotter shirt is
being made."

### My Collection: Permanent Gallery

Order history is renamed "My Collection" — or "My Travel Wardrobe". Each item shows the
full mockup image, the story title, the travel context ("42 countries · The Grand Tour"),
and the date ordered. A "Reorder" button creates a new design starting from the same
country set. A "Share" button surfaces the design for social sharing.

### Repeat Purchases: Earned Through Travel

Each time a user unlocks a new achievement — a new continent, a milestone country count,
a new year — a design specific to that achievement is surfaced. These are not generic
designs. They are locked to users who have earned them. A user at 49 countries sees the
"Half the World" design with a lock: "One more country to unlock this design."

This creates a direct link between travel activity and merchandise desire. The product
is a reward for real-world behaviour.

### Social Identity: The Shareable Design

Before purchase, from the option selection screen, users can share a "design preview"
card — the shirt design, their travel title, their country count — as a social card.
This is not an ad for Roavvy. It is a personal flex. "I've been to 42 countries. This
is what it looks like."

Roavvy branding is present but secondary. The user's travel story is primary.
