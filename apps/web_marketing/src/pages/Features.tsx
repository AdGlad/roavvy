const SCAN_VIDEO = '/videos/roavvy-scan-demo.mp4'
const CHALLENGE_VIDEO = '/videos/daily-challenge-demo.mp4'
const SCAN_POSTER = '/images/scan-poster.jpg'
const CHALLENGE_POSTER = '/images/challenge-poster.jpg'

export default function Features() {
  return (
    <>
      <PageHero
        label="Features"
        title="Everything your travel story needs"
        subtitle="From on-device photo scanning to personalised merchandise, Roavvy is built around your real journey."
      />
      <PhotoScanFeature />
      <WorldMapFeature />
      <AchievementsFeature />
      <DailyChallengeFeature />
      <MerchFeature />
      <PrivacyFeature />
    </>
  )
}

function PageHero({ label, title, subtitle }: { label: string; title: string; subtitle: string }) {
  return (
    <section className="bg-navy-900 pt-16 pb-24 text-center">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <span className="section-label">{label}</span>
        <h1 className="section-heading text-4xl md:text-5xl">{title}</h1>
        <p className="section-subheading">{subtitle}</p>
      </div>
    </section>
  )
}

// ── Photo Scanning ────────────────────────────────────────────────────────────

function PhotoScanFeature() {
  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          <div>
            <span className="section-label">Photo scanning</span>
            <h2 className="section-heading">Your camera roll knows where you've been</h2>
            <p className="section-subheading">
              Roavvy reads the GPS coordinates embedded in your existing photos — entirely on your device. No uploads, no cloud processing. Just instant results.
            </p>

            <ul className="mt-8 space-y-4">
              {[
                'Scans up to 2,000 photos per session',
                'GPS metadata read on-device only',
                'Incremental rescans for new photos',
                'Works with photos going back years',
                'No photo content is ever uploaded',
              ].map((item) => (
                <li key={item} className="flex items-start gap-3">
                  <CheckIcon />
                  <span className="text-slate-300 text-sm">{item}</span>
                </li>
              ))}
            </ul>
          </div>

          <VideoCard
            src={SCAN_VIDEO}
            poster={SCAN_POSTER}
            caption="On-device photo scanning — see your countries appear in seconds"
          />
        </div>
      </div>
    </section>
  )
}

// ── World Map ─────────────────────────────────────────────────────────────────

