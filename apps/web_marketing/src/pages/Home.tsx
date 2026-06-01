import { Link } from 'react-router-dom'

const APP_STORE_URL = 'https://apps.apple.com/'

export default function Home() {
  return (
    <>
      <HeroSection />
      <SocialProofSection />
      <ProblemSection />
      <ScreenshotsSection />
      <GuideSection />
      <PlanSection />
      <TestimonialsSection />
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
          Your travel story is buried in your camera roll.{' '}
          <span className="bg-gradient-to-r from-sky-400 via-blue-400 to-cyan-400 bg-clip-text text-transparent">
            Roavvy brings it back to life.
          </span>
        </h1>

        <p className="mt-6 text-xl md:text-2xl text-slate-400 leading-relaxed max-w-2xl mx-auto">
          Roavvy is an AI-powered travel discovery platform that transforms your photo library into a living map of your life — without ever uploading your private photos.
        </p>

        <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary text-base px-8 py-4 animate-glow"
          >
            <AppleIcon />
            Download Free on the App Store
          </a>
          <Link to="/features" className="btn-secondary text-base px-8 py-4">
            See how it works
            <ArrowIcon />
          </Link>
        </div>
        <p className="mt-4 text-slate-600 text-sm">
          Free forever &middot; iOS 16+ &middot; Android coming soon
        </p>

        {/* App screenshots */}
        <div className="mt-20 flex justify-center items-end gap-3 md:gap-5">
          <div className="hidden sm:block rounded-[2rem] border-[5px] border-slate-700 bg-black overflow-hidden shadow-2xl shadow-navy-900/80 w-32 md:w-40 -mb-4 opacity-70" style={{ transform: 'rotate(-6deg)' }}>
            <img src="/images/screenshots/achievements.jpg" alt="Travel achievements" className="w-full block" loading="eager" />
          </div>
          <div className="rounded-[2rem] border-[5px] border-slate-600 bg-black overflow-hidden shadow-2xl shadow-sky-500/20 w-44 md:w-56 z-10">
            <img src="/images/screenshots/map.jpg" alt="Interactive world map" className="w-full block" loading="eager" />
          </div>
          <div className="hidden sm:block rounded-[2rem] border-[5px] border-slate-700 bg-black overflow-hidden shadow-2xl shadow-navy-900/80 w-32 md:w-40 -mb-4 opacity-70" style={{ transform: 'rotate(6deg)' }}>
            <img src="/images/screenshots/daily-challange.jpg" alt="Daily challenge" className="w-full block" loading="eager" />
          </div>
        </div>
      </div>
    </section>
  )
}

// ── 2. Social Proof ───────────────────────────────────────────────────────────

