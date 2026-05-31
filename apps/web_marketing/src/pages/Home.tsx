import { Link } from 'react-router-dom'

const APP_STORE_URL = 'https://apps.apple.com/'

export default function Home() {
  return (
    <>
      <HeroSection />
      <ProblemSection />
      <GuideSection />
      <PlanSection />
      <CtaSection />
      <FailureSection />
      <SuccessSection />
    </>
  )
}

// ── 1. Hero ───────────────────────────────────────────────────────────────────

function HeroSection() {
  return (
    <section className="relative overflow-hidden bg-navy-900 pt-20 pb-32 md:pt-28 md:pb-40">
      {/* Background glow */}
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-sky-500/8 rounded-full blur-3xl" />
        <div className="absolute top-1/3 right-1/4 w-[300px] h-[300px] bg-blue-600/6 rounded-full blur-2xl" />
      </div>

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <div className="inline-flex items-center gap-2 bg-sky-400/10 border border-sky-400/20 rounded-full px-4 py-1.5 mb-8">
          <span className="w-2 h-2 rounded-full bg-sky-400 animate-pulse" />
          <span className="text-sky-400 text-sm font-medium">Now available on iOS</span>
        </div>

        <h1 className="text-5xl md:text-6xl lg:text-7xl font-extrabold text-white leading-tight tracking-tight max-w-4xl mx-auto">
          Turn your travels into a{' '}
          <span className="bg-gradient-to-r from-sky-400 via-blue-400 to-cyan-400 bg-clip-text text-transparent">
            living world map
          </span>
        </h1>

        <p className="mt-6 text-xl md:text-2xl text-slate-400 leading-relaxed max-w-2xl mx-auto">
          Roavvy scans your photo library on-device, discovers the countries you've visited, unlocks achievements, and helps you relive your journeys.
        </p>

        <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary text-base px-8 py-4 animate-glow"
          >
            <AppleIcon />
            Download on the App Store
          </a>
          <Link to="/features" className="btn-secondary text-base px-8 py-4">
            See how it works
            <ArrowIcon />
          </Link>
        </div>

        {/* Globe illustration */}
        <div className="mt-20 flex justify-center">
          <GlobeIllustration />
        </div>
      </div>
    </section>
  )
}

// ── 2. Problem ────────────────────────────────────────────────────────────────

