const SUPPORT_EMAIL = 'admin@roavvy.com'

const topics = [
  {
    icon: '⬇️',
    title: 'App download and installation',
    questions: [
      'Where can I download Roavvy?',
      'What iOS version is required?',
      'Is Roavvy available on Android?',
      "The app won't install on my device",
    ],
  },
  {
    icon: '📸',
    title: 'Photo scanning',
    questions: [
      'Why does Roavvy need photo library access?',
      'How long does scanning take?',
      'Not all my countries are showing up',
      'My recent photos haven\'t been detected',
    ],
  },
  {
    icon: '🔒',
    title: 'Privacy and data',
    questions: [
      'Are my photos uploaded to any server?',
      'What data does Roavvy store?',
      'How do I delete my travel data?',
      'Does Roavvy share my location history?',
    ],
  },
  {
    icon: '👕',
    title: 'Merchandise and orders',
    questions: [
      'How do I order a personalised t-shirt?',
      'How long does delivery take?',
      'Can I change or cancel my order?',
      "My order arrived damaged or incorrect",
    ],
  },
  {
    icon: '💳',
    title: 'Subscriptions and billing',
    questions: [
      'What is included in the free version?',
      'How do I manage my subscription?',
      'How do I cancel a subscription?',
      'I was charged incorrectly',
    ],
  },
  {
    icon: '🐛',
    title: 'Bug reports',
    questions: [
      'The app crashed or froze',
      'A feature is not working as expected',
      'I found an incorrect country detection',
      'How do I report a bug?',
    ],
  },
]

export default function Support() {
  return (
    <>
      {/* Header */}
      <section className="bg-navy-900 pt-16 pb-24 text-center">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <span className="section-label">Support</span>
          <h1 className="section-heading text-4xl md:text-5xl">How can we help?</h1>
          <p className="section-subheading">
            Browse common topics below or reach us directly by email.
          </p>
          <a
            href={`mailto:${SUPPORT_EMAIL}`}
            className="btn-primary mt-8 text-base px-8 py-4 inline-flex"
          >
            <EmailIcon />
            {SUPPORT_EMAIL}
          </a>
        </div>
      </section>

      {/* Topics */}
      <section className="bg-navy-950 py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-2xl font-bold text-white text-center mb-12">Common support topics</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {topics.map(({ icon, title, questions }) => (
              <div key={title} className="card hover:border-slate-700 transition-colors">
                <div className="text-3xl mb-3">{icon}</div>
                <h3 className="text-white font-semibold mb-4">{title}</h3>
                <ul className="space-y-2">
                  {questions.map((q) => (
                    <li key={q} className="flex items-start gap-2">
                      <svg className="w-4 h-4 text-slate-600 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                      </svg>
                      <a
                        href={`mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(q)}`}
                        className="text-slate-400 hover:text-sky-400 text-sm transition-colors"
                      >
                        {q}
                      </a>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Contact CTA */}
      <section className="bg-navy-900 py-20 text-center">
        <div className="max-w-xl mx-auto px-4">
          <div className="text-5xl mb-6">✉️</div>
          <h2 className="text-2xl font-bold text-white mb-4">Still need help?</h2>
          <p className="text-slate-400 text-sm leading-relaxed mb-8">
            Send us an email and we'll get back to you as quickly as we can. Please include your device model, iOS version, and a description of the issue.
          </p>
          <a
            href={`mailto:${SUPPORT_EMAIL}`}
            className="btn-primary text-base px-8 py-4 inline-flex"
          >
            <EmailIcon />
            Email {SUPPORT_EMAIL}
          </a>
        </div>
      </section>
    </>
  )
}

function EmailIcon() {
  return (
    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
    </svg>
  )
}