function SocialProofSection() {
  const stats = [
    { value: '100%', label: 'Free — always' },
    { value: '195+', label: 'Countries detectable' },
    { value: '1,000+', label: 'UNESCO sites mapped' },
    { value: '0', label: 'Photos ever uploaded' },
  ]

  return (
    <section className="bg-navy-950 py-14 border-b border-slate-800/60">
      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
          {stats.map(({ value, label }) => (
            <div key={label} className="text-center">
              <div className="text-3xl md:text-4xl font-extrabold text-sky-400 mb-1">{value}</div>
              <div className="text-slate-500 text-sm">{label}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

// ── 3. Problem ────────────────────────────────────────────────────────────────

function ProblemSection() {
  const pains = [
    {
      icon: '📸',
      title: 'Memories buried and forgotten',
      body: 'Thousands of travel photos sit unsorted in camera rolls. The story of where you have been is invisible — even to you.',
    },
    {
      icon: '🗺️',
      title: 'No single view of your journey',
      body: "You've seen the world, but there's no platform that shows your complete travel story in one beautiful, living place.",
    },
    {
      icon: '🏆',
      title: 'Milestones uncelebrated',
      body: 'Reaching 30 countries, discovering a UNESCO World Heritage site — these are real achievements that vanish without a trace.',
    },
    {
      icon: '🧢',
      title: 'Souvenirs that mean nothing',
      body: "Travel merchandise is mass-produced and generic. Nothing reflects the countries you've actually stood in.",
    },
  ]

  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">The problem</span>
          <h2 className="section-heading">
            Your memories are disappearing<br />into a camera roll
          </h2>
          <p className="section-subheading max-w-2xl mx-auto">
            Thousands of travel photos sit buried in forgotten folders and social feeds that were never designed to preserve a life of travel. Your story is scattered, invisible, and slipping away.
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

// ── 3. Screenshots ────────────────────────────────────────────────────────────

const FEATURE_SCREENS = [
  { src: '/images/screenshots/map.jpg', alt: 'Interactive world map', label: 'World Map' },
  { src: '/images/screenshots/achievements.jpg', alt: 'Travel achievements', label: 'Achievements' },
  { src: '/images/screenshots/daily-challange.jpg', alt: 'Daily UNESCO challenge', label: 'Daily Challenge' },
  { src: '/images/screenshots/travel-status.jpg', alt: 'Travel status overview', label: 'Travel Status' },
  { src: '/images/screenshots/merchandise.jpg', alt: 'Personalised travel merchandise', label: 'Merch' },
  { src: '/images/screenshots/passport.jpg', alt: 'Travel passport', label: 'Passport' },
]

function ScreenshotsSection() {
  return (
    <section className="bg-navy-900 py-20 overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-12">
          <span className="section-label">See it in action</span>
          <h2 className="section-heading">Everything your travel story needs</h2>
          <p className="section-subheading max-w-xl mx-auto">
            From your interactive world map to daily challenges, achievements, cinematic replays, and personalised merch — all powered by your own photos, entirely on your device.
          </p>
        </div>

        {/* Horizontally scrollable on mobile, centred grid on desktop */}
        <div className="flex gap-4 overflow-x-auto pb-4 snap-x snap-mandatory -mx-4 px-4 scrollbar-none md:justify-center md:overflow-visible md:flex-wrap md:gap-6">
          {FEATURE_SCREENS.map(({ src, alt, label }) => (
            <div key={src} className="snap-center shrink-0 flex flex-col items-center gap-3">
              <div className="rounded-[2rem] border-[5px] border-slate-700 bg-black overflow-hidden shadow-xl w-36 md:w-44">
                <img src={src} alt={alt} className="w-full block" loading="lazy" />
              </div>
              <span className="text-slate-500 text-xs font-medium">{label}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

function GuideSection() {
  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          <div>
            <span className="section-label">Your guide</span>
            <h2 className="section-heading">
              Your digital travel<br />companion
            </h2>
            <p className="section-subheading">
              Roavvy acts like a digital travel companion — helping you relive experiences, celebrate milestones, and turn memories into something tangible.
            </p>
            <p className="text-slate-500 mt-4 leading-relaxed">
              You are the traveller. Roavvy is the platform that makes your journey visible. Your photos never leave your device — everything is processed privately on-device, revealing a living map of your real travels in seconds.
            </p>

            <div className="mt-8 flex flex-col gap-3">
              {[
                'AI-powered on-device scanning — your photos never leave your phone',
                'Automatic country and landmark detection from GPS metadata',
                'An interactive world map that grows with every trip',
                'Travel achievements, heritage discovery, and cinematic travel replays',
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
      body: 'Roavvy reads GPS coordinates from your existing photos — entirely on your device. No uploads. No cloud. No privacy trade-offs.',
      icon: '📱',
    },
    {
      num: '02',
      title: 'Discover where you\'ve been',
      body: 'Instantly see every country and landmark you\'ve visited mapped onto a living, interactive world map. Your travel history becomes visual and alive.',
      icon: '🌍',
    },
    {
      num: '03',
      title: 'Unlock memories, achievements, and creations',
      body: 'Rediscover forgotten journeys, earn travel achievements, play daily UNESCO challenges, and order personalised merchandise from your real travel history.',
      icon: '✨',
    },
  ]

  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">How it works</span>
          <h2 className="section-heading">Simple. Private. Instant.</h2>
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

// ── 5. Testimonials ───────────────────────────────────────────────────────────

const testimonials = [
  {
    quote: "I scanned my library and suddenly had 34 countries lit up on a map I didn't know I had. There were trips I'd completely forgotten about. It was genuinely emotional.",
    name: 'Sarah M.',
    detail: 'Visited 34 countries',
    flag: '🇬🇧',
  },
  {
    quote: "The daily UNESCO challenge has become part of my morning routine. I've learned more about world heritage in a month of playing than I did in years of travelling.",
    name: 'James K.',
    detail: 'Daily challenge streak: 47 days',
    flag: '🇦🇺',
  },
  {
    quote: "I ordered a t-shirt with all the flags from my South East Asia trip and it's my favourite piece of clothing. It's a conversation starter every time I wear it.",
    name: 'Priya R.',
    detail: 'Visited 12 countries',
    flag: '🇸🇬',
  },
]

function TestimonialsSection() {
  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">Travellers love it</span>
          <h2 className="section-heading">Real stories from real journeys</h2>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {testimonials.map(({ quote, name, detail, flag }) => (
            <div key={name} className="card flex flex-col gap-4">
              <div className="flex gap-1">
                {[...Array(5)].map((_, i) => (
                  <svg key={i} className="w-4 h-4 text-amber-400" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                  </svg>
                ))}
              </div>
              <p className="text-slate-300 text-sm leading-relaxed flex-1">"{quote}"</p>
              <div className="flex items-center gap-2 pt-2 border-t border-slate-800/60">
                <span className="text-xl">{flag}</span>
                <div>
                  <div className="text-white text-sm font-semibold">{name}</div>
                  <div className="text-slate-600 text-xs">{detail}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

// ── 6. CTA ────────────────────────────────────────────────────────────────────

function CtaSection() {
  return (
    <section className="bg-gradient-to-b from-sky-950/40 to-navy-900 py-24">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <span className="section-label">Start today</span>
        <h2 className="section-heading text-4xl md:text-5xl">
          Your travel identity is<br />already in your pocket
        </h2>
        <p className="section-subheading">
          Download Roavvy and turn years of hidden memories into a living story you can revisit, share, wear, and keep building.
        </p>
        <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary text-base px-8 py-4"
          >
            <AppleIcon />
            Download Free on the App Store
          </a>
          <Link to="/features" className="btn-secondary text-base px-8 py-4">
            See all features
            <ArrowIcon />
          </Link>
        </div>
        <p className="mt-4 text-slate-600 text-sm">Free forever &middot; iOS 16+ &middot; Android coming soon</p>
      </div>
    </section>
  )
}

// ── 7. Avoid Failure ──────────────────────────────────────────────────────────

function FailureSection() {
  const costs = [
    'Years of travel remain buried and disconnected in your camera roll',
    'Countries you visited are gradually lost from memory, with no record left behind',
    'Your travel story stays invisible — no single place to see it, share it, or celebrate it',
    'Personal milestones go unrecognised and uncelebrated',
    'Generic mass-produced souvenirs fail to capture who you are as a traveller',
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
              Every journey deserves to be more than a forgotten photo
            </h2>
            <p className="section-subheading">
              The places you've been are part of who you are. Without a way to see, celebrate, and share them — they fade. Roavvy keeps your travel identity alive, for good.
            </p>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-primary mt-8 inline-flex"
            >
              <AppleIcon />
              Download Free on iOS
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
      body: "A beautiful, interactive visual record of every country you've visited — growing automatically as you scan more photos.",
    },
    {
      icon: '🏅',
      title: 'Travel achievements',
      body: 'Earn real badges for countries visited, continents explored, and UNESCO World Heritage Sites discovered. Your milestones, recognised.',
    },
    {
      icon: '🎬',
      title: 'Cinematic travel replays',
      body: 'Rediscover forgotten memories through AI-generated travel replays that bring your journeys back to life, visually and emotionally.',
    },
    {
      icon: '👕',
      title: 'Personalised merchandise',
      body: 'Order t-shirts, prints, and travel products featuring the actual countries from your own journey. Not a souvenir — a statement.',
    },
    {
      icon: '📤',
      title: 'Shareable travel identity',
      body: "Share your world map, achievement cards, and travel story. Show the world where you've been — and who you are as a traveller.",
    },
    {
      icon: '🔒',
      title: 'Private by design',
      body: 'Your photos never leave your device. Roavvy reads only GPS metadata on-device — no uploads, no cloud, no compromises.',
    },
  ]

  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">The outcome</span>
          <h2 className="section-heading">A living identity built from your real adventures</h2>
          <p className="section-subheading max-w-2xl mx-auto">
            Roavvy users don't just track countries — they build a living travel identity they can revisit, share, wear, and continue building for the rest of their lives.
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