function ProblemSection() {
  const pains = [
    {
      icon: '📸',
      title: 'Buried in your camera roll',
      body: 'Thousands of travel photos sit unsorted and forgotten. Finding memories from a specific trip takes minutes of scrolling.',
    },
    {
      icon: '🗺️',
      title: 'No visual travel story',
      body: "You know you've been to many places, but there's no single view that shows your full journey across the world.",
    },
    {
      icon: '🏆',
      title: 'Milestones go unnoticed',
      body: 'Reaching 30 countries, visiting a UNESCO World Heritage site — these are real achievements that disappear into the void.',
    },
    {
      icon: '🧢',
      title: 'Generic souvenirs',
      body: "Travel merchandise is mass-produced. Nothing reflects your specific journey, the countries you've actually visited.",
    },
  ]

  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">The problem</span>
          <h2 className="section-heading">
            Travel memories deserve<br />better than a camera roll
          </h2>
          <p className="section-subheading max-w-2xl mx-auto">
            You've explored the world. But your travel story is scattered, invisible, and harder to share than it should be.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {pains.map(({ icon, title, body }) => (
            <div key={title} className="card hover:border-slate-700 transition-colors">
              <div className="text-3xl mb-4">{icon}</div>
              <h3 className="text-white font-semibold mb-2">{title}</h3>
              <p className="text-slate-500 text-sm leading-relaxed">{body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

// ── 3. Guide ──────────────────────────────────────────────────────────────────

function GuideSection() {
  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          <div>
            <span className="section-label">Your guide</span>
            <h2 className="section-heading">
              The story was always<br />in your photos
            </h2>
            <p className="section-subheading">
              Roavvy helps you uncover the travel story already hidden in your photos — privately, visually, and effortlessly.
            </p>
            <p className="text-slate-500 mt-4 leading-relaxed">
              You are the traveller. Roavvy is the tool that makes your journey visible. We don't upload your photos — everything is processed on your device, giving you a beautiful map of your real travels in seconds.
            </p>

            <div className="mt-8 flex flex-col gap-3">
              {[
                'On-device scanning — your photos never leave your phone',
                'Automatic country detection from GPS metadata',
                'Instant visual world map of visited countries',
                'Travel achievements and UNESCO heritage discovery',
              ].map((point) => (
                <div key={point} className="flex items-start gap-3">
                  <svg className="w-5 h-5 text-sky-400 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span className="text-slate-300 text-sm">{point}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="relative flex justify-center">
            <PrivacyBadge />
          </div>
        </div>
      </div>
    </section>
  )
}

// ── 4. Plan ───────────────────────────────────────────────────────────────────

function PlanSection() {
  const steps = [
    {
      num: '01',
      title: 'Scan your photo library',
      body: 'Roavvy reads GPS coordinates from your existing photos — entirely on your device. No uploads. No cloud access required.',
      icon: '📱',
    },
    {
      num: '02',
      title: 'Discover your world',
      body: "Instantly see every country and region you've visited mapped onto a beautiful interactive globe. Unlock achievements as you explore.",
      icon: '🌍',
    },
    {
      num: '03',
      title: 'Share and celebrate',
      body: 'Share your travel map, earn UNESCO heritage badges, play daily challenges, and order personalised merchandise from your real travel history.',
      icon: '✨',
    },
  ]

  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">How it works</span>
          <h2 className="section-heading">Three steps to your travel story</h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 relative">
          {/* Connector line */}
          <div className="hidden md:block absolute top-12 left-1/6 right-1/6 h-px bg-gradient-to-r from-transparent via-sky-500/30 to-transparent" />

          {steps.map(({ num, title, body, icon }, i) => (
            <div key={num} className="relative card text-center hover:border-sky-500/30 transition-colors group">
              <div className="absolute -top-4 left-1/2 -translate-x-1/2 w-8 h-8 rounded-full bg-sky-500 flex items-center justify-center text-white text-xs font-bold shadow-lg shadow-sky-500/40">
                {i + 1}
              </div>
              <div className="text-4xl mt-4 mb-4">{icon}</div>
              <div className="text-sky-400/50 text-xs font-mono mb-2">{num}</div>
              <h3 className="text-white font-semibold text-lg mb-3">{title}</h3>
              <p className="text-slate-500 text-sm leading-relaxed">{body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

// ── 5. CTA ────────────────────────────────────────────────────────────────────

function CtaSection() {
  return (
    <section className="bg-gradient-to-b from-sky-950/40 to-navy-900 py-24">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <span className="section-label">Start today</span>
        <h2 className="section-heading text-4xl md:text-5xl">
          Your world map is<br />waiting to be discovered
        </h2>
        <p className="section-subheading">
          Download Roavvy and find out how far you've really travelled.
        </p>
        <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary text-base px-8 py-4"
          >
            <AppleIcon />
            Download on the App Store
          </a>
          <Link to="/features" className="btn-secondary text-base px-8 py-4">
            See all features
            <ArrowIcon />
          </Link>
        </div>
      </div>
    </section>
  )
}

// ── 6. Avoid Failure ──────────────────────────────────────────────────────────

function FailureSection() {
  const costs = [
    'Travel memories stay buried and are gradually forgotten',
    'Countries visited are lost from memory without a record',
    'There is no easy way to visualise or share your journey',
    'Personal travel milestones are never celebrated',
    'Generic souvenirs replace personalised travel identity',
  ]

  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          <div className="bg-slate-900/50 rounded-2xl border border-red-900/30 p-8">
            <div className="text-red-400 font-semibold text-sm mb-6 flex items-center gap-2">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Without Roavvy
            </div>
            <ul className="space-y-4">
              {costs.map((cost) => (
                <li key={cost} className="flex items-start gap-3">
                  <svg className="w-5 h-5 text-red-500/60 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                  <span className="text-slate-400 text-sm leading-relaxed">{cost}</span>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <span className="section-label">Don't lose your story</span>
            <h2 className="section-heading">
              Every journey deserves to be remembered
            </h2>
            <p className="section-subheading">
              The places you've been to are part of who you are. Without a way to record and celebrate them, they fade. Roavvy keeps your travel identity alive.
            </p>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-primary mt-8 inline-flex"
            >
              <AppleIcon />
              Get started — it's free
            </a>
          </div>
        </div>
      </div>
    </section>
  )
}

// ── 7. Success ────────────────────────────────────────────────────────────────

function SuccessSection() {
  const outcomes = [
    {
      icon: '🌍',
      title: 'A living world map',
      body: "A beautiful visual record of every country you've visited — updating automatically as you scan more photos.",
    },
    {
      icon: '🏅',
      title: 'Travel achievements',
      body: 'Earn badges and milestones for countries visited, continents explored, and UNESCO heritage sites discovered.',
    },
    {
      icon: '🏛️',
      title: 'Daily heritage challenges',
      body: 'Test your knowledge of UNESCO World Heritage Sites with a new daily challenge. Compete and compare with other travellers.',
    },
    {
      icon: '👕',
      title: 'Personalised merchandise',
      body: 'Order t-shirts, prints, and travel products featuring the actual countries from your own journey — not a generic souvenir.',
    },
    {
      icon: '📤',
      title: 'Shareable travel identity',
      body: "Share your world map, achievement cards, and travel stats. Show the world where you've been.",
    },
    {
      icon: '🔒',
      title: 'Privacy by default',
      body: 'Your photos never leave your device. Roavvy reads GPS metadata on-device — no uploads, no cloud scanning.',
    },
  ]

  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">The outcome</span>
          <h2 className="section-heading">Your travel story, finally visible</h2>
          <p className="section-subheading max-w-2xl mx-auto">
            Roavvy users don't just track countries — they build a living record of who they are as travellers.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {outcomes.map(({ icon, title, body }) => (
            <div key={title} className="card hover:border-sky-500/30 hover:-translate-y-0.5 transition-all duration-200 group">
              <div className="text-3xl mb-4">{icon}</div>
              <h3 className="text-white font-semibold mb-2 group-hover:text-sky-400 transition-colors">{title}</h3>
              <p className="text-slate-500 text-sm leading-relaxed">{body}</p>
            </div>
          ))}
        </div>

        <div className="mt-16 text-center">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary text-base px-10 py-4"
          >
            <AppleIcon />
            Download Roavvy — Free on iOS
          </a>
        </div>
      </div>
    </section>
  )
}

// ── Shared icons ──────────────────────────────────────────────────────────────

function AppleIcon() {
  return (
    <svg className="w-5 h-5" viewBox="0 0 814 1000" fill="currentColor">
      <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 405.5 8.2 319.2 8.2 237.2c0-137.7 90-210.4 176-210.4 46.5 0 85.4 30.7 114.9 30.7 28.2 0 71.4-32.5 124.8-32.5 20.3 0 93.7 1.9 156.8 66.8zM586.8 37.9c-6.4 36.5-20.9 72.3-44.2 100.6-23.4 28.5-52.8 49.8-83.3 56.6 0-.6-.1-1.3-.1-1.9 0-35.6 16.1-74.1 38.3-99.7C520.6 65.6 566.4 43 586.8 37.9z" />
    </svg>
  )
}

function ArrowIcon() {
  return (
    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
    </svg>
  )
}

function GlobeIllustration() {
  return (
    <div className="relative w-72 h-72 md:w-96 md:h-96">
      {/* Outer glow ring */}
      <div className="absolute inset-0 rounded-full border border-sky-500/20 animate-ping" style={{ animationDuration: '4s' }} />
      <div className="absolute inset-4 rounded-full border border-sky-500/15" />

      {/* Globe */}
      <div className="absolute inset-8 rounded-full border-2 border-sky-400/40 bg-gradient-to-br from-sky-950/60 to-navy-800/80 shadow-2xl shadow-sky-500/20 flex items-center justify-center overflow-hidden">
        {/* Latitude lines */}
        <svg className="absolute inset-0 w-full h-full opacity-30" viewBox="0 0 200 200">
          <ellipse cx="100" cy="100" rx="80" ry="80" fill="none" stroke="#38BDF8" strokeWidth="0.5" />
          <ellipse cx="100" cy="100" rx="80" ry="40" fill="none" stroke="#38BDF8" strokeWidth="0.5" />
          <ellipse cx="100" cy="100" rx="80" ry="15" fill="none" stroke="#38BDF8" strokeWidth="0.5" />
          <ellipse cx="100" cy="100" rx="40" ry="80" fill="none" stroke="#38BDF8" strokeWidth="0.5" />
          <line x1="20" y1="100" x2="180" y2="100" stroke="#38BDF8" strokeWidth="0.5" />
          <line x1="100" y1="20" x2="100" y2="180" stroke="#38BDF8" strokeWidth="0.3" />
        </svg>

        {/* Location pins */}
        <div className="relative w-full h-full">
          {[
            { top: '28%', left: '42%', delay: '0s' },
            { top: '45%', left: '65%', delay: '0.5s' },
            { top: '55%', left: '35%', delay: '1s' },
            { top: '38%', left: '75%', delay: '1.5s' },
            { top: '62%', left: '55%', delay: '0.3s' },
          ].map(({ top, left, delay }, i) => (
            <div
              key={i}
              className="absolute w-3 h-3 rounded-full bg-amber-400 shadow-lg shadow-amber-400/60 animate-ping"
              style={{ top, left, animationDuration: '2s', animationDelay: delay }}
            />
          ))}
        </div>
      </div>
    </div>
  )
}

function PrivacyBadge() {
  return (
    <div className="relative">
      <div className="w-80 h-80 rounded-3xl bg-gradient-to-br from-sky-950/60 to-navy-800 border border-sky-500/20 shadow-2xl shadow-sky-500/10 flex flex-col items-center justify-center p-8 text-center">
        <div className="text-6xl mb-6">🔒</div>
        <h3 className="text-white font-bold text-xl mb-3">Privacy First</h3>
        <p className="text-slate-400 text-sm leading-relaxed">
          Your photos never leave your device. Country detection happens entirely on-device using GPS metadata — not your actual images.
        </p>
        <div className="mt-6 flex items-center gap-2 text-sky-400 text-xs font-medium bg-sky-400/10 px-4 py-2 rounded-full border border-sky-400/20">
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
          </svg>
          100% on-device processing
        </div>
      </div>
    </div>
  )
}
