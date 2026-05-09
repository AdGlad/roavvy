# M102 — Achievement-Aware Merchandise Context System

**Branch:** `milestone/m102-achievement-aware-merchandise-context-system`  
**Status:** Not started  
**Created:** 2026-05-09

---

Act as Roavvy product architect, senior Flutter engineer, and QA reviewer.

focuses on creating a proper shared achievement-to-merchandise context system and generating meaningful preconfigured t-shirt options based on achievement data.

Do not redesign the purchase workflow.

Do not rewrite Memory Pulse.

Do not break the existing working purchase flow.

Continue reusing the same shared merchandise selection experience already used by Memory Pulse.

Primary goal

The system should now intelligently understand:

what achievement triggered the merch flow

what countries/trips/regions/continents relate to the achievement

what t-shirt styles should be generated from that context

Achievements should no longer open generic placeholder t-shirt options.

Instead they should generate relevant preconfigured merchandise concepts.

Critical requirements

You MUST:

continue reusing the existing Memory Pulse merch workflow

preserve all existing working behaviour

preserve artwork consistency through the flow

use safe incremental changes

You MUST NOT:

create a separate achievement purchase workflow

break Memory Pulse

rewrite checkout

rewrite Printful integration

redesign unrelated systems

Goal of this milestone

Create a shared merchandise context layer that can be used by:

Achievements

Memory Pulse

Trips

Year Recaps

Future travel milestones

The system should:

understand the achievement context

determine relevant travel data

generate a list of relevant preconfigured t-shirt options

open the existing merch selection experience

Required support

At minimum support these achievement types:

Country achievements

Examples:

First Country

5 Countries

10 Countries

25 Countries

Generate relevant country-based merchandise options.

Continent achievements

Examples:

Europe Explorer

Africa Explorer

Asia Explorer

Generate continent-specific merchandise options using only visited countries within that continent.

Region achievements

Examples:

Mediterranean Explorer

Southeast Asia Explorer

Generate region-based merchandise options using only countries from the relevant region that the user has visited.

Year achievements

Examples:

10 Countries in One Year

2026 Travel Recap

Generate year-specific merchandise using only travel data from that year.

Trip achievements

Examples:

5 Countries in One Trip

Summer Europe Trip

Generate trip-specific merchandise options.

Passport achievements

Examples:

50 Passport Stamps

Passport Collector

Generate passport-stamp-based merchandise options using actual stamp data where possible.

Required merchandise option types

At minimum support generating:

Passport stamp tees

Flag grid tees

Tour date tees

Single country flag tees

Country badge tees

Timeline/travel recap tees

You do not need to implement every future template yet.

Focus on building the shared context and option generation structure cleanly.

Important design requirements

Generated t-shirt options should feel relevant to the achievement.

Examples:

First Country

Generate:

Single country flag tee

Entry/exit passport stamp tee

Country badge tee

First country commemorative tee

Use the user’s actual first visited country.

5 Countries

Generate:

5-country flag grid

5-country passport stamp tee

“My First Five Countries” tee

5-country tour dates tee

Use the actual countries related to the milestone.

Europe Explorer

Generate:

Europe flag grid

Europe passport stamp tee

Europe tour shirt

Europe route/travel tee

Use only European countries visited by the user.

10 Countries in One Year

Generate:

Year flag grid

Year passport stamp layout

World Tour [Year] tee

Timeline/travel recap tee

Use only travel data from that year.

Scaling requirements

Improve layout scaling logic based on country/stamp count.

Small sets:

larger elements

minimal overlap

Medium sets:

balanced scaling

moderate spacing

Large sets:

smaller elements

controlled overlap/jitter

avoid unreadable layouts

Do not overcrowd designs.

Shared architecture requirement

Do not tightly couple achievement logic directly into the UI.

Create or extend a reusable shared merch context / option generation system that can later support:

Memory Pulse

Achievements

Trips

Recaps

Seasonal events

Future merch triggers

The implementation should fit naturally into the existing Flutter codebase and current architecture.

Do not force a completely new architecture if reusable structures already exist.

UI requirements

The merch selection list should:

continue looking like the current Memory Pulse workflow

display multiple generated tee options

show previews/mockups

show relevant titles/subtitles

show involved flags/countries where relevant

clearly reflect the achievement context

The user should feel:
“These shirts were generated specifically for my travel history.”

Important consistency requirement

Once a generated tee option is selected:

the artwork/design must remain stable through:

design

mockup

confirmation

checkout

unless the user explicitly edits the design.

Deliverables

Shared merch context generation layer.

Achievement-aware merchandise option generation.

Country/continent/region/year/trip/passport support.

Improved tee option relevance.

Shared workflow still reused from Memory Pulse.

No regressions to existing purchase flow.

Explanation of:

what shared structures were introduced

how achievement mapping works

how compatibility with Memory Pulse was preserved

QA checklist

Manually test:

Memory Pulse still works

First Country achievement

5 Countries achievement

Europe Explorer achievement

10 Countries in One Year achievement

Passport achievement

Tee selection list generation

Artwork consistency through flow

Mockup generation

Checkout flow

Scaling quality for:

1 country

5 countries

25 countries

50+ countries

Use safe incremental enhancements.
Prefer extending existing systems over replacing them.
