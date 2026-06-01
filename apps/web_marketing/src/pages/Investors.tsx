const INVESTOR_EMAIL = 'support@roavvy.com'

export default function Investors() {
  return (
    <>
      <InvestorHero />
      <VisionSection />
      <ProblemSolutionSection />
      <ProductSection />
      <MarketSection />
      <BusinessModelSection />
      <WhyNowSection />
      <FundingSection />
      <InvestorCta />
    </>
  )
}

// ── Hero ──────────────────────────────────────────────────────────────────────

function InvestorHero() {
  return (
    <section className="relative overflow-hidden bg-navy-900 pt-20 pb-32">
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-1/3 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-sky-500/5 rounded-full blur-3xl" />
      </div>

      <div className="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <div className="inline-flex items-center gap-2 bg-sky-400/10 border border-sky-400/20 rounded-full px-4 py-1.5 mb-8">
          <span className="text-sky-400 text-sm font-medium">Seeking investment</span>
        </div>

        <h1 className="text-4xl md:text-5xl lg:text-6xl font-extrabold text-white leading-tight tracking-tight mb-6">
          The platform where travel memories become{' '}
          <span className="bg-gradient-to-r from-sky-400 to-blue-400 bg-clip-text text-transparent">
            a living identity
          </span>
        </h1>

        <p className="text-xl text-slate-400 leading-relaxed max-w-3xl mx-auto">
          Roavvy is an AI-powered travel discovery platform that transforms photo libraries into living maps of users' lives — unlocking achievements, cinematic travel replays, heritage discovery, and personalised merchandise, all without uploading a single private photo.
        </p>

        <div className="mt-10">
          <a
            href={`mailto:${INVESTOR_EMAIL}?subject=Roavvy%20Investment%20Enquiry`}
            className="btn-primary text-base px-8 py-4 inline-flex"
          >
            Discuss investment opportunities
          </a>
        </div>
      </div>
    </section>
  )
}

// ── Vision ────────────────────────────────────────────────────────────────────

function VisionSection() {
  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <span className="section-label">Vision</span>
        <h2 className="section-heading text-4xl">
          Roavvy is building the platform where travel memories become experiences, achievements become identity, and personal history becomes something worth celebrating
        </h2>
        <p className="section-subheading text-lg max-w-3xl mx-auto">
          Billions of people carry their entire travel history in their pocket — invisible, unsorted, and buried in a camera roll. Roavvy is the layer that makes it visible: a living, personal travel identity that grows with every trip and lasts a lifetime.
        </p>
      </div>
    </section>
  )
}

// ── Problem / Solution ────────────────────────────────────────────────────────

