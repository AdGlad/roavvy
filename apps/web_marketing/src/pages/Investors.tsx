const INVESTOR_EMAIL = 'admin@roavvy.com'

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
          Building the travel identity layer<br />
          for the{' '}
          <span className="bg-gradient-to-r from-sky-400 to-blue-400 bg-clip-text text-transparent">
            camera roll generation
          </span>
        </h1>

        <p className="text-xl text-slate-400 leading-relaxed max-w-3xl mx-auto">
          Roavvy turns passive photo libraries into active travel profiles — helping users discover where they've been, celebrate milestones, play location-based challenges, and create personalised merchandise from their real travel history.
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
          Every traveller's journey<br />deserves to be visible
        </h2>
        <p className="section-subheading text-lg max-w-3xl mx-auto">
          Billions of people carry their entire travel history in their pocket — invisible, unsorted, and forgotten in a camera roll. Roavvy is the layer that makes it visible: a living, personal travel identity that grows with every trip.
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
            <h3 className="text-white text-2xl font-bold mb-4">Travel memories are the world's most underutilised personal data</h3>
            <p className="text-slate-400 text-sm leading-relaxed mb-6">
              The average smartphone user has thousands of travel photos. GPS metadata in those photos contains a complete, accurate travel history — yet it is ignored by every major platform.
            </p>
            <ul className="space-y-3">
              {[
                'Travel memories are buried in unsorted camera rolls',
                'No platform translates photos into a travel identity',
                'Travel achievements are invisible and uncelebrated',
                'Generic souvenirs fail to reflect personal journeys',
                'The travel engagement layer is entirely missing from mobile',
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
            <h3 className="text-white text-2xl font-bold mb-4">Roavvy — the travel identity platform</h3>
            <p className="text-slate-400 text-sm leading-relaxed mb-6">
              Roavvy scans photo GPS metadata on-device, builds a rich travel profile, and creates a multi-dimensional engagement platform around it — maps, achievements, challenges, and merchandise.
            </p>
            <ul className="space-y-3">
              {[
                'Instant on-device country detection — no uploads required',
                'Interactive world map built from real photo data',
                'Achievement and badge system for travel milestones',
                'Daily UNESCO heritage challenges for engagement and retention',
                'Personalised merchandise from real travel history',
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
    { icon: '📸', title: 'Photo scanning', body: 'On-device GPS extraction from existing photo libraries. No cloud processing. Instant results.' },
    { icon: '🌍', title: 'World map', body: 'Interactive globe showing every country visited. Automatic updates as photos are scanned.' },
    { icon: '🏆', title: 'Achievements', body: 'Badges for countries, continents, and UNESCO heritage sites. A gamified travel identity.' },
    { icon: '🏛️', title: 'Daily challenges', body: 'UNESCO World Heritage Site puzzles. Daily engagement, streaks, and social sharing.' },
    { icon: '👕', title: 'Merchandise', body: 'Personalised travel products based on real visited countries. Print-on-demand fulfilment.' },
    { icon: '📤', title: 'Social sharing', body: 'Shareable travel maps, achievement cards, and challenge scores.' },
  ]

  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">Product</span>
          <h2 className="section-heading">A multi-surface travel platform</h2>
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
          <h2 className="section-heading">A massive, underserved audience</h2>
          <p className="section-subheading max-w-2xl mx-auto">
            Every person who has ever taken a photo abroad is a potential Roavvy user. The data already exists in their pocket — it just needs to be unlocked.
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
    { icon: '💎', title: 'Premium subscriptions', body: 'Unlock advanced features, unlimited scans, extended history, and premium achievement packs.' },
    { icon: '👕', title: 'Personalised merchandise', body: 'Country flag t-shirts, travel prints, and personalised products. High margin, low operational overhead.' },
    { icon: '🎯', title: 'Heritage and challenge packs', body: 'Premium challenge expansions, thematic UNESCO packs, and travel quiz collections.' },
    { icon: '🤝', title: 'Travel brand partnerships', body: 'Destination discovery, travel brand integrations, and co-branded travel products.' },
    { icon: '🏪', title: 'Printed travel products', body: 'Custom travel maps, passport covers, travel journals, and personalised travel accessories.' },
    { icon: '📊', title: 'Aggregated insights', body: 'Anonymous, aggregated travel trend data for tourism boards, airlines, and destination marketers (opt-in only).' },
  ]

  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">Business model</span>
          <h2 className="section-heading">Multiple revenue streams</h2>
          <p className="section-subheading max-w-2xl mx-auto">
            Roavvy is designed with diversified, scalable revenue from day one — combining subscriptions with high-margin physical products and brand partnerships.
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
          <h2 className="section-heading">The conditions are aligned</h2>
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
            { label: 'Product development', body: 'Expand iOS features, launch Android, develop the web platform and social layer.' },
            { label: 'User acquisition', body: "Invest in App Store optimisation, content marketing, and strategic travel partnerships." },
            { label: 'Merchandise scale', body: 'Build the personalised merchandise pipeline — expand product range and fulfilment capacity.' },
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
          Interested in investing or partnering?
        </h2>
        <p className="text-slate-400 text-lg mb-8">
          To discuss investment or partnership opportunities, reach out directly. We'd love to share more about the product, traction, and roadmap.
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
