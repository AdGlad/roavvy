const APP_STORE_URL = 'https://apps.apple.com/'
const SUPPORT_EMAIL = 'admin@roavvy.com'

export default function Download() {
  return (
    <>
      <section className="bg-navy-900 pt-16 pb-24 text-center">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <span className="section-label">Download</span>
          <h1 className="section-heading text-5xl md:text-6xl">
            Get Roavvy
          </h1>
          <p className="section-subheading text-xl">
            Free on iOS. Start discovering your travel story in minutes.
          </p>

          <div className="mt-10 flex flex-col items-center gap-6">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-4 bg-black hover:bg-slate-900 border border-slate-700 hover:border-slate-500 text-white rounded-2xl px-8 py-5 transition-all duration-200 shadow-2xl hover:-translate-y-1 group"
            >
              <AppleIcon size={40} />
              <div className="text-left">
                <div className="text-xs text-slate-400 group-hover:text-slate-300 transition-colors">Download on the</div>
                <div className="text-2xl font-bold tracking-tight leading-tight">App Store</div>
              </div>
            </a>
            <p className="text-slate-600 text-sm">iOS 16.0 or later required &middot; iPhone and iPad</p>
          </div>
        </div>
      </section>

      {/* Key benefits */}
      <section className="bg-navy-950 py-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-2xl font-bold text-white text-center mb-12">Everything — completely free</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
            {[
              { icon: '🌍', title: 'World travel map', body: 'Automatic country detection from your photo library. See your journey on a beautiful interactive globe.' },
              { icon: '🏅', title: 'Travel achievements', body: 'Earn badges for countries, continents, and UNESCO heritage sites — automatically, based on your real travels.' },
              { icon: '🏛️', title: 'Daily heritage challenge', body: 'A new UNESCO World Heritage Site puzzle every day. Track your streak and share your results.' },
              { icon: '🔒', title: 'Privacy by design', body: 'Your photos never leave your phone. Country detection is 100% on-device — no uploads required.' },
              { icon: '📤', title: 'Shareable travel cards', body: 'Create and share travel stats, country count cards, and daily challenge scores.' },
              { icon: '👕', title: 'Personalised merchandise', body: 'Order custom travel products featuring the countries from your actual journey.' },
            ].map(({ icon, title, body }) => (
              <div key={title} className="card flex gap-4">
                <span className="text-3xl shrink-0">{icon}</span>
                <div>
                  <h3 className="text-white font-semibold mb-1">{title}</h3>
                  <p className="text-slate-500 text-sm leading-relaxed">{body}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Screenshots */}
      <section className="bg-navy-900 py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-2xl font-bold text-white mb-3">See it in action</h2>
          <p className="text-slate-500 text-sm mb-12">Real screenshots from the app</p>
          <div className="flex flex-wrap justify-center gap-5">
            {[
              { src: '/images/screenshots/map.jpg', label: 'World Map' },
              { src: '/images/screenshots/achievements.jpg', label: 'Achievements' },
              { src: '/images/screenshots/daily-challange.jpg', label: 'Daily Challenge' },
              { src: '/images/screenshots/travel-status.jpg', label: 'Travel Status' },
              { src: '/images/screenshots/passport.jpg', label: 'Passport' },
            ].map(({ src, label }) => (
              <div key={src} className="flex flex-col items-center gap-3">
                <div className="w-44 rounded-[2rem] border-[5px] border-slate-700 bg-black overflow-hidden shadow-2xl shadow-navy-900/80">
                  <img src={src} alt={label} className="w-full block" loading="lazy" />
                </div>
                <span className="text-slate-500 text-xs font-medium">{label}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Support note */}
      <section className="bg-navy-950 py-16 text-center">
        <div className="max-w-xl mx-auto px-4">
          <h2 className="text-xl font-bold text-white mb-3">Need help?</h2>
          <p className="text-slate-500 text-sm mb-6">If you have trouble downloading or setting up Roavvy, we're here to help.</p>
          <a
            href={`mailto:${SUPPORT_EMAIL}`}
            className="btn-secondary text-sm"
          >
            Contact support &rarr;
          </a>
        </div>
      </section>
    </>
  )
}

function AppleIcon({ size = 20 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 814 1000" fill="currentColor">
      <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 405.5 8.2 319.2 8.2 237.2c0-137.7 90-210.4 176-210.4 46.5 0 85.4 30.7 114.9 30.7 28.2 0 71.4-32.5 124.8-32.5 20.3 0 93.7 1.9 156.8 66.8zM586.8 37.9c-6.4 36.5-20.9 72.3-44.2 100.6-23.4 28.5-52.8 49.8-83.3 56.6 0-.6-.1-1.3-.1-1.9 0-35.6 16.1-74.1 38.3-99.7C520.6 65.6 566.4 43 586.8 37.9z" />
    </svg>
  )
}