function WorldMapFeature() {
  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          <div className="order-2 lg:order-1">
            <div className="card aspect-square flex items-center justify-center bg-gradient-to-br from-navy-800 to-sky-950/30">
              <div className="text-center">
                <div className="text-8xl mb-4">🌍</div>
                <p className="text-slate-500 text-sm">Interactive world map placeholder</p>
                <p className="text-slate-600 text-xs mt-1">Replace with app screenshot</p>
              </div>
            </div>
          </div>
          <div className="order-1 lg:order-2">
            <span className="section-label">World map</span>
            <h2 className="section-heading">An interactive globe of your real travels</h2>
            <p className="section-subheading">
              Watch countries light up as Roavvy discovers your visits. Pan, zoom, and explore your personal world map — a beautiful visual record of where you've been.
            </p>

            <div className="mt-8 grid grid-cols-2 gap-4">
              {[
                { stat: '195+', label: 'Countries to discover' },
                { stat: '7', label: 'Continents to explore' },
                { stat: '1000+', label: 'UNESCO sites mapped' },
                { stat: '∞', label: 'Journeys to relive' },
              ].map(({ stat, label }) => (
                <div key={label} className="card text-center py-5">
                  <div className="text-2xl font-bold text-sky-400">{stat}</div>
                  <div className="text-slate-500 text-xs mt-1">{label}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

// ── Achievements ──────────────────────────────────────────────────────────────

function AchievementsFeature() {
  const badges = [
    { icon: '🌍', name: 'World Traveller', desc: 'Visit 25 countries' },
    { icon: '🏅', name: 'Continental', desc: 'Visit all 7 continents' },
    { icon: '🏛️', name: 'Heritage Hunter', desc: 'Discover 10 UNESCO sites' },
    { icon: '✈️', name: 'Frequent Flyer', desc: 'Visit 3 countries in a month' },
    { icon: '🗺️', name: 'Explorer', desc: 'Visit 50 countries' },
    { icon: '🌏', name: 'Asia Adventurer', desc: 'Visit 10 Asian countries' },
  ]

  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">Achievements</span>
          <h2 className="section-heading">Celebrate every milestone</h2>
          <p className="section-subheading max-w-2xl mx-auto">
            Every country, every continent, every UNESCO site is a real achievement. Roavvy recognises them automatically and awards you the badge you've earned.
          </p>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
          {badges.map(({ icon, name, desc }) => (
            <div key={name} className="card text-center hover:border-amber-500/30 hover:-translate-y-1 transition-all duration-200 group">
              <div className="text-4xl mb-3">{icon}</div>
              <div className="text-white text-xs font-semibold mb-1 group-hover:text-amber-400 transition-colors">{name}</div>
              <div className="text-slate-600 text-xs">{desc}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

// ── Daily Challenge ────────────────────────────────────────────────────────────

function DailyChallengeFeature() {
  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          <div>
            <span className="section-label">Daily challenge</span>
            <h2 className="section-heading">A new UNESCO heritage puzzle every day</h2>
            <p className="section-subheading">
              Test your knowledge of UNESCO World Heritage Sites with a fresh challenge every morning. Use clues to guess the site, earn streaks, and compare your results.
            </p>

            <div className="mt-8 space-y-4">
              {[
                { icon: '🏛️', text: '1,000+ UNESCO World Heritage Sites' },
                { icon: '🎯', text: 'Up to 5 clues per challenge' },
                { icon: '🔥', text: 'Daily streaks and stats' },
                { icon: '📤', text: 'Share your result as a score grid' },
              ].map(({ icon, text }) => (
                <div key={text} className="flex items-center gap-3">
                  <span className="text-xl">{icon}</span>
                  <span className="text-slate-300 text-sm">{text}</span>
                </div>
              ))}
            </div>
          </div>

          <VideoCard
            src={CHALLENGE_VIDEO}
            poster={CHALLENGE_POSTER}
            caption="Daily UNESCO World Heritage challenge — guess from clues"
          />
        </div>
      </div>
    </section>
  )
}

// ── Merchandise ───────────────────────────────────────────────────────────────

function MerchFeature() {
  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          <div className="order-2 lg:order-1">
            <div className="card aspect-video flex items-center justify-center bg-gradient-to-br from-navy-800 to-amber-950/20">
              <div className="text-center">
                <div className="text-8xl mb-4">👕</div>
                <p className="text-slate-500 text-sm">Merchandise preview placeholder</p>
                <p className="text-slate-600 text-xs mt-1">Replace with product mockup</p>
              </div>
            </div>
          </div>
          <div className="order-1 lg:order-2">
            <span className="section-label">Personalised merchandise</span>
            <h2 className="section-heading">Wear your real travel history</h2>
            <p className="section-subheading">
              Order t-shirts, prints, and travel products featuring the actual country flags from your own journey. Not a souvenir — a statement.
            </p>

            <ul className="mt-8 space-y-3">
              {[
                "Flags from countries you've actually visited",
                'Custom layouts based on your travel map',
                'Print-on-demand — no stock, no waste',
                'Delivered worldwide',
              ].map((item) => (
                <li key={item} className="flex items-start gap-3">
                  <CheckIcon />
                  <span className="text-slate-300 text-sm">{item}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </section>
  )
}

// ── Privacy ───────────────────────────────────────────────────────────────────

function PrivacyFeature() {
  const points = [
    {
      icon: '📱',
      title: 'On-device processing',
      body: 'Country detection happens entirely on your phone. Your photos are never transmitted to any server.',
    },
    {
      icon: '🔍',
      title: 'GPS only, not images',
      body: 'Roavvy reads only the GPS coordinates embedded in photo metadata — not the photo content itself.',
    },
    {
      icon: '💾',
      title: 'You control your data',
      body: 'Your travel data is stored locally on your device. You can delete it at any time.',
    },
    {
      icon: '🚫',
      title: 'No tracking',
      body: 'No behavioural tracking. No selling of data. No third-party analytics on your travel patterns.',
    },
  ]

  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">Privacy-first</span>
          <h2 className="section-heading">Your travels are yours</h2>
          <p className="section-subheading max-w-2xl mx-auto">
            Roavvy is built privacy-first by design. Your photos and location history never leave your device.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {points.map(({ icon, title, body }) => (
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

// ── Shared ────────────────────────────────────────────────────────────────────

function VideoCard({ src, poster, caption }: { src: string; poster: string; caption: string }) {
  return (
    <div className="card p-0 overflow-hidden">
      <video
        autoPlay
        muted
        loop
        playsInline
        poster={poster}
        className="w-full aspect-[9/16] object-cover bg-navy-800"
      >
        <source src={src} type="video/mp4" />
        <div className="aspect-[9/16] flex items-center justify-center bg-navy-800 text-slate-600 text-sm">
          Video placeholder — add {src}
        </div>
      </video>
      <div className="px-4 py-3 border-t border-slate-800/60">
        <p className="text-slate-400 text-sm text-center">{caption}</p>
      </div>
    </div>
  )
}

function CheckIcon() {
  return (
    <svg className="w-5 h-5 text-sky-400 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
    </svg>
  )
}