function ProblemSolutionSection() {
  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Problem */}
          <div className="card border-red-900/30">
            <div className="text-red-400 font-semibold text-sm mb-6 flex items-center gap-2">
              <span className="text-lg">⚠️</span> The Problem
            </div>
            <h3 className="text-white text-2xl font-bold mb-4">Most travellers have thousands of photos — and no real way to see the story of where they've been</h3>
            <p className="text-slate-400 text-sm leading-relaxed mb-6">
              Memories disappear into camera rolls, forgotten folders, and social feeds that were never designed to preserve a life of travel. GPS metadata in those photos contains a complete travel history — ignored by every major platform.
            </p>
            <ul className="space-y-3">
              {[
                'Travel memories are buried, disconnected, and gradually forgotten',
                'No platform translates photo libraries into a living travel identity',
                'Travel milestones are invisible and go uncelebrated',
                'Generic souvenirs fail to reflect who users actually are as travellers',
                'The travel engagement and identity layer is entirely missing from mobile',
              ].map((p) => (
                <li key={p} className="flex items-start gap-2 text-slate-500 text-sm">
                  <span className="text-red-500/60 mt-0.5">✕</span>
                  {p}
                </li>
              ))}
            </ul>
          </div>

          {/* Solution */}
          <div className="card border-sky-500/20">
            <div className="text-sky-400 font-semibold text-sm mb-6 flex items-center gap-2">
              <span className="text-lg">💡</span> The Solution
            </div>
            <h3 className="text-white text-2xl font-bold mb-4">Roavvy — the AI-powered travel discovery platform</h3>
            <p className="text-slate-400 text-sm leading-relaxed mb-6">
              Roavvy scans photo GPS metadata on-device and transforms it into a multi-dimensional engagement platform — maps, cinematic replays, achievements, daily challenges, and personalised merchandise. Your travel history becomes visual, interactive, and alive.
            </p>
            <ul className="space-y-3">
              {[
                'AI-powered on-device scanning — no uploads, no privacy trade-offs',
                'Living interactive world map built from real photo data',
                'Achievement and badge system tied to real travel milestones',
                'Daily UNESCO heritage challenges driving engagement and retention',
                'Personalised merchandise from custom travel shirts to passport collectibles',
              ].map((p) => (
                <li key={p} className="flex items-start gap-2 text-slate-300 text-sm">
                  <span className="text-sky-400 mt-0.5">✓</span>
                  {p}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </section>
  )
}

// ── Product ───────────────────────────────────────────────────────────────────

function ProductSection() {
  const features = [
    { icon: '🤖', title: 'AI photo scanning', body: 'On-device AI extracts GPS metadata from existing photo libraries. No cloud processing. Zero uploads. Instant results.' },
    { icon: '🌍', title: 'Living world map', body: 'Interactive globe showing every country visited, growing automatically with every new scan.' },
    { icon: '🎬', title: 'Cinematic replays', body: 'AI-generated travel replays that bring forgotten memories back to life — visually and emotionally.' },
    { icon: '🏆', title: 'Achievements', body: 'Badges for countries, continents, and UNESCO heritage sites. A gamified travel identity built from real adventures.' },
    { icon: '🏛️', title: 'Daily challenges', body: 'UNESCO World Heritage Site puzzles driving daily engagement, streaks, and social sharing.' },
    { icon: '👕', title: 'Personalised merchandise', body: 'Custom travel shirts, prints, and passport collectibles generated from real visited countries. Print-on-demand fulfilment.' },
  ]

  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">Product</span>
          <h2 className="section-heading">One platform. Six powerful surfaces.</h2>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map(({ icon, title, body }) => (
            <div key={title} className="card hover:border-sky-500/30 transition-colors">
              <div className="text-3xl mb-3">{icon}</div>
              <h3 className="text-white font-semibold mb-2">{title}</h3>
              <p className="text-slate-500 text-sm leading-relaxed">{body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

// ── Market ────────────────────────────────────────────────────────────────────

function MarketSection() {
  const stats = [
    { value: '1.5B+', label: 'International trips taken per year' },
    { value: '4B+', label: 'Smartphones with photo libraries' },
    { value: '$1T+', label: 'Global travel market' },
    { value: '200M+', label: 'Self-described avid travellers globally' },
  ]

  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">Market opportunity</span>
          <h2 className="section-heading">The data is already in 4 billion pockets</h2>
          <p className="section-subheading max-w-2xl mx-auto">
            Every person who has ever taken a photo abroad is a potential Roavvy user. The travel history already exists — buried in their camera roll. Roavvy is the key that unlocks it.
          </p>
        </div>

        <div className="grid grid-cols-2 lg:grid-cols-4 gap-6 mb-16">
          {stats.map(({ value, label }) => (
            <div key={label} className="card text-center py-8">
              <div className="text-3xl font-bold text-sky-400 mb-2">{value}</div>
              <div className="text-slate-500 text-sm">{label}</div>
            </div>
          ))}
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {[
            { title: 'Core travellers', body: 'Frequent international travellers who actively track and share their travel history. High intent, high LTV.' },
            { title: 'Casual explorers', body: 'Occasional travellers who travel a few times per year and want a simple way to remember and share where they\'ve been.' },
            { title: 'Heritage enthusiasts', body: 'UNESCO heritage, cultural tourism, and history enthusiasts engaged by the daily challenge and site discovery features.' },
          ].map(({ title, body }) => (
            <div key={title} className="card">
              <h3 className="text-white font-semibold mb-2">{title}</h3>
              <p className="text-slate-500 text-sm leading-relaxed">{body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

// ── Business Model ────────────────────────────────────────────────────────────

function BusinessModelSection() {
  const revenues = [
    { icon: '👕', title: 'Personalised merchandise — core revenue', body: 'Country flag t-shirts, travel prints, passport-style collectibles, and custom travel accessories. High margin, print-on-demand fulfilment, zero inventory overhead.' },
    { icon: '🛍️', title: 'Expanding product range', body: 'Custom travel maps, travel journals, phone cases, and passport covers — all generated from the user\'s real visited countries. Each product is unique to its buyer.' },
    { icon: '🤝', title: 'Travel brand partnerships', body: 'Destination discovery integrations, co-branded travel products, and sponsored heritage content — aligned with the platform\'s existing travel identity audience.' },
    { icon: '📊', title: 'Aggregated travel insights', body: 'Anonymous, aggregated travel trend data for tourism boards, airlines, and destination marketers. Opt-in only, privacy-preserving, and entirely separate from any individual user data.' },
    { icon: '🔓', title: 'App is free — by design', body: 'Roavvy is free to download and use. This maximises reach, removes acquisition friction, and concentrates monetisation on high-intent merchandise purchases rather than subscription conversion.' },
    { icon: '📈', title: 'Revenue per engaged user', body: 'Each merchandise order generates meaningful revenue from an already-engaged user who has seen their own travel history and wants to wear it. Conversion intent is uniquely high.' },
  ]

  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">Business model</span>
          <h2 className="section-heading">Free app. High-intent merchandise revenue.</h2>
          <p className="section-subheading max-w-2xl mx-auto">
            Roavvy is free to use — always. Revenue comes from personalised merchandise that users actively want because it's built from their own travel history. No subscription friction. No paywall. Just genuine demand.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {revenues.map(({ icon, title, body }) => (
            <div key={title} className="card hover:border-amber-500/20 transition-colors">
              <div className="text-3xl mb-3">{icon}</div>
              <h3 className="text-white font-semibold mb-2">{title}</h3>
              <p className="text-slate-500 text-sm leading-relaxed">{body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

// ── Why Now ───────────────────────────────────────────────────────────────────

function WhyNowSection() {
  const reasons = [
    { icon: '🤖', title: 'On-device AI is here', body: 'iOS 18+ on-device intelligence makes private, high-quality photo analysis possible without cloud costs or privacy trade-offs.' },
    { icon: '📸', title: 'Camera rolls are massive', body: 'The average user has 2,000+ photos. Richer GPS metadata, better camera hardware, and more frequent travel mean more data to work with.' },
    { icon: '🌏', title: 'Travel is recovering', body: 'Post-pandemic international travel has surpassed 2019 levels. Travel intent and spending are at record highs.' },
    { icon: '🎮', title: 'Gamification is mainstream', body: 'Wordle, Duolingo, Strava — habit-forming daily engagement mechanics are proven to drive retention and sharing.' },
  ]

  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">Why now</span>
          <h2 className="section-heading">The right product at exactly the right moment</h2>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {reasons.map(({ icon, title, body }) => (
            <div key={title} className="card text-center hover:border-sky-500/30 transition-colors">
              <div className="text-4xl mb-4">{icon}</div>
              <h3 className="text-white font-semibold mb-2">{title}</h3>
              <p className="text-slate-500 text-sm leading-relaxed">{body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

// ── Funding ───────────────────────────────────────────────────────────────────

function FundingSection() {
  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">Funding interest</span>
          <h2 className="section-heading">Seeking seed investment</h2>
          <p className="section-subheading">
            Roavvy is seeking seed funding to accelerate product development, grow the user base, and scale the merchandise pipeline.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 mb-12">
          {[
            { label: 'Product development', body: 'Expand iOS features, launch Android, deepen AI capabilities, and develop the social sharing layer.' },
            { label: 'User acquisition', body: 'App Store optimisation, content marketing, influencer travel partnerships, and strategic launch in key travel markets.' },
            { label: 'Merchandise scale', body: 'Expand the personalised merchandise pipeline — broader product range, faster fulfilment, and international shipping coverage.' },
          ].map(({ label, body }) => (
            <div key={label} className="card text-center">
              <div className="w-10 h-10 rounded-full bg-sky-500/20 border border-sky-500/30 mx-auto mb-4 flex items-center justify-center">
                <div className="w-2 h-2 rounded-full bg-sky-400" />
              </div>
              <h3 className="text-white font-semibold mb-2">{label}</h3>
              <p className="text-slate-500 text-sm leading-relaxed">{body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

// ── Investor CTA ──────────────────────────────────────────────────────────────

function InvestorCta() {
  return (
    <section className="bg-gradient-to-b from-sky-950/40 to-navy-900 py-24">
      <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h2 className="text-3xl md:text-4xl font-bold text-white mb-6">
          Ready to back the travel identity platform?
        </h2>
        <p className="text-slate-400 text-lg mb-8">
          Roavvy is building the platform where personal history becomes something worth celebrating. If you're excited about what travel, AI, and identity can become — we'd love to talk.
        </p>
        <a
          href={`mailto:${INVESTOR_EMAIL}?subject=Roavvy%20Investment%20Enquiry`}
          className="btn-primary text-base px-10 py-4 inline-flex"
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
          </svg>
          {INVESTOR_EMAIL}
        </a>
      </div>
    </section>
  )
}
