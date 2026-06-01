import { Link } from 'react-router-dom'

const APP_STORE_URL = 'https://apps.apple.com/'

export default function About() {
  return (
    <>
      <MissionSection />
      <StorySection />
      <ValuesSection />
      <AndroidSection />
      <AboutCta />
    </>
  )
}

function MissionSection() {
  return (
    <section className="bg-navy-900 pt-16 pb-24 text-center">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <span className="section-label">About Roavvy</span>
        <h1 className="section-heading text-4xl md:text-5xl">
          We believe every journey deserves to be remembered
        </h1>
        <p className="section-subheading text-lg">
          Roavvy was built for the traveller who knows they've seen the world — but has no single place to see it back.
        </p>
      </div>
    </section>
  )
}

function StorySection() {
  return (
    <section className="bg-navy-950 py-24">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <span className="section-label">The story</span>
        <h2 className="section-heading text-3xl">Built from a simple question</h2>
        <div className="space-y-5 text-slate-400 text-sm leading-relaxed mt-6">
          <p>
            Most people who travel a lot carry thousands of photos on their phones. Those photos contain an exact, GPS-verified record of everywhere they've ever been — buried in metadata that no app ever thought to use.
          </p>
          <p>
            Roavvy was built to change that. By reading the location coordinates already embedded in your photos — entirely on your device, without uploading anything — Roavvy constructs a living map of your real travel history in seconds.
          </p>
          <p>
            From there, it goes further. Achievements for the milestones you've hit. Daily challenges to keep your curiosity alive. Personalised merchandise so your travel identity can be worn, shared, and celebrated — not just stored in a folder.
          </p>
          <p>
            Roavvy is free. It will stay free. The only thing we sell is personalised merchandise — physical products that earn their price because they mean something to the person wearing them.
          </p>
        </div>
      </div>
    </section>
  )
}

function ValuesSection() {
  const values = [
    {
      icon: '🔒',
      title: 'Privacy is non-negotiable',
      body: 'Your photos never leave your device. Country detection runs entirely on-device. We read GPS coordinates — not images, not faces, not anything personal. This is a design constraint, not a feature we can toggle off.',
    },
    {
      icon: '🆓',
      title: 'Free means free',
      body: "Roavvy is free to download and free to use — forever. There are no subscription tiers, no locked features, and no paywalls. We generate revenue only through personalised merchandise that users choose to order.",
    },
    {
      icon: '🌍',
      title: 'Travel is personal',
      body: 'Every travel history is unique. The countries you have visited, the heritage sites you have stood in, the moments you captured — these are yours. Roavvy makes them visible, not generic.',
    },
    {
      icon: '🏛️',
      title: 'Curiosity over consumption',
      body: "The daily UNESCO challenge isn't a game mechanic for retention metrics — it's a genuine attempt to make people curious about the world. We think that's worth building.",
    },
  ]

  return (
    <section className="bg-navy-900 py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="section-label">What we believe</span>
          <h2 className="section-heading">The principles behind Roavvy</h2>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
          {values.map(({ icon, title, body }) => (
            <div key={title} className="card">
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

function AndroidSection() {
  return (
    <section className="bg-navy-950 py-16">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <div className="inline-flex items-center gap-2 bg-green-400/10 border border-green-400/20 rounded-full px-4 py-1.5 mb-6">
          <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
          <span className="text-green-400 text-sm font-medium">Android — coming soon</span>
        </div>
        <h2 className="text-2xl font-bold text-white mb-4">Android is on the way</h2>
        <p className="text-slate-400 text-sm leading-relaxed max-w-xl mx-auto">
          Roavvy is currently available on iOS. Android support is actively in development. If you're an Android user, check back soon — your travel story will be waiting.
        </p>
      </div>
    </section>
  )
}

function AboutCta() {
  return (
    <section className="bg-gradient-to-b from-sky-950/40 to-navy-900 py-24 text-center">
      <div className="max-w-xl mx-auto px-4">
        <h2 className="text-3xl font-bold text-white mb-4">Ready to see your travel story?</h2>
        <p className="text-slate-400 text-sm mb-8">Free on iOS. No sign-up required to start scanning.</p>
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary text-base px-8 py-4"
          >
            Download Free on the App Store
          </a>
          <Link to="/features" className="btn-secondary text-base px-8 py-4">
            Explore features
          </Link>
        </div>
        <p className="mt-4 text-slate-600 text-sm">Questions? <a href="mailto:support@roavvy.com" className="text-sky-400 hover:text-sky-300 transition-colors">support@roavvy.com</a></p>
      </div>
    </section>
  )
}
